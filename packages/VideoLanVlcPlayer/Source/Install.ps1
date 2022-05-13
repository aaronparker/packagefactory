<#
    .SYNOPSIS
    Installs the application
#>
[CmdletBinding()]
Param ()

try {
    $Installer = Get-ChildItem -Path $PWD -Filter "vlc*.msi" -Recurse -ErrorAction "SilentlyContinue"
    $params = @{
        FilePath     = "$Env:SystemRoot\System32\msiexec.exe"
        ArgumentList = "/package `"$($Installer.FullName)`" ALLUSERS=1 /quiet"
        NoNewWindow  = $True
        PassThru     = $True
        Wait         = $True
    }
    $result = Start-Process @params
}
catch {
    throw "Failed to install VLC media player."
}
finally {
    If ($result.ExitCode -eq 0) {
        $Files = @("$env:ProgramData\Microsoft\Windows\Start Menu\Programs\VideoLAN\VLC\VideoLAN website.lnk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\VideoLAN\VLC\Release Notes.lnk",
            "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\VideoLAN\VLC\Documentation.lnk",
            "$env:PUBLIC\Desktop\VLC media player.lnk")
        Remove-Item -Path $Files -Force -ErrorAction "SilentlyContinue"
    }
    exit $result.ExitCode
}
