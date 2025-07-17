Set-ExecutionPolicy Bypass -Scope Process
$folderFilePath = (Get-ChildItem -Filter BMDClnt.exe -Recurse | select Directory).Directory.toString()
$bmdExeFile=$folderFilePath+"\BMDClnt.exe"
$bmdInstallINI=$folderFilePath+"\INSTALL.INI"
$bmdUninstallINI=$folderFilePath+"\uninstall.ini"

$boolStringInstallUninstall=$Args[0]

If ($boolStringInstallUninstall -eq "uninstall")
{
    Start-Process $bmdExeFile $bmdUninstallINI
}
else
{
    Start-Process $bmdExeFile $bmdInstallINI
}

