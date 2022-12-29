<#
 # File: c:\dev\intunepacketfactory\packages\Apps\Filezilla\Source\Install.ps1
 # Project: c:\dev\intunepacketfactory\packages\Apps\Filezilla\Source
 # Created Date: Thursday, December 29th 2022, 8:59:14 am
 # Author: Aaron Parker
 # -----
 # Description: Uninstalls the Application
 # -----
 # Last Modified: Thu Dec 29 2022
 # Modified By: Constantin Lotz
 # -----
 # 
 #  
 # -----
 # HISTORY:
 # Date      	By	Comments
 # ----------	---	----------------------------------------------------------
 # 2022-12-29	CL	added more logging capabilitys for the script itself 
 # 2022-12-29	AP  initial	
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

# Define Params here
$uninstaller            = "$env:ProgramFiles\FileZilla FTP Client\uninstall.exe"
$uninstallerArguments   = "/S"
$setupLocation          = "$env:ProgramFiles\FileZilla FTP Client" # No Ending Trail

# Logging Function 
$logging = $true;
$global:logfile = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Uninstallps1.log";

function Write-Feedback()
{
    param
    (
        [Parameter(Position=0,ValueFromPipeline=$true,Mandatory=$true)]
        [string]$msg,
        [Parameter(Position=1,ValueFromPipeline=$true,Mandatory=$false)]
        [switch]$logOnly,
        [Parameter(Position=2,ValueFromPipeline=$true,Mandatory=$false)]
        [string]$severity
    )

	# Call Example:
	# $logtime = get-date -format 'dd.MM.yyyy;HH:mm:ss'
	# Write-Feedback "$logtime - Info:Frage TFK Settings ab. User: $($phoneExtension) - AutoLogoffEnabled: $($userSettings.serviceAutoLogoffEnabled)"
	
    # Datei leeren wenn größer 50MB
    if ((Test-Path -Path $logfile) -eq $true) {
        If ((Get-Item $logfile).length -gt 50mb) {
            Clear-Content $global:logfile
            $logtime = get-date -format 'dd.MM.yyyy;HH:mm:ss'
            $msg = "$logtime - " + "Info" + ":" + "Logfile geleert, da größer als 50MB."
        }
    }
    
    # Wenn Schweregrad angegeben dann baue String korrekt
    if (![string]::IsNullOrEmpty($severity)) {
        $logtime = get-date -format 'dd.MM.yyyy;HH:mm:ss'
        $msg = "$logtime - " + $severity + ":" + $msg
    }

    # Nur In Datei loggen, aber nicht in Konsole
    if($logOnly.IsPresent)  {
        $msg | Out-File $global:logfile -Append
    } else {
        Write-Host $msg;
        $msg | Out-File $global:logfile -Append
    }
	
}
### End Logging Function



try {
    if ($logging) { Write-Feedback "Try stopping Processes....." -severity "Info" -logOnly }
    Get-Process -ErrorAction "SilentlyContinue" | `
        Where-Object { $_.Path -like "$setupLocation\*" } | `
        Stop-Process -Force -ErrorAction "SilentlyContinue"
}
catch {
    Write-Warning -Message "Failed to stop processes."
    if ($logging) { Write-Feedback "Failed to stop processes." -severity "Error" -logOnly }
}

try {
    $params = @{
        FilePath     = "$uninstaller"
        ArgumentList = "$uninstallerArguments"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }

    if ($logging) { Write-Feedback "Removing Programm: $uninstaller" -severity "Info" -logOnly }
    if ($logging) { Write-Feedback "Removing Parameters: $uninstallerArguments" -severity "Info" -logOnly }
    $result = Start-Process @params
    if ($logging) { Write-Feedback "Exit Code: $($result.ExitCode)" -severity "Info" -logOnly }
    if ($result.ExitCode -eq 0) {
        Remove-Item -Path $setupLocation -Recurse  -ErrorAction SilentlyContinue
        if ($logging) { Write-Feedback "Removing Programm File Location: $setupLocation" -severity "Info" -logOnly }
    }
}
catch {
    throw $_
}
finally {
    exit $result.ExitCode
}
