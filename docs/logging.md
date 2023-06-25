# Application Install Logging

The PSPackageFactory supports logging in two primary locations so that you can retrieve logs for troubleshooting. Logs are stored in the Intune Management Extension logs directory for a consistent location.

* `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\PSPackageFactoryInstall.log` - `Install.ps1` will write install actions to this log
* `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\<application>.log` - where supported, application installers will write a specific installation log to this location

![Intune logs](assets/img/intunelogs.png)
