#Requires -Modules Evergreen
<#
    Update the App.json for Adobe Reader
#>
[CmdletBinding()]
param (
    [Parameter()]
    [System.String] $Path = "~/projects/evergreen-packagefactory",

    [Parameter()]
    [System.String] $Manifest = "Applications.json",

    [Parameter()]
    [System.String] $AppManifest = "App.json"
)

# Read the list of applications 
$ApplicationList = Get-Content -Path $(Join-Path -Path $Path -ChildPath $Manifest) | ConvertFrom-Json

# Walk through the list of applications
ForEach ($Application in $ApplicationList.Applications) <#| Get-Member -MemberType "NoteProperty")#> {
    
    # Determine the application download and version number via Evergreen
    #$Properties = $ApplicationList.Applications.($Application.Name)
    $Evergreen = Invoke-Expression -Command $Application.Filter

    Write-Host "Found: $($Application.Title) $($Evergreen.Version) $($Evergreen.Architecture)."

    # Get the application package manifest and update it
    $AppConfiguration = $([System.IO.Path]::Combine($Path, $Application.Name, $AppManifest))
    $AppJson = Get-Content -Path $AppConfiguration | ConvertFrom-Json

    # If the version that Evergreen returns is higher than the version in the manifest
    If ([System.Version]$Evergreen.Version -ge [System.Version]$AppJson.PackageInformation.Version -or [System.String]::IsNullOrEmpty($AppJson.PackageInformation.Version)) {
    
        # Update the manifest with the application setup file
        # TODO: some applications may require unpacking the installer
        $AppJson.PackageInformation.Version = $Evergreen.Version
        $AppJson.PackageInformation.SetupFile = $(Split-Path -Path $Evergreen.URI -Leaf)

        # Update the application display name
        If ([System.Boolean]($Evergreen.PSobject.Properties.Name -match "Architecture")) {
            $AppJson.Information.DisplayName = "$($Application.Title) $($Evergreen.Version) $($Evergreen.Architecture)"
        }
        Else {
            $AppJson.Information.DisplayName = "$($Application.Title) $($Evergreen.Version)"
        }
    
        # Step through each DetectionRule to update version properties
        For ($i = 0; $i -le $AppJson.DetectionRule.Count - 1; $i++) {

            If ("Value" -in $AppJson.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name") {
                $AppJson.DetectionRule[$i].Value = $Evergreen.Version
            }

            If ("ProductVersion" -in $AppJson.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name") {
                $AppJson.DetectionRule[$i].ProductVersion = $Evergreen.Version
            }
        }

        # Write the application manifest back to disk
        $AppJson | ConvertTo-Json | Out-File -Path $AppConfiguration -Force

        # TODO: Update Save-Evergreen for custom path output and download installer here

        # TODO: Call Create-Win32App.ps1 here
    }
    ElseIf ([System.Version]$Evergreen.Version -lt [System.Version]$AppJson.PackageInformation.Version) {
        Write-Host -Object "$($Evergreen.Version) less than or equal to $($AppJson.PackageInformation.Version)."
    }
    Else {
        Write-Host -Object "Could not compare package version between Evergreen and the application manifest."
    }
}
