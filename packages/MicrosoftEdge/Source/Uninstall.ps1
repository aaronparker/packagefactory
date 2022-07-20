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
    $Version = Get-ChildItem -Path "${Env:ProgramFiles(x86)}\Microsoft\Edge\Application" | Where-Object { $_.Name -match "(\d+(\.\d+){1,4}).*" } | `
        Sort-Object -Property @{ Expression = { [System.Version]$_.Name }; Descending = $true }
    $Setup = Resolve-Path -Path "$($Version.FullName)\Installer\setup.exe"
    $params = @{
        FilePath     = $Setup.Path
        ArgumentList = "--uninstall --force-uninstall --system-level"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
}
catch {
    throw "Failed to uninstall Microsoft Edge."
}
finally {
    exit $result.ExitCode
}
