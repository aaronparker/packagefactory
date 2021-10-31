# Specify the name of the application as it appears in the DisplayName value in the Uninstall key location
$ApplicationName = "<app_display_name>"

# Process each key in 32-bit and 64-bit Uninstall registry paths to detect if application is already installed
$UninstallKeyPaths = @("HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall", "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall")
foreach ($UninstallKeyPath in $UninstallKeyPaths) {
    $UninstallKeys = Get-ChildItem -Path $UninstallKeyPath
    foreach ($UninstallKey in $UninstallKeys) {
        $CurrentUninstallKey = Get-ItemProperty -Path $UninstallKey.PSPath -ErrorAction SilentlyContinue
        if ($CurrentUninstallKey.DisplayName -like $ApplicationName) {
            return 1
        }
    }
}

# Handle non-detected applications
return 0