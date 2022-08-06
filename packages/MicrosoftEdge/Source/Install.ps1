<#
    .SYNOPSIS
    Installs the application
#>
[CmdletBinding()]
param ()

#region Restart if running in a 32-bit session
If (!([System.Environment]::Is64BitProcess)) {
    If ([System.Environment]::Is64BitOperatingSystem) {
        $Arguments = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$($MyInvocation.MyCommand.Definition)`""
        $ProcessPath = $(Join-Path -Path $Env:SystemRoot -ChildPath "\Sysnative\WindowsPowerShell\v1.0\powershell.exe")
        Write-Verbose -Message "Restarting in 64-bit PowerShell."
        Write-Verbose -Message "FilePath: $ProcessPath."
        Write-Verbose -Message "Arguments: $Arguments."
        $params = @{
            FilePath     = $ProcessPath
            ArgumentList = $Arguments
            Wait         = $True
            WindowStyle  = "Hidden"
        }
        Start-Process @params
        Exit 0
    }
}
#endregion

$prefs = @"
{
    "bookmark_bar": {
        "show_apps_shortcut": true,
        "show_managed_bookmarks": true,
        "show_on_all_tabs": false
    },
    "bookmarks": {
        "editing_enabled": true
    },
    "browser": {
        "dark_theme": true,
        "first_run_tabs": [
            "https://www.office.com"
        ],
        "show_toolbar_bookmarks_button": true,
        "show_toolbar_collections_button": true,
        "show_toolbar_downloads_button": true,
        "show_home_button": true,
        "show_prompt_before_closing_tabs": true,
        "show_toolbar_history_button": true
    },
    "default_search_provider": {
        "enabled": true,
        "search_url": "www.bing.com"
    },
    "fullscreen": {
        "allowed": true
    },
    "homepage": "https://www.office.com/",
    "homepage_is_newtabpage": false,
    "history": {
        "clear_on_exit": false,
        "deleting_enabled": true
    },
    "feedback_allowed": false
}
"@

try {
    $Installer = Get-ChildItem -Path $PWD -Filter "MicrosoftEdgeEnterpriseX64.msi" -Recurse -ErrorAction "SilentlyContinue"
    $params = @{
        FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/package `"$($Installer.FullName)`" ALLUSERS=1 DONOTCREATEDESKTOPSHORTCUT=true DONOTCREATETASKBARSHORTCUT=true /quiet /log `"C:\ProgramData\PackageFactory\logs\MicrosoftEdge.log`""
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params

    # Create the initial_preferences file
    $params = @{
        FilePath    = "${Env:ProgramFiles(x86)}\Microsoft\Edge\Application\initial_preferences"
        Encoding    = "Utf8"
        Force       = $True
        NoNewline   = $True
        ErrorAction = "SilentlyContinue"
    }
    $prefs | Out-File @params
}
catch {
    throw "Failed to install Microsoft Edge."
}
finally {
    If ($result.ExitCode -eq 0) {
        $Files = @("$env:PUBLIC\Desktop\Microsoft Edge.lnk")
        Remove-Item -Path $Files -Force -ErrorAction "SilentlyContinue"
    }
    exit $result.ExitCode
}
