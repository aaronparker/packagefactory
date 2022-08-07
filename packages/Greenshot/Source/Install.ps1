<#
    .SYNOPSIS
    Installs the application
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
    New-Item -Path "$env:ProgramData\PackageFactory\Logs" -ItemType "Directory" -ErrorAction "SilentlyContinue" | Out-Null
    $Installer = Get-ChildItem -Path $PWD -Filter "Greenshot-INSTALLER-*-RELEASE.exe" -Recurse -ErrorAction "SilentlyContinue"
    $params = @{
        FilePath     = $Installer.FullName
        ArgumentList = "/VERYSILENT /NORESTART /LOG=`"$env:ProgramData\PackageFactory\Logs\Greenshot.log`""
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params

    # Create the initial_preferences file
    $IniFile = Get-ChildItem -Path $PWD -Filter "greenshot-defaults.ini" -Recurse -ErrorAction "SilentlyContinue"
    $params = @{
        Path        = $IniFile.FullName
        Destination = "$env:ProgramFiles\Greenshot"
        Force       = $True
        ErrorAction = "SilentlyContinue"
    }
    Copy-Item @params
}
catch {
    throw "Failed to install Greenshot."
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
