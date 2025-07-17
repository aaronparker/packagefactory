# Specify the root folder where the "App.json" files are located
$rootFolder = "C:\projects\packagefactory\packages\App"

# Retrieve all "App.json" files within the specified folder and its subfolders
$appJsonFiles = Get-ChildItem -Path $rootFolder -Recurse -Filter "App.json"

# Array to store items that were edited due to duplicate GUIDs
$editedItems = @()

# Iterate over each "App.json" file and extract relevant data
$appData = foreach ($file in $appJsonFiles) {
    # Read the content of the "App.json" file and convert it to a PowerShell object
    $jsonContent = Get-Content -Path $file.FullName | ConvertFrom-Json

    # Extract the "DisplayName" and "PSPackageFactoryGuid" values
    $displayName = $jsonContent.Information.DisplayName
    $packageFactoryGuid = $jsonContent.Information.PSPackageFactoryGuid

    # Create a custom PowerShell object to store the extracted data
    [PSCustomObject]@{
        DisplayName = $displayName
        OriginalPSPackageFactoryGuid = $packageFactoryGuid
        UpdatedPSPackageFactoryGuid = $packageFactoryGuid
        FilePath = $file.FullName
    }
}

# Group the GUIDs and count their occurrences
$guidGroups = $appData | Group-Object -Property OriginalPSPackageFactoryGuid | Where-Object { $_.Count -gt 1 }

# Iterate over each group of duplicate GUIDs
foreach ($group in $guidGroups) {
    $duplicateGuid = $group.Name

    # Generate new GUIDs for duplicates within the group
    $newGuids = foreach ($item in $group.Group) {
        $newGuid = [guid]::NewGuid().ToString()
        $item.UpdatedPSPackageFactoryGuid = $newGuid
        $item
    }

    # Update the corresponding "App.json" files with new GUIDs
    $newGuids | ForEach-Object {
        # Read the content of the "App.json" file and convert it to a PowerShell object
        $jsonContent = Get-Content -Path $_.FilePath | ConvertFrom-Json

        # Update the "PSPackageFactoryGuid" field with the new GUID
        $jsonContent.Information.PSPackageFactoryGuid = $_.UpdatedPSPackageFactoryGuid

        # Convert the updated content back to JSON and save it to the file
        $fileContent = $jsonContent | ConvertTo-Json -Depth 4
        $fileContent | Set-Content -Path $_.FilePath

        # Add the edited item to the $editedItems array
        $editedItems += $_
    }
}

# Display the edited items in a formatted table
$editedItems | Format-Table -AutoSize
