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
ForEach ($Application in $ApplicationList.Applications | Get-Member -MemberType "NoteProperty") {
    
    # Determine the application download and version number via Evergreen
    $Properties = $ApplicationList.Applications.($Application.Name)
    $Evergreen = Invoke-Expression -Command $Properties.Filter

    # If the version that Evergreen returns is higher than the version in the manifest
    If ([System.Version]$Evergreen.Version -gt [System.Version]$AppJson.PackageInformation.Version -or [System.String]::IsNullOrEmpty($AppJson.PackageInformation.Version)) {

        # Get the application package manifest and update it
        $AppConfiguration = $([System.IO.Path]::Combine($Path, $Application.Name, $AppManifest))
        $AppJson = Get-Content -Path $AppConfiguration | ConvertFrom-Json
    
        # Update the manifest with the application setup file
        # TODO: some applications may require unpacking the installer
        $AppJson.PackageInformation.SetupFile = $(Split-Path -Path $Evergreen.URI -Leaf)

        # Update the application display name
        If ([System.Boolean]($Evergreen.PSobject.Properties.name -match "Architecture")) {
            $AppJson.Information.DisplayName = "$($Application.AppTitle) $($Evergreen.Version) $($Evergreen.Architecture)"
        }
        Else {
            $AppJson.Information.DisplayName = "$($Application.AppTitle) $($Evergreen.Version)"
        }
    
        # Step through each DetectionRule to update properties
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
    }
    ElseIf ([System.Version]$Evergreen.Version -le [System.Version]$AppJson.PackageInformation.Version) {
        Write-Host -Object "$($Evergreen.Version) less than or equal to $($AppJson.PackageInformation.Version)."
    }
    Else {
        Write-Host -Object "Could not determine version in the application manifest."
    }
}
