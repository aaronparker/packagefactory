# Use in a Pipeline

Using the package factory in a pipeline requires a Windows runner. The pipeline will run the same process as if the factory was running on a local machine.

## PowerShell Modules

The factory requires that the **MSAL.PS**, **IntuneWin32App**, **Evergreen**, **VcRedist** PowerShell modules are installed. Install with the following command:

```powershell
Install-Module -Name "MSAL.PS", "IntuneWin32App", "Evergreen", "VcRedist" -Force -SkipPublisherCheck
```

## Authentication

`Connect-MSIntuneGraph` can authenticate to an app registration by passing the tenant ID, application (or client) ID and the client secret:

```powershell
$params = @{
  TenantId     = "$env:TENANT_ID"
  ClientId     = "$env:CLIENT_ID"
  ClientSecret = "$env:CLIENT_SECRET"
}
Connect-MSIntuneGraph @params
```

## Create an Application Package

`New-Win32Package.ps1` is used to read the application package manifest, create the Intune Win32 package and call `Create-Win32App.ps1` to import the package into the target Intune tenant.

Here's an example with importing Adobe Acrobat Reader DC and Citrix Workspace app into your Intune tenant by passing an array of package names to the `-Application` parameter:

```powershell
$params = @{
    Path        = "E:\projects\packagefactory\packages"
    Application = "AdobeAcrobatReaderDCMUI", "CitrixWorkspaceApp"
    Type        = "App"
    WorkingPath = "E:\projects\packagefactory\output"
    Import      = $true
}
.\New-Win32Package.ps1 @params
```

## Create an Update Package

`New-Win32Package.ps1` can also create update packages where an application update is defined. The usage is exactly the same (because the update package logic is stored in the `App.json` for that package) - pass the package name to the `-Application` parameter, but also specify **Update** for the `-Type` parameter.

Here's an example with importing a Adobe Acrobat Reader DC update into your Intune tenant:

```powershell
Set-Location -Path "E:\projects\packagefactory"
$params = @{
    Path        = "E:\projects\packagefactory\packages"
    Application = "AdobeAcrobatReaderDCMUIx64"
    Type        = "Update"
    WorkingPath = "E:\projects\packagefactory\output"
    Import      = $true
}
.\New-Win32Package.ps1 @params
```
