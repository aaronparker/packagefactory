#description: Uninstalls the Microsoft Azure Pipelines agent.
#execution mode: Combined
#tags: Evergreen, Testing, DevOps
#Requires -Modules Evergreen
[System.String] $Path = "$Env:SystemDrive\agents"

#region Script logic
try {
    Push-Location -Path $Path
    $params = @{
        FilePath     = "$Path\config.cmd"
        ArgumentList = "remove --unattended --auth pat --token `"$($SecureVars.DevOpsPat)`""
        Wait         = $true
        NoNewWindow  = $true
        PassThru     = $true
    }
    Start-Process @params
}
catch {
    throw $_
}

# Remove the C:\agents directory and the local user account used by the agent service
Remove-Item -Path $Path -Recurse -Force -ErrorAction "SilentlyContinue"
Remove-LocalUser -Name $SecureVars.DevOpsUser -Confirm:$false -ErrorAction "SilentlyContinue"
#endregion
