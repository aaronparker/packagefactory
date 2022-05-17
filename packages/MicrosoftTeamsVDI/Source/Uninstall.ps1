<#
    .SYNOPSIS
    Uninstalls the application
#>
[CmdletBinding()]
Param ()

try {
    Get-Process -ErrorAction "SilentlyContinue" | `
        Where-Object { $_.Path -like "${env:ProgramFiles(x86)}\Microsoft\Teams*" } | `
        Stop-Process -Force -ErrorAction "SilentlyContinue"
}
catch {
    Write-Warning -Message "Failed to stop Teams processes."
}

try {
    $Product = Get-CimInstance -Class "Win32_Product" | Where-Object { $_.Caption -like "Teams Machine-Wide Installer" }
    $params = @{
        FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/uninstall `"$($Product.IdentifyingNumber)`" /quiet"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
}
catch {
    throw "Failed to uninstall Google Chrome."
}
finally {
    exit $result.ExitCode
}
