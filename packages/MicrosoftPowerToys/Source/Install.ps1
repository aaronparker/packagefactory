<#
    .SYNOPSIS
    Installs the application
#>
[CmdletBinding()]
param ()

try {
    New-Item -Path "$env:ProgramData\PackageFactory\Logs" -ItemType "Directory" -ErrorAction "SilentlyContinue" | Out-Null
    $Installer = Get-ChildItem -Path $PWD -Filter "PowerToysSetup*.exe" -Recurse -ErrorAction "SilentlyContinue"
    $params = @{
        FilePath     = $Installer.FullName
        ArgumentList = "/install /quiet /norestart /log $env:ProgramData\PackageFactory\Logs\MicrosoftPowerToys.log"
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
