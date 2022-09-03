
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
    [System.String] $PackageFolder = "packages",

    [Parameter()]
    [System.String] $PackageManifest = "App.json"
)

try {
    # Get the existing Win32 applications from Intune
    $ExistingIntuneApps = Get-IntuneWin32App | Select-Object -ExcludeProperty "largeIcon"
}
catch {
    throw $_
}

try {
    # Get the application manifest
    $SupportedAppData = @()
    $SupportedAppData = Get-ChildItem -Path $([System.IO.Path]::Combine($Path, $PackageFolder)) -Recurse -Filter $PackageManifest | `
        ForEach-Object { Get-Content -Path $_.FullName -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue" }
}
catch {
    throw $_
}

foreach ($Application in $script:ExistingIntuneApps) {
    try {
        $AppNote = $Application.notes | ConvertFrom-Json -ErrorAction "SilentlyContinue"
    }
    catch {
        $AppNote = $null
    }

    if ($null -ne $AppNote) {
        $MatchedApp = $script:SupportedAppData | Where-Object { $_.Information.PSPackageFactoryGuid -eq $AppNote.Guid }
        if ($null -ne $MatchedApp) {
            foreach ($App in $MatchedApp) {
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
    }
    else {
        Write-Verbose -Message "$($Application.displayName): application notes not configured for PSPackageFactory."
    }
}

# Sort-Object -Property "IntuneWin32Application", "UpdateRequired"
#@{ Expression = { [System.Version]$_.Version }; Descending = $true } 
