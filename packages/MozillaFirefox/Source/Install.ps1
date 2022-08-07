<#
    .SYNOPSIS
    Installs the application
#>
[CmdletBinding()]
param ()

#region Restart if running in a 32-bit session
If (!([System.Environment]::Is64BitProcess)) {
    If ([System.Environment]::Is64BitOperatingSystem) {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Definition)`""
        $ProcessPath = $(Join-Path -Path $Env:SystemRoot -ChildPath "\Sysnative\WindowsPowerShell\v1.0\powershell.exe")
        Write-Verbose -Message "Restarting in 64-bit PowerShell."
        Write-Verbose -Message "FilePath: $ProcessPath."
        Write-Verbose -Message "Arguments: $Arguments."
        $params = @{
            FilePath     = $ProcessPath
            ArgumentList = $Arguments
            Wait         = $True
            WindowStyle  = "Hidden"
        }
        Start-Process @params
        Exit 0
    }
}
#endregion

try {
    New-Item -Path "$env:ProgramData\PackageFactory\Logs" -ItemType "Directory" -ErrorAction "SilentlyContinue" | Out-Null
    $Installer = Get-ChildItem -Path $PWD -Filter "Firefox*.msi" -Recurse -ErrorAction "SilentlyContinue"
    $params = @{
        FilePath     = "$env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/install `"$($Installer.FullName)`" DESKTOP_SHORTCUT=false TASKBAR_SHORTCUT=false /quiet /log `"C:\ProgramData\PackageFactory\logs\MozillaFirefox.log`""
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
}
catch {
    throw "Failed to install Mozilla Firefox."
}
finally {
    exit $result.ExitCode
}
