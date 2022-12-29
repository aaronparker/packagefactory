<#
 # File: c:\dev\intunepacketfactory\packages\Apps\Filezilla\Source\Install.ps1
 # Project: c:\dev\intunepacketfactory\packages\Apps\Filezilla\Source
 # Created Date: Thursday, December 29th 2022, 8:59:14 am
 # Author: Aaron Parker
 # -----
 # Description: Installs an application based on logic defined in Install.json
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



[CmdletBinding(SupportsShouldProcess = $True)]
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

$logging = $true;
$global:logfile = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\Installps1.log";

# Logging Function 
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


#region Functions
function Get-InstallConfig {
    param (
        [System.String] $File = "Install.json",
        [System.Management.Automation.PathInfo] $Path = $PWD
    )
    try {
        $InstallFile = Join-Path -Path $Path -ChildPath $File
        Write-Verbose -Message "Read package install config: $InstallFile"
        Get-Content -Path $InstallFile -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
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
    $Installer = Get-ChildItem -Path $Path -Filter $File -Recurse -ErrorAction "SilentlyContinue" | Select-Object -First 1
    if ([System.String]::IsNullOrEmpty($Installer.FullName)) {
        throw "File not found: $File"
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
                    $FilePath = Get-ChildItem -Path $Path -Filter $Item.Source -Recurse -ErrorAction "SilentlyContinue"
                    Write-Verbose -Message "Source: $($FilePath.FullName)"
                    Write-Verbose -Message "Destination: $($Item.Destination)"
                    if ($logging) { Write-Feedback "Copy-File: Source: $($FilePath.FullName)" -severity "Info" -logOnly }
                    if ($logging) { Write-Feedback "Copy-File: Destination: $($Item.Destination)" -severity "Info" -logOnly }
                    $params = @{
                        Path        = $FilePath.FullName
                        Destination = $Item.Destination
                        Force       = $True
                        ErrorAction = "SilentlyContinue"
                    }
                    Copy-Item @params
                }
                catch {
                    if ($logging) { Write-Feedback "Copy-File: $($_)" -severity "Error" -logOnly }
                    throw $_
                }
            }
            else {
                if ($logging) { Write-Feedback "Copy-File: Cannot find destination: $($Item.Destination)" -severity "Error" -logOnly }
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
                        Recurse     = $True
                        Force       = $true
                        ErrorAction = "SilentlyContinue"
                    }
                    Remove-Item @params
                }
                else {
                    $params = @{
                        Path        = $Item
                        Force       = $true
                        ErrorAction = "SilentlyContinue"
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
                    if ($logging) { Write-Feedback "Stop-PathProcess Stop-Process where Path like: $($Item)" -severity "Info" -logOnly }
                    Get-Process | Where-Object { $_.Path -like $Item } | `
                        Stop-Process -Force -ErrorAction "SilentlyContinue"
                }
                else {
                    if ($logging) { Write-Feedback "Stop-PathProcess Stop-Process where Path like: $($Item)" -severity "Info" -logOnly }
                    Get-Process | Where-Object { $_.Path -like $Item } | `
                        Stop-Process -ErrorAction "SilentlyContinue"
                }
            }
            catch {
                if ($logging) { Write-Feedback "Stop-PathProcess Error: $($_.Exception.Message)" -severity "Warning" -logOnly }
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
                    NoNewWindow  = $True
                    PassThru     = $True
                    Wait         = $True
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
		$global:logfile = "$($Install.LogPath)" + "\" + "Installps1.log"
	} else {
        $global:logfile = "$($Install.LogPath)" + "\" + $($Install.PackageInformation.SetupFile) + "_Installps1.log"
    }
}


if ([System.String]::IsNullOrEmpty($Installer)) {
	if ($logging) { Write-Feedback "File not found: $($Install.PackageInformation.SetupFile)" -severity "Error" -logOnly }
    throw "File not found: $($Install.PackageInformation.SetupFile)"
    exit 1
}
else {
    # Create the log folder
    if (Test-Path -Path $Install.LogPath -PathType "Container") {
        Write-Verbose -Message "Directory exists: $($Install.LogPath)"
        if ($logging) { Write-Feedback "Directory exists: $($Install.LogPath)" -severity "Info" -logOnly }
    }
    else {
        Write-Verbose -Message "Create directory: $($Install.LogPath)"
        if ($logging) { Write-Feedback "Create directory: $($Install.LogPath)" -severity "Info" -logOnly }
        New-Item -Path $Install.LogPath -ItemType "Directory" -ErrorAction "SilentlyContinue" | Out-Null
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

    try {
        # Perform the application install
        switch ($Install.PackageInformation.SetupType) {
            "EXE" {
                Write-Verbose -Message "Installer: $Installer"
                Write-Verbose -Message "ArgumentList: $ArgumentList"
                if ($logging) { Write-Feedback "Installer: $Installer" -severity "Info" -logOnly }
                if ($logging) { Write-Feedback "ArgumentList: $ArgumentList" -severity "Info" -logOnly }
                $params = @{
                    FilePath     = $Installer
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $True
                    PassThru     = $True
                    Wait         = $True
                }
                if ($PSCmdlet.ShouldProcess($Installer, $ArgumentList)) {
                    $result = Start-Process @params
                }
            }
            "MSI" {
                Write-Verbose -Message "Installer: $Env:SystemRoot\System32\msiexec.exe"
                Write-Verbose -Message "ArgumentList: $ArgumentList"
                if ($logging) { Write-Feedback "Installer: $Env:SystemRoot\System32\msiexec.exe" -severity "Info" -logOnly }
                if ($logging) { Write-Feedback "ArgumentList: $ArgumentList" -severity "Info" -logOnly }
                $params = @{
                    FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $True
                    PassThru     = $True
                    Wait         = $True
                }
                if ($PSCmdlet.ShouldProcess("$Env:SystemRoot\System32\msiexec.exe", $ArgumentList)) {
                    $result = Start-Process @params
                }
            }
            default {
                if ($logging) { Write-Feedback "$($Install.PackageInformation.SetupType) not found in the supported setup types - EXE, MSI." -severity "Error" -logOnly }
                throw "$($Install.PackageInformation.SetupType) not found in the supported setup types - EXE, MSI."
                exit 1
            }
        }

        # If wait specified, wait the specified seconds
        if ($Install.InstallTasks.Wait -gt 0) { Start-Sleep -Seconds $Install.InstallTasks.Wait }

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
        if ($logging) { Write-Feedback "Exit Code: $($result.ExitCode)" -severity "Info" -logOnly }
        exit $result.ExitCode
    }
}
#endregion
