 Specify the root folder where the "App.json" files are located
$rootFolder = "C:\projects\packagefactory\packages\App"

# Retrieve all "App.json" files within the specified folder and its subfolders
$appJsonFiles = Get-ChildItem -Path $rootFolder -Recurse -Filter "App.json"

# Iterate over each "App.json" file and extract relevant data
foreach ($file in $appJsonFiles) {
    # Read the content of the "App.json" file and convert it to a PowerShell object
    $jsonContent = Get-Content -Path $file.FullName | ConvertFrom-Json
    Write-Host $jsonContent.Application.Name": "$jsonContent.Program.UninstallCommand
}