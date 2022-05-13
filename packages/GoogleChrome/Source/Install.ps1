<#
    .SYNOPSIS
    Installs the application
#>
[CmdletBinding()]
Param ()

try {
    $Installer = Get-ChildItem -Path $PWD -Filter "googlechromestandaloneenterprise64.msi" -Recurse -ErrorAction "SilentlyContinue"
    $params = @{
        FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/package `"$($Installer.FullName)`" ALLUSERS=1 /quiet"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params

    # Copy the initial_preferences file
    $File = Get-ChildItem -Path $PWD -Filter "initial_preferences" -Recurse -ErrorAction "SilentlyContinue"
    Copy-Item -Path $File.FullName -Destination "$Env:ProgramFiles\Google\Chrome\Application\initial_preferences" -Force -ErrorAction "SilentlyContinue" | Out-Null
}
catch {
    throw "Failed to install Google Chrome."
}
finally {
    exit $result.ExitCode
}
