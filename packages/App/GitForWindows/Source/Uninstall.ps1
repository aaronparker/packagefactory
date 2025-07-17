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
    $Uninstall = Get-InstalledSoftware | Where-Object { $_.Name -match "SoapUI*" }
    $ArgumentList = "/uninstall `"$($Uninstall.PSChildName)`" /quiet /norestart"
}
catch {
    throw $_
}
finally {
    exit $result.ExitCode
}
