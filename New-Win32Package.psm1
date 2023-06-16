<#
    Functions for use in New-Win32Package.ps1
#>

function Write-Msg ($Msg) {
    $Message = [HostInformationMessage]@{
        Message         = "[$(Get-Date -Format 'dd.MM.yyyy HH:mm:ss')]"
        ForegroundColor = "Black"
        BackgroundColor = "DarkCyan"
        NoNewline       = $true
    }
    $params = @{
        MessageData       = $Message
        InformationAction = "Continue"
        Tags              = "Microsoft365"
    }
    Write-Information @params
    $params = @{
        MessageData       = " $Msg"
        InformationAction = "Continue"
        Tags              = "Microsoft365"
    }
    Write-Information @params
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
