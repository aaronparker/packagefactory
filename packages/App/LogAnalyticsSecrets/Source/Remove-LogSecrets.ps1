#Requires -PSEdition Desktop
#Requires -RunAsAdministrator
<#
    Delete the key file
#>
[CmdletBinding()]
param (
    [System.String] $Path = "$Env:SystemRoot\System32\config\systemprofile\AppData\Local\key.xml"
)

begin {
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
}

process {
    try {
        if (Test-Path -Path $Path) {
            Remove-Item -Path $Path -Force -ErrorAction "SilentlyContinue"
        }
    }
    catch {
        throw $_
    }
}

end {
}
