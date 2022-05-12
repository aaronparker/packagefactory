#Requires -Modules Evergreen, VcRedist
<#
    Update the App.json for packages
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
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
    Write-Host -ForegroundColor "Cyan" "Read: $Manifest."
    $ApplicationList = Get-Content -Path $Manifest | ConvertFrom-Json
}
catch {
    throw $_.Exception.Message
}

# Walk through the list of applications
foreach ($Application in $ApplicationList) {

    # Determine the application download and version number via Evergreen
    #$Properties = $ApplicationList.Applications.($Application.Name)
    Write-Host -ForegroundColor "Cyan" "Application: $($Application.Title)"
    Write-Host -ForegroundColor "Cyan" "Running: $($Application.Filter)."
    $AppUpdate = Invoke-Expression -Command $Application.Filter
    Write-Host -ForegroundColor "Cyan" "Found: $($Application.Title) $($AppUpdate.Version) $($AppUpdate.Architecture)."

    # Get the application package manifest and update it
    $AppConfiguration = $([System.IO.Path]::Combine($Path, $Application.Name, $AppManifest))
    Write-Host -ForegroundColor "Cyan" "Read: $AppConfiguration."
    if (Test-Path -Path $AppConfiguration) {
        $AppData = Get-Content -Path $AppConfiguration | ConvertFrom-Json
    }
    else {
        Write-Warning -Message "Cannot find: $AppConfiguration."
    }

    # If the version that Evergreen returns is higher than the version in the manifest
    if ([System.Version]$AppUpdate.Version -ge [System.Version]$AppData.PackageInformation.Version -or [System.String]::IsNullOrEmpty($AppData.PackageInformation.Version)) {

        # Update the manifest with the application setup file
        # TODO: some applications may require unpacking the installer
        Write-Host -ForegroundColor "Cyan" "Update package."
        $AppData.PackageInformation.Version = $AppUpdate.Version

        if ([System.Boolean]($AppUpdate.PSobject.Properties.Name -match "URI")) {
            if ($AppUpdate.URI -match "\.zip$") {
                if (Test-Path -Path Env:Temp -ErrorAction "SilentlyContinue") { $ZipPath = $Env:Temp } else { $ZipPath = $HOME }
                $Download = $AppUpdate | Save-EvergreenApp -CustomPath $ZipPath
                [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
                $SetupFile = [IO.Compression.ZipFile]::OpenRead($Download.FullName).Entries.FullName
                Remove-Item -Path $Download.FullName -Force

                $AppData.PackageInformation.SetupFile = $SetupFile -replace "%20", " "
                $AppData.Program.InstallCommand = $AppData.Program.InstallTemplate -replace "#SetupFile", $SetupFile -replace "%20", " "
            } else {
                $AppData.PackageInformation.SetupFile = $(Split-Path -Path $AppUpdate.URI -Leaf) -replace "%20", " "
                $AppData.Program.InstallCommand = $AppData.Program.InstallTemplate -replace "#SetupFile", $(Split-Path -Path $AppUpdate.URI -Leaf) -replace "%20", " "
            }
        }
        else {
            $AppData.PackageInformation.SetupFile = $(Split-Path -Path $AppUpdate.Download -Leaf) -replace "%20", " "
            $AppData.Program.InstallCommand = $AppData.Program.InstallTemplate -replace "#SetupFile", $(Split-Path -Path $AppUpdate.Download -Leaf)
        }

        if ([System.Boolean]($AppUpdate.PSobject.Properties.Name -match "SilentUninstall")) {
            $AppData.Program.UninstallCommand = $AppUpdate.SilentUninstall -replace "%ProgramData%", "C:\ProgramData"
        }

        # Update the application display name
        if ([System.Boolean]($AppUpdate.PSobject.Properties.Name -match "Architecture")) {
            $AppData.Information.DisplayName = "$($Application.Title) $($AppUpdate.Version) $($AppUpdate.Architecture)"
        }
        else {
            $AppData.Information.DisplayName = "$($Application.Title) $($AppUpdate.Version)"
        }

        # Step through each DetectionRule to update version properties
        for ($i = 0; $i -le $AppData.DetectionRule.Count - 1; $i++) {

            if ("Value" -in ($AppData.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                $AppData.DetectionRule[$i].Value = $AppUpdate.Version
            }

            if ("VersionValue" -in ($AppData.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                $AppData.DetectionRule[$i].VersionValue = $AppUpdate.Version
            }

            if ("ProductVersion" -in ($AppData.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                $AppData.DetectionRule[$i].ProductVersion = $AppUpdate.Version
            }

            if ("ProductCode" -in ($AppData.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                if ($Null -ne $AppUpdate.ProductCode) {
                    $AppData.DetectionRule[$i].ProductCode = $AppUpdate.ProductCode
                }
            }
        }

        # Write the application manifest back to disk
        Write-Host -ForegroundColor "Cyan" "Output: $AppConfiguration."
        $AppData | ConvertTo-Json | Out-File -FilePath $AppConfiguration -Force
    }
    elseif ([System.Version]$AppUpdate.Version -lt [System.Version]$AppData.PackageInformation.Version) {
        Write-Host -ForegroundColor "Cyan" "$($AppUpdate.Version) less than $($AppData.PackageInformation.Version)."
    }
    else {
        Write-Host -ForegroundColor "Cyan" "Could not compare package version."
    }
}
