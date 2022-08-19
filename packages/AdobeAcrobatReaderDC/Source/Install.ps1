<#
    .SYNOPSIS
    Installs the application
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

#region Functions
function Get-InstallConfig {
    try {
        $Path = Join-Path -Path $PWD -ChildPath "Install.json"
        Get-Content -Path $Path -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
    }
    catch {
        throw $_
    }
}

function Get-Installer ($File) {
    $Installer = Get-ChildItem -Path $PWD -Filter $File -Recurse -ErrorAction "SilentlyContinue" | Select-Object -First 1
    if ([System.String]::IsNullOrEmpty($Installer)) {
        throw "File not found: $File"
    }
    else {
        return $Installer.FullName
    }
}
#region

# Get the install details for this application
$Install = Get-InstallConfig
$Installer = Get-Installer -File $Install.PackageInformation.SetupFile
if ([System.String]::IsNullOrEmpty($Installer)) {

    # Create the log folder
    New-Item -Path $Install.LogPath -ItemType "Directory" -ErrorAction "SilentlyContinue" | Out-Null

    # Build the argument list
    $ArgumentList = $Install.InstallTasks.ArgumentList -replace "#SetupFile", $Installer
    $ArgumentList = $ArgumentList -replace "#LogName", $Install.PackageInformation.SetupFile
    $ArgumentList = $ArgumentList -replace "#LogPath", $Install.LogPath

    try {
        switch ($Install.PackageInformation.SetupType) {
            "EXE" {
                $params = @{
                    FilePath     = $Installer
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $True
                    PassThru     = $True
                    Wait         = $True
                }
                $result = Start-Process @params
            }
            "MSI" {
                $params = @{
                    FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $True
                    PassThru     = $True
                    Wait         = $True
                }
                $result = Start-Process @params
            }
            default {
                exit 1
            }
        }
    }
    catch {
        throw $_
    }
    finally {
        Remove-Item -Path $Install.PostInstall.Remove -Force -ErrorAction "SilentlyContinue"
        exit $result.ExitCode
    }
}
else {
    exit 1
}
