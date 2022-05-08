#Requires -Modules Evergreen
<#
    Update the App.json for packages
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
param (
    [Parameter()]
    [System.String] $Path = "~/projects/packagefactory",

    [Parameter()]
    [System.String] $Manifest = "Applications.json",

    [Parameter()]
    [System.String] $AppManifest = "App.json"
)

try {
    # Read the list of applications; we're assuming that $Manifest exists
    Write-Host "Read: $Manifest."
    $ApplicationList = Get-Content -Path $Manifest | ConvertFrom-Json
}
catch {
    throw $_.Exception.Message
}

# Walk through the list of applications
foreach ($Application in $ApplicationList.Applications) {

    # Determine the application download and version number via Evergreen
    #$Properties = $ApplicationList.Applications.($Application.Name)
    Write-Host "Application: $($Application.Title)"
    Write-Host "Running: $($Application.Filter)."
    $Evergreen = Invoke-Expression -Command $Application.Filter
    Write-Host "Found: $($Application.Title) $($Evergreen.Version) $($Evergreen.Architecture)."

    # Get the application package manifest and update it
    $AppConfiguration = $([System.IO.Path]::Combine($Path, $Application.Name, $AppManifest))
    Write-Host "Read: $AppConfiguration."
    $AppJson = Get-Content -Path $AppConfiguration | ConvertFrom-Json

    # If the version that Evergreen returns is higher than the version in the manifest
    if ([System.Version]$Evergreen.Version -ge [System.Version]$AppJson.PackageInformation.Version -or `
            [System.String]::IsNullOrEmpty($AppJson.PackageInformation.Version)) {

        # Update the manifest with the application setup file
        # TODO: some applications may require unpacking the installer
        Write-Host "Update package."
        $AppJson.PackageInformation.Version = $Evergreen.Version
        $AppJson.PackageInformation.SetupFile = $(Split-Path -Path $Evergreen.URI -Leaf)
        $AppJson.Program.InstallCommand = $AppJson.Program.InstallTemplate -replace "#SetupFile", $(Split-Path -Path $Evergreen.URI -Leaf)

        # Update the application display name
        if ([System.Boolean]($Evergreen.PSobject.Properties.Name -match "Architecture")) {
            $AppJson.Information.DisplayName = "$($Application.Title) $($Evergreen.Version) $($Evergreen.Architecture)"
        }
        else {
            $AppJson.Information.DisplayName = "$($Application.Title) $($Evergreen.Version)"
        }

        # Step through each DetectionRule to update version properties
        for ($i = 0; $i -le $AppJson.DetectionRule.Count - 1; $i++) {

            if ("Value" -in ($AppJson.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                $AppJson.DetectionRule[$i].Value = $Evergreen.Version
            }

            if ("VersionValue" -in ($AppJson.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                $AppJson.DetectionRule[$i].VersionValue = $Evergreen.Version
            }

            if ("ProductVersion" -in ($AppJson.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                $AppJson.DetectionRule[$i].ProductVersion = $Evergreen.Version
            }
        }

        # Write the application manifest back to disk
        Write-Host "Output: $AppConfiguration."
        $AppJson | ConvertTo-Json | Out-File -Path $AppConfiguration -Force
    }
    elseif ([System.Version]$Evergreen.Version -lt [System.Version]$AppJson.PackageInformation.Version) {
        Write-Host -Object "$($Evergreen.Version) less than or equal to $($AppJson.PackageInformation.Version)."
    }
    else {
        Write-Host -Object "Could not compare package version between Evergreen and the application manifest."
    }
}
