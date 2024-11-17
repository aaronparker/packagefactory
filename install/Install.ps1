#Requires -Modules Evergreen
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
        $params = @{
            FilePath     = $ProcessPath
            ArgumentList = $Arguments
            Wait         = $true
            WindowStyle  = "Hidden"
        }
        Start-Process @params
        exit 0
    }
}
#endregion

# Import the shared functions
$ModuleFile = $(Join-Path -Path $PSScriptRoot -ChildPath "Install.psm1")
Import-Module -Name $ModuleFile -Force -ErrorAction "Stop"


# Get the install details for this application from the package library
$Install = Get-InstallConfig -Uri $PackageUri
Write-LogFile -Message "Installing: $($Install.PackageInformation.ApplicationName)"

# Create the application download directory
$Path = "$Path\$($Install.PackageInformation.ApplicationName)"
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null

# Get details of the available installers from the library
Write-LogFile -Message "Get Evergreen Library: $LibraryUri"
Write-LogFile -Message "Get application from library: $($Install.PackageInformation.ApplicationName)"
$LibraryApp = Get-EvergreenLibrary -Uri $LibraryUri | Get-EvergreenAppFromLibrary -Name $Install.PackageInformation.ApplicationName

# Filter the application by version - if the version is "Latest", select the first version
if ($Install.PackageInformation.Version -eq "Latest") {
    $App = $LibraryApp | Select-Object -First 1
    Write-LogFile -Message "Found $($App.Version) for: $($Install.PackageInformation.ApplicationName)"
}
else {
    # Filter for the specified version
    Write-LogFile -Message "Looking for version: $($Install.PackageInformation.Version)"
    $App = $LibraryApp | Where-Object { $_.Version -eq $Install.PackageInformation.Version }
    Write-LogFile -Message "Found $($App.Version) for: $($Install.PackageInformation.ApplicationName)"
}

# Download the installer. $Installer will be the file to install
if ($PSCmdlet.ShouldProcess($Install.PackageInformation.ApplicationName, "Save-EvergreenApp")) {
    Write-LogFile -Message "Downloading from: $($App.URI)"
    Write-LogFile -Message "Downloading installer to: $Path"
    try {
        $Installer = $App | Save-EvergreenApp -LiteralPath $Path
    }
    catch {
        Write-LogFile -Message "Save-EvergreenApp failed with: $($_.Exception.Message)" -LogLevel 3
    }
}
else {
    # This section is here only for -WhatIf support
    Write-LogFile -Message "Create directory: $Path"
    New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" -WhatIf:$false | Out-Null
    "Temp" | Out-File -FilePath "$Path\$(Split-Path -Path $App.URI -Leaf)" -Force -WhatIf:$false
    $Installer = Get-Item -Path "$Path\$(Split-Path -Path $App.URI -Leaf)"
    Write-LogFile -Message "Delete file: $Path\$(Split-Path -Path $App.URI -Leaf)"
    Remove-Item -Path "$Path\$(Split-Path -Path $App.URI -Leaf)" -ErrorAction "SilentlyContinue"
}

# If $Installer is $null, the download failed and we don't have a file to install
if ([System.String]::IsNullOrEmpty($Installer)) {
    if ([System.String]::IsNullOrEmpty($Install.PackageInformation.SetupFile)) {
        Write-LogFile -Message "Failed to determine installer file" -LogLevel 3
    }
    else {
        Write-LogFile -Message "File not found: $($Install.PackageInformation.SetupFile)" -LogLevel 3
    }
}
else {
    Write-LogFile -Message "Downloaded installer file: $($Installer.FullName)"

    # Create the application install log folder
    if (Test-Path -Path $Install.LogPath -PathType "Container") {
        Write-LogFile -Message "Log directory exists: $($Install.LogPath)"
    }
    else {
        Write-LogFile -Message "Create directory: $($Install.LogPath)"
        New-Item -Path $Install.LogPath -ItemType "Directory" -ErrorAction "Continue" | Out-Null
    }

    #region Install tasks
    # If the installer is a zip file, let's extract it and get the new installer from that zip
    if ($Installer.FullName -match "\.zip$") {
        Write-LogFile -Message "Extracting zip file: $($Installer.FullName)"
        Expand-Archive -Path $Installer.FullName -Destination $Path -Force -ErrorAction "Stop"
        if ([System.String]::IsNullOrEmpty($Install.PackageInformation.Match)) {
            $Installer = Get-ChildItem -Path $Path -Recurse -Include $Install.PackageInformation.SetupFile -ErrorAction "Continue" | Select-Object -First 1
        }
        else {
            # Get the installer from the extracted zip file where the file name matches the pattern
            $Installer = Get-ChildItem -Path $Path -Recurse -Include $Install.PackageInformation.SetupFile -ErrorAction "Continue" | `
                Where-Object { $_.FullName -match $Install.PackageInformation.Match } | `
                Select-Object -First 1
        }
        Write-LogFile -Message "Found installer in zip: $($Installer.FullName)"
    }

    # Download the files we need during install
    if ($Install.InstallTasks.SaveUri.Count -gt 0) {
        foreach ($File in $Install.InstallTasks.SaveUri) {
            $ConfigFile = Save-Uri -Uri $File -Destination $(Join-Path -Path $Path -ChildPath $(Split-Path -Path $File -Leaf))
        }
    }

    # Stop processes before installing the application
    if ($Install.InstallTasks.StopPath.Count -gt 0) { Stop-PathProcess -Path $Install.InstallTasks.StopPath }

    # Uninstall a Windows Installer application before installing the application
    if ($Install.InstallTasks.UninstallMsi.Count -gt 0) { Uninstall-Msi -ProductName $Install.InstallTasks.UninstallMsi -LogPath $Install.LogPath }

    # Remove files before installing the application
    if ($Install.InstallTasks.Remove.Count -gt 0) { Remove-Path -Path $Install.InstallTasks.Remove }

    # Build the application installer argument list
    Write-LogFile -Message "Build argument list with: $($Install.InstallTasks.ArgumentList)"
    $ArgumentList = $Install.InstallTasks.ArgumentList -replace "#SetupFile", $Installer.FullName
    $ArgumentList = $ArgumentList -replace "#ConfigFile", $ConfigFile
    $ArgumentList = $ArgumentList -replace "#LogName", $Installer.Name
    $ArgumentList = $ArgumentList -replace "#LogPath", $Install.LogPath
    $ArgumentList = $ArgumentList -replace "#PWD", $PWD.Path

    # Change to the installer directory
    Write-LogFile -Message "Change directory: $(([System.IO.Path]::GetDirectoryName($Installer)))"
    Push-Location -Path ([System.IO.Path]::GetDirectoryName($Installer))

    # Run commands before installing the application
    if ($Install.PostInstall.Run.Count -gt 0) {
        foreach ($RunTask in $Install.InstallTasks.Run) {
            Write-LogFile -Message "Run: $RunTask"
            if ($PSCmdlet.ShouldProcess($RunTask, "Invoke-Expression")) {
                Invoke-Expression -Command $($RunTask -replace "#ConfigFile", $ConfigFile)
            }
        }
    }

    try {
        # Perform the application install
        switch ($Install.PackageInformation.SetupType) {

            # Exe installer
            "EXE" {
                Write-LogFile -Message "Start install type: EXE"
                Write-LogFile -Message "Start process: $($Installer.FullName)"
                Write-LogFile -Message "ArgumentList: $ArgumentList"
                $params = @{
                    FilePath     = $Installer.FullName
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $true
                    PassThru     = $true
                    Wait         = if ($Install.InstallTasks.NoWait) { $false } else { $true }
                    Verbose      = $Script:VerbosePref
                }
                if ($PSCmdlet.ShouldProcess($Installer.FullName, $ArgumentList)) {
                    $result = Start-Process @params
                }

                if ($Install.InstallTasks.NoWait) {
                    Start-Sleep -Seconds 20
                    if ($Install.InstallTasks.NoWaitProcess) {
                        Write-LogFile -Message "Start-Process NoWait specified. Waiting for $($Install.InstallTasks.NoWaitProcess) to complete."
                        do {
                            Start-Sleep -Seconds 5
                        } while (Get-Process -Name $Install.InstallTasks.NoWaitProcess -ErrorAction "SilentlyContinue")
                    }
                }
            }

            # Msi installer
            "MSI" {
                Write-LogFile -Message "Start install type: MSI"
                Write-LogFile -Message "Start process: $Env:SystemRoot\System32\msiexec.exe"
                Write-LogFile -Message "ArgumentList: $ArgumentList"
                $params = @{
                    FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
                    ArgumentList = $ArgumentList
                    NoNewWindow  = $true
                    PassThru     = $true
                    Wait         = if ($Install.InstallTasks.NoWait) { $false } else { $true }
                    Verbose      = $Script:VerbosePref
                }
                if ($PSCmdlet.ShouldProcess("$Env:SystemRoot\System32\msiexec.exe", $ArgumentList)) {
                    $result = Start-Process @params
                }
            }

            # PowerShell script
            "PS1" {
                Write-LogFile -Message "Start install type: PS1"
                if ([System.String]::IsNullOrEmpty($Install.InstallTasks.InvokeCommand)) {
                    Write-LogFile -Message "Start process: $Env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
                    Write-LogFile -Message "ArgumentList: $ArgumentList"
                    $params = @{
                        FilePath     = "$Env:SystemRoot\System32\WindowsPowerShell\v1.0\powershell.exe"
                        ArgumentList = $ArgumentList
                        NoNewWindow  = $true
                        PassThru     = $true
                        Wait         = if ($Install.InstallTasks.NoWait) { $false } else { $true }
                        Verbose      = $Script:VerbosePref
                    }
                    if ($PSCmdlet.ShouldProcess($Installer.FullName, $ArgumentList)) {
                        $result = Start-Process @params
                    }
                }
                else {
                    foreach ($Command in $Install.InstallTasks.InvokeCommand) {
                        $InvokeCommand = $Command -replace "#Path", $Path -replace "$Version", $App.Version
                        Write-LogFile -Message "Invoke-Expression: $InvokeCommand"
                        if ($PSCmdlet.ShouldProcess($InvokeCommand, "Invoke-Expression")) {
                            Invoke-Expression -Command $InvokeCommand
                        }
                    }
                }
            }

            default {
                Write-LogFile -Message "$($Install.PackageInformation.SetupType) not found in the supported setup types." -LogLevel 3
            }
        }

        # If wait specified, wait the specified seconds
        if ($Install.InstallTasks.Wait -gt 0) {
            Write-LogFile -Message "Start sleep for $($Install.InstallTasks.Wait) seconds."
            Start-Sleep -Seconds $Install.InstallTasks.Wait
        }
        #endregion

        #region Perform post install actions
        # Stop processes after installing the application
        if ($Install.PostInstall.StopPath.Count -gt 0) { Stop-PathProcess -Path $Install.PostInstall.StopPath }

        # Create directories
        if ($Install.PostInstall.NewPath.Count -gt 0) {
            foreach ($NewPath in $Install.PostInstall.NewPath) {
                Write-LogFile -Message "Create directory: $($NewPath)"
                New-Item -Path $NewPath -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null
            }
        }

        # Files
        if ($Install.PostInstall.Remove.Count -gt 0) { Remove-Path -Path $Install.PostInstall.Remove }
        if ($Install.PostInstall.CopyFile.Count -gt 0) { Copy-File -File $Install.PostInstall.CopyFile }
        if ($Install.PostInstall.SaveUri.Count -gt 0) {
            foreach ($File in $Install.PostInstall.SaveUri) {
                $ConfigFile = Save-Uri -Uri $File.Source -Destination $File.Destination
            }
        }

        # Services
        if ($Install.PostInstall.DisableService.Count -gt 0) {
            foreach ($Service in $Install.PostInstall.DisableService) {
                Write-LogFile -Message "Disable service: $Service"
                Get-Service -Name $Service -ErrorAction "SilentlyContinue" | Set-Service -StartupType "Disabled" -ErrorAction "SilentlyContinue"
            }
        }

        # Scheduled tasks
        if ($Install.PostInstall.DisableTask.Count -gt 0) {
            foreach ($Task in $Install.PostInstall.DisableTask) {
                Write-LogFile -Message "Unregister task: $Task"
                Get-ScheduledTask -TaskName $Task -ErrorAction "SilentlyContinue" | Unregister-ScheduledTask -Confirm:$false -ErrorAction "SilentlyContinue"
            }
        }
        #endregion

        # Execute run tasks
        if ($Install.PostInstall.Run.Count -gt 0) {
            foreach ($RunTask in $Install.PostInstall.Run) {
                Write-LogFile -Message "Run: $RunTask"
                if ($PSCmdlet.ShouldProcess($RunTask, "Invoke-Expression")) {
                    Invoke-Expression -Command $RunTask
                }
            }
        }
    }
    catch {
        Write-LogFile -Message $_.Exception.Message -LogLevel 3
    }
    finally {
        # Change back to the original directory
        Pop-Location

        if ($result) {
            Write-LogFile -Message "Install complete. Exit Code: $($result.ExitCode)"
            exit $result.ExitCode
        }
        else {
            Write-LogFile -Message "Install complete."
        }
    }
}
