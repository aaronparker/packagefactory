<#
    .SYNOPSIS
    Uninstalls an application

    .NOTES
	Author: Aaron Parker

	Date      	Author          Comments
	----------	---             ----------------------------------------------------------
	2022-12-29	Constantin Lotz	Added more logging capabilities for the script itself 
	2022-12-29	Aaron Parker    Initial version
#>
[CmdletBinding(SupportsShouldProcess = $false)]
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
$Uninstaller = "$env:ProgramFiles\FileZilla FTP Client\uninstall.exe"
$Arguments = "/S"
$SetupPath = "$env:ProgramFiles\FileZilla FTP Client" # No Ending Trail

$Logging = $true
$Script:LogFile = "$Env:ProgramData\Microsoft\IntuneManagementExtension\Logs\PackageFactoryInstall.log"

#region Logging Function 
function Write-Feedback {
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true, Mandatory = $true)]
        [System.String] $Msg,
        [Parameter(Position = 1, ValueFromPipeline = $true, Mandatory = $false)]
        [System.String] $LogOnly,
        [Parameter(Position = 2, ValueFromPipeline = $true, Mandatory = $false)]
        [System.String] $Severity
    )

    # Call Example:
    # $logtime = get-date -format 'dd.MM.yyyy;HH:mm:ss'
    # Write-Feedback -Msg "$logtime - Info:Frage TFK Settings ab. User: $($phoneExtension) - AutoLogoffEnabled: $($userSettings.serviceAutoLogoffEnabled)"
	
    # Datei leeren wenn größer 50MB
    if ((Test-Path -Path $LogFile) -eq $true) {
        If ((Get-Item $LogFile).length -gt 50mb) {
            Clear-Content $Script:LogFile
            $LogTime = Get-Date -Format 'dd.MM.yyyy;HH:mm:ss'
            $Msg = "$LogTime - " + "Info" + ":" + "LogFile geleert, da größer als 50MB."
        }
    }
    
    # Wenn Schweregrad angegeben dann baue String korrekt
    if (![System.String]::IsNullOrEmpty($severity)) {
        $LogTime = Get-Date -Format 'dd.MM.yyyy;HH:mm:ss'
        $Msg = "$LogTime - " + $Severity + ":" + $Msg
    }

    # Nur In Datei loggen, aber nicht in Konsole
    if ($LogOnly.IsPresent) {
        $Msg | Out-File $Script:LogFile -Append
    }
    else {
        Write-Information -MessageData $Msg -InformationAction "Continue"
        $Msg | Out-File $Script:LogFile -Append
    }
}
#endregion



try {
    if ($Logging) { Write-Feedback -Msg "Stop processes" -Severity "Info" -LogOnly }
    Get-Process -ErrorAction "SilentlyContinue" | `
        Where-Object { $_.Path -like "$SetupPath\*" } | `
        Stop-Process -Force -ErrorAction "SilentlyContinue"
}
catch {
    Write-Warning -Message "Failed to stop processes."
    if ($Logging) { Write-Feedback -Msg "Failed to stop processes." -Severity "Error" -LogOnly }
}

try {
    $params = @{
        FilePath     = $Uninstaller
        ArgumentList = $Arguments
        NoNewWindow  = $true
        PassThru     = $true
        Wait         = $true
    }

    if ($Logging) {
        Write-Feedback -Msg "Removing program: '$Uninstaller'" -Severity "Info" -LogOnly
        Write-Feedback -Msg "With parameters: '$Arguments'" -Severity "Info" -LogOnly
    }
    $result = Start-Process @params
    if ($Logging) { Write-Feedback -Msg "Exit code: $($result.ExitCode)" -Severity "Info" -logOnly }
    if ($result.ExitCode -eq 0) {
        Remove-Item -Path $SetupPath -Recurse  -ErrorAction SilentlyContinue
        if ($Logging) { Write-Feedback -Msg "Removed program: $SetupPath" -Severity "Info" -LogOnly }
    }
}
catch {
    throw $_
}
finally {
    exit $result.ExitCode
}