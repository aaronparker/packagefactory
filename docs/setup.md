# Set Up the Packaging Factory

Running the packaging factory locally requires Windows because the [Microsoft Win32 Content Prep Tool](https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-prepare) runs on Windows only.

## Install the required PowerShell modules

Install the required PowerShell modules. **IntuneWin32** (which depends on **MSAL.PS**), **Evergreen** and **VcRedist** are required modules.

```powershell
Install-Module -Name IntuneWin32, Evergreen, VcRedist, MSAL.PS
```

It is always worth ensuring you are running the latest version of each module:

```powershell
Update-Module -Name IntuneWin32, Evergreen, VcRedist, MSAL.PS
```

## Download the Packaging Factory

Clone the packaging factory - you can download the zip file containing the entire repository; however, to ensure your locally copy can be updated from the repository, it will be easier to clone the repository via [git](https://git-scm.com/).

```powershell
New-Item -Path "C:\projects" -ItemType "Directory"
Set-Location -Path "C:\projects"
git clone https://github.com/aaronparker/packagefactory.git
```

Git can be easily install with winget:

```cmd
winget install Git.Git
```
