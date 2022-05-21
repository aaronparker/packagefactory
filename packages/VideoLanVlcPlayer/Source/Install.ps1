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
    $Installer = Get-ChildItem -Path $PWD -Filter "vlc*.msi" -Recurse -ErrorAction "SilentlyContinue"
    $params = @{
        FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/package `"$($Installer.FullName)`" ALLUSERS=1 /quiet"
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
        $Files = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\VideoLAN\VLC\VideoLAN website.lnk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\VideoLAN\VLC\Release Notes.lnk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\VideoLAN\VLC\Documentation.lnk",
            "$env:PUBLIC\Desktop\VLC media player.lnk")
        Remove-Item -Path $Files -Force -ErrorAction "SilentlyContinue"
    }
    exit $result.ExitCode
}
