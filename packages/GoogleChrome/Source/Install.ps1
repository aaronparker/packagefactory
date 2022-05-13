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
        ArgumentList = "/package $($Installer.FullName) ALLUSERS=1 /quiet"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
}
catch {
    throw "Failed to install VLC media player."
}
finally {
    If ($result.ExitCode -eq 0) {
        $File = Get-ChildItem -Path $PWD -Filter "initial_preferences" -Recurse -ErrorAction "SilentlyContinue"
        Copy-Item -Path $File.FullName -Destination "$Env:ProgramFiles\Google\Chrome\Application\initial_preferences" -Force -ErrorAction "SilentlyContinue"
    }
    exit $result.ExitCode
}
