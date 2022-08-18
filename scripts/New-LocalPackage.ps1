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

    # Get the application details
    $Apps = Get-Content -Path "$Path\Applications.json" | ConvertFrom-Json
    $Filter = ($Apps | Where-Object { $_.Name -eq "$Application" }).Filter

    # Download the application installer
    if ($Null -ne $Filter) {
        if ($Filter -match "Get-VcList") {
            Write-Host "Filter: $Filter"
            $App = Invoke-Expression -Command $Filter
            $Filename = $(Split-Path -Path $App.Download -Leaf)
            Write-Host "Package: $($App.Name); $Filename."
            New-Item -Path "$Path\packages\$Application\Source" -ItemType "Directory" -Force | Out-Null
            Invoke-WebRequest -Uri $App.Download -OutFile "$Path\packages\$Application\Source\$Filename" -UseBasicParsing
        }
        else {
            Write-Host "Filter: $Filter"
            $result = Invoke-Expression -Command $Filter | Save-EvergreenApp -CustomPath "$Path\packages\$Application\Source"
            if ($result.FullName -match "\.zip$") {
                Expand-Archive -Path $result.FullName -DestinationPath "$Path\packages\$Application\Source" -Force
                Remove-Item -Path $result.FullName -Force
            }
        }
    }
    else {
        Write-Host -ForegroundColor "Cyan" "$Application not supported for automatic download."
    }

    # Package the application
    if (Test-Path -Path "$Path\packages\$Application\Source") {
        $params = @{
            Application       = $Application
            Path              = "$Path\packages"
            DisplayNameSuffix = ""
        }
        .\Create-Win32App.ps1 @params
    }
    else {
        Write-Error -Message "Cannot find path $("$Path\packages\$Application\Source")"
    }
}
