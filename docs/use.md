# Run Locally

To run the package factory locally, clone the repository to a Windows machine, and install the required PowerShell modules.

## PowerShell Modules

The factory requires that the **MSAL.PS**, **IntuneWin32App**, **Evergreen**, **VcRedist** PowerShell modules are installed. Install with the following command, and ensure you are running the latest version of each module when using the package factory.

```powershell
Install-Module -Name "MSAL.PS", "IntuneWin32App", "Evergreen", "VcRedist" -Force -SkipPublisherCheck
```

## Authentication

When running the packaging factory locally on Windows to create application packages and import into an Intune tenant, you must first authenticate to the tenant. The user account used to authenticate must be an [Intune Administrator](https://learn.microsoft.com/en-us/azure/active-directory/roles/permissions-reference#intune-administrator) or an [Intune Application manager](https://learn.microsoft.com/en-us/microsoft-365/business-premium/m365bp-intune-admin-roles-in-the-mac).

Interactive authentication to a tenant can be performed with `Connect-MSIntuneGraph`:

```powershell
Connect-MSIntuneGraph -TenantId stealthpuppylab.onmicrosoft.com
```

### Authentication via an App Registration

`Connect-MSIntuneGraph` can authenticate to an app registration by passing the tenant ID, application (or client) ID and the client secret:

```powershell
$params = @{
    TenantId     = "6cdd8179-23e5-43d1-8517-b6276a8d3189"
    ClientId     = "60912c81-37e8-4c94-8cd6-b8b90a475c0e"
    ClientSecret = "<secret>"
}
Connect-MSIntuneGraph @params
```

## Create an Application Package

`New-Win32Package.ps1` is used to read the application package manifest, create the Intune Win32 package and call `Create-Win32App.ps1` to import the package into the target Intune tenant.

Here's an example with importing Adobe Acrobat Reader DC and Citrix Workspace app into your Intune tenant by passing an array of package names to the `-Application` parameter:

```powershell
Set-Location -Path "E:\projects\packagefactory"
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
