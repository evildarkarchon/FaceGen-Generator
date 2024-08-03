# Ensure necessary assemblies are loaded
Add-Type -AssemblyName System.Windows.Forms

# Determine the directory of the current script
$scriptDir = Split-Path -Path $PSCommandPath -Parent

# Define the path to the JSON file in the same directory as the script
$jsonFilePath = Join-Path -Path $scriptDir -ChildPath "xEditLocation.json"

# Variable to store location data
$locationData = $null

$script:regkey = 'HKLM:\Software\Wow6432Node\Bethesda Softworks\Fallout4'
$script:fo4 = Get-ItemPropertyValue -Path "$script:regkey" -Name 'installed path' -ErrorAction Stop
$script:data = Join-Path $fo4 "data"
$script:CK = Join-Path $fo4 "Creationkit.exe"
$script:Archive2 = Join-Path $script:data "tools\archive2\archive2.exe"
$script:facegenpatch = Join-Path $script:data "Facegenpatch.esp"
$script:ElrichDir = Join-Path $script:fo4 "tools\elric"
$script:Elrich = Join-Path $script:fo4 "tools\elric\elrich.exe"

# Function to get or select the xEdit/FO4Edit path and executable

function GetOrSelectxEditPath {
    # Check if the JSON file exists and read the stored path and executable
    if (Test-Path $jsonFilePath) {
        $locationData = Get-Content -Path $jsonFilePath | ConvertFrom-Json

        # Make sure we are getting the correct properties as strings
        $path = [string]$locationData.Directory
        $executable = [string]$locationData.Executable
        Write-Host "Found stored path to xEdit/FO4Edit: $path"
        Write-Host "Found stored executable: $executable"
        $fullPath = Join-Path -Path $path -ChildPath $executable

        # Verify if the executable exists
        if (Test-Path -Path $fullPath) {
            return $fullPath
        } else {
            Write-Host "`nERROR: The stored executable does not exist. Please select a new one.`n"
        }
    }

    # If JSON file doesn't exist or executable is not found, prompt the user to select it
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Title = "Select FO4Edit or xEdit executable"
    $openFileDialog.Filter = "FO4Edit or xEdit|fo4edit.exe;xedit.exe"
    $openFileDialog.InitialDirectory = $scriptDir
    if ($openFileDialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $selectedExe = $openFileDialog.FileName
        $selectedPath = Split-Path -Path $selectedExe -Parent
        $selectedExecutable = [System.IO.Path]::GetFileName($selectedExe)

        # Save the path and executable to the JSON file
        $locationData = @{
            Directory = $selectedPath
            Executable = $selectedExecutable
        }
        $locationData | ConvertTo-Json -Compress | Set-Content -Path $jsonFilePath -Force
        Write-Host "`nPath and executable saved successfully.`n"

        return $selectedExe
    } else {
        Write-Host "`nERROR: FO4Edit or xEdit executable not selected.`n"
        pause
        exit
    }
}

function CheckForFacegenPatch {

    while ($true) {
        if (Test-Path -Path $script:facegenpatch) {
            Write-Host "facegenpatch.esp found."
            break
        } else {
            Write-Host "Waiting for facegenpatch.esp..."
            Start-Sleep -Seconds 10
        }
    }
}

$steamapiPath = Join-Path $script:fo4 "steam_api64.dll"
$steamapiBackupPath = Join-Path $script:fo4 "steam_api64_downgradeBackup.dll"
$steamapiTempPath = Join-Path $script:fo4 "steam_api64.dll.tempbackup"
$script:steamapiWasReplaced = $false
function HandleSteamApiMismatch {
    # In case the user has latest Steam Creation Kit but downgraded game executable.

    $steamapiHash = Get-FileHash -Path $steamapiPath
    $creationKitHash = Get-FileHash -Path $script:CK
    if ($steamapiHash.Hash -eq `
    "81321A5CB72AE3F81243FD0B0D8928A063CA09129AB0878573BD36A28422EC4C" `
    -and $creationKitHash.Hash -eq `
    "051462F19DBE6A88CC0432297F88F6B00BBE11C5A0BE0FCEA934DCCE985B31A2") {
        Write-Host "Creation Kit is NG but has OG steam_api64.dll"
        if (Test-Path -Path $steamapiBackupPath) {
            Write-Host "NG steam_api64.dll backup found."
            Copy-Item -Path $steamapiPath -Destination $steamapiTempPath
            Copy-Item -Path $steamapiBackupPath -Destination $steamapiPath
            $script:steamapiWasReplaced = $true
        }
    }
}

# Define the full registry key path
$regkeydir = "Registry::HKEY_CLASSES_ROOT\modl\shell\open\command"

# Retrieve the '(Default)' value from the registry key
$registryValue = Get-ItemProperty -Path $regkeydir -Name "(Default)" -ErrorAction SilentlyContinue

# Check if the '(Default)' value was retrieved successfully
if ($registryValue -and $registryValue."(Default)") {
    # Extract the folder path from the '(Default)' value
    $mo2dir = Split-Path -Path $registryValue."(Default)" -Parent

    # Output the folder path
    Write-Host "MO2 Install Path: $mo2dir"
} else {
    Write-Host "Could not find MO2 installation path."
}

# Main script execution
try {
    $fo4EditExe = GetOrSelectxEditPath

    $script = Split-Path -Path $fo4EditExe -Parent

    $pas = Join-Path -Path $script -ChildPath "Edit Scripts\FaceGen Generator.pas"
    $facegenfilterscript = Join-Path -Path $script -ChildPath "Edit Scripts\Elric\FaceGen.cs"

    # Debug output to confirm the $pas path
    #Write-Host "Path to .pas file: $pas"

    # Check if the .pas file exists before trying to run the process
    if (!(Test-Path -Path $pas)) {
        Write-Host "ERROR: The .pas file does not exist at the specified path: $pas"
        exit
    }
    $esp = [System.IO.Path]::GetFileName($script:facegenpatch)
    $script:elrichdir = Split-Path -Path $script:Elrich -Parent
    # Start the process with the valid executable path
    if (!(Test-Path -Path $script:facegenpatch)) {
    Start-Process -FilePath $fo4EditExe -ArgumentList "-FO4 -autoload -nobuildrefs -script:`"$pas`"" -Wait
    CheckForFacegenPatch
    }
    HandleSteamApiMismatch
    Start-Process -FilePath $script:CK -WorkingDirectory $script:fo4 -ArgumentList "-ExportFaceGenData:$esp W32" -Wait
    if ($script:steamapiWasReplaced) {
        Copy-Item $steamapiTempPath -Destination $steamapiPath
    }
    Start-Process -FilePath $script:Elrich -WorkingDirectory $ElrichDir `
    -ArgumentList "`"$script:elrichdir\Settings\PCMeshes.esf`" -ElricOptions.FilterScript=`"$facegenfilterscript`" -ElricOptions.ConvertTarget=`"$script:data`" -ElricOptions.OutputDirectory=`"$script:data`" -ElricOptions.CloseWhenFinished=True" `
    -Wait

} catch {
    Write-Host "`nAn unexpected error occurred.`n"
    Write-Error $_
    pause
    Write-Output "Done"
    exit
}