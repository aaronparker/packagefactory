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
    [System.String] $AppManifest = "App.json",

    [Parameter()]
    [System.String] $InstallManifest = "Install.json"
)

try {
    # Read the list of applications; we're assuming that $Manifest exists
    Write-Host -ForegroundColor "Cyan" "Read: $Manifest."
    $ApplicationList = Get-Content -Path $Manifest -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
}
catch {
    throw $_
}

# Walk through the list of applications
foreach ($Application in $ApplicationList) {

    # Determine the application download and version number via Evergreen
    Write-Host -ForegroundColor "Cyan" "Application: $($Application.Title)"
    Write-Host -ForegroundColor "Cyan" "Running: $($Application.Filter)."

    # Get the details of the application
    $AppUpdate = Invoke-Expression -Command $Application.Filter -ErrorAction "SilentlyContinue" -WarningAction "SilentlyContinue"

    if ($Null -ne $AppUpdate) {
        Write-Host -ForegroundColor "Cyan" "Found: $($Application.Title) $($AppUpdate.Version) $($AppUpdate.Architecture)."

        #region Get the application package manifest and update it
        $AppConfiguration = $([System.IO.Path]::Combine($Path, $Application.Name, $AppManifest))
        Write-Host -ForegroundColor "Cyan" "Read: $AppConfiguration."
        if (Test-Path -Path $AppConfiguration) {
            try {
                $AppData = Get-Content -Path $AppConfiguration -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
            }
            catch {
                throw $_
            }
        }
        else {
            Write-Warning -Message "Cannot find: $AppConfiguration."
        }

        # If the version that Evergreen returns is higher than the version in the manifest
        if ([System.Version]$AppUpdate.Version -ge [System.Version]$AppData.PackageInformation.Version -or [System.String]::IsNullOrEmpty($AppData.PackageInformation.Version)) {

            # Update the manifest with the application setup file
            Write-Host -ForegroundColor "Cyan" "Update package."
            $AppData.PackageInformation.Version = $AppUpdate.Version

            if ([System.Boolean]($AppUpdate.PSobject.Properties.Name -match "URI")) {
                if ($AppUpdate.URI -match "\.zip$") {
                    if (Test-Path -Path Env:Temp -ErrorAction "SilentlyContinue") { $ZipPath = $Env:Temp } else { $ZipPath = $HOME }
                    $Download = $AppUpdate | Save-EvergreenApp -CustomPath $ZipPath
                    [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
                    $SetupFile = [IO.Compression.ZipFile]::OpenRead($Download.FullName).Entries.FullName
                    $AppData.PackageInformation.SetupFile = $SetupFile -replace "%20", " "
                    $AppData.Program.InstallCommand = $AppData.Program.InstallTemplate -replace "#SetupFile", $SetupFile -replace "%20", " "
                }
                else {
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

            # Step through each CustomRequirementRule to update version properties
            for ($i = 0; $i -le $AppData.CustomRequirementRule.Count - 1; $i++) {

                if ("Value" -in ($AppData.CustomRequirementRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                    $AppData.CustomRequirementRule[$i].Value = $AppUpdate.Version
                }

                if ("VersionValue" -in ($AppData.CustomRequirementRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                    $AppData.CustomRequirementRule[$i].VersionValue = $AppUpdate.Version
                }
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
        #endregion


        #region Get the application install manifest and update it
        $InstallConfiguration = $([System.IO.Path]::Combine($Path, $Application.Name, $InstallData.PackageInformation.SourceFolder, $InstallManifest))
        Write-Host -ForegroundColor "Cyan" "Read: $InstallConfiguration."
        if (Test-Path -Path $InstallConfiguration) {
            try {
                $InstallData = Get-Content -Path $InstallConfiguration -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
            }
            catch {
                throw $_
            }

            # If the version that Evergreen returns is higher than the version in the manifest
            if ([System.Version]$AppUpdate.Version -ge [System.Version]$InstallData.PackageInformation.Version -or [System.String]::IsNullOrEmpty($InstallData.PackageInformation.Version)) {

                # Update the manifest with the application setup file
                Write-Host -ForegroundColor "Cyan" "Update package."
                $InstallData.PackageInformation.Version = $AppUpdate.Version

                if ([System.Boolean]($AppUpdate.PSobject.Properties.Name -match "URI")) {
                    if ($AppUpdate.URI -match "\.zip$") {
                        if (Test-Path -Path Env:Temp -ErrorAction "SilentlyContinue") { $ZipPath = $Env:Temp } else { $ZipPath = $HOME }
                        $Download = $AppUpdate | Save-EvergreenApp -CustomPath $ZipPath
                        [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
                        $SetupFile = [IO.Compression.ZipFile]::OpenRead($Download.FullName).Entries.FullName
                        $InstallData.PackageInformation.SetupFile = $SetupFile -replace "%20", " "
                        $InstallData.Program.InstallCommand = $InstallData.Program.InstallTemplate -replace "#SetupFile", $SetupFile -replace "%20", " "
                    }
                    else {
                        $InstallData.PackageInformation.SetupFile = $(Split-Path -Path $AppUpdate.URI -Leaf) -replace "%20", " "
                        $InstallData.Program.InstallCommand = $InstallData.Program.InstallTemplate -replace "#SetupFile", $(Split-Path -Path $AppUpdate.URI -Leaf) -replace "%20", " "
                    }
                }
                else {
                    $InstallData.PackageInformation.SetupFile = $(Split-Path -Path $AppUpdate.Download -Leaf) -replace "%20", " "
                    $InstallData.Program.InstallCommand = $InstallData.Program.InstallTemplate -replace "#SetupFile", $(Split-Path -Path $AppUpdate.Download -Leaf)
                }

                # Write the application install manifest back to disk
                Write-Host -ForegroundColor "Cyan" "Output: $InstallConfiguration."
                $InstallData | ConvertTo-Json | Out-File -FilePath $InstallConfiguration -Force
            }
            elseif ([System.Version]$AppUpdate.Version -lt [System.Version]$AppData.PackageInformation.Version) {
                Write-Host -ForegroundColor "Cyan" "$($AppUpdate.Version) less than $($AppData.PackageInformation.Version)."
            }
            else {
                Write-Host -ForegroundColor "Cyan" "Could not compare package version."
            }

            # Remove the zip file if it exists
            if (Test-Path -Path $Download.FullName) { Remove-Item -Path $Download.FullName -Force -ErrorAction "SilentlyContinue" }
        }
        else {
            Write-Warning -Message "Cannot find: $InstallConfiguration."
        }
        #endregion
    }
    else {
        Write-Host "Failed to return details from: $($Application.Filter )"
    }
}
