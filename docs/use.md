# Using PSPackageFactory

## Run Locally

Authentication to a tenant can be performed manually via `Connect-MSIntuneGraph`, after which `Create-Win32App.ps1` can be run to create a target application package.

```powershell
Connect-MSIntuneGraph -TenantId stealthpuppylab.onmicrosoft.com

$Application = "AdobeAcrobatReaderDC"
$Manifest = Get-Content -Path "E:\projects\packagefactory\packages\$Application\App.json" | ConvertFrom-Json
Invoke-Expression -Command $Manifest.Application.Filter | Save-EvergreenApp -CustomPath "E:\projects\packagefactory\packages\$Application\Source"

$params = @{
    Application      = $Application
    Path             = "C:\projects\packagefactory\packages"
    DisplayNameSuffix = "(Package Factory)"
}
.\Create-Win32App.ps1 @params
```

This process is simplified with `New-LocalWin32App.ps1`. Here's how to clone the repository, install the required modules, and import Adobe Acrobat Reader DC and Citrix Workspace app into your Intune tenant:

```powershell
New-Item -Path "E:\projects" --ItemType "Directory"
Set-Location -Path "E:\projects"
git clone https://github.com/aaronparker/packagefactory.git

Install-Module -Name "IntuneWin32App", "Evergreen", "VcRedist"
Connect-MSIntuneGraph -TenantID stealthpuppylab.onmicrosoft.com

Set-Location -Path "E:\projects\packagefactory"
.\scripts\New-LocalWin32App.ps1 -Applications "AdobeAcrobatReaderDC", "CitrixWorkspaceApp"
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

$Manifest = Get-Content -Path "${{ github.workspace }}\packages\${{ github.event.inputs.configuration }}\App.json | ConvertFrom-Json
Invoke-Expression -Command $Manifest.Application.Filter | Save-EvergreenApp -CustomPath "${{ github.workspace }}\packages\${{ github.event.inputs.configuration }}\Source"

$params = @{
  Application = "${{ github.event.inputs.configuration }}"
  Path        = "${{ github.workspace }}\packages"
}
. "${{ github.workspace }}\scripts\Create-Win32App.ps1" @params
```
