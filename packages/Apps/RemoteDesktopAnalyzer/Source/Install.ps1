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
    # Copy the file into the target path
    $DestinationPath = "$Env:ProgramFiles\RemoteDisplayAnalyzer"
    New-Item -Path $DestinationPath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null
    $File = Get-ChildItem -Path $PWD -Include "RemoteDisplayAnalyzer.exe" -Recurse
    Copy-Item -Path $File.FullName -Destination $DestinationPath -Force
}
catch {
    throw $_
}
