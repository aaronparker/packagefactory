#Requires -PSEdition Desktop
#Requires -Modules Evergreen, VcRedist
<#
    Import application packages into Intune locally
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Writes status to the pipeline log.")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "", Justification = "Needed to execute Evergreen or VcRedist commands.")]
param (
    [Parameter()]
    [System.String] $Path = "E:\projects\packagefactory",

    [Parameter()]
    [System.String] $PackageFolder = "packages",

    [Parameter()]
    [System.String] $PackageManifest = "App.json",

    [Parameter()]
    [System.String] $InstallScript = "Install.ps1",

    [Parameter()]
    [System.String[]] $Applications = @("Microsoft.NET",
        "MicrosoftVcRedist2022x86",
        "MicrosoftVcRedist2022x64",
        "AdobeAcrobatReaderDCMUI",
        "ImageCustomise"),

    [Parameter()]
    [ValidateSet("Apps", "Updates")]
    [System.String] $Type = "Apps"
)

# Set information output
$InformationPreference = "Continue"
$VerbosePreference = "Continue"

foreach ($ApplicationName in $Applications) {
    try {
        # Get the application details
        Write-Information -MessageData "Application: $ApplicationName"
        $AppPath = [System.IO.Path]::Combine($Path, $PackageFolder, $Type, $ApplicationName)
        Write-Information -MessageData "Read: $([System.IO.Path]::Combine($AppPath, $PackageManifest))"
        $Manifest = Get-Content -Path $([System.IO.Path]::Combine($AppPath, $PackageManifest)) | ConvertFrom-Json
    }
    catch {
        throw $_
    }

    try {
        # Get existing Win32 app if present
        $DetectCurrentWin32App = $null
        $DetectCurrentWin32App = $allWin32Apps | 
                                 # The line below - is a hack to ensure that the script will continue if Notes field doesn't contain json as expected
                                 Where-Object{$_.notes -like '{"*' } |
                                 Where-Object{($_.notes | ConvertFrom-Json).Guid -eq $Manifest.Information.PSPackageFactoryGuid}

        # Retrieve App metadata from Evergreen
        $AppData = Invoke-Expression -Command $Manifest.Application.Filter
        # NewVersion identified (true/false)
        $NewVersion = ($($DetectCurrentWin32App.displayVersion | Sort-Object -Descending |  Select-Object -First 1) -ne $AppData.Version)
    }
    catch {
        throw $_
    }

    # Download the application installer
    if ($Null -eq $Manifest.Application.Filter) {
        Write-Warning -Message "$ApplicationName not supported for automatic download"
        Write-Information -MessageData "Please ensure application binaries are saved to: $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder))"
    }
    elseif($NewVersion) {
        if ($Manifest.Application.Filter -match "Get-VcList") {

            Write-Information -MessageData "Invoke filter: $($Manifest.Application.Filter)"
            $App = Invoke-Expression -Command $Manifest.Application.Filter
            $Filename = $(Split-Path -Path $App.Download -Leaf)
            Write-Information -MessageData "Package: $($App.Name); $Filename."
            New-Item -Path [System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder) -ItemType "Directory" -Force | Out-Null
            Invoke-WebRequest -Uri $App.Download -OutFile $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder, $Filename)) -UseBasicParsing
        }
        else {

            # Get the application installer via Evergreen and download
            Write-Information -MessageData "Invoke filter: $($Manifest.Application.Filter)"
            Write-Information -MessageData "Downloading to: $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder))"
            $result = Invoke-Expression -Command $Manifest.Application.Filter | Save-EvergreenApp -CustomPath $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder))

            # Unpack the installer file if its a zip file
            Write-Information -MessageData "Downloaded: $($result.FullName)"
            if ($result.FullName -match "\.zip$") {
                $params = @{
                    Path            = $result.FullName
                    DestinationPath = $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder))
                }
                Write-Information -MessageData "Expand: $($result.FullName)"
                Expand-Archive @params
                Remove-Item -Path $result.FullName -Force
            }

            # Run the command defined in PrePackageCmd
            if ($Manifest.Application.PrePackageCmd.Length -gt 0) {
                $TempPath = $([System.IO.Path]::Combine($Env:Temp, $result.BaseName))
                $params = @{
                    FilePath     = $result.FullName
                    ArgumentList = $($Manifest.Application.PrePackageCmd -replace "#Path", $TempPath)
                    NoNewWindow  = $True
                    Wait         = $True
                }
                Write-Information -MessageData "Start: $($result.FullName) $($Manifest.Application.PrePackageCmd -replace "#Path", $TempPath)"
                Start-Process @params

                $params = @{
                    Path        = "$TempPath\*"
                    Destination = $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder))
                    Recurse     = $True
                    Force       = $True
                }
                Write-Information -MessageData "Copy from: $TempPath, to: $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder))"
                Copy-Item @params
                Remove-Item -Path $result.FullName -Force
            }
        }

        # Copy Install.ps1 into the source folder
        if (Test-Path -Path $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder, "Install.json"))) {
            $params = @{
                Path        = $([System.IO.Path]::Combine($Path, $InstallScript))
                Destination = $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder, $InstallScript))
                ErrorAction = "SilentlyContinue"
            }
            Write-Information -MessageData "Copy: $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder, $InstallScript))"
            Copy-Item @params
        }
        else {
            Write-Information -MessageData "Install.json does not exist."
        }
    }

    # Package the application
    if (Test-Path -Path $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder))) {
        $params = @{
            Application       = $ApplicationName
            Path              = $([System.IO.Path]::Combine($Path, $PackageFolder))
            Type              = $Type
            DisplayNameSuffix  = "(Package Factory)"
            Verbose           = $true
        }
        Write-Information -MessageData "Invoke: $Path\Create-Win32App.ps1"
        & "$Path\Create-Win32App.ps1" @params
    }
    else{
        Write-Output "Software package is already updated in Intune"
    }
}
