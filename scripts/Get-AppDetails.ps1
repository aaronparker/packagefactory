[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
param (
    [Parameter()]
    [System.String] $Path = $PWD,

    [Parameter()]
    [System.String] $PackageFolder = "packages",

    [Parameter()]
    [System.String] $PackageManifest = "App.json"
)

try {
    # Read the list of applications; we're assuming that $Manifest exists
    Write-Host -ForegroundColor "Cyan" "Get package list from: $([System.IO.Path]::Combine($Path, $PackageFolder))."
    $ManifestList = Get-ChildItem -Path $([System.IO.Path]::Combine($Path, $PackageFolder)) -Recurse -Filter $PackageManifest
    Write-Host -ForegroundColor "Cyan" "Found packages: $($ManifestList.Count)"
}
catch {
    throw $_
}

# Walk through the list of applications
foreach ($ManifestJson in $ManifestList) {
    try {
        # Read the manifest file and convert from JSON
        Write-Host -ForegroundColor "Cyan" "Read manifest: $($ManifestJson.FullName)"
        $Manifest = Get-Content -Path $ManifestJson.FullName -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
    }
    catch {
        throw $_
    }
    $Manifest.Application.Filter
}
