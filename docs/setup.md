# Set Up the Packaging Factory

Running the packaging factory locally requires a support version of Windows because the [Microsoft Win32 Content Prep Tool](https://learn.microsoft.com/en-us/mem/intune/apps/apps-win32-prepare) runs on Windows only. Additionally, the packaging factory has only been tested on Windows PowerShell. It may run on PowerShell 7; however, it is not actively tested on that version of PowerShell.

## Install the required PowerShell modules

Install the required PowerShell modules. **IntuneWin32** (which depends on **MSAL.PS**), **Evergreen** and **VcRedist** are required modules.

```powershell
Install-Module -Name IntuneWin32App, Evergreen, VcRedist, MSAL.PS
```

It is always worth ensuring you are running the latest version of each module:

```powershell
Update-Module -Name IntuneWin32App, Evergreen, VcRedist, MSAL.PS
Import-Module -Name IntuneWin32App, Evergreen, VcRedist, MSAL.PS -Force
```

## Download the Packaging Factory

Clone the packaging factory - you can download the zip file containing the entire repository; however, to ensure your local copy can be updated with changes to the source repository, it will be easier to clone the repository with git [git](https://git-scm.com/).

Git can be installed easily with winget:

```cmd
winget install Git.Git
```

With git installed, you can clone the repository into a target directory (e.g. `E:\projects\packagefactory`) with the following commands:

```powershell
New-Item -Path "E:\projects" -ItemType "Directory"
Set-Location -Path "E:\projects"
git clone https://github.com/aaronparker/packagefactory.git
```

## Keeping in sync with the Package Factory

After creating application packages with the package factory, you will have additional files downloaded including icons and installers in your cloned directory. To reset the package factory back to defaults and synchronise your copy with the source repository, you can reset your local changes and download new changes with:

```bash
git clean -f
git restore .
git pull
```

## GUI Tools

If you aren't comfortable with the command-line instructions above, there are GUI-based git tools available that can simplify cloning the repository and managing your local copy. We recommend using:

* [GitHub Desktop](https://desktop.github.com/); or
* [Fork](https://git-fork.com/)
