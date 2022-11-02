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
    Get-Process -ErrorAction "SilentlyContinue" | `
        Where-Object { $_.Path -like "$env:ProgramFiles\Microsoft OneDrive\*" } | `
        Stop-Process -Force -ErrorAction "SilentlyContinue"
}
catch {
    Write-Warning -Message "Failed to stop OneDrive processes."
}

try {
    $Path = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe"
    $Command = Get-ItemProperty -Path $Path -ErrorAction "SilentlyContinue" | Select-Object -ExpandProperty "UninstallString" -First 1
    $Executable = ($Command -split "/")[0]
    $params = @{
        FilePath     = $Executable
        ArgumentList = "/uninstall /allusers /quiet"
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
