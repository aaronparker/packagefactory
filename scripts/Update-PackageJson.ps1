#Requires -Modules Evergreen, VcRedist
<#
    Update the App.json for packages
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
    Write-Verbose -Message "Get package list from: $([System.IO.Path]::Combine($Path, $PackageFolder))."
    $ManifestList = Get-ChildItem -Path $([System.IO.Path]::Combine($Path, $PackageFolder)) -Recurse -Filter $PackageManifest
    Write-Verbose -Message "Found packages: $($ManifestList.Count)"
}
catch {
    throw $_
}

# Walk through the list of applications
foreach ($ManifestJson in $ManifestList) {

    try {
        # Read the manifest file and convert from JSON
        Write-Verbose -Message "Read manifest: $($ManifestJson.FullName)"
        $Manifest = Get-Content -Path $ManifestJson.FullName -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
        $Manifest
    }
    catch {
        throw $_
    }

    if ($null -eq $Manifest.Application.Filter) {
        Write-Verbose -Message "Not supported for automatic update: $($ManifestJson.FullName)."
    }
    else {
        # Determine the application download and version number via Evergreen or VcRedist
        # Get the details of the application
        Write-Verbose -Message "Application: $($Manifest.Application.Title)"
        Write-Verbose -Message "Running: $($Manifest.Application.Filter)."
        $AppUpdate = Invoke-Expression -Command $Manifest.Application.Filter -Verbose:$false -ErrorAction "SilentlyContinue" -WarningAction "SilentlyContinue"

        if ($Null -ne $AppUpdate) {
            Write-Verbose -Message "Found: $($Manifest.Application.Title) $($AppUpdate.Version) $($AppUpdate.Architecture)."

            # If the version that Evergreen returns is higher than the version in the manifest
            if ([System.Version]$AppUpdate.Version -eq [System.Version]$Manifest.PackageInformation.Version) {
                Write-Verbose -Message "Update version: $($AppUpdate.Version) matches manifest version: $($Manifest.PackageInformation.Version)."
            }
            elseif ([System.Version]$AppUpdate.Version -gt [System.Version]$Manifest.PackageInformation.Version -or [System.String]::IsNullOrEmpty($Manifest.PackageInformation.Version)) {

                # Update the manifest with the application setup file
                Write-Verbose -Message "Update package from: $($Manifest.PackageInformation.Version) to: $($AppUpdate.Version)."
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
                    else {
                        $Manifest.PackageInformation.SetupFile = $(Split-Path -Path $AppUpdate.URI -Leaf) -replace "%20", " "
                        $Manifest.Program.InstallCommand = $Manifest.Program.InstallTemplate -replace "#SetupFile", $(Split-Path -Path $AppUpdate.URI -Leaf) -replace "%20", " "
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
                }

                # Write the application manifest back to disk
                Write-Verbose -Message "Output: $($ManifestJson.FullName)."
                $Manifest | ConvertTo-Json | Out-File -FilePath $ManifestJson.FullName -Force
            }
            elseif ([System.Version]$AppUpdate.Version -lt [System.Version]$Manifest.PackageInformation.Version) {
                Write-Verbose -Message "Update version: $($AppUpdate.Version) less than manifest version: $($Manifest.PackageInformation.Version)."
            }
            else {
                Write-Verbose -Message "Could not compare package version."
            }
            #endregion


            #region Get the application install manifest and update it
            $InstallConfiguration = $([System.IO.Path]::Combine($Path, $PackageFolder, $Manifest.Application.Name, $Manifest.PackageInformation.SourceFolder, $InstallManifest))
            Write-Verbose -Message "Read: $InstallConfiguration."
            if (Test-Path -Path $InstallConfiguration) {
                try {
                    $InstallData = Get-Content -Path $InstallConfiguration -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
                }
                catch {
                    throw $_
                }

                # If the version that Evergreen returns is higher than the version in the manifest
                if ([System.Version]$AppUpdate.Version -eq [System.Version]$InstallData.PackageInformation.Version) {
                    Write-Verbose -Message "Update version: $($AppUpdate.Version) matches install script version: $($Manifest.PackageInformation.Version)."
                }
                elseif ([System.Version]$AppUpdate.Version -gt [System.Version]$InstallData.PackageInformation.Version -or [System.String]::IsNullOrEmpty($InstallData.PackageInformation.Version)) {

                    # Update the manifest with the application setup file
                    Write-Verbose -Message "Update install script: $InstallConfiguration"
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
                            $InstallData.PackageInformation.SetupFile = $(Split-Path -Path $AppUpdate.URI -Leaf) -replace "%20", " "
                        }
                    }
                    else {
                        $InstallData.PackageInformation.SetupFile = $(Split-Path -Path $AppUpdate.Download -Leaf) -replace "%20", " "
                    }

                    # Write the application install manifest back to disk
                    Write-Verbose -Message "Output: $InstallConfiguration."
                    $InstallData | ConvertTo-Json | Out-File -FilePath $InstallConfiguration -Force
                }
                elseif ([System.Version]$AppUpdate.Version -lt [System.Version]$InstallData.PackageInformation.Version) {
                    Write-Verbose -Message "Update version: $($AppUpdate.Version) less than install script version: $($InstallData.PackageInformation.Version)."
                }
                else {
                    Write-Verbose -Message "Could not compare install script version."
                }

                # Remove the zip file if it exists
                if (Test-Path -Path $Download.FullName -ErrorAction "SilentlyContinue") { Remove-Item -Path $Download.FullName -Force -ErrorAction "SilentlyContinue" }
            }
            else {
                Write-Warning -Message "Cannot find: $InstallConfiguration."
            }
            #endregion
        }
        else {
            Write-Host "Failed to return details from: $($Manifest.Application.Filter )"
        }
    }
}
