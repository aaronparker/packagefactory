<#
    .SYNOPSIS
    Uninstalls the application
#>
[CmdletBinding()]
Param ()

try {
    $Path = "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\{7f0d7424-d132-4aaf-baa9-5d7d436f0feb}"
    $Command = Get-ItemProperty -Path $Path -ErrorAction "SilentlyContinue" | Select-Object -ExpandProperty "QuietUninstallString" -First 1
    $Executable = ($Command -split "/")[0]
    $params = @{
        FilePath     = $Executable
        ArgumentList = "/uninstall /quiet /norestart"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
}
catch {
    throw "Failed to uninstall Microsoft PowerToys."
}
finally {
    exit $result.ExitCode
}
