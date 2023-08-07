#Requires -PSEdition Desktop
#Requires -RunAsAdministrator
<#
    Encrypts secrets and saves to XML
#>
[CmdletBinding()]
param (
    [System.String] $WorkspaceId = "",
    [System.String] $SharedKey = "",
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
    if (Test-Path -Path $(Split-Path -Path $Path -Parent)) {
        # Path exists
    }
    else {
        New-Item -Path $(Split-Path -Path $Path -Parent) -ItemType "Directory" -Force | Out-Null
    }

    try {
        [PSCustomObject]@{
            WorkspaceId = $(ConvertTo-SecureString -String $WorkspaceId -AsPlainText -Force)
            SharedKey   = $(ConvertTo-SecureString -String $SharedKey -AsPlainText -Force)
        } | Export-Clixml -Path $Path -Force
    }
    catch {
        throw $_
    }
}

end {
}
