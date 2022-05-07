# Define minimum required version
$ApplicationVersion = "1.62.2"

# File path to compare version properties
$Path = "${Env:ProgramFiles(x86)}\Microsoft VS Code"
$File = "Code.exe"

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
