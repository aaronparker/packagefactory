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
    $Version = Get-ChildItem -Path "${Env:ProgramFiles(x86)}\Microsoft\EdgeWebView\Application" | Where-Object { $_.Name -match "(\d+(\.\d+){1,4}).*" } | `
        Sort-Object -Property @{ Expression = { [System.Version]$_.Name }; Descending = $true }
    $Setup = Resolve-Path -Path "$($Version.FullName)\Installer\setup.exe"
    $params = @{
        FilePath     = $Setup.Path
        ArgumentList = "--force-uninstall --uninstall --msedgewebview --system-level --verbose-logging"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
}
catch {
    throw $_
}
finally {
    exit $result.ExitCode
}
