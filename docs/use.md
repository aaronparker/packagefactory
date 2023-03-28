# Run Locally

## Authentication

When running the packaging factory locally on Windows to create application packages and import into an Intune tenant, you must first authenticate to the tenant. The user account used to authenticate must be an [Intune Administrator](https://learn.microsoft.com/en-us/azure/active-directory/roles/permissions-reference#intune-administrator) or an [Intune Application manager](https://learn.microsoft.com/en-us/microsoft-365/business-premium/m365bp-intune-admin-roles-in-the-mac).

Authentication to a tenant can be performed with `Connect-MSIntuneGraph`:

```powershell
Connect-MSIntuneGraph -TenantId stealthpuppylab.onmicrosoft.com
```

## Create an Application Package

`Create-Win32App.ps1` can be run to create a target application package; however, we need to read `App.json` to find the application installer, and download it to the package Source folder.

This process is simplified with `New-LocalWin32App.ps1` - this script will perform the steps above and call `Create-Win32App.ps1`. Here's and example with importing Adobe Acrobat Reader DC and Citrix Workspace app into your Intune tenant:

```powershell
Set-Location -Path "E:\projects\packagefactory"
$params = @{
    Path         = "E:\projects\packagefactory"
    Applications = "AdobeAcrobatReaderDCMUI", "CitrixWorkspaceApp"
    Type         = "Apps"
}
.\scripts\New-LocalWin32App.ps1 @params
```
