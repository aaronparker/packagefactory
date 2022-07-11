<#
    .SYNOPSIS
    Uninstalls the application
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
    Get-Process -ErrorAction "SilentlyContinue" | `
        Where-Object { $_.Path -like "$env:ProgramFiles\Greenshot\*" } | `
        Stop-Process -Force -ErrorAction "SilentlyContinue"
}
catch {
    Write-Warning -Message "Failed to stop OneDrive processes."
}

try {
    $params = @{
        FilePath     = "$env:ProgramFiles\Greenshot\unins000.exe"
        ArgumentList = "/VERYSILENT"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
    if ($result.ExitCode -eq 0) {
        Remove-Item -Path "$env:ProgramFiles\Greenshot" -Recurse -Force
    }
}
catch {
    throw "Failed to uninstall Greenshot."
}
finally {
    exit $result.ExitCode
}
