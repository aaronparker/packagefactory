<#
    .SYNOPSIS
    Installs the application
#>
[CmdletBinding()]
param ()

try {
    $Installer = Get-ChildItem -Path $PWD -Filter "PowerToysSetup*.exe" -Recurse -ErrorAction "SilentlyContinue"
    $params = @{
        FilePath     = $Installer.FullName
        ArgumentList = "/install /quiet /norestart"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
}
catch {
    throw "Failed to install Microsoft PowerToys."
}
finally {
    exit $result.ExitCode
}
