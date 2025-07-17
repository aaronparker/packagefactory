$software = "HP Insights"

$installed = Get-ItemProperty -Path `
    "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*", `
    "HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*" `
    -ErrorAction SilentlyContinue | Where-Object { $_.DisplayName -like "*$software*" }

if ($installed) { Write-Host "$software not uninstalled"; exit 1 } else { Write-Host "$software uninstalled"; exit 0 }