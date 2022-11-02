<#
    .SYNOPSIS
    Installs an application based on logic defined in Install.json

    .NOTES
    Version: 1.0
    Date: 13th September 2022
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
                    $params = @{
                        Path        = $FilePath.FullName
                        Destination = $Item.Destination
                        Force       = $True
                        ErrorAction = "SilentlyContinue"
                    }
                    Copy-Item @params
                }
                catch {
                    throw $_
                }
            }
            else {
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
                    Get-Process | Where-Object { $_.Path -like $Item } | `
                        Stop-Process -Force -ErrorAction "SilentlyContinue"
                }
                else {
                    Get-Process | Where-Object { $_.Path -like $Item } | `
                        Stop-Process -ErrorAction "SilentlyContinue"
                }
            }
            catch {
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
if ([System.String]::IsNullOrEmpty($Installer)) {
    throw "File not found: $($Install.PackageInformation.SetupFile)"
    exit 1
}
else {
    # Create the log folder
    if (Test-Path -Path $Install.LogPath -PathType "Container") {
        Write-Verbose -Message "Directory exists: $($Install.LogPath)"
    }
    else {
        Write-Verbose -Message "Create directory: $($Install.LogPath)"
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
        exit $result.ExitCode
    }
}
#endregion
