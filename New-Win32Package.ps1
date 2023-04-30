#Requires -PSEdition Desktop
#Requires -Modules Evergreen, VcRedist
<#
    .SYNOPSIS
    Convert an application into an Intunewin package and imported into an Intune tenant.

    .PARAMETER Path
    Literal path to the packages directory within the downloaded project.

    .PARAMETER PackageManifest
    The package manifest file name stored in each package directory.

    .PARAMETER InstallScript
    The install script file name stored in each package directory.

    .PARAMETER Application
    An array of application names to import into the target Intune tenant. The application names must match those applications stored in the project.

    .PARAMETER Type
    The package type to import into the target Intune tenant - App or Update. The array passed to Applications must match those application packages defined for this type.

    .PARAMETER WorkingPath
    Path to a working directory used when creating the Intunewin packages.

    .PARAMETER Import
    Switch parameter to specify that the the package should be imported into the Microsoft Intune tenant.

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
    [Parameter()]
    [System.String] $Path = "E:\projects\packagefactory\packages",

    [Parameter()]
    [System.String] $PackageManifest = "App.json",

    [Parameter()]
    [System.String] $InstallScript = "Install.ps1",

    [Parameter()]
    [System.String[]] $Application = @(
        "AdobeAcrobatReaderDCMUI",
        "CitrixWorkspaceApp",
        "ImageCustomise",
        "Microsoft.NETCurrent",
        "MicrosoftEdgeWebView2",
        "MicrosoftSupportCenter",
        "MicrosoftVcRedist2022x86",
        "MicrosoftVcRedist2022x64",
        "PaintDotNetOfflineInstaller".
        "VideoLanVlcPlayer",
        "ZoomMeetings"),

    [Parameter()]
    [ValidateSet("App", "Update")]
    [System.String] $Type = "App",

    [Parameter()]
    [ValidateScript({ if (-not(Test-Path -Path $_ -PathType "Container")) { throw "Path not found: '$_'" } })]
    [System.String] $WorkingPath = $([System.IO.Path]::Combine($PSScriptRoot, "output")),

    [Parameter(Mandatory = $false, HelpMessage = "Import the package into Microsoft Intune.")]
    [System.Management.Automation.SwitchParameter] $Import
)

begin {
    function Write-Msg ($Msg) {
        $params = @{
            MessageData       = "[$(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')] $Msg"
            InformationAction = "Continue"
            Tags              = "Intune"
        }
        Write-Information @params
    }

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
            Write-Msg -Msg "Read manifest: $([System.IO.Path]::Combine($Path, $Type, $ApplicationName, $PackageManifest))"
            $Manifest = $ManifestPath | ConvertFrom-Json -ErrorAction "Stop"
            Write-Msg -Msg "Manifest OK"

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
                    Write-Warning -Message "'$SourcePath' is not empty."
                }

                # Copy the contents of the source directory from the package definition to the working directory
                Write-Msg -Msg "Copy '$([System.IO.Path]::Combine($AppPath, "Source"))' to '$SourcePath'."
                $params = @{
                    Path            = "$([System.IO.Path]::Combine($AppPath, "Source"))\*"
                    DestinationPath = $SourcePath
                    Recurse         = $true
                    Force           = $true
                    ErrorAction     = "Stop"
                }
                Copy-Item @params

                # Get the application installer via Evergreen and download
                Write-Msg -Msg "Invoke filter: '$($Manifest.Application.Filter)'"
                Write-Msg -Msg "Downloading to: '$SourcePath'."
                $result = Invoke-Expression -Command $Manifest.Application.Filter | Save-EvergreenApp -CustomPath $SourcePath

                # Unpack the installer file if its a zip file
                Write-Msg -Msg "Downloaded: '$($result.FullName)'."
                if ($result.FullName -match "\.zip$") {
                    $params = @{
                        Path            = $result.FullName
                        DestinationPath = $SourcePath
                        ErrorAction     = "Stop"
                    }
                    Write-Msg -Msg "Expand: '$($result.FullName)'."
                    Expand-Archive @params
                    Write-Msg -Msg "Delete: '$($result.FullName)'."
                    Remove-Item -Path $result.FullName -Force
                }

                # Run the command defined in PrePackageCmd
                if ($Manifest.Application.PrePackageCmd.Length -gt 0) {
                    $TempPath = $([System.IO.Path]::Combine($Env:Temp, $result.BaseName))
                    $params = @{
                        FilePath     = $result.FullName
                        ArgumentList = $($Manifest.Application.PrePackageCmd -replace "#Path", $TempPath)
                        NoNewWindow  = $true
                        Wait         = $true
                        ErrorAction  = "Stop"
                    }
                    Write-Msg -Msg "Start: '$($result.FullName) $($Manifest.Application.PrePackageCmd -replace "#Path", $TempPath)'."
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
                    Remove-Item -Path $result.FullName -Force
                }

                # Copy Install.ps1 into the source folder
                if (Test-Path -Path $([System.IO.Path]::Combine($SourcePath, "Install.json"))) {
                    $params = @{
                        Path        = $([System.IO.Path]::Combine($Path, $InstallScript))
                        Destination = $([System.IO.Path]::Combine($SourcePath, $InstallScript))
                        ErrorAction = "Stop"
                    }
                    Write-Msg -Msg "Copy: $([System.IO.Path]::Combine($SourcePath, $InstallScript))"
                    Copy-Item @params
                }
                else {
                    Write-Msg -Msg "Install.json does not exist."
                }
            }

            #region Create the intunewin package
            Write-Msg -Msg "Create intunewin package in: $Path\output."
            $params = @{
                SourceFolder         = $SourcePath
                SetupFile            = $Manifest.PackageInformation.SetupFile
                OutputFolder         = $OutputPath
                Force                = $true
            }
            New-IntuneWin32AppPackage @params
            #endregion

            #region Import the package
            if ($Import -eq $true) {
                Write-Msg -Msg "-Import specified. Importing package into tenant."

                # Get the package file
                $PackageFile = Get-ChildItem -Path "$OutputPath\output" -Recurse -Include "*.intunewin" -ErrorAction "SilentlyContinue"
                if ($null -eq $PackageFile) { throw [System.IO.FileNotFoundException]::New("Intunewin package file not found.") }
                if ($PackageFile.Count -gt 1) { throw [System.IO.InvalidDataException]::New("Found more than 1 intunewin file.") }
                Write-Msg -Msg "Found package file: '$($PackageFile.FullName)'."

                # Launch script to import the package
                Write-Msg -Msg "Create package with: '$PSScriptRoot\scripts\Create-Win32App.ps1'."
                $params = @{
                    Json        = $([System.IO.Path]::Combine($AppPath, $PackageManifest))
                    PackageFile = $PackageFile.FullName
                }
                & "$PSScriptRoot\scripts\Create-Win32App.ps1" @params | Select-Object -ExcludeProperty "largeIcon"
            }
            #endregion
        }
        else {
            Write-Warning -Message "Cannot find package definition for '$ApplicationName' in '$AppPath'."
        }
    }
}

end {
}
