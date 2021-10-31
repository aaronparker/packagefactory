# Specify the name of the application as it appears in the DisplayName value in the Uninstall key location
$ApplicationName = "<app_display_name>"

# Define minimum required version
$ApplicationVersion = "1.0.0"

# Process each key in 64-bit Uninstall registry path and detect if application is installed, or if a newer version exists that should be superseeded
$UninstallKeyPath = "HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
$UninstallKeys = Get-ChildItem -Path $UninstallKeyPath
foreach ($UninstallKey in $UninstallKeys) {
    $CurrentUninstallKey = Get-ItemProperty -Path $UninstallKey.PSPath -ErrorAction SilentlyContinue
    if ($CurrentUninstallKey.DisplayName -like $ApplicationName) {
        # An installed version of the application was detected, ensure the version info is equal to or greater than with what's specified as the minimum required version
        if ([System.Version]$CurrentUninstallKey.DisplayVersion -ge [System.Version]$ApplicationVersion) {
            return 0
        }
    }
}