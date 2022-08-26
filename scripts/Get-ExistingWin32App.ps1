
<#
    Import application packages into Intune
#>
[CmdletBinding(SupportsShouldProcess = $false)]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "", Justification = "Writes status to the pipeline log.")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "", Justification = "Needed to execute Evergreen or VcRedist commands.")]
param (
    [Parameter()]
    [ValidateNotNullOrEmpty()]
    [System.String] $Path = $PWD,

    [Parameter()]
    [System.String] $AppManifest = "Applications.json",

    [Parameter()]
    [System.String] $PackageFolder = "packages",

    [Parameter()]
    [System.String] $PackageManifest = "App.json"
)

# try {
#     # Authenticate to the Graph API
#     # Expects secrets to be passed into environment variables
#     Write-Host "Authenticate to the Graph API"
#     $params = @{
#         TenantId     = "$env:TENANT_ID"
#         ClientId     = "$env:CLIENT_ID"
#         ClientSecret = "$env:CLIENT_SECRET"
#     }
#     $global:AuthToken = Connect-MSIntuneGraph @params
# }
# catch {
#     throw $_
# }

try {
    # Get the existing Win32 applications from Intune
    $ExistingIntuneApps = Get-IntuneWin32App | Select-Object -ExcludeProperty "largeIcon"
}
catch {
    throw $_
}

if (Test-Path -Path $AppManifest) {}
else {
    # Build path to the Applications.json
    $AppManifest = [System.IO.Path]::Combine($Path, $AppManifest)
}

try {
    # Get the application manifest
    # $SupportedAppData = @()
    # $SupportedApps = Get-Content -Path $AppManifest -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
    # foreach ($Application in $SupportedApps) {

    #     # Read app data from JSON manifest
    #     $AppDataFile = [System.IO.Path]::Combine($Path, $PackageFolder, $Application.Name, $PackageManifest)
    #     $SupportedAppData += Get-Content -Path $AppDataFile -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
    # }

    $SupportedAppData = @()
    $SupportedAppData = Get-ChildItem -Path $([System.IO.Path]::Combine($Path, $PackageFolder)) -Recurse -Filter $PackageManifest | `
        ForEach-Object { Get-Content -Path $_.FullName -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue" }
}
catch {
    throw $_
}

foreach ($Application in $ExistingIntuneApps) {
    try {
        $AppNote = $Application.notes | ConvertFrom-Json -ErrorAction "SilentlyContinue"
        $App = $SupportedAppData | Where-Object { $_.Information.PSPackageFactoryGuid -eq $AppNote.Guid }
        if ($null -ne $App) {

            $Update = $false
            if ([System.Version]$App.PackageInformation.Version -gt [System.Version]$Application.displayVersion) {
                $Update = $true
            }
            $Object = [PSCustomObject]@{
                "IntuneWin32Application" = $Application.displayName
                "UpdateRequired"         = $Update
                "IntuneVersion"          = $Application.displayVersion
                "FactoryVersion"         = $App.PackageInformation.Version
            }
            Write-Output -InputObject $Object
        }
    }
    catch {
        #Write-Host "  App package notes not configured for PSPackageFactory"
    }
}
