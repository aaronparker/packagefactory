#Requires -PSEdition Desktop
#Requires -RunAsAdministrator
<#
    Uses Evergreen to download and install Azure Devops Pipeline agent
#>
[CmdletBinding()]
param (
    [System.String] $Path = "$Env:SystemDrive\agents",
    [System.String] $KeyFile = "$Env:SystemRoot\System32\config\systemprofile\AppData\Local\DevOpsKey.xml"
)

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

#region Read secrets file
if (Test-Path -Path $KeyFile) {
    continue
}
else {
    throw [System.IO.FileNotFoundException]::new("$KeyFile not found.")
}
try {
    $Secrets = Import-Clixml -Path $KeyFile
}
catch {
    throw $_
}

# Check that the required variables have been set in the key file
foreach ($Value in "DevOpsUser", "DevOpsPat") {
    if ($null -eq $Secrets.$Value) { throw "$Value is $null" }
}
#endregion

#region Script logic
try {
    Push-Location -Path $Path
    $params = @{
        FilePath     = "$Path\config.cmd"
        ArgumentList = "remove --unattended --auth pat --token `"$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secrets.DevOpsPat)))`""
        Wait         = $true
        NoNewWindow  = $true
        PassThru     = $true
    }
    Start-Process @params
}
catch {
    throw $_
}

# Remove the C:\agents directory and the local user account used by the agent service
Remove-Item -Path $Path -Recurse -Force -ErrorAction "SilentlyContinue"
Remove-LocalUser -Name $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secrets.DevOpsUser))) -Confirm:$false -ErrorAction "SilentlyContinue"
#endregion
