#Requires -Modules Evergreen, VcRedist
<#
    Import application packages into Intune
#>
[CmdletBinding(SupportsShouldProcess = $false)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Writes status to the pipeline log.")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "", Justification = "Needed to execute Evergreen or VcRedist commands.")]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.String] $Application,

    [Parameter()]
    [ValidateNotNullOrEmpty()]
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

# Convert $Application into an array because we can't pass an array via inputs into the workflow
Write-Host "Path: $Path"
Write-Host "Applications: $Application"
[System.Array] $Applications = $Application.ToString() -split ","

function Join-Dir ([System.String[]] $Path) {
    [System.IO.Path]::Combine($Path)
}

try {
    # Authenticate to the Graph API
    # Expects secrets to be passed into environment variables
    Write-Host "Authenticate to the Graph API"
    $params = @{
        TenantId     = "$env:TENANT_ID"
        ClientId     = "$env:CLIENT_ID"
        ClientSecret = "$env:CLIENT_SECRET"
    }
    $global:AuthToken = Connect-MSIntuneGraph @params
}
catch {
    throw $_
}

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

foreach ($App in $Applications) {
    $AppItem = $App.Trim()
    Write-Host "Application: $AppItem"
    $Filter = ($SupportedApps | Where-Object { $_.Name -eq $AppItem }).Filter

    if ($Null -ne $Filter) {
        if ($Filter -match "Get-VcList") {

            # Handle the Visual C++ Redistributables via VcRedist
            $AppItem = Invoke-Expression -Command $Filter
            $Filename = $(Split-Path -Path $AppItem.Download -Leaf)
            Write-Host "Package: $($AppItem.Name); $Filename."
            $params = @{
                Path     = $(Join-Dir -Path $Path, $PackageFolder, $AppItem, $SourceFolder)
                ItemType = "Directory"
                Force    = $True
            }
            New-Item @params | Out-Null
            $params = @{
                Uri             = $AppItem.Download
                OutFile         = $(Join-Dir -Path $Path, $PackageFolder, $AppItem, $SourceFolder, $Filename)
                UseBasicParsing = $True
            }
            Invoke-WebRequest @params
        }
        else {

            # Get the application installer via Evergreen and download
            $result = Invoke-Expression -Command $Filter | Save-EvergreenApp -CustomPath $(Join-Dir -Path $Path, $PackageFolder, $AppItem, $SourceFolder)

            # Unpack the installer file if its a zip file
            Write-Host "Downloaded: $($result.FullName)"
            if ($result.FullName -match "\.zip$") {
                $params = @{
                    Path            = $result.FullName
                    DestinationPath = $(Join-Dir -Path $Path, $PackageFolder, $AppItem, $SourceFolder)
                }
                Write-Host "Expand: $($result.FullName)"
                Expand-Archive @params
                Remove-Item -Path $result.FullName -Force
            }
        }

        # Copy Install.ps1 into the source folder
        if (Test-Path -Path $(Join-Dir -Path $Path, $PackageFolder, $AppItem, $SourceFolder, "Install.json")) {
            $params = @{
                Path        = $(Join-Dir -Path $Path, $InstallScript)
                Destination = $(Join-Dir -Path $Path, $PackageFolder, $AppItem, $SourceFolder, $InstallScript)
                ErrorAction = "SilentlyContinue"
            }
            Write-Host "Copy: $(Join-Dir -Path $Path, $PackageFolder, $AppItem, $SourceFolder, $InstallScript)"
            Copy-Item @params
        }
        else {
            Write-Host "Install.json does not exist."
        }

        # Import the application into Intune
        $params = @{
            Application       = $AppItem
            Path              = $(Join-Dir -Path $Path, $PackageFolder)
            DisplayNameSuffix = "(Package Factory)"
        }
        $params
        Write-Host "Run: Create-Win32App.ps1"
        . $([System.IO.Path]::Combine($Path, "Create-Win32App.ps1")) @params
    }
    else {
        Write-Host "Application not supported by this workflow: $AppItem"
    }
}
