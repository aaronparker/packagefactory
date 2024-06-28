#Requires -PSEdition Desktop
#Requires -Modules Evergreen, VcRedist
<#
    .SYNOPSIS
    Convert an application into an Intunewin package and import into an Intune tenant.
    Calls scripts/Create-Win32App.ps1 to perform the import based on App.json

    .PARAMETER Path
    Literal path to the packages directory within the downloaded project.

    .PARAMETER PackageManifest
    The package manifest file name stored in each package directory.

    .PARAMETER InstallScript
    Path to the template install script. If the package is configured to use Install.json, the script will be copied into the package.

    .PARAMETER PSAppDeployToolkit
    Path to the PSAppDeployToolkit. If a package is configured to use the PSAppDeployToolkit it will be copied into the package.

    .PARAMETER Application
    An array of application names to import into the target Intune tenant. The application names must match those applications stored in the project.

    .PARAMETER Type
    The package type to import into the target Intune tenant - App or Update. The array passed to Applications must match those application packages defined for this type.

    .PARAMETER WorkingPath
    Path to a working directory used when creating the Intunewin packages.

    .PARAMETER Import
    Switch parameter to specify that the the package should be imported into the Microsoft Intune tenant.

    .PARAMETER Force
    Create the package, even if a matching version already exists.

    .PARAMETER Certificate
    Specifies the certificate that will be used to sign the script or file. Enter a variable that stores an object representing the certificate. Used by Set-AuthenticodeSignature.

    .PARAMETER CertificateSubject
    Specifies the certificate subject name that will be used to sign scripts. Used by Set-AuthenticodeSignature.

    .PARAMETER CertificateThumbprint
    Specifies the certificate thumbprint that will be used to sign scripts. Used by Set-AuthenticodeSignature.

    .PARAMETER TimestampServer
    Uses the specified time stamp server to add a time stamp to the signature. Type the URL of the time stamp server as a string. The URL must start with https:// or http://. Used by Set-AuthenticodeSignature.

    .PARAMETER IncludeChain
    Determines which certificates in the certificate trust chain are included in the digital signature. NotRoot is the default. Used by Set-AuthenticodeSignature.

    .EXAMPLE
    $params = @{
        Path        = "E:\projects\packagefactory\packages"
        Application = "AdobeAcrobatReaderDCMUI"
        Type        = "App"
        WorkingPath = "E:\projects\packagefactory\output"
        Import      = $true
    }
    .\New-Win32Package.ps1 @params

    .NOTES
        Author: Aaron Parker
        Twitter: @stealthpuppy
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "", Justification = "Needed to execute Evergreen or VcRedist commands")]
param (
    [Parameter(Mandatory = $false, HelpMessage = "The package name to create and import into Intune.")]
    [System.String[]] $Application = @(
        "AdobeAcrobatReaderDCMUI",
        "ImageCustomise",
        "Microsoft.NETCurrent",
        "MicrosoftEdgeWebView2",
        "MicrosoftVcRedist2022x86",
        "MicrosoftVcRedist2022x64",
        "PaintDotNetOfflineInstaller",
        "VideoLanVlcPlayer",
        "ZoomMeetings"),

    [Parameter(Mandatory = $false, HelpMessage = "The type of package to create.")]
    [ValidateSet("App", "Update")]
    [System.String] $Type = "App",

    [Parameter(Mandatory = $false, HelpMessage = "The path to the packages in the package factory.")]
    [System.String] $Path = "E:\projects\packagefactory\packages",

    [Parameter(Mandatory = $false, HelpMessage = "The manifest file that defines each package properties. Defaults to 'App.json'.")]
    [System.String] $PackageManifest = "App.json",

    [Parameter(Mandatory = $false, HelpMessage = "The path to the project's Install.ps1 file. This file reads 'Install.json' in the package source to perform an application install.")]
    [System.String] $InstallScript = $([System.IO.Path]::Combine($PSScriptRoot, "Install.ps1")),

    [Parameter(Mandatory = $false, HelpMessage = "The path to the PSAppDeployToolkit. Used if the package supports the PSAppDeployToolkit for install.")]
    [System.String] $PSAppDeployToolkit = $([System.IO.Path]::Combine($PSScriptRoot, "PSAppDeployToolkit", "Toolkit")),

    [Parameter(Mandatory = $false, HelpMessage = "The path to the working directory to be used when creating packages.")]
    [System.String] $WorkingPath = $([System.IO.Path]::Combine($PSScriptRoot, "output")),

    [Parameter(Mandatory = $false, HelpMessage = "Import the package into Microsoft Intune")]
    [System.Management.Automation.SwitchParameter] $Import,

    [Parameter(Mandatory = $false, HelpMessage = "Create the package, even if a matching version already exists.")]
    [System.Management.Automation.SwitchParameter] $Force,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the certificate that will be used to sign the script or file. Enter a variable that stores an object representing the certificate.")]
    [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the certificate subject name that will be used to sign scripts.")]
    [System.String] $CertificateSubject,

    [Parameter(Mandatory = $false, HelpMessage = "Specifies the certificate thumbprint that will be used to sign scripts.")]
    [System.String] $CertificateThumbprint,

    [Parameter(Mandatory = $false, HelpMessage = "Uses the specified time stamp server to add a time stamp to the signature. Type the URL of the time stamp server as a string. The URL must start with https:// or http://.")]
    [System.String] $TimestampServer,

    [Parameter(Mandatory = $false, HelpMessage = "Determines which certificates in the certificate trust chain are included in the digital signature. NotRoot is the default.")]
    [ValidateSet("All", "Signer", "NotRoot")]
    [System.String] $IncludeChain = "NotRoot"
)

begin {
    #region Call functions
    try {
        $ModuleFile = $(Join-Path -Path $PSScriptRoot -ChildPath "New-Win32Package.psm1")
        Test-Path -Path $ModuleFile -PathType "Leaf" -ErrorAction "Stop" | Out-Null
        Import-Module -Name $ModuleFile -Force -ErrorAction "Stop"
    }
    catch {
        throw $_
    }
    #endregion

    # Set information output
    $ProgressPreference = "SilentlyContinue"
    $InformationPreference = "Continue"
    $VerbosePreference = "Continue"
}

process {
    foreach ($ApplicationName in $Application) {

        # Build variables
        Write-Msg -Msg "Application: '$ApplicationName'"
        $AppPath = [System.IO.Path]::Combine($Path, $Type, $ApplicationName)
        $ManifestFile = $([System.IO.Path]::Combine($AppPath, $PackageManifest))
        $ManifestContent = Get-Content -Path $([System.IO.Path]::Combine($AppPath, $PackageManifest))
        $SourcePath = [System.IO.Path]::Combine($WorkingPath, $ApplicationName, "Source")
        $OutputPath = [System.IO.Path]::Combine($WorkingPath, $ApplicationName, "Output")

        # Check that the application package definition exists
        Write-Msg -Msg "Check for path '$ManifestFile'"
        if (Test-Path -Path $ManifestFile -PathType "Leaf") {

            # Get the application details
            Write-Msg -Msg "Read manifest: '$([System.IO.Path]::Combine($Path, $Type, $ApplicationName, $PackageManifest))'"
            $Manifest = $ManifestContent | ConvertFrom-Json -ErrorAction "Stop"
            Write-Msg -Msg "Manifest OK"

            # Lets see if this application is already in Intune and needs to be updated
            $UpdateApp = Test-IntuneWin32App -Manifest $Manifest

            # Create the package and import the application
            if ($UpdateApp -eq $true -or $Force -eq $true) {

                # Create the target directories
                Write-Msg -Msg "Create path: '$SourcePath'"
                New-Item -Path $SourcePath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null
                Write-Msg -Msg "Create path: '$OutputPath'"
                New-Item -Path $OutputPath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null

                # Remove any existing intunewin packages
                Write-Msg -Msg "Removing intunewin packages from '$OutputPath'"
                Get-ChildItem -Path $OutputPath -Recurse -Include "*.intunewin" -ErrorAction "SilentlyContinue" | ForEach-Object { Remove-Item -Path $_.FullName -Force }

                # Download the application installer
                if ($null -eq $Manifest.Application.Filter) {
                    Write-Warning -Message "$ApplicationName not supported for automatic download"
                    Write-Msg -Msg "Please ensure application binaries are saved to: '$SourcePath'"
                }
                else {

                    # Check if there are files in the source folder
                    if ((Get-ChildItem -Path $SourcePath -Recurse -File).Count -gt 0) {
                        Write-Warning -Message "'$SourcePath' is not empty. Package may included extra files"
                    }

                    #region Configure the installer script logic using Install.ps1 or PSAppDeployToolkit
                    if (Test-Path -Path $([System.IO.Path]::Combine($AppPath, "Source", "Deploy-Application.ps1"))) {

                        # Copy the PSAppDeployToolkit into the target path
                        # Update SourcePath to point to the PSAppDeployToolkit\Files directory
                        Write-Msg -Msg "Copy PSAppDeployToolkit to '$SourcePath'"
                        $params = @{
                            Path        = "$PSAppDeployToolkit\*"
                            Destination = $SourcePath
                            Recurse     = $true
                            Exclude     = "Deploy-Application.ps1"
                            ErrorAction = "Stop"
                        }
                        Copy-Item @params
                        $params = @{
                            Path        = $([System.IO.Path]::Combine($AppPath, "Source", "Deploy-Application.ps1"))
                            Destination = $([System.IO.Path]::Combine($SourcePath, "Deploy-Application.ps1"))
                            ErrorAction = "Stop"
                        }
                        Copy-Item @params
                        New-Item -Path $([System.IO.Path]::Combine($SourcePath, "Files")) -ItemType "Directory" -ErrorAction "SilentlyContinue" | Out-Null
                        New-Item -Path $([System.IO.Path]::Combine($SourcePath, "SupportFiles")) -ItemType "Directory" -ErrorAction "SilentlyContinue" | Out-Null
                        $SourcePath = [System.IO.Path]::Combine($SourcePath, "Files")
                    }
                    elseif (Test-Path -Path $([System.IO.Path]::Combine($AppPath, "Source", "Install.json"))) {

                        # Copy the custom Install.ps1 into the target path
                        $Destination = $([System.IO.Path]::Combine($SourcePath, "Install.ps1"))
                        $params = @{
                            Path        = $InstallScript
                            Destination = $Destination
                            ErrorAction = "Stop"
                        }
                        Write-Msg -Msg "Copy install script: '$InstallScript' to '$Destination'"
                        Copy-Item @params
                    }
                    else {
                        Write-Msg -Msg "Install.json does not exist or PSAppDeployToolkit not used"
                    }
                    #endregion

                    # Copy the contents of the source directory from the package definition to the working directory
                    Write-Msg -Msg "Copy: '$([System.IO.Path]::Combine($AppPath, "Source"))' to '$SourcePath'"
                    $params = @{
                        Path        = "$([System.IO.Path]::Combine($AppPath, "Source"))\*"
                        Destination = $SourcePath
                        Recurse     = $true
                        Force       = $true
                        ErrorAction = "Stop"
                    }
                    Copy-Item @params

                    # Download the application installer or run command in .Filter
                    Write-Msg -Msg "Invoke filter: '$($Manifest.Application.Filter)'"
                    if ($Manifest.Application.Filter -match "Get-EvergreenAppFromApi|Get-EvergreenApp") {
                        # Evergreen
                        Write-Msg -Msg "Downloading with Evergreen to: '$SourcePath'"
                        $Result = Invoke-Expression -Command $Manifest.Application.Filter | Save-EvergreenApp -LiteralPath $SourcePath
                    }
                    elseif ($Manifest.Application.Filter -match "Get-VcList") {
                        # VcRedist
                        Write-Msg -Msg "Downloading with Evergreen to: '$SourcePath'"
                        $Result = Invoke-Expression -Command $Manifest.Application.Filter | Save-EvergreenApp -LiteralPath $SourcePath
                    }
                    else {
                        # Other
                        Write-Msg -Msg "Executing command: '$($Manifest.Application.Filter)'"
                        Invoke-Expression -Command $Manifest.Application.Filter
                    }

                    #region Unpack the installer file if its a zip file
                    foreach ($File in $Result) { Write-Msg -Msg "Downloaded: '$($File.FullName)'" }
                    if ($Result.FullName -match "\.zip$") {
                        $params = @{
                            Path            = $Result.FullName
                            DestinationPath = $SourcePath
                            ErrorAction     = "Stop"
                        }
                        Write-Msg -Msg "Expand: '$($Result.FullName)'"
                        Expand-Archive @params
                        Write-Msg -Msg "Delete: '$($Result.FullName)'"
                        Remove-Item -Path $Result.FullName -Force
                    }
                    #endregion

                    #region Run the command defined in PrePackageCmd
                    if ($Manifest.Application.PrePackageCmd.Length -gt 0) {
                        $TempPath = $([System.IO.Path]::Combine($Env:Temp, $Result.BaseName))
                        $params = @{
                            FilePath     = $Result.FullName
                            ArgumentList = $($Manifest.Application.PrePackageCmd -replace "#Path", $TempPath)
                            NoNewWindow  = $true
                            Wait         = $true
                            ErrorAction  = "Stop"
                        }
                        Write-Msg -Msg "Start: '$($Result.FullName) $($Manifest.Application.PrePackageCmd -replace "#Path", $TempPath)'"
                        Start-Process @params

                        $params = @{
                            Path        = "$TempPath\*"
                            Destination = $SourcePath
                            Recurse     = $true
                            Force       = $true
                            ErrorAction = "Stop"
                        }
                        Write-Msg -Msg "Copy from: '$TempPath', to: '$SourcePath'"
                        Copy-Item @params
                        Remove-Item -Path $Result.FullName -Force
                    }
                    #endregion
                }

                # Check for the valid MSI - if changed uninstallation and detection will fail
                if ($Manifest.PackageInformation.SetupType -eq "MSI") {

                    # Get Real GUID from .msi File
                    $MsiID = Get-MsiProductCode -Path $(Join-Path -Path $SourcePath -ChildPath $($Manifest.PackageInformation.SetupFile))
                    $MsiGuid = [System.Guid]::New($MsiID)

                    # Check the GUID in the uninstall string
                    if ($Manifest.Program.UninstallCommand -match "{\w{8}-\w{4}-\w{4}-\w{4}-\w{12}}") {
                        $UninstallGuid = [System.Guid]::New($Matches[0])
                        if (-not($UninstallGuid.Equals($MsiGuid))) {
                            Write-Warning -Message "Uninstall string '$($UninstallGuid.GUID)' does not match MSI package ID: '$($MsiID.GUID)'"
                        }
                    }

                    # Check the GUID in the detection rules
                    foreach ($Rule in ($Manifest.DetectionRule | Where-Object { $_.Type -eq "Registry" })) {
                        if ($Rule.KeyPath -match "{\w{8}-\w{4}-\w{4}-\w{4}-\w{12}}") {
                            $DetectionGuid = [System.Guid]::New($Matches[0])
                            if (-not($DetectionGuid.Equals($MsiGuid))) {
                                Write-Warning -Message "Detection rule registry path '$($Rule.KeyPath)' does not match MSI package ID: '$($MsiID.GUID)'"
                            }
                        }
                    }
                }

                # Sign the scripts in the package
                if ($PSBoundParameters.ContainsKey("Certificate") -or $PSBoundParameters.ContainsKey("CertificateSubject") -or $PSBoundParameters.ContainsKey("CertificateThumbprint")) {
                    if ($PSBoundParameters.ContainsKey("Certificate")) {
                        $params = @{
                            Path        = $SourcePath
                            Certificate = $Certificate
                        }
                    }
                    elseif ($PSBoundParameters.ContainsKey("CertificateSubject")) {
                        $params = @{
                            Path               = $SourcePath
                            CertificateSubject = $CertificateSubject
                        }
                    }
                    elseif ($PSBoundParameters.ContainsKey("CertificateThumbprint")) {
                        $params = @{
                            Path                  = $SourcePath
                            CertificateThumbprint = $CertificateThumbprint
                        }
                    }
                    Write-Msg -Msg "Signing scripts in '$SourcePath'"
                    Set-ScriptSignature @params | ForEach-Object { Write-Msg -Msg "Signed script: $($_.Path)" }
                }

                #region Create the intunewin package
                if ($Result.FullName -match "\.intunewin$") {
                    Write-Msg -Msg "Copy downloaded intunewin file to: '$Path\output'"
                    Copy-Item -Path $Result.FullName -Destination $OutputPath -Force
                }
                else {
                    Write-Msg -Msg "Create intunewin package in: '$Path\output'"
                    $params = @{
                        SourceFolder = $SourcePath
                        SetupFile    = $Manifest.PackageInformation.SetupFile
                        OutputFolder = $OutputPath
                        Force        = $true
                    }
                    $IntuneWinPackage = New-IntuneWin32AppPackage @params
                }

                # Get the package file
                $PackageFile = Get-ChildItem -Path $OutputPath -Recurse -Include "*.intunewin" -ErrorAction "SilentlyContinue"
                if ($null -eq $PackageFile) { throw [System.IO.FileNotFoundException]::New("Intunewin package file not found") }
                if ($PackageFile.Count -gt 1) { throw [System.IO.InvalidDataException]::New("Found more than 1 intunewin file") }
                Write-Msg -Msg "Found package file: '$($PackageFile.FullName)'"
                #endregion

                #region Import the package
                if ($Import -eq $true) {
                    Write-Msg -Msg "-Import specified. Importing package into tenant"

                    # Launch script to import the package
                    Write-Msg -Msg "Create package with: '$PSScriptRoot\scripts\Create-Win32App.ps1'"
                    $params = @{
                        Json        = $([System.IO.Path]::Combine($AppPath, $PackageManifest))
                        PackageFile = $IntuneWinPackage.Path
                    }
                    & "$PSScriptRoot\scripts\Create-Win32App.ps1" @params | Select-Object -Property * -ExcludeProperty "largeIcon"
                }
                #endregion
            }
        }
        else {
            Write-Warning -Message "Cannot find package definition for '$ApplicationName' in '$AppPath'"
        }
    }
}

end {
}
