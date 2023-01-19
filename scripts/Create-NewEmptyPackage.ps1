<#
 # File: c:\dev\intunepacketfactory\scripts\Create-NewEmptyPackage.ps1
 # Project: c:\dev\intunepacketfactory\scripts
 # Created Date: Monday, January 2nd 2023, 10:39:50 am
 # Author: Constantin Lotz
 # -----
 # Description:
 # -----
 # Last Modified: Tue Jan 03 2023
 # Modified By: Constantin Lotz
 # -----
 # Copyright (c) 2023 Constey
 # 
 #  
 # -----
 # HISTORY:
 # Date      	By	Comments
 # ----------	---	----------------------------------------------------------
 # 2023-01-03	CL	error corrections in paths
 #>
 param(
    [Parameter(Mandatory = $true, HelpMessage = "Specify the application package name.")]
    [ValidateNotNullOrEmpty()]
    [System.String[]] $Application,

    [Parameter(Mandatory = $true, HelpMessage = "Specify the path to the packages folder.")]
    [ValidateNotNullOrEmpty()]
    [System.String] $PathOfInstallFile,

    [Parameter(Mandatory = $false, HelpMessage = "Specify the installer Type: EXE or MSI")]
    [ValidateNotNullOrEmpty()]
    [System.String] $InstallerType,

    [Parameter(Mandatory = $false, HelpMessage = "Specify the Version Number of the Application")]
    [ValidateNotNullOrEmpty()]
    [System.String] $ProductVersion,

    [Parameter(Mandatory = $false, HelpMessage = "Specify the root directory where Create-Win32App.ps1 resides.")]
    [ValidateNotNullOrEmpty()]
    [System.String] $packagefactoryPath = "C:\dev\intunepacketfactory\"
)


function Get-MsiProductCode {
    # Modified Version of https://www.powershellgallery.com/packages/Get-MsiProductCode/1.0/Content/Get-MsiProductCode.ps1
    # from Thomas J. Malkewitz @dotsp1
    # mod. by @constey
    Param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeLine = $true
        )]
        [ValidateScript({
            if ($_.EndsWith('.msi')) {
                $true
            } else {
                throw "$_ must be an '*.msi' file."
            }
            if (Test-Path $_) {
                $true
            } else {
                throw "$_ does not exist."
            }
        })]
        [String[]]
        $Path
    )
    
    Process {
        foreach ($item in $Path) {
            try {
                $windowsInstaller = New-Object -com WindowsInstaller.Installer
    
                $database = $windowsInstaller.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $windowsInstaller, @((Get-Item -Path $item).FullName, 0))
    
                $view = $database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $database, ("SELECT Value FROM Property WHERE Property = 'ProductCode'"))
                $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
    
                $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
    
                Write-Output -InputObject $($record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1))
    
                $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
                [Void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($windowsInstaller)
            } catch {
                Write-Error -Message $_.ToString()
                
                break
            }
        }
    }
}

function Get-MsiProductVersion {
    # Modified Version of https://www.powershellgallery.com/packages/Get-MsiProductCode/1.0/Content/Get-MsiProductCode.ps1
    # from Thomas J. Malkewitz @dotsp1
    # mod. by @constey
    Param (
        [Parameter(
            Mandatory = $true,
            ValueFromPipeLine = $true
        )]
        [ValidateScript({
            if ($_.EndsWith('.msi')) {
                $true
            } else {
                throw "$_ must be an '*.msi' file."
            }
            if (Test-Path $_) {
                $true
            } else {
                throw "$_ does not exist."
            }
        })]
        [String[]]
        $Path
    )
    
    Process {
        foreach ($item in $Path) {
            try {
                $windowsInstaller = New-Object -com WindowsInstaller.Installer
    
                $database = $windowsInstaller.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $windowsInstaller, @((Get-Item -Path $item).FullName, 0))
    
                $view = $database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $database, ("SELECT Value FROM Property WHERE Property = 'ProductVersion'"))
                $view.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $view, $null)
    
                $record = $view.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $view, $null)
    
                Write-Output -InputObject $($record.GetType().InvokeMember('StringData', 'GetProperty', $null, $record, 1))
    
                $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
                [Void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($windowsInstaller)
            } catch {
                Write-Error -Message $_.ToString()
                
                break
            }
        }
    }
}


# Search Create-Win32App.ps1
while ((Test-Path ([System.IO.Path]::Combine($packagefactoryPath, "Create-Win32App.ps1"))) -eq $false) {
    $packagefactoryPath = Read-Host -Prompt "Could not find Create-Win32App.ps1 location in: $([System.IO.Path]::Combine($packagefactoryPath, 'Create-Win32App.ps1')). Please specify. Example: C:\dev\intunepacketfactory\"
}
Write-Host "packagefactoryPath Path: $packagefactoryPath"

$RepositoryPath = [System.IO.Path]::Combine($packagefactoryPath, "packages\Apps")
while ((Test-Path $RepositoryPath) -eq $false) {
    $RepositoryPath = Read-Host -Prompt 'Could not find packages/Apps location. Please specify. Example: C:\dev\intunepacketfactory\packages\Apps'
}
Write-Host "Repository Path: $RepositoryPath"

# Detect Installertype based on the File specified
if ([string]::IsNullOrEmpty($InstallerType)) {
    if ($PathOfInstallFile.EndsWith('.msi')) {
        $InstallerType = "MSI"
    } elseif ($PathOfInstallFile.EndsWith('.exe')) { 
        $InstallerType = "EXE"
    } else {
        throw "$PathOfInstallFile cannot detect wich InstallerType we have. Specify with -InstallerType."
    }
}
Write-Host "PathOfInstallFile: $PathOfInstallFile"
Write-Host "InstallerType: $InstallerType"

# Detect ProductVersion based on the File specified
while ([string]::IsNullOrEmpty($ProductVersion)) {
    if ($PathOfInstallFile.EndsWith('.msi')) {
        $ProductVersion = Get-MsiProductVersion -Path $PathOfInstallFile
    } elseif ($PathOfInstallFile.EndsWith('.exe')) { 
        $ProductVersion = $((Get-Command $PathOfInstallFile).FileVersionInfo.ProductVersion)
    } else {
        throw "$PathOfInstallFile cannot detect wich InstallerType we have. Specify with -InstallerType."
    }

    if ([string]::IsNullOrEmpty($ProductVersion)) {
        $ProductVersion = Read-Host -Prompt 'Could not detect Version Number. Please enter it manually. Example: 22.2.207.0'
    }
}
Write-Host "ProductVersion: $ProductVersion"

$targetAppDirectory = [System.IO.Path]::Combine($RepositoryPath, $Application)
Write-Host "targetAppDirectory: $targetAppDirectory"
if (Test-Path $targetAppDirectory) {
    throw  "Target directory: $targetAppDirectory already exists."
    exit 1;
} else {
    try {
        # does copy-item
        #New-Item -itemtype directory -path $RepositoryPath -Name $Application
        if ($InstallerType -eq "MSI") {
            $templateLocation = [System.IO.Path]::Combine($packagefactoryPath, "template\NewEmptyPackage\MSI\")
            Write-Host "templateLocation: $templateLocation"
            Copy-Item $templateLocation $targetAppDirectory -Recurse
        } elseif ($InstallerType -eq "EXE") {
            $templateLocation = [System.IO.Path]::Combine($packagefactoryPath, "template\NewEmptyPackage\EXE\")
            Write-Host "templateLocation: $templateLocation"
            Copy-Item $templateLocation $targetAppDirectory -Recurse
        }

        # Copy Installer in Product dir
        $sourceFolder = [System.IO.Path]::Combine($targetAppDirectory, "Source\")
        Copy-Item $PathOfInstallFile $sourceFolder
        
    } catch {
        throw "$_ Error while creating new Application Directory $Application in $RepositoryPath -> $targetAppDirectory"
    }
}

Start-Sleep -Seconds 1
## Add Params:
try {
    $AppJsonFile        = Get-ChildItem -Path $targetAppDirectory -Recurse -Filter "App.json" 
    Write-Host "AppJsonFile: $AppJsonFile"
    $InstallJsonFile    = Get-ChildItem -Path $targetAppDirectory -Recurse -Filter "Install.json" 
    Write-Host "InstallJsonFile: $InstallJsonFile"
} catch {
    throw "Cannot find an .json File. App.json: $AppJsonFile ; Install.json: $InstallJsonFile"
}

# App.json
$Json = Get-Content -Path $($AppJsonFile.FullName) | ConvertFrom-Json
$Json.Information | Add-Member -MemberType "NoteProperty" -Name "PSPackageFactoryGuid" -Value $((New-Guid).Guid)
$Json.Application.Name              = "$Application"
$Json.Application.Title             = "$Application"
$Json.PackageInformation.SetupFile  = [System.IO.Path]::GetFileName($PathOfInstallFile)
$Json.PackageInformation.Version    = "$ProductVersion"
$Json.Information.DisplayName    = "$Application $ProductVersion"

if ($InstallerType -eq "MSI") {
    $msiProductCode = Get-MsiProductCode -Path $PathOfInstallFile
    $msiProductCode = [System.guid]::New($msiProductCode)
    $uninstallcommand = 'MsiExec.exe /X "{' + $msiProductCode.GUID + '}" /quiet'
    $Json.Program | Add-Member -MemberType "NoteProperty" -Name "UninstallCommand" -Value $uninstallcommand
    $Json.DetectionRule[0].ProductCode = '{' + $msiProductCode.GUID + '}' 
}
$Json | ConvertTo-Json | Out-File -FilePath $($AppJsonFile.FullName) -Encoding "Utf8"

# Install .json
$Json = Get-Content -Path $($InstallJsonFile.FullName) | ConvertFrom-Json

$Json.PackageInformation.SetupFile  = [System.IO.Path]::GetFileName($PathOfInstallFile)
$Json.PackageInformation.Version    = "$ProductVersion"
$Json | ConvertTo-Json | Out-File -FilePath $($InstallJsonFile.FullName) -Encoding "Utf8"

