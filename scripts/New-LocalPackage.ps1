$Application = "MicrosoftVcRedist2022x86"
$Apps = Get-Content -Path "E:\Temp\packagefactory\Applications.json" | ConvertFrom-Json
$Filter = ($Apps | Where-Object { $_.Name -eq "$Application" }).Filter
if ($Filter -match "Get-VcList") {
    $App = Invoke-Expression -Command $Filter
    $Filename = $(Split-Path -Path $App.Download -Leaf)
    Write-Host "Package: $($App.Name); $Filename."
    New-Item -Path "E:\Temp\packagefactory\packages\$Application\Source" -ItemType "Directory" -Force | Out-Null
    Invoke-WebRequest -Uri $App.Download -OutFile "E:\Temp\packagefactory\packages\$Application\Source\$Filename" -UseBasicParsing
} else {
    $result = Invoke-Expression -Command $Filter | Save-EvergreenApp -CustomPath "E:\Temp\packagefactory\packages\$Application\Source"
    If ($result.FullName -match "\.zip$") {
        Expand-Archive -DestinationPath "E:\Temp\packagefactory\packages\$Application\Source"
        Remove-Item -Path $result.FullName -Force
    }
}

$params = @{
    Application       = $Application
    Path              = "E:\Temp\packagefactory\packages"
    DisplayNameSuffix = ""
}
.\Create-Win32App.ps1 @params
