<#
    .SYNOPSIS
    Uninstalls the application
#>
[CmdletBinding()]
Param ()

try {
    $Chrome = Get-CimInstance -Class "Win32_Product" | Where-Object { $_.Caption -like "Google Chrome" }
    $params = @{
        FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/uninstall `"$($Chrome.IdentifyingNumber)`" /quiet"
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


