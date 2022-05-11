#Requires -Modules Evergreen, VcRedist
<#
    Test the App.json for packages
#>
[CmdletBinding()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingWriteHost", "")]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute("PSAvoidUsingInvokeExpression", "")]
param (
    [Parameter()]
    [System.String] $Path = "~/projects/packagefactory/packages",

    [Parameter()]
    [System.String] $Manifest = "Applications.json",

    [Parameter()]
    [System.String] $AppManifest = "App.json"
)

try {
    # Read the list of applications; we're assuming that $Manifest exists
    Write-Host -ForegroundColor "Cyan" "Read: $Manifest."
    $ApplicationList = Get-Content -Path $Manifest | ConvertFrom-Json
}
catch {
    throw $_.Exception.Message
}

# Walk through the list of applications
foreach ($Application in $ApplicationList) {

    # Determine the application download and version number via Evergreen
    #$Properties = $ApplicationList.Applications.($Application.Name)
    Write-Host -ForegroundColor "Cyan" "Application: $($Application.Title)"
    Write-Host -ForegroundColor "Cyan" "Running: $($Application.Filter)."
    if ($Application.Filter -match "Get-VcList") {
        $App = Invoke-Expression -Command $Filter
        $Filename = $(Split-Path -Path $App.Download -Leaf)
        Write-Host "Package: $($App.Name); $Filename."
        New-Item -Path $([System.IO.Path]::Combine($Path, $Application.Name, "Source")) -ItemType "Directory" -Force | Out-Null
        Invoke-WebRequest -Uri $App.Download -OutFile $([System.IO.Path]::Combine($Path, $Application.Name, "Source", $Filename)) -UseBasicParsing
    }
    else {
        $AppUpdate = Invoke-Expression -Command $Application.Filter
        $AppUpdate | Save-EvergreenApp -CustomPath $([System.IO.Path]::Combine($Path, $Application.Name, "Source"))
    }

    # Get the application package manifest and update it
    $AppConfiguration = $([System.IO.Path]::Combine($Path, $Application.Name, $AppManifest))
    if (Test-Path -Path $AppConfiguration) {
        Write-Host -ForegroundColor "Cyan" "Read: $AppConfiguration."
        $AppData = Get-Content -Path $AppConfiguration | ConvertFrom-Json
    }
    else {
        Write-Warning -Message "Cannot find: $AppConfiguration."
    }

    # Install the application
    Write-Host -ForegroundColor "Cyan" "Install application."
    Push-Location -Path $([System.IO.Path]::Combine($Path, $Application.Name, "Source"))
    Invoke-Expression -Command $AppData.Program.InstallCommand
    Pop-Location

    # Step through each DetectionRule to update version properties
    # foreach ($DetectionRuleItem in $AppData.DetectionRule) {
    #     switch ($DetectionRuleItem.Type) {
    #         "MSI" {
    #             # Create a MSI installation based detection rule
    #             $DetectionRuleArgs = @{
    #                 "ProductCode"            = $DetectionRuleItem.ProductCode
    #                 "ProductVersionOperator" = $DetectionRuleItem.ProductVersionOperator
    #             }
    #             if (-not([System.String]::IsNullOrEmpty($DetectionRuleItem.ProductVersion))) {
    #                 $DetectionRuleArgs.Add("ProductVersion", $DetectionRuleItem.ProductVersion)
    #             }
    #         }
    #         "Script" {
    #             # Create a PowerShell script based detection rule
    #             $DetectionRuleArgs = @{
    #                 "ScriptFile"            = (Join-Path -Path $ScriptsFolder -ChildPath $DetectionRuleItem.ScriptFile)
    #                 "EnforceSignatureCheck" = [System.Convert]::ToBoolean($DetectionRuleItem.EnforceSignatureCheck)
    #                 "RunAs32Bit"            = [System.Convert]::ToBoolean($DetectionRuleItem.RunAs32Bit)
    #             }
    #         }
    #         "Registry" {
    #             switch ($DetectionRuleItem.DetectionMethod) {
    #                 "Existence" {
    #                     # Construct registry existence detection rule parameters
    #                     $DetectionRuleArgs = @{
    #                         "Existence"            = $true
    #                         "KeyPath"              = $DetectionRuleItem.KeyPath
    #                         "DetectionType"        = $DetectionRuleItem.DetectionType
    #                         "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
    #                     }
    #                     if (-not([System.String]::IsNullOrEmpty($DetectionRuleItem.ValueName))) {
    #                         $DetectionRuleArgs.Add("ValueName", $DetectionRuleItem.ValueName)
    #                     }
    #                 }
    #                 "VersionComparison" {
    #                     # Construct registry version comparison detection rule parameters
    #                     $DetectionRuleArgs = @{
    #                         "VersionComparison"         = $true
    #                         "KeyPath"                   = $DetectionRuleItem.KeyPath
    #                         "ValueName"                 = $DetectionRuleItem.ValueName
    #                         "VersionComparisonOperator" = $DetectionRuleItem.Operator
    #                         "VersionComparisonValue"    = $DetectionRuleItem.Value
    #                         "Check32BitOn64System"      = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
    #                     }
    #                 }
    #                 "StringComparison" {
    #                     # Construct registry string comparison detection rule parameters
    #                     $DetectionRuleArgs = @{
    #                         "StringComparison"         = $true
    #                         "KeyPath"                  = $DetectionRuleItem.KeyPath
    #                         "ValueName"                = $DetectionRuleItem.ValueName
    #                         "StringComparisonOperator" = $DetectionRuleItem.Operator
    #                         "StringComparisonValue"    = $DetectionRuleItem.Value
    #                         "Check32BitOn64System"     = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
    #                     }
    #                 }
    #                 "IntegerComparison" {
    #                     # Construct registry integer comparison detection rule parameters
    #                     $DetectionRuleArgs = @{
    #                         "IntegerComparison"         = $true
    #                         "KeyPath"                   = $DetectionRuleItem.KeyPath
    #                         "ValueName"                 = $DetectionRuleItem.ValueName
    #                         "IntegerComparisonOperator" = $DetectionRuleItem.Operator
    #                         "IntegerComparisonValue"    = $DetectionRuleItem.Value
    #                         "Check32BitOn64System"      = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
    #                     }
    #                 }
    #             }
    #         }
    #         "File" {
    #             switch ($DetectionRuleItem.DetectionMethod) {
    #                 "Existence" {
    #                     # Create a custom file based requirement rule
    #                     $DetectionRuleArgs = @{
    #                         "Existence"            = $true
    #                         "Path"                 = $DetectionRuleItem.Path
    #                         "FileOrFolder"         = $DetectionRuleItem.FileOrFolder
    #                         "DetectionType"        = $DetectionRuleItem.DetectionType
    #                         "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
    #                     }
    #                 }
    #                 "DateModified" {
    #                     # Create a custom file based requirement rule
    #                     $DetectionRuleArgs = @{
    #                         "DateModified"         = $true
    #                         "Path"                 = $DetectionRuleItem.Path
    #                         "FileOrFolder"         = $DetectionRuleItem.FileOrFolder
    #                         "Operator"             = $DetectionRuleItem.Operator
    #                         "DateTimeValue"        = $DetectionRuleItem.DateTimeValue
    #                         "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
    #                     }
    #                 }
    #                 "DateCreated" {
    #                     # Create a custom file based requirement rule
    #                     $DetectionRuleArgs = @{
    #                         "DateCreated"          = $true
    #                         "Path"                 = $DetectionRuleItem.Path
    #                         "FileOrFolder"         = $DetectionRuleItem.FileOrFolder
    #                         "Operator"             = $DetectionRuleItem.Operator
    #                         "DateTimeValue"        = $DetectionRuleItem.DateTimeValue
    #                         "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
    #                     }
    #                 }
    #                 "Version" {
    #                     # Create a custom file based requirement rule
    #                     $DetectionRuleArgs = @{
    #                         "Version"              = $true
    #                         "Path"                 = $DetectionRuleItem.Path
    #                         "FileOrFolder"         = $DetectionRuleItem.FileOrFolder
    #                         "Operator"             = $DetectionRuleItem.Operator
    #                         "VersionValue"         = $DetectionRuleItem.VersionValue
    #                         "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
    #                     }
    #                 }
    #                 "Size" {
    #                     # Create a custom file based requirement rule
    #                     $DetectionRuleArgs = @{
    #                         "Size"                 = $true
    #                         "Path"                 = $DetectionRuleItem.Path
    #                         "FileOrFolder"         = $DetectionRuleItem.FileOrFolder
    #                         "Operator"             = $DetectionRuleItem.Operator
    #                         "SizeInMBValue"        = $DetectionRuleItem.SizeInMBValue
    #                         "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
    #                     }
    #                 }
    #             }
    #         }
    #     }
    # }

    # Uninstall the application
    Write-Host -ForegroundColor "Cyan" "Uninstall application."
    Push-Location -Path $([System.IO.Path]::Combine($Path, $Application.Name, "Source"))
    Invoke-Expression -Command $AppData.Program.UninstallCommand
    Pop-Location
}
