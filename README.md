# PSPackageFactory

## A Package Factory for Microsoft Intune

Combining [Evergreen](https://stealthpuppy.com/evergreen), [VcRedist](https://vcredist.com/), [IntuneWin32App](https://github.com/MSEndpointMgr/IntuneWin32App) and [IntuneWin32AppPackager](https://github.com/MSEndpointMgr/IntuneWin32AppPackager) to create a packaging factory for Microsoft Intune.

**Documentation**: [https://stealthpuppy.com/packagefactory](https://stealthpuppy.com/packagefactory)

----

**PSPackageFactory** is a fork of [IntuneWin32AppPackager](https://github.com/MSEndpointMgr/IntuneWin32AppPackager) combined with [Evergreen](https://stealthpuppy.com/evergreen) and [VcRedist](https://vcredist.com/) to create an automated packaging factory for Microsoft Intune.

This package factory enables maintaining a library of applications for automatic update, packaging and import into Microsoft Intune. `New-Win32Package.ps1` uses Evergreen and VcRedist to download the latest version of a target application before packaging and importing into Intune.

## Packaging Framework

For applications that can't be automatically updated (e.g., installers are locked behind a login, or an installer that is custom to the target environment), this packaging framework can be used as a repeatable process to package and import those applications into Intune.

## Updates

Evergreen keeps the library up to date by updating `App.json` for each package via a GitHub Workflow that runs once every 24 hours.

[![update-packagejson](https://github.com/aaronparker/packagefactory/actions/workflows/update-packagejson.yml/badge.svg)](https://github.com/aaronparker/packagefactory/actions/workflows/update-packagejson.yml)
