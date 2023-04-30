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
    # Get the path to Uninstall.exe
    $Path = "${env:ProgramFiles(x86)}\Lenovo\VantageService"
    $InstallDirectory = Get-ChildItem -Path $Path | Where-Object { $_.Name -match "(\d+(\.\d+){1,4})" } | `
        Sort-Object -Property @{ Expression = { [System.Version]$_.Name }; Descending = $true } | `
        Select-Object -First 1
    $Uninstall = [System.IO.Path]::Combine($Path, $InstallDirectory.Name, "Uninstall.exe")

    if (Test-Path -Path $Uninstall) {
        $params = @{
            FilePath     = [System.IO.Path]::Combine($Path, $InstallDirectory.Name, "Uninstall.exe")
            ArgumentList = "/SILENT"
            NoNewWindow  = $True
            PassThru     = $True
            Wait         = $True
        }
        $result = Start-Process @params
    }
    else {
        throw [System.IO.FileNotFoundException] "$Uninstall"
    }
}
catch {
    throw $_
}
finally {
    exit $result.ExitCode
}
