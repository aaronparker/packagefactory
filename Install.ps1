<#
    .SYNOPSIS
    Installs the application
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
#endregion

# Get the install details for this application
$Install = Get-InstallConfig
$Installer = Get-Installer -File $Install.PackageInformation.SetupFile
if ([System.String]::IsNullOrEmpty($Installer)) {
    throw "File not found: $($Install.PackageInformation.SetupFile)"
    exit 1
}
else {
    # Create the log folder
    Write-Verbose -Message "Create directory: $($Install.LogPath)"
    New-Item -Path $Install.LogPath -ItemType "Directory" -ErrorAction "SilentlyContinue" | Out-Null

    # Stop processes before installing the application
    if ($Install.InstallTasks.Path.Count -gt 0) { Stop-PathProcess -Path $Install.InstallTasks.Path }

    # Build the argument list
    $ArgumentList = $Install.InstallTasks.ArgumentList -replace "#SetupFile", $Installer
    $ArgumentList = $ArgumentList -replace "#LogName", $Install.PackageInformation.SetupFile
    $ArgumentList = $ArgumentList -replace "#LogPath", $Install.LogPath

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

        # Perform post install actions
        Copy-File -File $Install.PostInstall.Copy
    }
    catch {
        throw $_
    }
    finally {
        if ($Install.PostInstall.Remove.Count -gt 0) { Remove-Item -Path $Install.PostInstall.Remove -Force -ErrorAction "SilentlyContinue" }
        exit $result.ExitCode
    }
}
