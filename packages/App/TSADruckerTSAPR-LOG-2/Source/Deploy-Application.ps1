<#
.SYNOPSIS

PSApppDeployToolkit - This script performs the installation or uninstallation of an application(s).

.DESCRIPTION

- The script is provided as a template to perform an install or uninstall of an application(s).
- The script either performs an "Install" deployment type or an "Uninstall" deployment type.
- The install deployment type is broken down into 3 main sections/phases: Pre-Install, Install, and Post-Install.

The script dot-sources the AppDeployToolkitMain.ps1 script which contains the logic and functions required to install or uninstall an application.

PSApppDeployToolkit is licensed under the GNU LGPLv3 License - (C) 2023 PSAppDeployToolkit Team (Sean Lillis, Dan Cunningham and Muhammad Mashwani).

This program is free software: you can redistribute it and/or modify it under the terms of the GNU Lesser General Public License as published by the
Free Software Foundation, either version 3 of the License, or any later version. This program is distributed in the hope that it will be useful, but
WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
for more details. You should have received a copy of the GNU Lesser General Public License along with this program. If not, see <http://www.gnu.org/licenses/>.

.PARAMETER DeploymentType

The type of deployment to perform. Default is: Install.

.PARAMETER DeployMode

Specifies whether the installation should be run in Interactive, Silent, or NonInteractive mode. Default is: Interactive. Options: Interactive = Shows dialogs, Silent = No dialogs, NonInteractive = Very silent, i.e. no blocking apps. NonInteractive mode is automatically set if it is detected that the process is not user interactive.

.PARAMETER AllowRebootPassThru

Allows the 3010 return code (requires restart) to be passed back to the parent process (e.g. SCCM) if detected from an installation. If 3010 is passed back to SCCM, a reboot prompt will be triggered.

.PARAMETER TerminalServerMode

Changes to "user install mode" and back to "user execute mode" for installing/uninstalling applications for Remote Desktop Session Hosts/Citrix servers.

.PARAMETER DisableLogging

Disables logging to file for the script. Default is: $false.

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeployMode 'Silent'; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -AllowRebootPassThru; Exit $LastExitCode }"

.EXAMPLE

powershell.exe -Command "& { & '.\Deploy-Application.ps1' -DeploymentType 'Uninstall'; Exit $LastExitCode }"

.EXAMPLE

Deploy-Application.exe -DeploymentType "Install" -DeployMode "Silent"

.INPUTS

None

You cannot pipe objects to this script.

.OUTPUTS

None

This script does not generate any output.

.NOTES

Toolkit Exit Code Ranges:
- 60000 - 68999: Reserved for built-in exit codes in Deploy-Application.ps1, Deploy-Application.exe, and AppDeployToolkitMain.ps1
- 69000 - 69999: Recommended for user customized exit codes in Deploy-Application.ps1
- 70000 - 79999: Recommended for user customized exit codes in AppDeployToolkitExtensions.ps1

.LINK

https://psappdeploytoolkit.com
#>


[CmdletBinding()]
Param (
    [Parameter(Mandatory = $false)]
    [ValidateSet('Install', 'Uninstall', 'Repair')]
    [String]$DeploymentType = 'Install',
    [Parameter(Mandatory = $false)]
    [ValidateSet('Interactive', 'Silent', 'NonInteractive')]
    [String]$DeployMode = 'Silent',
    [Parameter(Mandatory = $false)]
    [switch]$AllowRebootPassThru = $false,
    [Parameter(Mandatory = $false)]
    [switch]$TerminalServerMode = $false,
    [Parameter(Mandatory = $false)]
    [switch]$DisableLogging = $false
)

Try {
    ## Set the script execution policy for this process
    Try {
        Set-ExecutionPolicy -ExecutionPolicy 'ByPass' -Scope 'Process' -Force -ErrorAction 'Stop'
    }
    Catch {
    }

    ##*===============================================
    ##* VARIABLE DECLARATION
    ##*===============================================
    ## Variables: Application
    [String]$appVendor = 'Eurofit'
    [String]$appName = 'TSA Drucker Installieren TSAPR-LOG-2'
    [String]$appVersion = ''
    [String]$appArch = 'x64'
    [String]$appLang = 'DE'
    [String]$appRevision = '01'
    [String]$appScriptVersion = '1.0.0'
    [String]$appScriptDate = '14.08.2025'
    [String]$appScriptAuthor = 'j.gruber'
    ##*===============================================
    ## Variables: Install Titles (Only set here to override defaults set by the toolkit)
    [String]$installName = ''
    [String]$installTitle = ''

    ##* Do not modify section below
    #region DoNotModify

    ## Variables: Exit Code
    [Int32]$mainExitCode = 0

    ## Variables: Script
    [String]$deployAppScriptFriendlyName = 'Deploy Application'
    [Version]$deployAppScriptVersion = [Version]'3.10.2'
    [String]$deployAppScriptDate = '02/05/2023'
    [Hashtable]$deployAppScriptParameters = $PsBoundParameters

    ## Variables: Environment
    If (Test-Path -LiteralPath 'variable:HostInvocation') {
        $InvocationInfo = $HostInvocation
    }
    Else {
        $InvocationInfo = $MyInvocation
    }
    [String]$scriptDirectory = Split-Path -Path $InvocationInfo.MyCommand.Definition -Parent

    ## Dot source the required App Deploy Toolkit Functions
    Try {
        [String]$moduleAppDeployToolkitMain = "$scriptDirectory\AppDeployToolkit\AppDeployToolkitMain.ps1"
        If (-not (Test-Path -LiteralPath $moduleAppDeployToolkitMain -PathType 'Leaf')) {
            Throw "Module does not exist at the specified location [$moduleAppDeployToolkitMain]."
        }
        If ($DisableLogging) {
            . $moduleAppDeployToolkitMain -DisableLogging
        }
        Else {
            . $moduleAppDeployToolkitMain
        }
    }
    Catch {
        If ($mainExitCode -eq 0) {
            [Int32]$mainExitCode = 60008
        }
        Write-Error -Message "Module [$moduleAppDeployToolkitMain] failed to load: `n$($_.Exception.Message)`n `n$($_.InvocationInfo.PositionMessage)" -ErrorAction 'Continue'
        ## Exit the script, returning the exit code to SCCM
        If (Test-Path -LiteralPath 'variable:HostInvocation') {
            $script:ExitCode = $mainExitCode; Exit
        }
        Else {
            Exit $mainExitCode
        }
    }

    #endregion
    ##* Do not modify section above
    ##*===============================================
    ##* END VARIABLE DECLARATION
    ##*===============================================

    If ($deploymentType -ine 'Uninstall' -and $deploymentType -ine 'Repair') {
        ##*===============================================
        ##* PRE-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Installation'

        ## Show Welcome Message, close Internet Explorer if required, allow up to 3 deferrals, verify there is enough disk space to complete the install, and persist the prompt
        Show-InstallationWelcome -CloseApps 'iexplore,AcroRd32,Acrobat' -AllowDefer -DeferTimes 3 -CheckDiskSpace -PersistPrompt -CloseAppsCountdown 0 -MinimizeWindows $true

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Installation tasks here>

        ##*===============================================
        ##* INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Installation'

        ## Handle Zero-Config MSI Installations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Install'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat; If ($defaultMspFiles) {
                $defaultMspFiles | ForEach-Object { Execute-MSI -Action 'Patch' -Path $_ }
            }
        }

        ## <Perform Installation tasks here>

        # Create directory for printer installation tracking
        # Use user-specific location if running in user context
        $isUserContext = -not ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains "S-1-5-32-544")
        if ($isUserContext) {
            $printerDataPath = "$($env:LOCALAPPDATA)\Printers"
        } else {
            $printerDataPath = "$($env:ProgramData)\Printers"
        }
        
        if (-not (Test-Path $printerDataPath))
        {
            New-Item -Path $printerDataPath -ItemType Directory -Force | Out-Null
        }

        # Start logging
        Start-Transcript "$printerDataPath\TSAPrinterInstall.log" -Append

        try {
            Write-Log -Message "Starting installation of network printer \\tsaps1\tsaPR-LOG-2" -Source $deployAppScriptFriendlyName
            
            # Check if running in user context and handle accordingly
            $isUserContext = -not ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains "S-1-5-32-544")
            if ($isUserContext) {
                Write-Log -Message "Running in user context - using user-specific printer installation" -Source $deployAppScriptFriendlyName
            }
            
            # Check if printer already exists
            $existingPrinter = Get-Printer -Name "\\tsaps1\tsaPR-LOG-2" -ErrorAction SilentlyContinue
            
            if ($existingPrinter) {
                Write-Log -Message "Printer \\tsaps1\tsaPR-LOG-2 already exists. Removing existing printer..." -Source $deployAppScriptFriendlyName
                Remove-Printer -Name "\\tsaps1\tsaPR-LOG-2" -ErrorAction SilentlyContinue
            }
            
            # Add the network printer
            Write-Log -Message "Adding network printer \\tsaps1\tsaPR-LOG-2" -Source $deployAppScriptFriendlyName
            Add-Printer -ConnectionName "\\tsaps1\tsaPR-LOG-2" -ErrorAction Stop
            
            # Verify printer was added successfully
            $newPrinter = Get-Printer -Name "\\tsaps1\tsaPR-LOG-2" -ErrorAction SilentlyContinue
            if ($newPrinter) {
                Write-Log -Message "Successfully installed printer \\tsaps1\tsaPR-LOG-2" -Source $deployAppScriptFriendlyName
                
                # Set as default printer (optional - uncomment if needed)
                # Set-Printer -Name "\\tsaps1\tsaPR-LOG-2" -Default
                # Write-Log -Message "Set \\tsaps1\tsaPR-LOG-2 as default printer" -Source $deployAppScriptFriendlyName
                
                # Create installation marker
                Set-Content -Path "$printerDataPath\TSAPrinterTSAPR-LOG-2.ps1.tag" -Value "Installed" -Force
                Write-Log -Message "Installation marker created successfully" -Source $deployAppScriptFriendlyName
            } else {
                throw "Printer installation verification failed"
            }
        }
        catch {
            Write-Log -Message "Failed to install printer \\tsaps1\tsaPR-LOG-2. Error: $($_.Exception.Message)" -Severity 3 -Source $deployAppScriptFriendlyName
            throw $_
        }
        finally {
            Stop-Transcript
        }


        ##*===============================================
        ##* POST-INSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Installation'

        ## <Perform Post-Installation tasks here>

        ## Display a message at the end of the install
        If (-not $useDefaultMsi) {
            Show-InstallationPrompt -Message 'Printer installation completed successfully.' -ButtonRightText 'OK' -Icon Information -NoWait
        }
    }
    ElseIf ($deploymentType -ieq 'Uninstall') {
        ##*===============================================
        ##* PRE-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Pre-Uninstallation'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore,AcroRd32,Acrobat' -CloseAppsCountdown 60 -DeferTimes 0 -MinimizeWindows $true

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Uninstallation tasks here>

        ##*===============================================
        ##* UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Uninstallation'

        ## Handle Zero-Config MSI Uninstallations
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Uninstall'; Path = $defaultMsiFile }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }

        ## <Perform Uninstallation tasks here>

        # Determine printer data path for user context
        $isUserContext = -not ([Security.Principal.WindowsIdentity]::GetCurrent().Groups -contains "S-1-5-32-544")
        if ($isUserContext) {
            $printerDataPath = "$($env:LOCALAPPDATA)\Printers"
        } else {
            $printerDataPath = "$($env:ProgramData)\Printers"
        }
        
        # Start logging
        Start-Transcript "$printerDataPath\TSAPrinterUninstall.log" -Append

        try {
            Write-Log -Message "Starting uninstallation of printer \\tsaps1\tsaPR-LOG-2" -Source $deployAppScriptFriendlyName
            
            # Check if printer exists
            $existingPrinter = Get-Printer -Name "\\tsaps1\tsaPR-LOG-2" -ErrorAction SilentlyContinue
            
            if ($existingPrinter) {
                Write-Log -Message "Removing printer \\tsaps1\tsaPR-LOG-2" -Source $deployAppScriptFriendlyName
                Remove-Printer -Name "\\tsaps1\tsaPR-LOG-2" -ErrorAction Stop
                Write-Log -Message "Successfully removed printer \\tsaps1\tsaPR-LOG-2" -Source $deployAppScriptFriendlyName
            } else {
                Write-Log -Message "Printer \\tsaps1\tsaPR-LOG-2 not found, nothing to remove" -Source $deployAppScriptFriendlyName
            }
            
            # Remove installation marker
            if (Test-Path "$printerDataPath\TSAPrinterTSAPR-LOG-2.ps1.tag") {
                Remove-Item -Path "$printerDataPath\TSAPrinterTSAPR-LOG-2.ps1.tag" -Force
                Write-Log -Message "Removed installation marker" -Source $deployAppScriptFriendlyName
            }
        }
        catch {
            Write-Log -Message "Failed to uninstall printer TSAPR-LOG-2. Error: $($_.Exception.Message)" -Severity 3 -Source $deployAppScriptFriendlyName
            throw $_
        }
        finally {
            Stop-Transcript
        }

        ##*===============================================
        ##* POST-UNINSTALLATION
        ##*===============================================
        [String]$installPhase = 'Post-Uninstallation'

        ## <Perform Post-Uninstallation tasks here>

    }
    ElseIf ($deploymentType -ieq 'Repair') {
        ##*===============================================
        ##* PRE-REPAIR
        ##*===============================================
        [String]$installPhase = 'Pre-Repair'

        ## Show Welcome Message, close Internet Explorer with a 60 second countdown before automatically closing
        Show-InstallationWelcome -CloseApps 'iexplore' -CloseAppsCountdown 60 -DeferTimes 0 -MinimizeWindows $true

        ## Show Progress Message (with the default message)
        Show-InstallationProgress

        ## <Perform Pre-Repair tasks here>

        ##*===============================================
        ##* REPAIR
        ##*===============================================
        [String]$installPhase = 'Repair'

        ## Handle Zero-Config MSI Repairs
        If ($useDefaultMsi) {
            [Hashtable]$ExecuteDefaultMSISplat = @{ Action = 'Repair'; Path = $defaultMsiFile; }; If ($defaultMstFile) {
                $ExecuteDefaultMSISplat.Add('Transform', $defaultMstFile)
            }
            Execute-MSI @ExecuteDefaultMSISplat
        }
        ## <Perform Repair tasks here>

        ##*===============================================
        ##* POST-REPAIR
        ##*===============================================
        [String]$installPhase = 'Post-Repair'

        ## <Perform Post-Repair tasks here>


    }
    ##*===============================================
    ##* END SCRIPT BODY
    ##*===============================================

    ## Call the Exit-Script function to perform final cleanup operations
    Exit-Script -ExitCode $mainExitCode
}
Catch {
    [Int32]$mainExitCode = 60001
    [String]$mainErrorMessage = "$(Resolve-Error)"
    Write-Log -Message $mainErrorMessage -Severity 3 -Source $deployAppScriptFriendlyName
    Show-DialogBox -Text $mainErrorMessage -Icon 'Stop'
    Exit-Script -ExitCode $mainExitCode
}

