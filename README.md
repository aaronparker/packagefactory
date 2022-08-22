# Intune Package Factory

Using [Evergreen](https://stealthpuppy.com/evergreen), [VcRedist](https://vcredist.com/), [IntuneWin32App](https://github.com/MSEndpointMgr/IntuneWin32App) and [IntuneWin32AppPackager](https://github.com/MSEndpointMgr/IntuneWin32AppPackager) to create a packaging factory for Microsoft Intune.

----

This package factory enables maintaining a library of applications for automatic update, packaging and import into Microsoft Intune. `Create-Win32App.ps1` in this repository has been updated to use Evergreen to download the latest version of a target application before packaging and importing into Intune.

Additionally, Evergreen is used to keep the library of application definitions (`App.json`) up to date via a GitHub Workflow that runs once every 24 hours.

[![update-packagejson](https://github.com/aaronparker/packagefactory/actions/workflows/update-packagejson.yml/badge.svg)](https://github.com/aaronparker/packagefactory/actions/workflows/update-packagejson.yml)

## Run Locally

Authentication to a tenant can be performed manually via `Connect-MSIntuneGraph`, after which `Create-Win32App.ps1` can be run to create a target application package.

```powershell
Connect-MSIntuneGraph -TenantId stealthpuppylab.onmicrosoft.com

$Application = "AdobeAcrobatReaderDC"
$Json = Get-Content -Path ".\Applications.json" | ConvertFrom-Json
$Filter = ($Json | Where-Object { $_.Name -eq $Application }).Filter
Invoke-Expression -Command $Filter | Save-EvergreenApp -CustomPath ".\packages\$Application\Source"

$params = @{
    Application = $Application
    Path        = "C:\projects\packagefactory\packages"
    DisplayNameSuffix = "(Package Factory)"
}
.\Create-Win32App.ps1 @params
```

This process is simplified with `New-LocalPackage.ps1`. Here's how to clone the repository, install the required modules, and import Adobe Acrobat Reader DC and Citrix Workspace app into your Intune tenant:

```powershell
New-Item -Path "E:\projects" --ItemType "Directory"
Set-Location -Path "E:\projects"
git clone https://github.com/aaronparker/packagefactory.git

Install-Module -Name "IntuneWin32App", "Evergreen", "VcRedist"
Connect-MSIntuneGraph -TenantID stealthpuppylab.onmicrosoft.com

Set-Location -Path "E:\projects\packagefactory"
.\scripts\New-LocalPackage.ps1 -Applications "AdobeAcrobatReaderDC", "CitrixWorkspaceApp"
```

## Run in a Pipeline

Or used in a pipeline (e.g., via GitHub Workflows) to authenticate without user interaction and completely automate the full creation of application packages. See [./github/workflows/create-package.yml](./.github/workflows/create-package.yml)

```powershell
$params = @{
    TenantId     = "${{ secrets.TENANT_ID }}"
    ClientID     = "${{ secrets.CLIENT_ID }}"
    ClientSecret = "${{ secrets.CLIENT_SECRET }}"
}
$global:AuthToken = Connect-MSIntuneGraph @params

$Json = Get-Content -Path "${{ github.workspace }}\Applications.json" | ConvertFrom-Json
$Filter = ($Json | Where-Object { $_.Name -eq "${{ github.event.inputs.configuration }}" }).Filter
Invoke-Expression -Command $Filter | Save-EvergreenApp -CustomPath "${{ github.workspace }}\packages\${{ github.event.inputs.configuration }}\Source"

$params = @{
  Application = "${{ github.event.inputs.configuration }}"
  Path        = "${{ github.workspace }}\packages"
}
. "${{ github.workspace }}\scripts\Create-Win32App.ps1" @params
```

----

## Further Reading

Read more: [IntuneWin32AppPackager Framework Overview](INTUNEWIN32.md)
