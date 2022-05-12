[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
param ()

try {
    $ApplicationList = Get-Content -Path ".\Applications.json" | ConvertFrom-Json
}
catch {
    throw $_.Exception.Message
}

# Walk through the list of applications
foreach ($Application in $ApplicationList.Applications) {
    Invoke-Expression -Command $Application.Filter
}
