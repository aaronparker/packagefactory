# Find the 
try {
    # Get the path to LenovoVantageService.exe
    $Path = "${env:ProgramFiles(x86)}\Lenovo\VantageService"
    $InstallDirectory = Get-ChildItem -Path $Path | Where-Object { $_.Name -match "(\d+(\.\d+){1,4})" } | `
        Sort-Object -Property @{ Expression = { [System.Version]$_.Name }; Descending = $true } | `
        Select-Object -First 1
    $Application = [System.IO.Path]::Combine($Path, $InstallDirectory.Name, "LenovoVantageService.exe")

    # Return success if found
    if (Test-Path -Path $Application) {
        return 0
    }
    else {
        return 1
    }
}
catch {
    return 1
}
