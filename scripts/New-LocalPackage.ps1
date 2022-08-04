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
    [System.String[]] $Applications = @("MicrosoftVcRedist2022x86", "MicrosoftVcRedist2022x64", "AdobeAcrobatReaderDC")
)

foreach ($Application in $Applications) {

    $Apps = Get-Content -Path "$Path\Applications.json" | ConvertFrom-Json
    $Filter = ($Apps | Where-Object { $_.Name -eq "$Application" }).Filter
    if ($Filter -match "Get-VcList") {
        $App = Invoke-Expression -Command $Filter
        $Filename = $(Split-Path -Path $App.Download -Leaf)
        Write-Host "Package: $($App.Name); $Filename."
        New-Item -Path "$Path\packages\$Application\Source" -ItemType "Directory" -Force | Out-Null
        Invoke-WebRequest -Uri $App.Download -OutFile "$Path\packages\$Application\Source\$Filename" -UseBasicParsing
    }
    else {
        $result = Invoke-Expression -Command $Filter | Save-EvergreenApp -CustomPath "$Path\packages\$Application\Source"
        if ($result.FullName -match "\.zip$") {
            Expand-Archive -DestinationPath "$Path\packages\$Application\Source"
            Remove-Item -Path $result.FullName -Force
        }
    }

    $params = @{
        Application       = $Application
        Path              = "$Path\packages"
        DisplayNameSuffix = ""
    }
    .\Create-Win32App.ps1 @params
}
