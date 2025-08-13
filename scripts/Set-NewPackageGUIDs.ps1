# Specify the root folder where the "App.json" files are located
$rootFolder = "..\packages\App"

# Retrieve all "App.json" files within the specified folder and its subfolders
$appJsonFiles = Get-ChildItem -Path $rootFolder -Recurse -Filter "App.json"

# Iterate over each "App.json" file and extract relevant data
$appData = foreach ($file in $appJsonFiles) {
    # Read the content of the "App.json" file and convert it to a PowerShell object
    $jsonContent = Get-Content -Path $file.FullName | ConvertFrom-Json

    # Check if "PSPackageFactoryGuid" is "new" and generate a new GUID if true
    if ($jsonContent.Information.PSPackageFactoryGuid -eq "new") {
        $newGuid = [guid]::NewGuid().ToString()
        $jsonContent.Information.PSPackageFactoryGuid = $newGuid

        # Save the updated content back to the file
        $fileContent = $jsonContent | ConvertTo-Json -Depth 4
        $fileContent | Set-Content -Path $file.FullName

        # Create a custom PowerShell object to store the extracted data
        $displayName = $jsonContent.Information.DisplayName
        [PSCustomObject]@{
            DisplayName                  = $displayName
            OriginalPSPackageFactoryGuid = "new"
            UpdatedPSPackageFactoryGuid  = $newGuid
            FilePath                     = $file.FullName
        }
    }
}

# Display the edited items in a formatted table
$appData | Format-Table -AutoSize
