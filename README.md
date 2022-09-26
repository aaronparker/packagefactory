# PSPackageFactory - A Package Factory for Microsoft Intune

Combining [Evergreen](https://stealthpuppy.com/evergreen), [VcRedist](https://vcredist.com/), [IntuneWin32App](https://github.com/MSEndpointMgr/IntuneWin32App) and [IntuneWin32AppPackager](https://github.com/MSEndpointMgr/IntuneWin32AppPackager) to create a packaging factory for Microsoft Intune.

Documentation: [https://stealthpuppy.com/packagefactory](https://stealthpuppy.com/packagefactory)

----

This package factory enables maintaining a library of applications for automatic update, packaging and import into Microsoft Intune. `Create-Win32App.ps1` in this repository has been updated to use Evergreen (and VcRedist) to download the latest version of a target application before packaging and importing into Intune.

Additionally, Evergreen is used to keep the library up to date by updating `App.json` for each package via a GitHub Workflow that runs once every 24 hours.

[![update-packagejson](https://github.com/aaronparker/packagefactory/actions/workflows/update-packagejson.yml/badge.svg)](https://github.com/aaronparker/packagefactory/actions/workflows/update-packagejson.yml)

For those applications that can't be automatically updated (e.g., installers are locked behind a login, or an installer is custom to the target environment), this packaging framework can be used to enable a repeatable process to package and import those applications.
