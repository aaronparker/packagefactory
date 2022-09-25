# A Package Factory for Microsoft Intune

## About

**PSPackageFactory** is a fork of [IntuneWin32AppPackager](https://github.com/MSEndpointMgr/IntuneWin32AppPackager) combined with [Evergreen](https://stealthpuppy.com/evergreen) and [VcRedist](https://vcredist.com/) to create an automated packaging factory for Microsoft Intune.

This package factory enables maintaining a library of applications for automatic update, packaging and import into Microsoft Intune. `Create-Win32App.ps1` in this repository has been updated to use Evergreen and VcRedist to download the latest version of a target application before packaging and importing into Intune.

Additionally, Evergreen  and VcRedist are used to keep the library up to date by updating `App.json` for each package via a GitHub Workflow that runs once every 24 hours. This ensures that the packaging factory is always current and will create an Intune Win32 application package using the latest version of an application.

For those applications that can't be automatically updated (e.g., installers are locked behind a login, or an installer is custom to the target environment), this packaging framework can be used to enable a repeatable process to package and import those applications.

## Features

PSPackageFactory builds on IntuneWin32AppPackager, and adds functionality including:

* Supports a library of application packages or application update packages
* Automatically updates `App.json` with details of the latest application version
* Supports icons available over HTTPS - the icon will be downloaded at packaging time
* Supports additional Win32 application package properties
* Adds package properties to enable identification of the same application across multiple versions
