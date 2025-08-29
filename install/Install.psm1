<#
    Shared functions for scripts
#>

# Pass WhatIf and Verbose preferences to functions and cmdlets below
if ($WhatIfPreference -eq $true) { $Script:WhatIfPref = $true } else { $WhatIfPref = $false }
if ($VerbosePreference -eq $true) { $Script:VerbosePref = $true } else { $VerbosePref = $false }

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

    begin {
        # Log file path
        $LogFile = "$Env:ProgramData\Microsoft\IntuneManagementExtension\Logs\PSPackageFactoryInstall.log"
    }

    process {
        # Build the line which will be recorded to the log file
        $TimeGenerated = $(Get-Date -Format "HH:mm:ss.ffffff")
        $Context = $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)
        $Thread = $([Threading.Thread]::CurrentThread.ManagedThreadId)
        $LineFormat = $Message, $TimeGenerated, (Get-Date -Format "yyyy-MM-dd"), "$($MyInvocation.ScriptName | Split-Path -Leaf -ErrorAction "SilentlyContinue"):$($MyInvocation.ScriptLineNumber)", $Context, $LogLevel, $Thread
        $Line = '<![LOG[{0}]LOG]!><time="{1}" date="{2}" component="{3}" context="{4}" type="{5}" thread="{6}" file="">' -f $LineFormat

        # Add content to the log file and output to the console
        Write-Information -MessageData "[$TimeGenerated] $Message" -InformationAction "Continue"
        Add-Content -Value $Line -Path $LogFile

        # Write-Warning for log level 2 or 3
        if ($LogLevel -eq 3 -or $LogLevel -eq 2) {
            Write-Warning -Message "[$TimeGenerated] $Message"
        }
    }
}

function Export-MdtVariable {
    try {
        # Create an object to access the task sequence environment
        $TsEnv = New-Object -ComObject "Microsoft.SMS.TSEnvironment"

        # Export all variables in the task sequence environment to a PSObject
        $PSObject = New-Object -TypeName "PSObject"
        $TsEnv.GetVariables() | ForEach-Object { 
            $PSObject | Add-Member -Name "$_" -Type "NoteProperty" -Value "$($TsEnv.Value($_))"
        }

        # Write to the pipeline
        $PSObject | Write-Output
    }
    catch {
        # Return $null if the task sequence environment object cannot be created
        return $null
    }
}

function Get-InstalledSoftware {
    $PropertyNames = "DisplayName", "DisplayVersion", "Publisher", "UninstallString", "PSPath", "WindowsInstaller",
    "InstallDate", "InstallSource", "HelpLink", "Language", "EstimatedSize", "SystemComponent"
    ("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*") | `
        ForEach-Object {
        Get-ItemProperty -Path $_ -Name $PropertyNames -ErrorAction "SilentlyContinue" | `
            . { process { if ($null -ne $_.DisplayName) { $_ } } } | `
            Where-Object { $_.SystemComponent -ne 1 } | `
            Select-Object -Property @{n = "Name"; e = { $_.DisplayName } }, @{n = "Version"; e = { $_.DisplayVersion } }, "Publisher",
        "UninstallString", @{n = "RegistryPath"; e = { $_.PSPath -replace "Microsoft.PowerShell.Core\\Registry::", "" } },
        "PSChildName", "WindowsInstaller", "InstallDate", "InstallSource", "HelpLink", "Language", "EstimatedSize" | `
            Sort-Object -Property "Name", "Publisher"
    }
}

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
            }
        }
    }
}

function Save-Uri {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [System.Uri] $Uri,
        [System.String] $Destination
    )
    begin {
        [System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
        $ProgressPreference = "SilentlyContinue"
    }
    process {
        if (Test-Path -Path $(Split-Path -Path $Destination -Parent)) {
            try {
                Write-LogFile -Message "Download file: $Uri"
                Write-LogFile -Message "Destination: $Destination"
                $params = @{
                    Uri             = $Uri
                    OutFile         = $Destination
                    UseBasicParsing = $true
                    ErrorAction     = "Continue"
                }
                Invoke-WebRequest @params
                if (Test-Path -Path $Destination) {
                    Write-Output -InputObject $Destination
                }
                else {
                    return $null
                }
            }
            catch {
                Write-LogFile -Message "Save-Uri: $($_.Exception.Message)" -LogLevel 3
            }
        }
        else {
            Write-LogFile -Message "Save-Uri: Cannot find path for $Destination" -LogLevel 3
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
                elseif (Test-Path -Path $Item -PathType "Leaf") {
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
                    Get-Process | Where-Object { $_.Path -like $Item } | ForEach-Object {
                        Stop-Process -Name $_.ProcessName -Force @params
                    }
                }
                else {
                    Get-Process | Where-Object { $_.Path -like $Item } | ForEach-Object {
                        Stop-Process -Name $_.ProcessName @params
                    }
                }
            }
            catch {
                Write-LogFile -Message "Stop-PathProcess error: $($_.Exception.Message)" -LogLevel 2
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
                }
            }
        }
    }
}

function Install-Font {
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, Position = 0)]
        [System.String] $Path
    )

    begin {
        Write-LogFile -Message "Load assembly: PresentationCore"
        Add-Type -AssemblyName "PresentationCore"

        # Get the font files in the target path
        $FontFiles = Get-ChildItem -Path $Path -Include "*.ttf", "*.otf" -Recurse
        Write-LogFile -Message "Found $($FontFiles.Count) font files in path: $Path"
    }

    process {
        foreach ($Font in $FontFiles) {
            try {
                # Load the font file
                Write-LogFile -Message "Load font: $($Font.FullName)"
                $Gt = [Windows.Media.GlyphTypeface]::New($Font.FullName)

                # Get the font family name
                $FamilyName = $Gt.Win32FamilyNames['en-US']
                if ($null -eq $FamilyName) {
                    $FamilyName = $Gt.Win32FamilyNames.Values.Item(0)
                }

                # Get the font face name
                $FaceName = $Gt.Win32FaceNames['en-US']
                if ($null -eq $FaceName) {
                    $FaceName = $Gt.Win32FaceNames.Values.Item(0)
                }

                # Add the font and get the font name
                $FontName = ("$FamilyName $FaceName").Trim()
                switch ($Font.Extension) {
                    ".ttf" { $FontName = "$FontName (TrueType)" }
                    ".otf" { $FontName = "$FontName (OpenType)" }
                }

                Write-LogFile -Message "Installing font: $FontName"
                Write-LogFile -Message "Copy font file: $($Font.Name)"
                Copy-Item -Path $Font.FullName -Destination "$Env:SystemRoot\Fonts\$($Font.Name)" -Force

                Write-LogFile -Message "Add font to registry: $($Font.Name)"
                New-ItemProperty -Name $FontName -Path "HKLM:\Software\Microsoft\Windows NT\CurrentVersion\Fonts" -PropertyType string -Value $Font.Name -Force | Out-Null

                # Dispose the font collection
                Write-LogFile -Message "Font installed successfully"
            }
            catch {
                Write-LogFile -Message $_.Exception.Message -LogLevel 3
            }
            finally {
                Remove-Variable -Name "Gt"
            }
        }
    }
}

function New-Shortcut {
    param(
        [System.String] $ShortcutName,
        [System.String] $TargetPath,
        [System.String] $Description,
        [System.String] $WorkingDirectory,
        [System.String] $Arguments,
        [System.String] $IconLocation,
        [System.Int32] $IconIndex = 0,
        [System.Int32] $WindowStyle = 1
    )

    # Create a new WScript.Shell object
    $WScriptShell = New-Object -ComObject "WScript.Shell"

    # Create a new shortcut
    $ShortcutPath = [System.IO.Path]::Combine("$Env:ProgramData\Microsoft\Windows\Start Menu\Programs", $ShortcutName)
    Write-LogFile -Message "Create shortcut: $ShortcutPath"
    $Shortcut = $WScriptShell.CreateShortcut($ShortcutPath)
    $Shortcut.TargetPath = ($TargetPath)

    # Set the shortcut properties
    if (!([System.String]::IsNullOrEmpty($Description))) { $Shortcut.Description = $Description }

    # If the working directory is not specified, use the directory of the target path
    if ([System.String]::IsNullOrEmpty($WorkingDirectory)) {
        $WorkingDirectory = [System.IO.Path]::GetDirectoryName($TargetPath)
    }
    $Shortcut.WorkingDirectory = $WorkingDirectory

    # If the arguments are not specified, do not set them
    if (!([System.String]::IsNullOrEmpty($Arguments))) { $Shortcut.Arguments = $Arguments }

    # If the icon location is not specified, use the target path
    if ([System.String]::IsNullOrEmpty($IconLocation)) {
        $IconLocation = $TargetPath
    }
    $Shortcut.IconLocation = "$IconLocation, $IconIndex"

    # Set the window style
    $Shortcut.WindowStyle = $WindowStyle

    # Save the shortcut
    Write-LogFile -Message "Save shortcut: $ShortcutPath"
    $Shortcut.Save()
}
