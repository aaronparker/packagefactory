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
    $Installer = Get-ChildItem -Path $PWD -Filter "FoxitPDFReader*Setup.msi" -Recurse -ErrorAction "SilentlyContinue"
    $Properties = "AUTO_UPDATE=0 NOTINSTALLUPDATE=1 MAKEDEFAULT=0 LAUNCHCHECKDEFAULT=0 VIEW_IN_BROWSER=0 DESKTOP_SHORTCUT=0 STARTMENU_SHORTCUT_UNINSTALL=0 DISABLE_UNINSTALL_SURVEY=1 ALLUSERS=1"
    $params = @{
        FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/package `"$($Installer.FullName)`" $Properties /quiet"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
}
catch {
    throw "Failed to install Foxit Reader."
}
finally {
    if ($result.ExitCode -eq 0) {
        $Files = @("$env:PUBLIC\Desktop\Greenshot.lnk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Greenshot\License.txt.lnk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Greenshot\Readme.txt.lnk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Greenshot\Uninstall Greenshot.lnk")
        Remove-Item -Path $Files -Force -ErrorAction "SilentlyContinue"
    }
    exit $result.ExitCode
}
