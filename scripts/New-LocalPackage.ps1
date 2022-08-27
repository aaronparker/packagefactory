#Requires -PSEdition Desktop
#Requires -Modules Evergreen, VcRedist
<#
    Import application packages into Intune locally
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
param (
    [Parameter()]
    [System.String] $Path = "E:\projects\packagefactory",

    [Parameter()]
    [System.String] $PackageFolder = "packages",

    [Parameter()]
    [System.String] $PackageManifest = "App.json",

    [Parameter()]
    [System.String[]] $Applications = @("Microsoft.NET",
        "MicrosoftVcRedist2022x86",
        "MicrosoftVcRedist2022x64",
        "AdobeAcrobatReaderDC",
        "ImageCustomise")
)

foreach ($Application in $Applications) {
    try {
        # Get the application details
        Write-Host "Application: $Application"
        $AppPath = [System.IO.Path]::Combine($Path, $PackageFolder, $Application)
        Write-Host -ForegroundColor "Cyan" "Read: $([System.IO.Path]::Combine($AppPath, $PackageManifest))"
        $Manifest = Get-Content -Path $([System.IO.Path]::Combine($AppPath, $PackageManifest)) | ConvertFrom-Json
    }
    catch {
        throw $_
    }
    
    # Download the application installer
    if ($Null -eq $Manifest.Application.Filter) {
        Write-Host -ForegroundColor "Cyan" "$Application not supported for automatic download."
    }
    else {
        if ($Manifest.Application.Filter -match "Get-VcList") {

            Write-Host -ForegroundColor "Cyan" "Filter: $($Manifest.Application.Filter)"
            $App = Invoke-Expression -Command $Manifest.Application.Filter
            $Filename = $(Split-Path -Path $App.Download -Leaf)
            Write-Host -ForegroundColor "Cyan" "Package: $($App.Name); $Filename."
            New-Item -Path [System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder) -ItemType "Directory" -Force | Out-Null
            Invoke-WebRequest -Uri $App.Download -OutFile $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder, $Filename)) -UseBasicParsing
        }
        else {

            Write-Host -ForegroundColor "Cyan" "Filter: $($Manifest.Application.Filter)"
            $result = Invoke-Expression -Command $Manifest.Application.Filter | Save-EvergreenApp -CustomPath $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder))
            if ($result.FullName -match "\.zip$") {
                Expand-Archive -Path $result.FullName -DestinationPath $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder)) -Force
                Remove-Item -Path $result.FullName -Force
            }
        }
    }

    # Package the application
    if (Test-Path -Path $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder))) {
        $params = @{
            Application       = $Application
            Path              = $([System.IO.Path]::Combine($Path, $PackageFolder))
            DisplayNameSuffix  = ""
        }
        .\Create-Win32App.ps1 @params
    }
    else {
        Write-Error -Message "Cannot find path $([System.IO.Path]::Combine($AppPath, $Manifest.PackageInformation.SourceFolder))"
    }
}
