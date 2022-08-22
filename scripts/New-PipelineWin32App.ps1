#Requires -Modules Evergreen, VcRedist
<#
    Import application packages into Intune
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Writes status to the pipeline log.")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "", Justification = "Needed to execute Evergreen or VcRedist commands.")]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty]
    [System.String[]] $Application,

    [Parameter()]
    [ValidateNotNullOrEmpty]
    [System.String] $Path,

    [Parameter()]
    [System.String] $AppManifest = "Applications.json",

    [Parameter()]
    [System.String] $PackageFolder = "packages",

    [Parameter()]
    [System.String] $SourceFolder = "Source",

    [Parameter()]
    [System.String] $InstallScript = "Install.ps1"
)

begin {
    function Join-Dir ([System.String[]] $Path) {
        [System.IO.Path]::Combine($Path)
    }

    # Authenticate to the Graph API
    # Expects secrets to be passed into environment variables
    Write-Host "Authenticate to the Graph API"
    $params = @{
        TenantId     = "$env:TENANT_ID"
        ClientId     = "$env:CLIENT_ID"
        ClientSecret = "$env:CLIENT_SECRET"
    }
    $global:AuthToken = Connect-MSIntuneGraph @params

    # Build path to the Applications.json
    if (Test-Path -Path $AppManifest) {}
    else {
        $AppManifest = Join-Dir -Path $Path, $AppManifest
    }

    try {
        # Get the application manifest
        $SupportedApps = Get-Content -Path $AppManifest -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
    }
    catch {
        throw $_
    }
}

process {
    if ($Null -ne $global:AuthToken) {
        foreach ($App in $Application) {
            Write-Host "Application: $App"
            $Filter = ($SupportedApps | Where-Object { $_.Name -eq $App }).Filter

            if ($Null -ne $Filter) {
                if ($Filter -match "Get-VcList") {

                    # Handle the Visual C++ Redistributables via VcRedist
                    $App = Invoke-Expression -Command $Filter
                    $Filename = $(Split-Path -Path $App.Download -Leaf)
                    Write-Host "Package: $($App.Name); $Filename."
                    $params = @{
                        Path     = $(Join-Dir -Path $Path, $PackageFolder, $App, $SourceFolder)
                        ItemType = "Directory"
                        Force    = $True
                    }
                    New-Item @params | Out-Null
                    $params = @{
                        Uri             = $App.Download
                        OutFile         = $(Join-Dir -Path $Path, $PackageFolder, $App, $SourceFolder, $Filename)
                        UseBasicParsing = $True
                    }
                    Invoke-WebRequest @params
                }
                else {

                    # Get the application installer via Evergreen and download
                    $result = Invoke-Expression -Command $Filter | Save-EvergreenApp -CustomPath $(Join-Dir -Path $Path, $PackageFolder, $App, $SourceFolder)

                    # Unpack the installer file if its a zip file
                    Write-Host "Downloaded: $($result.FullName)"
                    if ($result.FullName -match "\.zip$") {
                        $params = @{
                            Path            = $result.FullName
                            DestinationPath = $(Join-Dir -Path $Path, $PackageFolder, $App, $SourceFolder)
                        }
                        Write-Host "Expand: $($result.FullName)"
                        Expand-Archive @params
                        Remove-Item -Path $result.FullName -Force
                    }
                }

                # Copy Install.ps1 into the source folder
                if (Test-Path -Path $(Join-Dir -Path $Path, $PackageFolder, $App, $SourceFolder, "Install.json")) {
                    $params = @{
                        Path        = $(Join-Dir -Path $Path, $InstallScript)
                        Destination = $(Join-Dir -Path $Path, $PackageFolder, $App, $SourceFolder, $InstallScript)
                        ErrorAction = "SilentlyContinue"
                    }
                    Write-Host "Copy: $(Join-Dir -Path $Path, $PackageFolder, $App, $SourceFolder, $InstallScript)"
                    Copy-Item @params
                }

                # Import the application into Intune
                $params = @{
                    Application      = $App
                    Path             = $(Join-Dir -Path $Path, $PackageFolder)
                    DisplayNameSuffix = "(Package Factory)"
                }
                $params
                Write-Host "Run: Create-Win32App.ps1"
                . [System.IO.Path]::Combine($Path, "Create-Win32App.ps1") @params
            }
            else {
                Write-Host "Application not supported by this workflow: $App"
            }
        }
    }
    else {
        throw "Cannot find authentication token."
    }
}
