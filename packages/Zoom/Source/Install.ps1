<#
    .SYNOPSIS
    Installs the application
    https://support.zoom.us/hc/en-us/articles/201362163-Mass-deploying-with-preconfigured-settings-for-Windows
#>
[CmdletBinding()]
param ()

#region Restart if running in a 32-bit session
if (!([System.Environment]::Is64BitProcess)) {
    if ([System.Environment]::Is64BitOperatingSystem) {
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
        exit 0
    }
}
#endregion

try {
    $Installer = Get-ChildItem -Path $PWD -Filter "ZoomInstallerFull.msi" -Recurse -ErrorAction "SilentlyContinue"
    $params = @{
        FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/package `"$($Installer.FullName)`" ALLUSERS=1 zSilentStart=false zNoDesktopShortCut=true /log `"$env:ProgramData\PackageFactory\Logs\ZoomMeetingsClient.log`" /quiet"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
}
catch {
    throw "Failed to install Zoom Cloud Meetings."
}
finally {
    if ($result.ExitCode -eq 0) {
        $Files = @("$env:PUBLIC\Desktop\Zoom.lnk")
        Remove-Item -Path $Files -Force -ErrorAction "SilentlyContinue"
    }
    exit $result.ExitCode
}
