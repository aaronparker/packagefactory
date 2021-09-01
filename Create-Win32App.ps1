<#
.SYNOPSIS
    Create a Win32 app in Microsoft Intune based on input from app manifest file.

.DESCRIPTION
    Create a Win32 app in Microsoft Intune based on input from app manifest file.

.PARAMETER Validate
    Specify to validate manifest file configuration.

.EXAMPLE
    .\Create-Win32App.ps1

.NOTES
    FileName:    Create-Win32App.ps1
    Author:      Nickolaj Andersen
    Contact:     @NickolajA
    Created:     2020-09-26
    Updated:     2020-09-26

    Version history:
    1.0.0 - (2020-09-26) Script created
#>
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [parameter(Mandatory = $false, HelpMessage = "Specify to validate manifest file configuration.")]
    [ValidateNotNullOrEmpty()]
    [switch]$Validate
)
Process {
    # Read app data from JSON manifest
    $AppDataFile = Join-Path -Path $PSScriptRoot -ChildPath "App.json"
    $AppData = Get-Content -Path $AppDataFile | ConvertFrom-Json

    # Required packaging variables
    $SourceFolder = Join-Path -Path $PSScriptRoot -ChildPath $AppData.PackageInformation.SourceFolder
    $OutputFolder = Join-Path -Path $PSScriptRoot -ChildPath $AppData.PackageInformation.OutputFolder
    $ScriptsFolder = Join-Path -Path $PSScriptRoot -ChildPath "Scripts"
    $AppIconFile = Join-Path -Path $PSScriptRoot -ChildPath $AppData.PackageInformation.IconFile

    if (-not($PSBoundParameters["Validate"])) {
        # Connect and retrieve authentication token
        Connect-MSIntuneGraph -TenantName $AppData.TenantInformation.Name -PromptBehavior $AppData.TenantInformation.PromptBehavior -ApplicationID $AppData.TenantInformation.ApplicationID -Verbose
    }

    # Create required .intunewin package from source folder
    $IntuneAppPackage = New-IntuneWin32AppPackage -SourceFolder $SourceFolder -SetupFile $AppData.PackageInformation.SetupFile -OutputFolder $OutputFolder -Verbose

    # Create default requirement rule
    $RequirementRule = New-IntuneWin32AppRequirementRule -Architecture $AppData.RequirementRule.Architecture -MinimumSupportedOperatingSystem $AppData.RequirementRule.MinimumRequiredOperatingSystem

    # Create additional custom requirement rules
    $CustomRequirementRuleCount = ($AppData.CustomRequirementRule | Measure-Object).Count
    if ($CustomRequirementRuleCount -ge 1) {
        $RequirementRules = New-Object -TypeName "System.Collections.ArrayList"
        foreach ($RequirementRuleItem in $AppData.CustomRequirementRule) {
            switch ($RequirementRuleItem.Type) {
                "File" {
                    switch ($RequirementRuleItem.DetectionMethod) {
                        "Existence" {
                            # Create a custom file based requirement rule
                            $RequirementRuleArgs = @{
                                "Existence" = $true
                                "Path" = $RequirementRuleItem.Path
                                "FileOrFolder" = $RequirementRuleItem.FileOrFolder
                                "DetectionType" = $RequirementRuleItem.DetectionType
                                "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                            }
                        }
                        "DateModified" {
                            # Create a custom file based requirement rule
                            $RequirementRuleArgs = @{
                                "DateModified" = $true
                                "Path" = $RequirementRuleItem.Path
                                "FileOrFolder" = $RequirementRuleItem.FileOrFolder
                                "Operator" = $RequirementRuleItem.Operator
                                "DateTimeValue" = $RequirementRuleItem.DateTimeValue
                                "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                            }
                        }
                        "DateCreated" {
                            # Create a custom file based requirement rule
                            $RequirementRuleArgs = @{
                                "DateCreated" = $true
                                "Path" = $RequirementRuleItem.Path
                                "FileOrFolder" = $RequirementRuleItem.FileOrFolder
                                "Operator" = $RequirementRuleItem.Operator
                                "DateTimeValue" = $RequirementRuleItem.DateTimeValue
                                "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                            }
                        }
                        "Version" {
                            # Create a custom file based requirement rule
                            $RequirementRuleArgs = @{
                                "Version" = $true
                                "Path" = $RequirementRuleItem.Path
                                "FileOrFolder" = $RequirementRuleItem.FileOrFolder
                                "Operator" = $RequirementRuleItem.Operator
                                "VersionValue" = $RequirementRuleItem.VersionValue
                                "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                            }
                        }
                        "Size" {
                            # Create a custom file based requirement rule
                            $RequirementRuleArgs = @{
                                "Size" = $true
                                "Path" = $RequirementRuleItem.Path
                                "FileOrFolder" = $RequirementRuleItem.FileOrFolder
                                "Operator" = $RequirementRuleItem.Operator
                                "SizeInMBValue" = $RequirementRuleItem.SizeInMBValue
                                "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                            }
                        }
                    }

                    # Create file based requirement rule
                    $CustomRequirementRule = New-IntuneWin32AppRequirementRuleFile @RequirementRuleArgs
                }
                "Registry" {
                    switch ($RequirementRuleItem.DetectionMethod) {
                        "Existence" {
                            # Create a custom registry based requirement rule
                            $RequirementRuleArgs = @{
                                "Existence" = $true
                                "KeyPath" = $RequirementRuleItem.KeyPath
                                "ValueName" = $RequirementRuleItem.ValueName
                                "DetectionType" = $RequirementRuleItem.DetectionType
                                "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                            }
                        }
                        "StringComparison" {
                            # Create a custom registry based requirement rule
                            $RequirementRuleArgs = @{
                                "StringComparison" = $true
                                "KeyPath" = $RequirementRuleItem.KeyPath
                                "ValueName" = $RequirementRuleItem.ValueName
                                "StringComparisonOperator" = $RequirementRuleItem.Operator
                                "StringComparisonValue" = $RequirementRuleItem.Value
                                "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                            }
                        }
                        "VersionComparison" {
                            # Create a custom registry based requirement rule
                            $RequirementRuleArgs = @{
                                "VersionComparison" = $true
                                "KeyPath" = $RequirementRuleItem.KeyPath
                                "ValueName" = $RequirementRuleItem.ValueName
                                "VersionComparisonOperator" = $RequirementRuleItem.Operator
                                "VersionComparisonValue" = $RequirementRuleItem.Value
                                "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                            }
                        }
                        "IntegerComparison" {
                            # Create a custom registry based requirement rule
                            $RequirementRuleArgs = @{
                                "IntegerComparison" = $true
                                "KeyPath" = $RequirementRuleItem.KeyPath
                                "ValueName" = $RequirementRuleItem.ValueName
                                "IntegerComparisonOperator" = $RequirementRuleItem.Operator
                                "IntegerComparisonValue" = $RequirementRuleItem.Value
                                "Check32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.Check32BitOn64System)
                            }
                        }
                    }

                    # Create registry based requirement rule
                    $CustomRequirementRule = New-IntuneWin32AppRequirementRuleRegistry @RequirementRuleArgs
                }
                "Script" {
                    switch ($RequirementRuleItem.DetectionMethod) {
                        "StringOutput" {
                            # Create a custom script based requirement rule
                            $RequirementRuleArgs = @{
                                "StringOutputDataType" = $true
                                "ScriptFile" = (Join-Path -Path $ScriptsFolder -ChildPath $RequirementRuleItem.ScriptFile)
                                "ScriptContext" = $RequirementRuleItem.ScriptContext
                                "StringComparisonOperator" = $RequirementRuleItem.Operator
                                "StringValue" = $RequirementRuleItem.Value
                                "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                            }
                        }
                        "IntegerOutput" {
                            # Create a custom script based requirement rule
                            $RequirementRuleArgs = @{
                                "IntegerOutputDataType" = $true
                                "ScriptFile" = $RequirementRuleItem.ScriptFile
                                "ScriptContext" = $RequirementRuleItem.ScriptContext
                                "IntegerComparisonOperator" = $RequirementRuleItem.Operator
                                "IntegerValue" = $RequirementRuleItem.Value
                                "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                            }
                        }
                        "BooleanOutput" {
                            # Create a custom script based requirement rule
                            $RequirementRuleArgs = @{
                                "BooleanOutputDataType" = $true
                                "ScriptFile" = $RequirementRuleItem.ScriptFile
                                "ScriptContext" = $RequirementRuleItem.ScriptContext
                                "BooleanComparisonOperator" = $RequirementRuleItem.Operator
                                "BooleanValue" = $RequirementRuleItem.Value
                                "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                            }
                        }
                        "DateTimeOutput" {
                            # Create a custom script based requirement rule
                            $RequirementRuleArgs = @{
                                "DateTimeOutputDataType" = $true
                                "ScriptFile" = $RequirementRuleItem.ScriptFile
                                "ScriptContext" = $RequirementRuleItem.ScriptContext
                                "DateTimeComparisonOperator" = $RequirementRuleItem.Operator
                                "DateTimeValue" = $RequirementRuleItem.Value
                                "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                            }
                        }
                        "FloatOutput" {
                            # Create a custom script based requirement rule
                            $RequirementRuleArgs = @{
                                "FloatOutputDataType" = $true
                                "ScriptFile" = $RequirementRuleItem.ScriptFile
                                "ScriptContext" = $RequirementRuleItem.ScriptContext
                                "FloatComparisonOperator" = $RequirementRuleItem.Operator
                                "FloatValue" = $RequirementRuleItem.Value
                                "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                            }
                        }
                        "VersionOutput" {
                            # Create a custom script based requirement rule
                            $RequirementRuleArgs = @{
                                "VersionOutputDataType" = $true
                                "ScriptFile" = $RequirementRuleItem.ScriptFile
                                "ScriptContext" = $RequirementRuleItem.ScriptContext
                                "VersionComparisonOperator" = $RequirementRuleItem.Operator
                                "VersionValue" = $RequirementRuleItem.Value
                                "RunAs32BitOn64System" = [System.Convert]::ToBoolean($RequirementRuleItem.RunAs32BitOn64System)
                                "EnforceSignatureCheck" = [System.Convert]::ToBoolean($RequirementRuleItem.EnforceSignatureCheck)
                            }
                            
                        }
                    }

                    # Create script based requirement rule
                    $CustomRequirementRule = New-IntuneWin32AppRequirementRuleScript @RequirementRuleArgs
                }
            }

            # Add requirement rule to list
            $RequirementRules.Add($CustomRequirementRule) | Out-Null
        }
    }

    # Create an array for multiple detection rules if required
    if ($AppData.DetectionRule.Count -gt 1) {
        if ("Script" -in $AppData.DetectionRule.Type) {
            # When a Script detection rule is used, other detection rules cannot be used as well. This should be handled within the module itself by the Add-IntuneWin32App function
        }
    }

    # Create detection rules
    $DetectionRules = New-Object -TypeName "System.Collections.ArrayList"
    foreach ($DetectionRuleItem in $AppData.DetectionRule) {
        switch ($DetectionRuleItem.Type) {
            "MSI" {
                # Create a MSI installation based detection rule
                $DetectionRuleArgs = @{
                    "ProductCode" = $DetectionRuleItem.ProductCode
                    "ProductVersionOperator" = $DetectionRuleItem.ProductVersionOperator
                }
                if (-not([string]::IsNullOrEmpty($DetectionRuleItem.ProductVersion))) {
                    $DetectionRuleArgs.Add("ProductVersion", $DetectionRuleItem.ProductVersion)
                }

                # Create MSI based detection rule
                $DetectionRule = New-IntuneWin32AppDetectionRuleMSI @DetectionRuleArgs
            }
            "Script" {
                # Create a PowerShell script based detection rule
                $DetectionRuleArgs = @{
                    "ScriptFile" = (Join-Path -Path $ScriptsFolder -ChildPath $DetectionRuleItem.ScriptFile)
                    "EnforceSignatureCheck" = [System.Convert]::ToBoolean($DetectionRuleItem.EnforceSignatureCheck)
                    "RunAs32Bit" = [System.Convert]::ToBoolean($DetectionRuleItem.RunAs32Bit)
                }

                # Create script based detection rule
                $DetectionRule = New-IntuneWin32AppDetectionRuleScript @DetectionRuleArgs
            }
            "Registry" {
                switch ($DetectionRuleItem.DetectionMethod) {
                    "Existence" {
                        # Construct registry existence detection rule parameters
                        $DetectionRuleArgs = @{
                            "Existence" = $true
                            "KeyPath" = $DetectionRuleItem.KeyPath
                            "DetectionType" = $DetectionRuleItem.DetectionType
                            "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                        }
                        if (-not([string]::IsNullOrEmpty($DetectionRuleItem.ValueName))) {
                            $DetectionRuleArgs.Add("ValueName", $DetectionRuleItem.ValueName)
                        }
                    }
                    "VersionComparison" {
                        # Construct registry version comparison detection rule parameters
                        $DetectionRuleArgs = @{
                            "VersionComparison" = $true
                            "KeyPath" = $DetectionRuleItem.KeyPath
                            "ValueName" = $DetectionRuleItem.ValueName
                            "VersionComparisonOperator" = $DetectionRuleItem.Operator
                            "VersionComparisonValue" = $DetectionRuleItem.Value
                            "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                        }
                    }
                    "StringComparison" {
                        # Construct registry string comparison detection rule parameters
                        $DetectionRuleArgs = @{
                            "StringComparison" = $true
                            "KeyPath" = $DetectionRuleItem.KeyPath
                            "ValueName" = $DetectionRuleItem.ValueName
                            "StringComparisonOperator" = $DetectionRuleItem.Operator
                            "StringComparisonValue" = $DetectionRuleItem.Value
                            "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                        }
                    }
                    "IntegerComparison" {
                        # Construct registry integer comparison detection rule parameters
                        $DetectionRuleArgs = @{
                            "IntegerComparison" = $true
                            "KeyPath" = $DetectionRuleItem.KeyPath
                            "ValueName" = $DetectionRuleItem.ValueName
                            "IntegerComparisonOperator" = $DetectionRuleItem.Operator
                            "IntegerComparisonValue" = $DetectionRuleItem.Value
                            "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                        }
                    }
                }

                # Create registry based detection rule
                $DetectionRule = New-IntuneWin32AppDetectionRuleRegistry @DetectionRuleArgs
            }
            "File" {
                switch ($DetectionRuleItem.DetectionMethod) {
                    "Existence" {
                        # Create a custom file based requirement rule
                        $DetectionRuleArgs = @{
                            "Existence" = $true
                            "Path" = $DetectionRuleItem.Path
                            "FileOrFolder" = $DetectionRuleItem.FileOrFolder
                            "DetectionType" = $DetectionRuleItem.DetectionType
                            "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                        }
                    }
                    "DateModified" {
                        # Create a custom file based requirement rule
                        $DetectionRuleArgs = @{
                            "DateModified" = $true
                            "Path" = $DetectionRuleItem.Path
                            "FileOrFolder" = $DetectionRuleItem.FileOrFolder
                            "Operator" = $DetectionRuleItem.Operator
                            "DateTimeValue" = $DetectionRuleItem.DateTimeValue
                            "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                        }
                    }
                    "DateCreated" {
                        # Create a custom file based requirement rule
                        $DetectionRuleArgs = @{
                            "DateCreated" = $true
                            "Path" = $DetectionRuleItem.Path
                            "FileOrFolder" = $DetectionRuleItem.FileOrFolder
                            "Operator" = $DetectionRuleItem.Operator
                            "DateTimeValue" = $DetectionRuleItem.DateTimeValue
                            "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                        }
                    }
                    "Version" {
                        # Create a custom file based requirement rule
                        $DetectionRuleArgs = @{
                            "Version" = $true
                            "Path" = $DetectionRuleItem.Path
                            "FileOrFolder" = $DetectionRuleItem.FileOrFolder
                            "Operator" = $DetectionRuleItem.Operator
                            "VersionValue" = $DetectionRuleItem.VersionValue
                            "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                        }
                    }
                    "Size" {
                        # Create a custom file based requirement rule
                        $DetectionRuleArgs = @{
                            "Size" = $true
                            "Path" = $DetectionRuleItem.Path
                            "FileOrFolder" = $DetectionRuleItem.FileOrFolder
                            "Operator" = $DetectionRuleItem.Operator
                            "SizeInMBValue" = $DetectionRuleItem.SizeInMBValue
                            "Check32BitOn64System" = [System.Convert]::ToBoolean($DetectionRuleItem.Check32BitOn64System)
                        }
                    }
                }

                # Create file based detection rule
                $DetectionRule = New-IntuneWin32AppDetectionRuleFile @DetectionRuleArgs
            }
        }

        # Add detection rule to list
        $DetectionRules.Add($DetectionRule) | Out-Null
    }

    # Add icon
    if (Test-Path -Path $AppIconFile) {
        $Icon = New-IntuneWin32AppIcon -FilePath $AppIconFile
    }

    # Construct a table of default parameters for Win32 app
    $Win32AppArgs = @{
        "FilePath" = $IntuneAppPackage.Path
        "DisplayName" = $AppData.Information.DisplayName
        "Description" = $AppData.Information.Description
        "Publisher" = $AppData.Information.Publisher
        "InstallExperience" = $AppData.Program.InstallExperience
        "RestartBehavior" = $AppData.Program.DeviceRestartBehavior
        "DetectionRule" = $DetectionRules
        "RequirementRule" = $RequirementRule
        "Verbose" = $true
    }

    # Dynamically add additional parameters for Win32 app
    if ($RequirementRules -ne $null) {
        $Win32AppArgs.Add("AdditionalRequirementRule", $RequirementRules)
    }
    if (Test-Path -Path $AppIconFile) {
        $Win32AppArgs.Add("Icon", $Icon)
    }
    if (-not([string]::IsNullOrEmpty($AppData.Information.Notes))) {
        $Win32AppArgs.Add("Notes", $AppData.Information.Notes)
    }
    if (-not([string]::IsNullOrEmpty($AppData.Program.InstallCommand))) {
        $Win32AppArgs.Add("InstallCommandLine", $AppData.Program.InstallCommand)
    }
    if (-not([string]::IsNullOrEmpty($AppData.Program.UninstallCommand))) {
        $Win32AppArgs.Add("UninstallCommandLine", $AppData.Program.UninstallCommand)
    }

    if ($PSBoundParameters["Validate"]) {
        if (-not([string]::IsNullOrEmpty($Win32AppArgs["Icon"]))) {
            # Redact icon Base64 code for better visibility in validate context
            $Win32AppArgs["Icon"] = $Win32AppArgs["Icon"].SubString(0,20) + "... //redacted for validation context//"
        }

        # Output manifest configuration
        $Win32AppArgs | ConvertTo-Json
    }
    else {
        # Create Win32 app
        Add-IntuneWin32App @Win32AppArgs
    }
}