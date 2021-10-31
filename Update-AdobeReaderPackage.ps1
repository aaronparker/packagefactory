
$r = Get-EvergreenApp -Name "AdobeAcrobatReaderDC"
$Reader = $r | Where-Object { $_.Language -eq "English" -and $_.Architecture -eq "x64" }
$json = Get-Content -Path "./App.json" | ConvertFrom-Json
$json.PackageInformation.SetupFile = $(Split-Path -Path $Reader.URI -Leaf)
$json.Information.DisplayName = "Adobe Acrobat Reader DC $($Reader.Version) $($Reader.Architecture)"
$json.DetectionRule[0].Value = $Reader.Version
$json | ConvertTo-Json | Out-File -Path "./App.json" -Force
