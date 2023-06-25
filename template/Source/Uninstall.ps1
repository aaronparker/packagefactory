<#
    .SYNOPSIS
        Template script to uninstall an application

    .NOTES
        Author: Aaron Parker
        Update: Constantin Lotz
#>
[CmdletBinding(SupportsShouldProcess = $false)]
param ()

# Pass WhatIf and Verbose preferences to functions and cmdlets below
if ($WhatIfPreference -eq $true) { $Script:WhatIfPref = $true } else { $WhatIfPref = $false }
if ($VerbosePreference -eq $true) { $Script:VerbosePref = $true } else { $VerbosePref = $false }

#region Restart if running in a 32-bit session
if (!([System.Environment]::Is64BitProcess)) {
    if ([System.Environment]::Is64BitOperatingSystem) {

        # Create a string from the passed parameters
        [System.String]$ParameterString = ""
        foreach ($Parameter in $PSBoundParameters.GetEnumerator()) {
            $ParameterString += " -$($Parameter.Key) $($Parameter.Value)"
        }

        # Execute the script in a 64-bit process with the passed parameters
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Definition)`"$ParameterString"
        $ProcessPath = $(Join-Path -Path $Env:SystemRoot -ChildPath "\Sysnative\WindowsPowerShell\v1.0\powershell.exe")
        Write-LogFile -Message "Restarting in 64-bit PowerShell."
        Write-LogFile -Message "File path: $ProcessPath."
        Write-LogFile -Message "Arguments: $Arguments."
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

#region Logging Function
function Write-LogFile {
    <#
        .SYNOPSIS
            This function creates or appends a line to a log file

        .DESCRIPTION
            This function writes a log line to a log file in the form synonymous with
            ConfigMgr logs so that tools such as CMtrace and SMStrace can easily parse
            the log file.  It uses the ConfigMgr client log format's file section
            to add the line of the script in which it was called.

        .PARAMETER  Message
            The message parameter is the log message you'd like to record to the log file

        .PARAMETER  LogLevel
            The logging level is the severity rating for the message you're recording. Like ConfigMgr
            clients, you have 3 severity levels available; 1, 2 and 3 from informational messages
            for FYI to critical messages that stop the install. This defaults to 1.

        .EXAMPLE
            PS C:\> Write-LogFile -Message 'Value1' -LogLevel 'Value2'
            This example shows how to call the Write-LogFile function with named parameters.

        .NOTES
            Constantin Lotz;
            Adam Bertram, https://github.com/adbertram/PowerShellTipsToWriteBy/blob/f865c4212284dc25fe613ca70d9a4bafb6c7e0fe/chapter_7.ps1#L5
    #>
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true, Mandatory = $true)]
        [System.String] $Message,

        [Parameter(Position = 1, Mandatory = $false)]
        [ValidateSet(1, 2, 3)]
        [System.Int16] $LogLevel = 1
    )

    process {
        ## Build the line which will be recorded to the log file
        $TimeGenerated = "$(Get-Date -Format HH:mm:ss).$((Get-Date).Millisecond)+000"
        $LineFormat = $Message, $TimeGenerated, (Get-Date -Format "yyyy-MM-dd"), "$($MyInvocation.ScriptName | Split-Path -Leaf):$($MyInvocation.ScriptLineNumber)", $LogLevel
        $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="" type="{4}" thread="" file="">' -f $LineFormat

        Write-Information -MessageData $Message -InformationAction "Continue"
        Add-Content -Value $Line -Path $Script:LogFile
    }
}
#endregion

#region Uninstall logic
# Log file path. Parent directory should exist if device is enrolled in Intune
$Script:LogFile = "$Env:ProgramData\Microsoft\IntuneManagementExtension\Logs\PSPackageFactoryUninstall.log"

# Define Params here
$Uninstaller = "$env:ProgramFiles\FileZilla FTP Client\uninstall.exe"
$Arguments = "/S"
$SetupPath = "$env:ProgramFiles\FileZilla FTP Client" # No Ending Trail

try {
    Get-Process | Where-Object { $_.Path -like "$SetupPath\*" } | ForEach-Object { Write-LogFile -Message "Stop-PathProcess: $($_.ProcessName)" }
    $params = {
        ErrorAction = "Continue"
        WhatIf      = $Script:WhatIfPref
        Verbose     = $Script:VerbosePref
    }
    Get-Process -ErrorAction "SilentlyContinue" | `
        Where-Object { $_.Path -like "$SetupPath\*" } | `
        Stop-Process -Force @params
}
catch {
    Write-Warning -Message "Failed to stop processes."
    Write-LogFile -Message "Failed to stop processes." -Severity "Error" -LogOnly
}

try {
    $params = @{
        FilePath     = $Uninstaller
        ArgumentList = $Arguments
        NoNewWindow  = $true
        PassThru     = $true
        Wait         = $true
        WhatIf      = $Script:WhatIfPref
        Verbose     = $Script:VerbosePref
    }
    Write-LogFile -Message "Removing program: '$Uninstaller'"
    Write-LogFile -Message "With parameters: '$Arguments'"
    $result = Start-Process @params
    Write-LogFile -Message "Exit code: $($result.ExitCode)"
    if ($result.ExitCode -eq 0) {
        Remove-Item -Path $SetupPath -Recurse -ErrorAction "SilentlyContinue"
        Write-LogFile -Message "Removed program: $SetupPath"
    }
}
catch {
    Write-LogFile -Message $_.Exception.Message -LogLevel 3
    throw $_
}
finally {
    Write-LogFile -Message "Uninstall.ps1 complete. Exit Code: $($result.ExitCode)"
    exit $result.ExitCode
}
#endregion
