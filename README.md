# 📦 PSPackageFactory

## A Package Factory for Microsoft Intune

![Intune logo](docs/assets/img/intune.png)

**PSPackageFactory** is a fork of [IntuneWin32AppPackager](https://github.com/MSEndpointMgr/IntuneWin32AppPackager) combined with [Evergreen](https://stealthpuppy.com/evergreen) and [VcRedist](https://vcredist.com/) to create an automated packaging factory for Microsoft Intune.

**Documentation**: [https://stealthpuppy.com/packagefactory](https://stealthpuppy.com/packagefactory)

## 🤖 Automated Packaging Framework

This package factory provides a library of applications for automatic update, packaging and import into Microsoft Intune. `New-Win32Package.ps1` uses Evergreen and VcRedist to download the latest version of a target application before packaging and importing into Intune.

Evergreen keeps the library up to date by updating `App.json` for each package via a GitHub Workflow that runs once every 24 hours.

[![update-packagejson](https://github.com/aaronparker/packagefactory/actions/workflows/update-packagejson.yml/badge.svg)](https://github.com/aaronparker/packagefactory/actions/workflows/update-packagejson.yml)

## 🤚🏻 Manual Packaging Framework

Even if you're using a solution such as [Patch My PC](https://patchmypc.com/), there are applications that can't be automatically updated (e.g., installers are locked behind a login, or an installer that is custom to the target environment), this packaging framework can be used as a repeatable process to package and import those applications into Intune.
