# About App.json

Each package is defined by `App.json`. This is largely the same as the original JSON as defined by [IntuneWin32AppPackager](intunewin32.md); however, it has been extended in several key ways.

1. An `Application` definition is included that defines details of the target application and how to find the latest version and download URL via Evergreen or VcRedist
2. The `PackageInformation.Version` value and other locations where the application version is stored, are update automatically when a new version of the application is detected
3. The icon defined in `PackageInformation.IconFile` can be a HTTP source. `Create-Win32App.ps1` will attempt to download the icon when creating the application package. An icon library is maintain here: [https://github.com/aaronparker/icons/](https://github.com/aaronparker/icons/)
4. A unique GUID identifier is added to `Information.PSPackageFactoryGuid` and added to the `Notes` section of the application in Intune. This is used to link different versions of the same application in Intune. This approach can be used to determine whether an updated version of the application should be imported into Intune
5. `Dependencies`, `Supersedence`, and `Assignments` can be added - the intention is to update the package factory to use these values in the future

!!! info

    The Package Factory includes a set of applications that are [supported for automatic updates via Evergreen](https://stealthpuppy.com/evergreen/apps/) and [VcRedist](https://vcredist.com). Other applications can be packaged by manually downloading the application installer and updating App.json with the package details.

Here's an example `App.json` for Adobe Acrobat Reader DC:

```json
{
  "Application": {
    "Name": "AdobeAcrobatReaderDC",
    "Filter": "Get-EvergreenApp -Name \"AdobeAcrobatReaderDC\" | Where-Object { $_.Language -eq \"MUI\" -and $_.Architecture -eq \"x64\" } | Select-Object -First 1",
    "Title": "Adobe Acrobat Reader DC",
    "Language": "English",
    "Architecture": "x64"
  },
  "PackageInformation": {
    "SetupType": "EXE",
    "SetupFile": "AcroRdrDCx642200220191_MUI.exe",
    "Version": "22.002.20191",
    "SourceFolder": "Source",
    "OutputFolder": "Package",
    "IconFile": "https://github.com/aaronparker/icons/raw/main/companyportal/Adobe-AcrobatReader.png"
  },
  "Information": {
    "DisplayName": "Adobe Acrobat Reader DC 22.002.20191 x64",
    "Description": "The leading PDF viewer to print, sign, and annotate PDFs.",
    "Publisher": "Adobe",
    "InformationURL": "https://www.adobe.com/acrobat/pdf-reader.html",
    "PrivacyURL": "https://www.adobe.com/privacy.html",
    "FeaturedApp": false,
    "Categories": [],
    "PSPackageFactoryGuid": "a0042672-7240-4312-892e-39623320c0a3"
  },
  "Program": {
    "InstallTemplate": "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\\Install.ps1",
    "InstallCommand": "powershell.exe -ExecutionPolicy Bypass -NonInteractive -WindowStyle Hidden -File .\\Install.ps1",
    "UninstallCommand": "msiexec.exe /X \"{AC76BA86-1033-1033-7760-BC15014EA700}\" /quiet",
    "InstallExperience": "system",
    "DeviceRestartBehavior": "suppress",
    "AllowAvailableUninstall": false
  },
  "RequirementRule": {
    "MinimumRequiredOperatingSystem": "W10_1809",
    "Architecture": "x64"
  },
  "CustomRequirementRule": [],
  "DetectionRule": [
    {
      "Type": "File",
      "DetectionMethod": "Version",
      "Path": "C:\\Program Files\\Adobe\\Acrobat DC\\Acrobat",
      "FileOrFolder": "Acrobat.exe",
      "Operator": "greaterThanOrEqual",
      "VersionValue": "22.002.20191",
      "Check32BitOn64System": "false"
    }
  ],
  "Dependencies": [],
  "Supersedence": [],
  "Assignments": []
}
```
