#Requires -PSEdition Desktop
#Requires -Modules Evergreen, VcRedist
using namespace System.Management.Automation
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
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "", Justification = "Needed to execute Evergreen or VcRedist commands.")]
param (
    [Parameter(Mandatory = $false)]
    [System.String[]] $Application = @(
        "AdobeAcrobatReaderDCMUI",
        "CitrixWorkspaceApp",
        "ImageCustomise",
        "Microsoft.NETCurrent",
        "MicrosoftEdgeWebView2",
        "MicrosoftVcRedist2022x86",
        "MicrosoftVcRedist2022x64",
        "PaintDotNetOfflineInstaller",
        "VideoLanVlcPlayer",
        "ZoomMeetings"),

    [Parameter(Mandatory = $false)]
    [ValidateSet("App", "Update")]
    [System.String] $Type = "App",

    [Parameter(Mandatory = $false)]
    [System.String] $Path = "E:\projects\packagefactory\packages",

    [Parameter(Mandatory = $false)]
    [System.String] $PackageManifest = "App.json",

    [Parameter(Mandatory = $false)]
    [System.String] $InstallScript = $([System.IO.Path]::Combine($PSScriptRoot, "Install.ps1")),

    [Parameter(Mandatory = $false)]
    [System.String] $PSAppDeployToolkit = $([System.IO.Path]::Combine($PSScriptRoot, "PSAppDeployToolkit", "Toolkit")),

    [Parameter(Mandatory = $false)]
    [System.String] $WorkingPath = $([System.IO.Path]::Combine($PSScriptRoot, "output")),

    [Parameter(Mandatory = $false, HelpMessage = "Import the package into Microsoft Intune.")]
    [System.Management.Automation.SwitchParameter] $Import,

    [Parameter(Mandatory = $false, HelpMessage = "Create the package, even if a matching version already exists.")]
    [System.Management.Automation.SwitchParameter] $Force
)

begin {
    #region Functions
    function Write-Msg ($Msg) {
        $Message = [HostInformationMessage]@{
            Message         = "[$(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')]"
            ForegroundColor = "Black"
            BackgroundColor = "DarkCyan"
            NoNewline       = $true
        }
        $params = @{
            MessageData       = $Message
            InformationAction = "Continue"
            Tags              = "Microsoft365"
        }
        Write-Information @params
        $params = @{
            MessageData       = " $Msg"
            InformationAction = "Continue"
            Tags              = "Microsoft365"
        }
        Write-Information @params
    }

    function Get-MsiProductCode {
        <#
            Modified Version of https://www.powershellgallery.com/packages/Get-MsiProductCode/1.0/Content/Get-MsiProductCode.ps1
            from Thomas J. Malkewitz @dotsp1
            mod. by @constey
        #>
        param (
            [Parameter(Mandatory = $true, ValueFromPipeLine = $true)]
            [ValidateScript({
                    if ($_.EndsWith('.msi')) { $true } else { throw "$_ must be an '*.msi' file." }
                    if (Test-Path $_) { $true } else { throw "$_ does not exist." }
                })]
            [System.String[]] $Path
        )
    
        process {
            foreach ($Item in $Path) {
                try {
                    $WindowsInstaller = New-Object -ComObject "WindowsInstaller.Installer"
                    $Database = $WindowsInstaller.GetType0().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $WindowsInstaller, @((Get-Item -Path $Item).FullName, 0))
                    $View = $Database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $Database, ("SELECT Value FROM Property WHERE Property = 'ProductCode'"))
                    $View.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $View, $null)
                    $Record = $View.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $View, $null)
                    Write-Output -InputObject $($record.GetType().InvokeMember('StringData', 'GetProperty', $null, $Record, 1))
                }
                catch {
                    Write-Error -Message $_.Exception.Message
                    break
                }
                finally {
                    $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
                    [Void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($WindowsInstaller)
                }
            }
        }
    }
    #endregion

    # Set information output
    $InformationPreference = "Continue"
    $VerbosePreference = "Continue"
}

process {
    foreach ($ApplicationName in $Application) {

        # Build variables
        Write-Msg -Msg "Application: $ApplicationName"
        $AppPath = [System.IO.Path]::Combine($Path, $Type, $ApplicationName)
        $ManifestPath = Get-Content -Path $([System.IO.Path]::Combine($AppPath, $PackageManifest))
        $SourcePath = [System.IO.Path]::Combine($WorkingPath, $ApplicationName, "Source")
        $OutputPath = [System.IO.Path]::Combine($WorkingPath, $ApplicationName, "Output")

        # Check that the application package definition exists
        if (Test-Path -Path $ManifestPath -PathType "Leaf") {

            # Get the application details
            Write-Msg -Msg "Read manifest: '$([System.IO.Path]::Combine($Path, $Type, $ApplicationName, $PackageManifest))'."
            $Manifest = $ManifestPath | ConvertFrom-Json -ErrorAction "Stop"
            Write-Msg -Msg "Manifest OK"

            # Lets see if this application is already in Intune and needs to be updated
            Remove-Variable -Name "ExistingApp" -ErrorAction "SilentlyContinue"
            $ExistingApp = Get-IntuneWin32App | `
                Select-Object -Property * -ExcludeProperty "largeIcon" | `
                Where-Object { $_.notes -match "PSPackageFactory" } | `
                Where-Object { ($_.notes | ConvertFrom-Json -ErrorAction "SilentlyContinue").Guid -eq $Manifest.Information.PSPackageFactoryGuid } | `
                Sort-Object -Property @{ Expression = { [System.Version]$_.displayVersion }; Descending = $true } -ErrorAction "SilentlyContinue" | `
                Select-Object -First 1

            # Determine whether the new package should be imported
            if ($null -eq $ExistingApp) {
                Write-Msg -Msg "Import new application: '$($Manifest.Information.DisplayName)'"
                $UpdateApp = $true
            }
            elseif ([System.String]::IsNullOrEmpty($ExistingApp.displayVersion)) {
                Write-Msg -Msg "Found matching app but `displayVersion` is null: '$($ExistingApp.displayName)'"
                $UpdateApp = $false
            }
            elseif ($Manifest.PackageInformation.Version -le $ExistingApp.displayVersion) {
                Write-Msg -Msg "Existing Intune app version is current: '$($ExistingApp.displayName)'"
                $UpdateApp = $false
            }
            elseif ($Manifest.PackageInformation.Version -gt $ExistingApp.displayVersion) {
                Write-Msg -Msg "Import application version: '$($Manifest.Information.DisplayName)'"
                $UpdateApp = $true
            }

            # Create the package and import the application
            if ($UpdateApp -eq $true -or $Force -eq $true) {

                # Create the target directories
                Write-Msg -Msg "Create path: '$SourcePath'."
                New-Item -Path $SourcePath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null
                Write-Msg -Msg "Create path: '$OutputPath'."
                New-Item -Path $OutputPath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null

                # Remove any existing intunewin packages
                Write-Msg -Msg "Removing intunewin packages from '$OutputPath'."
                Get-ChildItem -Path $OutputPath -Recurse -Include "*.intunewin" -ErrorAction "SilentlyContinue" | ForEach-Object { Remove-Item -Path $_.FullName -Force }

                # Download the application installer
                if ($null -eq $Manifest.Application.Filter) {
                    Write-Warning -Message "$ApplicationName not supported for automatic download"
                    Write-Msg -Msg "Please ensure application binaries are saved to: '$SourcePath'."
                }
                else {

                    # Check if there are files in the source folder
                    if ((Get-ChildItem -Path $SourcePath -Recurse -File).Count -gt 0) {
                        Write-Warning -Message "'$SourcePath' is not empty. Package may included extra files."
                    }

                    #region Configure the installer script logic using Install.ps1 or PSAppDeployToolkit
                    if (Test-Path -Path $([System.IO.Path]::Combine($AppPath, "Source", "Deploy-Application.ps1"))) {

                        # Copy the PSAppDeployToolkit into the target path
                        # Update SourcePath to point to the PSAppDeployToolkit\Files directory
                        Write-Msg -Msg "Copy PSAppDeployToolkit to '$SourcePath'."
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
                        Write-Msg -Msg "Copy install script: '$InstallScript' to '$Destination'."
                        Copy-Item @params
                    }
                    else {
                        Write-Msg -Msg "Install.json does not exist or PSAppDeployToolkit not used."
                    }
                    #endregion

                    # Copy the contents of the source directory from the package definition to the working directory
                    Write-Msg -Msg "Copy: '$([System.IO.Path]::Combine($AppPath, "Source"))' to '$SourcePath'."
                    $params = @{
                        Path        = "$([System.IO.Path]::Combine($AppPath, "Source"))\*"
                        Destination = $SourcePath
                        Recurse     = $true
                        Force       = $true
                        ErrorAction = "Stop"
                    }
                    Copy-Item @params

                    # Download the application installer via Evergreen and download
                    Write-Msg -Msg "Invoke filter: '$($Manifest.Application.Filter)'"
                    Write-Msg -Msg "Downloading to: '$SourcePath'."
                    $Result = Invoke-Expression -Command $Manifest.Application.Filter | Save-EvergreenApp -CustomPath $SourcePath

                    #region Unpack the installer file if its a zip file
                    foreach ($File in $Result) { Write-Msg -Msg "Downloaded: '$($File.FullName)'." }
                    if ($Result.FullName -match "\.zip$") {
                        $params = @{
                            Path            = $Result.FullName
                            DestinationPath = $SourcePath
                            ErrorAction     = "Stop"
                        }
                        Write-Msg -Msg "Expand: '$($Result.FullName)'."
                        Expand-Archive @params
                        Write-Msg -Msg "Delete: '$($Result.FullName)'."
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
                        Write-Msg -Msg "Start: '$($Result.FullName) $($Manifest.Application.PrePackageCmd -replace "#Path", $TempPath)'."
                        Start-Process @params

                        $params = @{
                            Path        = "$TempPath\*"
                            Destination = $SourcePath
                            Recurse     = $true
                            Force       = $true
                            ErrorAction = "Stop"
                        }
                        Write-Msg -Msg "Copy from: '$TempPath', to: '$SourcePath'."
                        Copy-Item @params
                        Remove-Item -Path $Result.FullName -Force
                    }
                    #endregion
                }

                #region Create the intunewin package
                Write-Msg -Msg "Create intunewin package in: $Path\output."
                $params = @{
                    SourceFolder = $SourcePath
                    SetupFile    = $Manifest.PackageInformation.SetupFile
                    OutputFolder = $OutputPath
                    Force        = $true
                }
                $IntuneWinPackage = New-IntuneWin32AppPackage @params
                #endregion

                #region Import the package
                if ($Import -eq $true) {
                    Write-Msg -Msg "-Import specified. Importing package into tenant."

                    # Get the package file
                    $PackageFile = Get-ChildItem -Path $OutputPath -Recurse -Include "*.intunewin" -ErrorAction "SilentlyContinue"
                    if ($null -eq $PackageFile) { throw [System.IO.FileNotFoundException]::New("Intunewin package file not found.") }
                    if ($PackageFile.Count -gt 1) { throw [System.IO.InvalidDataException]::New("Found more than 1 intunewin file.") }
                    Write-Msg -Msg "Found package file: '$($PackageFile.FullName)'."

                    # Launch script to import the package
                    Write-Msg -Msg "Create package with: '$PSScriptRoot\scripts\Create-Win32App.ps1'."
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
            Write-Warning -Message "Cannot find package definition for '$ApplicationName' in '$AppPath'."
        }
    }
}

end {
}
