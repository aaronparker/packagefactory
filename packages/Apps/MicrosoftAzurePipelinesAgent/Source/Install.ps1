#description: Installs the Microsoft Azure Pipelines agent to enable automated testing via Azure Pipelines. Do not run on production session hosts.
#execution mode: Combined
#tags: Evergreen, Testing, DevOps
#Requires -Modules Evergreen
[System.String] $Path = "$Env:SystemDrive\agents"

# Check that the required variables have been set in Nerdio Manager
foreach ($Value in "DevOpsUrl", "DevOpsPat", "DevOpsPool", "DevOpsUser", "DevOpsPassword") {
    if ($null -eq $SecureVars.$Value) { throw "$Value is $null" }
}

#region Script logic
New-Item -Path $Path -ItemType "Directory" -Force -ErrorAction "SilentlyContinue" | Out-Null

try {
    # Download
    Import-Module -Name "Evergreen" -Force
    $App = Get-EvergreenApp -Name "MicrosoftAzurePipelinesAgent" | `
        Where-Object { $_.Architecture -eq "x64" } | `
        Select-Object -First 1
    $OutFile = Save-EvergreenApp -InputObject $App -CustomPath $Env:Temp -WarningAction "SilentlyContinue"
}
catch {
    throw $_.Exception.Message
}

try {
    # Create the local account that the DevOps Pipelines agent service will run under
    $params = @{
        Name                     = $SecureVars.DevOpsUser
        Password                 = (ConvertTo-SecureString -String $SecureVars.DevOpsPassword -AsPlainText -Force)
        Description              = "Azure Pipelines agent service for elevated exec."
        UserMayNotChangePassword = $true
        Confirm                  = $false
    }
    New-LocalUser @params
    Add-LocalGroupMember -Group "Administrators" -Member $SecureVars.DevOpsUser
}
catch {
    throw $_
}

try {
    Expand-Archive -Path $OutFile.FullName -DestinationPath $Path -Force
    Push-Location -Path $Path

    # Agent install options
    $Options = "--unattended
        --url `"$($SecureVars.DevOpsUrl)`"
        --auth pat
        --token `"$($SecureVars.DevOpsPat)`"
        --pool `"$($SecureVars.DevOpsPool)`"
        --agent $Env:COMPUTERNAME
        --runAsService
        --windowsLogonAccount `"$($SecureVars.DevOpsUser)`"
        --windowsLogonPassword `"$($SecureVars.DevOpsPassword)`"
        --replace"
    $params = @{
        FilePath     = "$Path\config.cmd"
        ArgumentList = $($Options -replace "\s+", " ")
        Wait         = $true
        NoNewWindow  = $true
        PassThru     = $true
    }
    Start-Process @params
}
catch {
    throw $_
}
#endregion
