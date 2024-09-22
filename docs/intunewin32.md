# IntuneWin32AppPackager Framework Overview

[IntuneWin32AppPackager](https://github.com/MSEndpointMgr/IntuneWin32App) aims at making it easier to package, create and at the same time document Win32 applications for Microsoft Intune. A manifest file named `App.json` needs to be configured to control how the application is created. Configurations such as application name, description, requirement rules, detection roles and other is defined within the manifest file. `Create-Win32App.ps1` is used to start the creation of the application, based upon configurations specified in the manifest file, `App.json`.

## File and folder structure

For each application that has to be packaged as a Win32 app, a specific application folder should be created with the **IntuneWin32AppPackager** files and folder residing inside it. Below is an example of how the folder structure could look like:

- Root
  - Application 1.0.0 (Folder where the IntuneWin32AppPackager is contained within)
    - Package (Folder)
    - Source (Folder)
    - Scripts (Folder)
    - Icon.png (this can also be a HTTP reference)
    - App.json

### Package folder

A required folder where the packaged .intunewin file will be created in after execution of `Create-Win32App.ps1`.

### Source folder

A required folder that must contain the source files, meaning everything that's supposed to be packaged as a .intunewin file, else the packaging will fail if empty.

### Scripts folder

Use this folder for any custom created scripts used for either Requirement Rules or Detection Rules. This folder is only required when such custom script files are used.

## Create-Win32App.ps1 script

Main framework script that packages, retrieves the required information from the manifest file and constructs necessary objects that are passed on to `Add-IntuneWin32App` function from the IntuneWin32App module. This script has a -Validate switch that can be used to validate the manifest file configuration, which results in that the configuration is written as output to the console instead of creating a new Win32 application.

## First things first

Using this Win32 application packaging framework requires the **IntuneWin32App** module, minimum version `1.3.3`, to be installed on the device where it's executed. Install the module from the PSGallery using:

```PowerShell
Install-Module -Name IntuneWin32App
```

## Manifest configuration (App.json)

Within the manifest file, there are several segments of configuration that controls different parts in the packaging framework. Below are sample configurations for each segment including their possible values. Since the manifest file is written in JSON, there's no built in commenting support system. Segments consists of static properties, such as PackageInformation for instance. Static properties within the manifest file should never be changed. Sub-properties such as `SetupType` for instance, are referred to as dynamic properties (meaning that they are named differently depending on the configuration scenario, e.g. MSI or EXE, or a detection rule based on a script or registry key). Some dynamic properties have a set of pre-defined values which can be used. Such dynamic properties are documented with their possible values, for instance as shown below:

```json
"DeviceRestartBehavior": "suppress \\ force \\ basedOnReturnCode \\ allow"
```

Each possible value are separated with the '\\' character, where the desired value are kept and the rest are simply removed.

### PackageInformation

Below block is the main information related to the packaging of a Win32 app, like the setup file, content source folder and output folder for the .intunewin file, but it also contains other information such as the icon file to use and last but not least, the overall packaging method as either EXE or MSI.

```json
"PackageInformation": {
    "SetupType": "MSI \\ EXE",
    "SetupFile": "Setup.exe",
    "SourceFolder": "Source",
    "OutputFolder": "Package",
    "IconFile": "Icon.png"
}
```

### Information

This block contains the basic Win32 app information, such as the display name, description and publisher. All properties are required to have a value, with an exception for the Notes property.

```json
"Information": {
    "DisplayName": "AppName 1.0.0",
    "Description": "Installs AppName 1.0.0",
    "Publisher": "AppVendor"
}
```

### Program

This block contains the desired program information of a Win32 app. InstallCommand and UninstallCommand are only required when `SetupType` in the PackageInformation section is set to EXE, otherwise the packaging creation process will automatically construct the installation and uninstallation commands for MSI installations. In addition to this, the install experience, for the installation to run in either System or User context including the restart behavior are specified here.

```json
"Program": {
    "InstallCommand": "<-- Only required when SetupType is set as EXE -->",
    "UninstallCommand": "<-- Only required when SetupType is set as EXE -->",
    "InstallExperience": "system \\ user",
    "DeviceRestartBehavior": "suppress \\ force \\ basedOnReturnCode \\ allow",
    "AllowAvailableUninstall": false \\ true
}
```

### DetectionRule

As you may know, the Win32 app model provides several methods on detecting if the application is or have already been installed. **IntuneWin32AppPackager** framework supports all potential detection rules, such as MSI, File, Registry or Script based. It's supported to add multiple detection rules can be added to the manifest file.

NOTE: It's not supported to add multiple detection rules when a Script detection rule is used.

### DetectionRule - Registry

A Registry detection rule type can be of different detection methods, such as:

- Existence
- IntegerComparison
- StringComparison
- VersionComparison

Below are example configurations for each supported detection method for a Registry detection rule.

#### DetectionRule - Registry - Existence

```json
{
    "Type": "Registry",
    "DetectionMethod": "Existence",
    "KeyPath": "HKEY_LOCAL_MACHINE\\SOFTWARE\\Key",
    "ValueName": "DisplayVersion",
    "DetectionType": "exists \\ notExists",
    "Check32BitOn64System": "false \\ true"
}
```

#### DetectionRule - Registry - IntegerComparison

```json
{
    "Type": "Registry",
    "DetectionMethod": "IntegerComparison",
    "KeyPath": "HKEY_LOCAL_MACHINE\\SOFTWARE\\Key",
    "ValueName": "DisplayVersion",
    "Operator": "notEqual \\ lessThanOrEqual \\ lessThan \\ greaterThanOrEqual \\ greaterThan \\ equal",
    "Value": "1",
    "Check32BitOn64System": "false \\ true"
}
```

#### DetectionRule - Registry - StringComparison

```json
{
    "Type": "Registry",
    "DetectionMethod": "StringComparison",
    "KeyPath": "HKEY_LOCAL_MACHINE\\SOFTWARE\\Key",
    "ValueName": "DisplayVersion",
    "Operator": "notEqual \\ equal",
    "Value": "1.0.0",
    "Check32BitOn64System": "false \\ true"
}
```

More: Registry - StringComparison

```json
{
    "Type": "Registry",
    "DetectionMethod": "VersionComparison",
    "KeyPath": "HKEY_LOCAL_MACHINE\\SOFTWARE\\Key",
    "ValueName": "DisplayVersion",
    "Operator": "notEqual \\ lessThanOrEqual \\ lessThan \\ greaterThanOrEqual \\ greaterThan \\ equal",
    "Value": "1.0.0",
    "Check32BitOn64System": "false \\ true"
}
```

### DetectionRule - File

A File detection rule type can be of different detection methods, such as:

- Existence
- DateModified
- DateCreated
- Version
- Size

```json
{
    "Type": "Registry",
    "DetectionMethod": "VersionComparison",
    "KeyPath": "HKEY_LOCAL_MACHINE\\SOFTWARE\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\123",
    "ValueName": "DisplayVersion",
    "Operator": "greaterThanOrEqual",
    "Value": "1.0.0",
    "Check32BitOn64System": "false"
}
```

### MSI Example manifest

```json
{
    "PackageInformation": {
        "SetupType": "MSI",
        "SetupFile": "7z1900-x64.msi",
        "SourceFolder": "Source",
        "OutputFolder": "Package",
        "IconFile": "Icon.png"
    },
    "Information": {
        "DisplayName": "7-Zip 19.0 x64",
        "Description": "Install 7-Zip archive compression application",
        "Publisher": "7-Zip",
        "Notes": "Core application"
    },
    "Program": {
        "InstallExperience": "system",
        "DeviceRestartBehavior": "suppress"
    },
    "RequirementRule": {
        "MinimumRequiredOperatingSystem": "W10_1809",
        "Architecture": "x64"
    },
    "CustomRequirementRule": [
    ],
    "DetectionRule": [
        {
            "Type": "MSI",
            "ProductCode": "{23170F69-40C1-2702-1900-000001000000}",
            "ProductVersionOperator": "notConfigured",
            "ProductVersion": ""
        }
    ]
}
```
