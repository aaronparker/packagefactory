<#
    .SYNOPSIS
        Installs an application based on logic defined in Install.json. Simple alternative to PSAppDeployToolkit
        Script is copied into Source folder if Install.json exists.

    .NOTES
        Author: Aaron Parker
        Update: Constantin Lotz
#>
[CmdletBinding(SupportsShouldProcess = $true)]
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
    [CmdletBinding(SupportsShouldProcess = $false)]
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

#region Installer functions
function Get-InstallConfig {
    param (
        [System.String] $File = "Install.json",
        [System.Management.Automation.PathInfo] $Path = $PWD
    )
    try {
        $InstallFile = Join-Path -Path $Path -ChildPath $File
        Write-LogFile -Message "Read package install config: $InstallFile"
        Get-Content -Path $InstallFile -ErrorAction "Stop" | ConvertFrom-Json -ErrorAction "Continue"
    }
    catch {
        Write-LogFile -Message "Get-InstallConfig: $($_.Exception.Message)" -LogLevel 3
        throw $_
    }
}

function Get-Installer {
    param (
        [System.String] $File,
        [System.Management.Automation.PathInfo] $Path = $PWD
    )
    $Installer = Get-ChildItem -Path $Path -Filter $File -Recurse -ErrorAction "Continue" | Select-Object -First 1
    if ([System.String]::IsNullOrEmpty($Installer.FullName)) {
        Write-LogFile -Message "File not found: $File" -LogLevel 3
        throw [System.IO.FileNotFoundException]::New("File not found: $File")
    }
    else {
        Write-LogFile -Message "Found installer: $($Installer.FullName)"
        return $Installer.FullName
    }
}

function Copy-File {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [System.Array] $File,
        [System.Management.Automation.PathInfo] $Path = $PWD
    )
    process {
        foreach ($Item in $File) {
            try {
                $FilePath = Get-ChildItem -Path $Path -Filter $Item.Source -Recurse -ErrorAction "Continue"
                Write-LogFile -Message "Copy-File: Source: $($FilePath.FullName)"
                Write-LogFile -Message "Copy-File: Destination: $($Item.Destination)"
                $params = @{
                    Path        = $FilePath.FullName
                    Destination = $Item.Destination
                    Container   = $false
                    Force       = $true
                    ErrorAction = "Continue"
                    WhatIf      = $Script:WhatIfPref
                    Verbose     = $Script:VerbosePref
                }
                Copy-Item @params
            }
            catch {
                Write-LogFile -Message "Copy-File: $($_.Exception.Message)" -LogLevel 3
                Write-Warning -Message $_.Exception.Message
            }
        }
    }
}

function Remove-Path {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [System.String[]] $Path
    )
    process {
        foreach ($Item in $Path) {
            try {
                if (Test-Path -Path $Item -PathType "Container") {
                    $params = @{
                        Path        = $Item
                        Recurse     = $true
                        Force       = $true
                        ErrorAction = "Continue"
                        WhatIf      = $Script:WhatIfPref
                        Verbose     = $Script:VerbosePref
                    }
                    Remove-Item @params
                    Write-LogFile -Message "Remove-Item: $Item"
                }
                else {
                    $params = @{
                        Path        = $Item
                        Force       = $true
                        ErrorAction = "Continue"
                        WhatIf      = $Script:WhatIfPref
                        Verbose     = $Script:VerbosePref
                    }
                    Remove-Item @params
                    Write-LogFile -Message "Remove-Item: $Item"
                }
            }
            catch {
                Write-LogFile -Message "Remove-Path error: $($_.Exception.Message)" -LogLevel 3
                Write-Warning -Message $_.Exception.Message
            }
        }
    }
}

function Stop-PathProcess {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [System.String[]] $Path,
        [System.Management.Automation.SwitchParameter] $Force
    )
    process {
        foreach ($Item in $Path) {
            try {
                Get-Process | Where-Object { $_.Path -like $Item } | ForEach-Object { Write-LogFile -Message "Stop-PathProcess: $($_.ProcessName)" }
                $params = {
                    ErrorAction = "Continue"
                    WhatIf      = $Script:WhatIfPref
                    Verbose     = $Script:VerbosePref
                }
                if ($PSBoundParameters.ContainsKey("Force")) {
                    Get-Process | Where-Object { $_.Path -like $Item } | `
                        Stop-Process -Force @params
                }
                else {
                    Get-Process | Where-Object { $_.Path -like $Item } | `
                        Stop-Process @params
                }
            }
            catch {
                Write-LogFile -Message "Stop-PathProcess error: $($_.Exception.Message)" -LogLevel 2
                Write-Warning -Message $_.Exception.Message
            }
        }
    }
}

function Uninstall-Msi {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [System.String[]] $ProductName,
        [System.String] $LogPath
    )
    process {
        foreach ($Item in $ProductName) {
            if ($PSCmdlet.ShouldProcess($Item)) {
                $Product = Get-CimInstance -Class "Win32_InstalledWin32Program" | Where-Object { $_.Name -like $Item }
                try {
                    $Product = Get-CimInstance -Class "Win32_InstalledWin32Program" | Where-Object { $_.Name -like $Item }
                    $params = @{
                        FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
                        ArgumentList = "/uninstall `"$($Product.MsiProductCode)`" /quiet /log `"$LogPath\Uninstall-$($Item -replace " ").log`""
                        NoNewWindow  = $true
                        PassThru     = $true
                        Wait         = $true
                        ErrorAction  = "Continue"
                        Verbose      = $Script:VerbosePref
                    }
                    $result = Start-Process @params
                    Write-LogFile -Message "$Env:SystemRoot\System32\msiexec.exe /uninstall `"$($Product.MsiProductCode)`" /quiet /log `"$LogPath\Uninstall-$($Item -replace " ").log`""
                    Write-LogFile -Message "Msiexec result: $($result.ExitCode)"
                    return $result.ExitCode
                }
                catch {
                    Write-LogFile -Message "Uninstall-Msi error: $($_.Exception.Message)" -LogLevel 3
                    Write-Warning -Message $_.Exception.Message
                }
            }
        }
    }
}
#endregion

#region Install logic

# Log file path. Parent directory should exist if device is enrolled in Intune
$Script:LogFile = "$Env:ProgramData\Microsoft\IntuneManagementExtension\Logs\PSPackageFactoryInstall.log"

# Trim log if greater than 50 MB
if (Test-Path -Path $Script:LogFile) {
    if ((Get-Item -Path $Script:LogFile).Length -gt 50MB) {
        Clear-Content -Path $Script:LogFile
        Write-LogFile -Message "Log file size greater than 50MB. Clearing log." -LogLevel 2
    }
}

# Get the install details for this application
$Install = Get-InstallConfig
$Installer = Get-Installer -File $Install.PackageInformation.SetupFile

if ([System.String]::IsNullOrEmpty($Installer)) {
    Write-LogFile -Message "File not found: $($Install.PackageInformation.SetupFile)" -LogLevel 3
    throw [System.IO.FileNotFoundException]::New("File not found: $($Install.PackageInformation.SetupFile)")
}
else {

    # Stop processes before installing the application
    if ($Install.InstallTasks.StopPath.Count -gt 0) { Stop-PathProcess -Path $Install.InstallTasks.StopPath }

    # Uninstall the application
    if ($Install.InstallTasks.UninstallMsi.Count -gt 0) { Uninstall-Msi -ProductName $Install.InstallTasks.UninstallMsi -LogPath $Install.LogPath }
    if ($Install.InstallTasks.Remove.Count -gt 0) { Remove-Path -Path $Install.InstallTasks.Remove }

    # Create the log folder
    if (Test-Path -Path $Install.LogPath -PathType "Container") {
        Write-LogFile -Message "Directory exists: $($Install.LogPath)"
    }
    else {
        Write-LogFile -Message "Create directory: $($Install.LogPath)"
        New-Item -Path $Install.LogPath -ItemType "Directory" -ErrorAction "Continue" | Out-Null
    }

    # Build the argument list
    $ArgumentList = $Install.InstallTasks.ArgumentList -replace "#SetupFile", $Installer
    $ArgumentList = $ArgumentList -replace "#LogName", $Install.PackageInformation.SetupFile
    $ArgumentList = $ArgumentList -replace "#LogPath", $Install.LogPath
    $ArgumentList = $ArgumentList -replace "#PWD", $PWD.Path
    $ArgumentList = $ArgumentList -replace "#SetupDirectory", ([System.IO.Path]::GetDirectoryName($Installer))

    try {
        # Perform the application install
        switch ($Install.PackageInformation.SetupType) {
            "EXE" {
                Write-LogFile -Message "Installer: $Installer"
                Write-LogFile -Message "ArgumentList: $ArgumentList"
                $params = @{
                    FilePath     = $Installer
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $true
                    PassThru     = $true
                    Wait         = $true
                    Verbose      = $Script:VerbosePref
                }
                if ($PSCmdlet.ShouldProcess($Installer, $ArgumentList)) {
                    $result = Start-Process @params
                }
            }
            "MSI" {
                Write-LogFile -Message "Installer: $Env:SystemRoot\System32\msiexec.exe"
                Write-LogFile -Message "ArgumentList: $ArgumentList"
                $params = @{
                    FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $true
                    PassThru     = $true
                    Wait         = $true
                    Verbose      = $Script:VerbosePref
                }
                if ($PSCmdlet.ShouldProcess("$Env:SystemRoot\System32\msiexec.exe", $ArgumentList)) {
                    $result = Start-Process @params
                }
            }
            default {
                Write-LogFile -Message "$($Install.PackageInformation.SetupType) not found in the supported setup types - EXE, MSI." -LogLevel 3
                throw "$($Install.PackageInformation.SetupType) not found in the supported setup types - EXE, MSI."
            }
        }

        # If wait specified, wait the specified seconds
        if ($Install.InstallTasks.Wait -gt 0) { Start-Sleep -Seconds $Install.InstallTasks.Wait }

        # Stop processes after installing the application
        if ($Install.PostInstall.StopPath.Count -gt 0) { Stop-PathProcess -Path $Install.PostInstall.StopPath }

        # Perform post install actions
        if ($Install.PostInstall.Remove.Count -gt 0) { Remove-Path -Path $Install.PostInstall.Remove }
        if ($Install.PostInstall.CopyFile.Count -gt 0) { Copy-File -File $Install.PostInstall.CopyFile }

        # Execute run tasks
        if ($Install.PostInstall.Run.Count -gt 0) {
            foreach ($Task in $Install.PostInstall.Run) { Invoke-Expression -Command $Task }
        }
    }
    catch {
        Write-LogFile -Message $_.Exception.Message -LogLevel 3
        throw $_
    }
    finally {
        Write-LogFile -Message "Install.ps1 complete. Exit Code: $($result.ExitCode)"
        exit $result.ExitCode
    }
}
#endregion
