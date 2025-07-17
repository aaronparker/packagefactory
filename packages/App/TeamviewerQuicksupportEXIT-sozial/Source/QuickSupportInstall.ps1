Set-ExecutionPolicy Bypass -Scope Process
$FileObject = Get-ChildItem -Filter "*Quick Support.exe" -Recurse
$quickSupportExeFile=$FileObject.FullName

Set-Location $FileObject.Directory

Write-Host $FileObject.BaseName
Write-Host $quickSupportExeFile

$boolStringInstallUninstall=$Args[0]

$targetFolder = "C:\Program Files (x86)\Teamviewer"
$shortcutPath = "C:\Users\Public\Desktop\$($FileObject.BaseName)"
$targetExePath = Join-Path $targetFolder $FileObject.Name

If ($boolStringInstallUninstall -eq "uninstall")
{
    Write-Host "Uninstalling Quick Support"
    if (Test-Path $targetExePath) {
        Remove-Item $targetExePath -Force
        Write-Host "Deleted $targetExePath"
    }
    if (Test-Path $shortcutPath) {
        Remove-Item $shortcutPath -Force
        Write-Host "Deleted $shortcutPath"
    }
}
else
{
    Write-Host "Installing Quick Support"
    if (!(Test-Path $targetFolder)) {
        New-Item -Path $targetFolder -ItemType Directory -Force | Out-Null
        Write-Host "Created folder $targetFolder"
    }
    Copy-Item -Path $quickSupportExeFile -Destination $targetExePath -Force
    Write-Host "Copied $quickSupportExeFile to $targetExePath"
    New-Item -Path $shortcutPath -ItemType SymbolicLink -Target $targetExePath -Force
    Write-Host "Created shortcut $shortcutPath"
}

