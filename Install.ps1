<#
    .SYNOPSIS
    Installs an application based on logic defined in Install.json

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

        # Create a string from the passed parameters
        [System.String]$ParameterString = ""
        foreach ($Parameter in $PSBoundParameters.GetEnumerator()) {
            $ParameterString += " -$($Parameter.Key) $($Parameter.Value)"
        }

        # Execute the script in a 64-bit process with the passed parameters
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Definition)`"$ParameterString"
        $ProcessPath = $(Join-Path -Path $Env:SystemRoot -ChildPath "\Sysnative\WindowsPowerShell\v1.0\powershell.exe")
        Write-Verbose -Message "Restarting in 64-bit PowerShell."
        Write-Verbose -Message "File path: $ProcessPath."
        Write-Verbose -Message "Arguments: $Arguments."
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

$Logging = $true
$Script:LogFile = "$Env:ProgramData\Microsoft\IntuneManagementExtension\Logs\PackageFactoryInstall.log"

#region Logging Function
function Write-Feedback {
    <#
        Call Example:
        $logtime = get-date -format 'dd.MM.yyyy;HH:mm:ss'
        Write-Feedback -Msg "$logtime - Info:Frage TFK Settings ab. User: $($phoneExtension) - AutoLogoffEnabled: $($userSettings.serviceAutoLogoffEnabled)"
    #>
    param (
        [Parameter(Position = 0, ValueFromPipeline = $true, Mandatory = $true)]
        [System.String] $Msg,
        [Parameter(Position = 1, Mandatory = $false)]
        [System.String] $LogOnly,
        [Parameter(Position = 2, Mandatory = $false)]
        [System.String] $Severity
    )

    process {
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
            $Msg = "$LogTime - $($Severity): $Msg"
        }

        # Nur In Datei loggen, aber nicht in Konsole
        if ($LogOnly.IsPresent) {
            $Msg | Out-File -FilePath $Script:LogFile -Encoding "Utf8" -Append
        }
        else {
            Write-Information -MessageData $Msg -InformationAction "Continue"
            $Msg | Out-File -FilePath $Script:LogFile -Encoding "Utf8" -Append
        }
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
        Write-Verbose -Message "Read package install config: $InstallFile"
        Get-Content -Path $InstallFile -ErrorAction "Stop" | ConvertFrom-Json -ErrorAction "Continue"
    }
    catch {
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
        throw [System.IO.FileNotFoundException]::New("File not found: $File")
    }
    else {
        Write-Verbose -Message "Found installer: $($Installer.FullName)"
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
            if (Test-Path -Path $Item.Destination -PathType "Container") {
                try {
                    $FilePath = Get-ChildItem -Path $Path -Filter $Item.Source -Recurse -ErrorAction "Continue"
                    Write-Verbose -Message "Source: $($FilePath.FullName)"
                    Write-Verbose -Message "Destination: $($Item.Destination)"
                    if ($Logging) { Write-Feedback -Msg "Copy-File: Source: $($FilePath.FullName)" -Severity "Info" -LogOnly }
                    if ($Logging) { Write-Feedback -Msg "Copy-File: Destination: $($Item.Destination)" -Severity "Info" -LogOnly }
                    $params = @{
                        Path        = $FilePath.FullName
                        Destination = $Item.Destination
                        Force       = $true
                        ErrorAction = "Continue"
                    }
                    Copy-Item @params
                }
                catch {
                    if ($Logging) { Write-Feedback -Msg "Copy-File: $($_)" -Severity "Error" -LogOnly }
                    throw $_
                }
            }
            else {
                if ($Logging) { Write-Feedback -Msg "Copy-File: Cannot find destination: $($Item.Destination)" -Severity "Error" -LogOnly }
                throw "Cannot find destination: $($Item.Destination)"
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
                    }
                    Remove-Item @params
                }
                else {
                    $params = @{
                        Path        = $Item
                        Force       = $true
                        ErrorAction = "Continue"
                    }
                    Remove-Item @params
                }
            }
            catch {
                throw $_
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
                if ($PSBoundParameters.ContainsKey("Force")) {
                    if ($Logging) { Write-Feedback -Msg "Stop-PathProcess Stop-Process where Path like: $($Item)" -Severity "Info" -LogOnly }
                    Get-Process | Where-Object { $_.Path -like $Item } | `
                        Stop-Process -Force -ErrorAction "Continue"
                }
                else {
                    if ($Logging) { Write-Feedback -Msg "Stop-PathProcess Stop-Process where Path like: $($Item)" -Severity "Info" -LogOnly }
                    Get-Process | Where-Object { $_.Path -like $Item } | `
                        Stop-Process -ErrorAction "Continue"
                }
            }
            catch {
                if ($Logging) { Write-Feedback -Msg "Stop-PathProcess Error: $($_.Exception.Message)" -Severity "Warning" -LogOnly }
                Write-Warning -Message $_.Exception.Message
            }
        }
    }
}

function Uninstall-Msi {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [System.String[]] $Caption,
        [System.String] $LogPath
    )
    process {
        foreach ($Item in $Caption) {
            try {
                $Product = Get-CimInstance -Class "Win32_Product" | Where-Object { $_.Caption -like $Item }
                $params = @{
                    FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
                    ArgumentList = "/uninstall `"$($Product.IdentifyingNumber)`" /quiet /log `"$LogPath\Uninstall-$($Item -replace " ").log`""
                    NoNewWindow  = $true
                    PassThru     = $true
                    Wait         = $true
                    ErrorAction  = "Continue"
                }
                if ($PSCmdlet.ShouldProcess("$Env:SystemRoot\System32\msiexec.exe", $ArgumentList)) {
                    $result = Start-Process @params
                }
                return $result.ExitCode
            }
            catch {
                throw $_
            }
        }
    }
}
#endregion

#region Install logic
# Get the install details for this application
$Install = Get-InstallConfig
$Installer = Get-Installer -File $Install.PackageInformation.SetupFile

# Define Logging for this PS
if ([System.String]::IsNullOrEmpty($Install.LogPath) -eq $false) {
    if ([System.String]::IsNullOrEmpty($Install.PackageInformation.SetupFile)) {
        $Script:LogFile = "$($Install.LogPath)" + "\" + "PackageFactoryInstall.log"
    }
    else {
        $Script:LogFile = "$($Install.LogPath)" + "\" + $($Install.PackageInformation.SetupFile) + "_PackageFactoryInstall.log"
    }
}


if ([System.String]::IsNullOrEmpty($Installer)) {
    if ($Logging) { Write-Feedback -Msg "File not found: $($Install.PackageInformation.SetupFile)" -Severity "Error" -LogOnly }
    throw [System.IO.FileNotFoundException]::New("File not found: $($Install.PackageInformation.SetupFile)")
}
else {
    # Create the log folder
    if (Test-Path -Path $Install.LogPath -PathType "Container") {
        Write-Verbose -Message "Directory exists: $($Install.LogPath)"
        if ($Logging) { Write-Feedback -Msg "Directory exists: $($Install.LogPath)" -Severity "Info" -LogOnly }
    }
    else {
        Write-Verbose -Message "Create directory: $($Install.LogPath)"
        if ($Logging) { Write-Feedback -Msg "Create directory: $($Install.LogPath)" -Severity "Info" -LogOnly }
        New-Item -Path $Install.LogPath -ItemType "Directory" -ErrorAction "Continue" | Out-Null
    }

    # Stop processes before installing the application
    if ($Install.InstallTasks.Path.Count -gt 0) { Stop-PathProcess -Path $Install.InstallTasks.Path }

    # Uninstall the application
    if ($Install.InstallTasks.UninstallMsi.Count -gt 0) { Uninstall-Msi -Caption $Install.InstallTasks.UninstallMsi -LogPath $Install.LogPath }
    if ($Install.InstallTasks.Remove.Count -gt 0) { Remove-Path -Path $Install.InstallTasks.Remove }

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
                Write-Verbose -Message "Installer: $Installer"
                Write-Verbose -Message "ArgumentList: $ArgumentList"
                if ($Logging) {
                    Write-Feedback -Msg "Installer: $Installer" -Severity "Info" -LogOnly
                    Write-Feedback -Msg "ArgumentList: $ArgumentList" -Severity "Info" -LogOnly
                }
                $params = @{
                    FilePath     = $Installer
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $true
                    PassThru     = $true
                    Wait         = $true
                }
                if ($PSCmdlet.ShouldProcess($Installer, $ArgumentList)) {
                    $result = Start-Process @params
                }
            }
            "MSI" {
                Write-Verbose -Message "Installer: $Env:SystemRoot\System32\msiexec.exe"
                Write-Verbose -Message "ArgumentList: $ArgumentList"
                if ($Logging) {
                    Write-Feedback -Msg "Installer: $Env:SystemRoot\System32\msiexec.exe" -Severity "Info" -LogOnly
                    Write-Feedback -Msg "ArgumentList: $ArgumentList" -Severity "Info" -LogOnly
                }
                $params = @{
                    FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $true
                    PassThru     = $true
                    Wait         = $true
                }
                if ($PSCmdlet.ShouldProcess("$Env:SystemRoot\System32\msiexec.exe", $ArgumentList)) {
                    $result = Start-Process @params
                }
            }
            default {
                if ($Logging) { Write-Feedback -Msg "$($Install.PackageInformation.SetupType) not found in the supported setup types - EXE, MSI." -Severity "Error" -LogOnly }
                throw "$($Install.PackageInformation.SetupType) not found in the supported setup types - EXE, MSI."
            }
        }

        # If wait specified, wait the specified seconds
        if ($Install.InstallTasks.Wait -gt 0) { Start-Sleep -Seconds $Install.InstallTasks.Wait }

         # Stop processes after installing the application
         if ($Install.PostInstall.StopPath.Count -gt 0) { Stop-PathProcess -Path $Install.PostInstall.StopPath }

        # Perform post install actions
        if ($Install.PostInstall.Copy.Count -gt 0) { Copy-File -File $Install.PostInstall.Copy }

        # Execute run tasks
        if ($Install.PostInstall.Run.Count -gt 0) {
            foreach ($Task in $Install.PostInstall.Run) { Invoke-Expression -Command $Task }
        }
    }
    catch {
        throw $_
    }
    finally {
        if ($Install.PostInstall.Remove.Count -gt 0) { Remove-Path -Path $Install.PostInstall.Remove }
        if ($Logging) { Write-Feedback -Msg "Exit Code: $($result.ExitCode)" -Severity "Info" -LogOnly }
        exit $result.ExitCode
    }
}
#endregion
