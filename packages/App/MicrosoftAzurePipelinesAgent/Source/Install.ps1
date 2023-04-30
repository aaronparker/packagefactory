#Requires -PSEdition Desktop
#Requires -RunAsAdministrator
<#
    Uses Evergreen to download and install Azure Devops Pipeline agent
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingConvertToSecureStringWithPlainText", "", Justification = "Needed when creating the local user account.")]
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
foreach ($Value in "DevOpsUrl", "DevOpsPat", "DevOpsPool", "DevOpsUser", "DevOpsPassword") {
    if ($null -eq $Secrets.$Value) { throw "$Value is $null" }
}
#endregion

#region Script logic
# Trust the PSGallery for modules
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name "NuGet" -MinimumVersion "2.8.5.208" -Force -ErrorAction "SilentlyContinue"
Install-PackageProvider -Name "PowerShellGet" -MinimumVersion "2.2.5" -Force -ErrorAction "SilentlyContinue"
if (Get-PSRepository | Where-Object { $_.Name -eq "PSGallery" -and $_.InstallationPolicy -ne "Trusted" }) {
    Set-PSRepository -Name "PSGallery" -InstallationPolicy "Trusted"
}

# Install the Evergreen module; https://github.com/aaronparker/Evergreen
$InstalledModule = Get-Module -Name "Evergreen" -ListAvailable -ErrorAction "SilentlyContinue" | `
    Sort-Object -Property @{ Expression = { [System.Version]$_.Version }; Descending = $true } -ErrorAction "SilentlyContinue" | `
    Select-Object -First 1
$PublishedModule = Find-Module -Name "Evergreen" -ErrorAction "SilentlyContinue"
if (($null -eq $InstalledModule) -or ([System.Version]$PublishedModule.Version -gt [System.Version]$InstalledModule.Version)) {
    Write-Information -MessageData ":: Install module: "Evergreen"" -InformationAction "Continue"
    $params = @{
        Name               = "Evergreen"
        SkipPublisherCheck = $true
        Scope              = "CurrentUser"
        Force              = $true
        ErrorAction        = "Stop"
    }
    Install-Module @params
}
#endregion

#region Script logic
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null

try {
    # Download
    Import-Module -Name "Evergreen" -Force
    $App = Get-EvergreenApp -Name "MicrosoftAzurePipelinesAgent" | `
        Where-Object { $_.Architecture -eq "x64" } | `
        Select-Object -First 1
    $OutFile = Save-EvergreenApp -InputObject $App -CustomPath $Env:Temp -WarningAction "SilentlyContinue"
}
catch {
    throw $_.Exception.Message
}

try {
    # Create the local account that the DevOps Pipelines agent service will run under
    $params = @{
        Name                     = $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secrets.DevOpsUser)))
        Password                 = $(ConvertTo-SecureString -String $([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secrets.DevOpsPassword))) -AsPlainText -Force)
        Description              = "Azure Pipelines agent service for elevated exec."
        UserMayNotChangePassword = $true
        Confirm                   = $false
    }
    New-LocalUser @params
    Add-LocalGroupMember -Group "Administrators" -Member $DevOpsUser
}
catch {
    throw $_
}

try {
    Expand-Archive -Path $OutFile.FullName -DestinationPath $Path -Force
    Push-Location -Path $Path

    # Agent install options
    $Options = "--unattended
        --url `"$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secrets.DevOpsUrl)))`"
        --auth pat
        --token `"$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secrets.DevOpsPat)))`"
        --pool `"$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secrets.DevOpsPool)))`"
        --agent $Env:COMPUTERNAME
        --runAsService
        --windowsLogonAccount `"$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secrets.DevOpsUser)))`"
        --windowsLogonPassword `"$([System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($Secrets.DevOpsPassword)))`"
        --replace"
    $params = @{
        FilePath     = "$Path\config.cmd"
        ArgumentList = $($Options -replace "\s+", " ")
        Wait         = $true
        NoNewWindow  = $true
        PassThru     = $true
    }
    Start-Process @params
}
catch {
    throw $_
}
#endregion
