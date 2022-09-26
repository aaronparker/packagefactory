# Run in a Pipeline

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
