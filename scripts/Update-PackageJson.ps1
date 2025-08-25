#Requires -Modules Evergreen, VcRedist
<#
    Update the App.json for packages
    Notice: Requires Powershell 6+ (due to ConvertFrom-Json -Depth parameter)
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
param (
    [Parameter()]
    [System.String] $Path = $PWD,

    [Parameter()]
    [System.String] $PackageFolder = "packages",

    [Parameter()]
    [System.String] $PackageManifest = "App.json",

    [Parameter()]
    [System.String] $InstallManifest = "Install.json"
)

try {
    # Read the list of applications; we're assuming that $Manifest exists
    Write-Host -ForegroundColor "Cyan" "Get package list from: $([System.IO.Path]::Combine($Path, $PackageFolder))."
    $ManifestList = Get-ChildItem -Path $([System.IO.Path]::Combine($Path, $PackageFolder)) -Recurse -Filter $PackageManifest
    Write-Host -ForegroundColor "Cyan" "Found $($ManifestList.Count) packages"
}
catch {
    throw $_
}

# Walk through the list of applications
foreach ($ManifestJson in $ManifestList) {

    try {
        # Read the manifest file and convert from JSON
        Write-Host -ForegroundColor "Cyan" "Read manifest: $($ManifestJson.FullName)"
        $Manifest = Get-Content -Path $ManifestJson.FullName -ErrorAction "SilentlyContinue" | ConvertFrom-Json -Depth 20 -ErrorAction "SilentlyContinue"
    }
    catch {
        Write-Warning -Message "Error reading $($ManifestJson.FullName) with: $($_.Exception.Message)"
    }

    if ([System.String]::IsNullOrEmpty($Manifest.Application.Filter)) {
        Write-Host -ForegroundColor "Cyan" "Not supported for automatic update: $($ManifestJson.FullName)."
    }
    else {
        # Determine the application download and version number via Evergreen or VcRedist
        # Get the details of the application
        Write-Host -ForegroundColor "Cyan" "Application: $($Manifest.Application.Title)"
        Write-Host -ForegroundColor "Cyan" "Running: $($Manifest.Application.Filter)."
        $AppUpdate = Invoke-Expression -Command $Manifest.Application.Filter -ErrorAction "SilentlyContinue" -WarningAction "SilentlyContinue"

        if ([System.String]::IsNullOrEmpty($AppUpdate.Version)) {
            Write-Warning -Message "Returned null version value from: $($Manifest.Application.Filter)"
        }
        else {
            Write-Host -ForegroundColor "Cyan" "Found: $($Manifest.Application.Title) $($AppUpdate.Version) $($AppUpdate.Architecture)."

            # If the version that Evergreen returns is higher than the version in the manifest
            if ([System.Version]$AppUpdate.Version -eq [System.Version]$Manifest.PackageInformation.Version) {
                Write-Host -ForegroundColor "Cyan" "Update version: $($AppUpdate.Version) matches manifest version: $($Manifest.PackageInformation.Version)."
            }
            elseif ([System.Version]$AppUpdate.Version -gt [System.Version]$Manifest.PackageInformation.Version -or [System.String]::IsNullOrEmpty($Manifest.PackageInformation.Version)) {

                # Update the manifest with the application setup file
                Write-Host -ForegroundColor "Cyan" "Update package from: $($Manifest.PackageInformation.Version) to: $($AppUpdate.Version)."
                $Manifest.PackageInformation.Version = $AppUpdate.Version

                if ([System.Boolean]($AppUpdate.PSobject.Properties.Name -match "URI")) {
                    if ($AppUpdate.URI -match "\.zip$") {
                        if (Test-Path -Path Env:Temp -ErrorAction "SilentlyContinue") { $ZipPath = $Env:Temp } else { $ZipPath = $HOME }
                        $Download = $AppUpdate | Save-EvergreenApp -CustomPath $ZipPath
                        [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
                        $SetupFile = [IO.Compression.ZipFile]::OpenRead($Download.FullName).Entries.FullName

                        $Manifest.PackageInformation.SetupFile = $SetupFile -replace "%20", " "
                        $Manifest.Program.InstallCommand = $Manifest.Program.InstallTemplate -replace "#SetupFile", $SetupFile -replace "%20", " "
                    }
                    elseif ($AppUpdate.URI -match "\.intunewin$") {
                        # Do nothing because the download is already in intunewin format
                    }
                    else {
                        if ([System.Boolean]($AppUpdate.PSobject.Properties.name -match "Filename")) {
                            $Manifest.PackageInformation.SetupFile = $AppUpdate.Filename -replace "%20", " "
                            $Manifest.Program.InstallCommand = $Manifest.Program.InstallTemplate -replace "#SetupFile", $AppUpdate.Filename -replace "%20", " "
                        }
                        else {
                            $Manifest.PackageInformation.SetupFile = $(Split-Path -Path $AppUpdate.URI -Leaf) -replace "%20", " "
                            $Manifest.Program.InstallCommand = $Manifest.Program.InstallTemplate -replace "#SetupFile", $(Split-Path -Path $AppUpdate.URI -Leaf) -replace "%20", " "
                        }
                    }
                }
                else {
                    $Manifest.PackageInformation.SetupFile = $(Split-Path -Path $AppUpdate.Download -Leaf) -replace "%20", " "
                    $Manifest.Program.InstallCommand = $Manifest.Program.InstallTemplate -replace "#SetupFile", $(Split-Path -Path $AppUpdate.Download -Leaf)
                }

                if ([System.Boolean]($AppUpdate.PSobject.Properties.Name -match "SilentUninstall")) {
                    $Manifest.Program.UninstallCommand = $AppUpdate.SilentUninstall -replace "%ProgramData%", "C:\ProgramData"
                }

                # Update the application display name
                if ([System.Boolean]($AppUpdate.PSobject.Properties.Name -match "Architecture")) {
                    $Manifest.Information.DisplayName = "$($Manifest.Application.Title) $($AppUpdate.Version) $($AppUpdate.Architecture)"
                }
                else {
                    $Manifest.Information.DisplayName = "$($Manifest.Application.Title) $($AppUpdate.Version)"
                }

                # Step through each CustomRequirementRule to update version properties
                for ($i = 0; $i -le $Manifest.CustomRequirementRule.Count - 1; $i++) {

                    if ("Value" -in ($Manifest.CustomRequirementRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                        $Manifest.CustomRequirementRule[$i].Value = $AppUpdate.Version
                    }

                    if ("VersionValue" -in ($Manifest.CustomRequirementRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                        $Manifest.CustomRequirementRule[$i].VersionValue = $AppUpdate.Version
                    }
                }

                # Step through each DetectionRule to update version properties
                for ($i = 0; $i -le $Manifest.DetectionRule.Count - 1; $i++) {
                    if ("Value" -in ($Manifest.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                        $Manifest.DetectionRule[$i].Value = $AppUpdate.Version
                    }

                    if ("VersionValue" -in ($Manifest.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                        $Manifest.DetectionRule[$i].VersionValue = $AppUpdate.Version
                    }

                    if ("ProductVersion" -in ($Manifest.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                        $Manifest.DetectionRule[$i].ProductVersion = $AppUpdate.Version
                    }

                    if ("ProductCode" -in ($Manifest.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                        if ($Null -ne $AppUpdate.ProductCode) {
                            $Manifest.DetectionRule[$i].ProductCode = $AppUpdate.ProductCode
                        }
                    }

                    if ("Path" -in ($Manifest.DetectionRule[$i] | Get-Member -MemberType "NoteProperty" | Select-Object -ExpandProperty "Name")) {
                        if ($Manifest.DetectionRule[$i].Path -match "(\d+(\.\d+){1,4})") {
                            $Manifest.DetectionRule[$i].Path = $Manifest.DetectionRule[$i].Path -replace "(\d+(\.\d+){1,4})", $AppUpdate.Version
                        }
                    }
                }

                # Write the application manifest back to disk
                Write-Host -ForegroundColor "Cyan" "Output: $($ManifestJson.FullName)."
                $Manifest | ConvertTo-Json -Depth 20 | Out-File -FilePath $ManifestJson.FullName -Force
            }
            elseif ([System.Version]$AppUpdate.Version -lt [System.Version]$Manifest.PackageInformation.Version) {
                Write-Host -ForegroundColor "Cyan" "Update version: $($AppUpdate.Version) less than manifest version: $($Manifest.PackageInformation.Version)."
            }
            else {
                Write-Host -ForegroundColor "Cyan" "Could not compare package version."
            }
            #endregion


            #region Get the application install manifest and update it
            $InstallConfiguration = $([System.IO.Path]::Combine($ManifestJson.Directory, $Manifest.PackageInformation.SourceFolder, $InstallManifest))
            Write-Host -ForegroundColor "Cyan" "Read: $InstallConfiguration."
            if (Test-Path -Path $InstallConfiguration) {
                try {
                    $InstallData = Get-Content -Path $InstallConfiguration -ErrorAction "SilentlyContinue" | ConvertFrom-Json -Depth 20 -ErrorAction "SilentlyContinue"
                }
                catch {
                    throw $_
                }

                # If the version that Evergreen returns is higher than the version in the manifest
                if ([System.Version]$AppUpdate.Version -eq [System.Version]$InstallData.PackageInformation.Version) {
                    Write-Host -ForegroundColor "Cyan" "Update version: $($AppUpdate.Version) matches install script version: $($Manifest.PackageInformation.Version)."
                }
                elseif ([System.Version]$AppUpdate.Version -gt [System.Version]$InstallData.PackageInformation.Version -or [System.String]::IsNullOrEmpty($InstallData.PackageInformation.Version)) {

                    # Update the manifest with the application setup file
                    Write-Host -ForegroundColor "Cyan" "Update install script: $InstallConfiguration"
                    $InstallData.PackageInformation.Version = $AppUpdate.Version

                    if ([System.Boolean]($AppUpdate.PSobject.Properties.Name -match "URI")) {
                        if ($AppUpdate.URI -match "\.zip$") {
                            if (Test-Path -Path Env:Temp -ErrorAction "SilentlyContinue") { $ZipPath = $Env:Temp } else { $ZipPath = $HOME }
                            $Download = $AppUpdate | Save-EvergreenApp -CustomPath $ZipPath
                            [Reflection.Assembly]::LoadWithPartialName('System.IO.Compression.FileSystem')
                            $SetupFile = [IO.Compression.ZipFile]::OpenRead($Download.FullName).Entries.FullName
                            $InstallData.PackageInformation.SetupFile = $SetupFile -replace "%20", " "
                        }
                        else {
                            if ([System.Boolean]($AppUpdate.PSobject.Properties.name -match "Filename")) {
                                $InstallData.PackageInformation.SetupFile = $AppUpdate.Filename -replace "%20", " "
                            }
                            else {
                                $InstallData.PackageInformation.SetupFile = $(Split-Path -Path $AppUpdate.URI -Leaf) -replace "%20", " "
                            }
                        }
                    }
                    else {
                        $InstallData.PackageInformation.SetupFile = $(Split-Path -Path $AppUpdate.Download -Leaf) -replace "%20", " "
                    }

                    # Write the application install manifest back to disk
                    Write-Host -ForegroundColor "Cyan" "Output: $InstallConfiguration."
                    $InstallData | ConvertTo-Json -Depth 20 | Out-File -FilePath $InstallConfiguration -Force
                }
                elseif ([System.Version]$AppUpdate.Version -lt [System.Version]$InstallData.PackageInformation.Version) {
                    Write-Host -ForegroundColor "Cyan" "Update version: $($AppUpdate.Version) less than install script version: $($InstallData.PackageInformation.Version)."
                }
                else {
                    Write-Host -ForegroundColor "Cyan" "Could not compare install script version."
                }

                # Remove the zip file if it exists
                if (Test-Path -Path $Download.FullName -ErrorAction "SilentlyContinue") { Remove-Item -Path $Download.FullName -Force -ErrorAction "SilentlyContinue" }
            }
            else {
                Write-Warning -Message "Cannot find: $InstallConfiguration."
            }
            #endregion
        }
    }
}
