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

if (Test-Path -Path "${env:ProgramFiles(x86)}\Microsoft\Teams\current\Teams.exe") {

    try {
        Get-Process -ErrorAction "SilentlyContinue" | `
            Where-Object { $_.Path -like "${env:ProgramFiles(x86)}\Microsoft\Teams*" } | `
            Stop-Process -Force -ErrorAction "SilentlyContinue"
    }
    catch {
        Write-Warning -Message "Failed to stop Teams processes."
    }

    try {
        $Product = Get-CimInstance -Class "Win32_Product" | Where-Object { $_.Caption -like "Teams Machine-Wide Installer" }
        $params = @{
            FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
            ArgumentList = "/uninstall `"$($Product.IdentifyingNumber)`" /quiet"
            NoNewWindow  = $True
            PassThru     = $True
            Wait         = $True
        }
        $result = Start-Process @params
        Remove-Item -Path "${env:ProgramFiles(x86)}\Microsoft\Teams" -Recurse -Force -ErrorAction "SilentlyContinue"
        Remove-Item -Path "${env:ProgramFiles(x86)}\Microsoft\TeamsPresenceAddin" -Recurse -Force -ErrorAction "SilentlyContinue"
    }
    catch {
        throw "Failed to uninstall Microsoft Teams."
    }
    finally {
        exit $result.ExitCode
    }
}

try {
    $Installer = Get-ChildItem -Path $PWD -Filter "Teams_windows_x64.msi" -Recurse -ErrorAction "SilentlyContinue"
    $params = @{
        FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/package `"$($Installer.FullName)`" OPTIONS=`"noAutoStart=true`" ALLUSER=1 ALLUSERS=1 /quiet"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
}
catch {
    throw "Failed to install Microsoft Teams."
}
finally {
    exit $result.ExitCode
}
