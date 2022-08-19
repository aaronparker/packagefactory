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
        Write-Verbose -Message "Read: $Path"
        Get-Content -Path $Path -ErrorAction "SilentlyContinue" | ConvertFrom-Json -ErrorAction "SilentlyContinue"
    }
    catch {
        throw $_
    }
}

function Get-Installer {
    [CmdletBinding()]
    param ( $File )
    $Installer = Get-ChildItem -Path $PWD -Filter $File -Recurse -ErrorAction "SilentlyContinue" | Select-Object -First 1
    if ([System.String]::IsNullOrEmpty($Installer.FullName)) {
        throw "File not found: $File"
    }
    else {
        Write-Verbose -Message "Found: $($Installer.FullName)"
        return $Installer.FullName
    }
}

function Copy-File {
    [CmdletBinding()]
    param ( $File )
    process {
        foreach ($Item in $File) {
            if (Test-Path -Path $Item.Destination) {
                try {
                    $FilePath = Get-ChildItem -Path $PWD -Filter $Item.Source -Recurse -ErrorAction "SilentlyContinue"
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

    # Build the argument list
    $ArgumentList = $Install.InstallTasks.ArgumentList -replace "#SetupFile", $Installer
    $ArgumentList = $ArgumentList -replace "#LogName", $Install.PackageInformation.SetupFile
    $ArgumentList = $ArgumentList -replace "#LogPath", $Install.LogPath

    try {
        # Perform the application install
        switch ($Install.PackageInformation.SetupType) {
            "EXE" {
                Write-Verbose -Message "   Installer: $Installer"
                Write-Verbose -Message "ArgumentList: $ArgumentList"
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
                Write-Verbose -Message "   Installer: $Env:SystemRoot\System32\msiexec.exe"
                Write-Verbose -Message "ArgumentList: $ArgumentList"
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
                throw "Setup type not found."
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
