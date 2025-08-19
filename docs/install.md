# About Install.json

The Packaging Factory implements support for a standardised approach to installing an application via [`Install.ps1`](https://github.com/aaronparker/packagefactory/blob/main/Install.ps1). Using this install script is optional, but it simplifies the maintenance of install scripts by using a single script that reads `Install.json` that defines the installation logic for an application.

The use of `Install.ps1` is defined in `Program.InstallCommand` section in the `App.json` file for each application:

```json
  "Program": {
    "InstallTemplate": "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\\Install.ps1",
    "InstallCommand": "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\\Install.ps1",
    "UninstallCommand": "msiexec.exe /X \"{AC76BA86-1033-1033-7760-BC15014EA700}\" /quiet",
    "InstallExperience": "system",
    "DeviceRestartBehavior": "suppress",
    "AllowAvailableUninstall": false
  },
```

You can replace the installation command with the [PowerShell App Deployment Toolkit](https://psappdeploytoolkit.com/) or directly referencing the application installer; however, `Install.ps1` provides a simple approach to installing an application while providing some additional features.

`Install.json` defines details for the application installer and important install tasks including the application installer silent install arguments:

```json
{
    "PackageInformation": {
        "SetupType": "EXE",
        "SetupFile": "AcroRdrDCx642200220191_MUI.exe",
        "Version": "22.002.20191"
    },
    "LogPath": "C:\\ProgramData\\Microsoft\\IntuneManagementExtension\\Logs",
    "InstallTasks": {
        "ArgumentList": "-sfx_nu /sALL /rps /l /msi EULA_ACCEPT=YES ENABLE_CHROMEEXT=0 DISABLE_BROWSER_INTEGRATION=1 ENABLE_OPTIMIZATION=YES ADD_THUMBNAILPREVIEW=0 DISABLEDESKTOPSHORTCUT=1 /log \"#LogPath\\#LogName.log\""
    },
    "PostInstall": {
        "Remove": [
        ],
        "CopyFile": [
        ]
    }
}
```

Like `App.json`, `Install.json` is also automatically updated with application information returned from Evergreen, including the installer file name and the application version number. By updating the `PackageInformation.SetupFile` information in `Install.json`, we ensure that `Install.ps1` will look for that specific installer file and not attempt to execute any other file.

## PSAppDeployToolkit

If you prefer to use the PSAppDeployToolkit, replace `Install.json` with `Invoke-AppDeployToolkit.ps1`. When `New-Win32Package.ps1` is run, it will detect the presence of `Invoke-AppDeployToolkit.ps1` and copy the PSAppDeployToolkit into the package before preparing the .intunewin file.
