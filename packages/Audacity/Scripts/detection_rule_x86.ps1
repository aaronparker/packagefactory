# Define minimum required version
$ApplicationVersion = "3.1.3"

# File path to compare version properties
$Path = "${Env:ProgramFiles(x86)}\Audacity"
$File = "Audacity"

If (Test-Path -Path $([System.IO.Path]::Combine($Path, $File)) -ErrorAction "SilentlyContinue") {
    $VersionInfo = (Get-Item -Path $([System.IO.Path]::Combine($Path, $File))).VersionInfo
    If ([System.Version]$VersionInfo.FileVersion -ge [System.Version]$ApplicationVersion) {
        Return 0
    }
    Else {
        Return 1
    }
}
Else {
    Return 1
}
