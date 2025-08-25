using namespace System.Management.Automation
<#
    Functions for use in New-Win32Package.ps1
#>

function Test-IntuneWin32App {
    <#
        Return true of false if there's a matching Win32 package in the Intune tenant
    #>
    param (
        [Parameter(Mandatory = $true)]
        [System.Object] $Manifest
    )

    Write-Information -MessageData "$($PSStyle.Foreground.Cyan)Retrieve existing Win32 applications in Intune"
    $ExistingApp = Get-IntuneWin32App | `
        Select-Object -Property * -ExcludeProperty "largeIcon" | `
        Where-Object { $_.notes -match "PSPackageFactory" } | `
        Where-Object { ($_.notes | ConvertFrom-Json -ErrorAction "SilentlyContinue").Guid -eq $Manifest.Information.PSPackageFactoryGuid } | `
        Sort-Object -Property @{ Expression = { [System.Version]$_.displayVersion }; Descending = $true } -ErrorAction "SilentlyContinue" | `
        Select-Object -First 1

    # Determine whether the new package should be imported
    if ($null -eq $ExistingApp) {
        Write-Information -MessageData "$($PSStyle.Foreground.Cyan)Import new application: '$($Manifest.Information.DisplayName)'"
        Write-Output -InputObject $true
    }
    elseif ([System.String]::IsNullOrEmpty($ExistingApp.displayVersion)) {
        Write-Information -MessageData "$($PSStyle.Foreground.Cyan)Found matching app but 'displayVersion' is null: '$($ExistingApp.displayName)'"
        Write-Output -InputObject $false
    }
    elseif ([version]$Manifest.PackageInformation.Version -le [version]$ExistingApp.displayVersion) {
        Write-Information -MessageData "$($PSStyle.Foreground.Cyan)Existing Intune app version is current: '$($ExistingApp.displayName)'"
        Write-Output -InputObject $false
    }
    elseif ([version]$Manifest.PackageInformation.Version -gt [version]$ExistingApp.displayVersion) {
        Write-Information -MessageData "$($PSStyle.Foreground.Cyan)Import application version: '$($Manifest.Information.DisplayName)'"
        Write-Output -InputObject $true
    }
    else {
        Write-Output -InputObject $false
    }
}

function Get-MsiProductCode {
    <#
        Modified Version of https://www.powershellgallery.com/packages/Get-MsiProductCode/1.0/Content/Get-MsiProductCode.ps1
        from Thomas J. Malkewitz @dotsp1
        mod. by @constey
    #>
    param (
        [Parameter(Mandatory = $true, ValueFromPipeLine = $true)]
        [ValidateScript({
                if ($_.EndsWith('.msi')) { $true } else { throw "$_ must be an '*.msi' file." }
                if (Test-Path $_) { $true } else { throw "$_ does not exist." }
            })]
        [System.String[]] $Path
    )

    process {
        foreach ($Item in $Path) {
            try {
                $WindowsInstaller = New-Object -ComObject "WindowsInstaller.Installer"
                $Database = $WindowsInstaller.GetType().InvokeMember('OpenDatabase', 'InvokeMethod', $null, $WindowsInstaller, @((Get-Item -Path $Item).FullName, 0))
                $View = $Database.GetType().InvokeMember('OpenView', 'InvokeMethod', $null, $Database, ("SELECT Value FROM Property WHERE Property = 'ProductCode'"))
                $View.GetType().InvokeMember('Execute', 'InvokeMethod', $null, $View, $null)
                $Record = $View.GetType().InvokeMember('Fetch', 'InvokeMethod', $null, $View, $null)
                Write-Output -InputObject $($record.GetType().InvokeMember('StringData', 'GetProperty', $null, $Record, 1))
            }
            catch {
                Write-Error -Message $_.Exception.Message
                break
            }
            finally {
                $view.GetType().InvokeMember('Close', 'InvokeMethod', $null, $view, $null)
                [Void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($WindowsInstaller)
            }
        }
    }
}

function Set-ScriptSignature {
    <#
        Use Set-AuthenticodeSignature to sign all scripts in a defined path
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = "Certificate")]
        [Parameter(Mandatory = $true, ParameterSetName = "Subject")]
        [Parameter(Mandatory = $true, ParameterSetName = "Thumbprint")]
        [ValidateScript({ if (Test-Path -Path $_) { $true } else { throw [System.IO.DirectoryNotFoundException]::New("Directory not found: $_") } })]
        [System.String[]] $Path,

        [Parameter(Mandatory = $true, ParameterSetName = "Certificate")]
        [System.Security.Cryptography.X509Certificates.X509Certificate2] $Certificate,

        [Parameter(Mandatory = $true, ParameterSetName = "Subject")]
        [System.String] $CertificateSubject,

        [Parameter(Mandatory = $true, ParameterSetName = "Thumbprint")]
        [System.String] $CertificateThumbprint,

        [Parameter(Mandatory = $false, ParameterSetName = "Certificate")]
        [Parameter(Mandatory = $false, ParameterSetName = "Subject")]
        [Parameter(Mandatory = $false, ParameterSetName = "Thumbprint")]
        [System.String] $TimestampServer,

        [Parameter(Mandatory = $false, ParameterSetName = "Certificate")]
        [Parameter(Mandatory = $false, ParameterSetName = "Subject")]
        [Parameter(Mandatory = $false, ParameterSetName = "Thumbprint")]
        [System.String] $IncludeChain = "NotRoot"
    )

    begin {
        $CertPaths = @("Cert:\CurrentUser\My", "Cert:\CurrentUser\Root", "Cert:\CurrentUser\TrustedPublisher",
            "Cert:\LocalMachine\My", "Cert:\LocalMachine\Root", "Cert:\LocalMachine\TrustedPublisher")

        if ($PSBoundParameters.ContainsKey("CertificateSubject")) {
            $Certificate = Get-ChildItem -Path $CertPaths -CodeSigningCert | Where-Object { $_.Subject -eq $CertificateSubject }
            if ($null -eq $Certificate) { throw [Microsoft.PowerShell.Commands.CertificateNotFoundException]::New("Certificate matching subject name '$CertificateSubject' not found.") }
        }
        elseif ($PSBoundParameters.ContainsKey("CertificateThumbprint")) {
            $Certificate = Get-ChildItem -Path $CertPaths -CodeSigningCert | Where-Object { $_.Subject -eq $CertificateThumbprint }
            if ($null -eq $Certificate) { throw [Microsoft.PowerShell.Commands.CertificateNotFoundException]::New("Certificate matching thumbprint '$CertificateThumbprint' not found.") }
        }
    }

    process {
        foreach ($Directory in $Path) {
            Get-ChildItem -Path $Directory -Recurse -Include "*.ps1", "*.psm1", "*.psd1" | ForEach-Object {
                try {
                    $params = @{
                        FilePath      = $_.FullName
                        Certificate   = $Certificate
                        HashAlgorithm = "SHA256"
                        IncludeChain  = $IncludeChain
                        ErrorAction   = "Stop"
                    }
                    if ($PSBoundParameters.ContainsKey("TimestampServer")) {
                        $params.TimestampServer = $TimestampServer
                    }
                    if ($PSCmdlet.ShouldProcess("Set-AuthenticodeSignature", $_.FullName)) {
                        Set-AuthenticodeSignature @params
                    }
                }
                catch {
                    Write-Error -Message "Failed to sign script '$($_.FullName)', with '$($_.Exception.Message)'"
                }
            }
        }
    }
}
