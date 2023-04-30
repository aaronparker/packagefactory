<#
    .SYNOPSIS
    Uninstalls the application
#>
[CmdletBinding()]
param ()

#region Restart if running in a 32-bit session
if (!([System.Environment]::Is64BitProcess)) {
    if ([System.Environment]::Is64BitOperatingSystem) {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Definition)`""
        $ProcessPath = $(Join-Path -Path $Env:SystemRoot -ChildPath "\Sysnative\WindowsPowerShell\v1.0\powershell.exe")

        $params = @{
            FilePath     = $ProcessPath
            ArgumentList = $Arguments
            Wait         = $True
            WindowStyle  = "Hidden"
        }
        Start-Process @params
        exit 0
    }
}
#endregion

try {
    # Remove the directory
    $Path = "$Env:ProgramFiles\RemoteDisplayAnalyzer"
    Get-Process -ErrorAction "SilentlyContinue" | `
        Where-Object { $_.Path -like "$Env:ProgramFiles\RemoteDisplayAnalyzer\*" } | `
        Stop-Process -Force -ErrorAction "SilentlyContinue"
    Remove-Item -Path $Path -Force -Recurse
}
catch {
    throw $_
}
