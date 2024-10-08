# Ensure necessary assemblies are loaded
Add-Type -AssemblyName System.Windows.Forms

# Determine the directory of the current script
$scriptDir = Split-Path -Path $PSCommandPath -Parent

# Define the path to the JSON file in the same directory as the script
$jsonFilePath = Join-Path -Path $scriptDir -ChildPath "config.json"

# Variable to store location data
$script:configfile  = $null


$script:regkey = 'HKLM:\Software\Wow6432Node\Bethesda Softworks\Fallout4'
$script:fo4regPath = $scriptDir #set to script dir in case registry check fails

function Show-OpenFileDialog {
    param (
        [string]$title,
        [string]$filter,
        [string]$initialDirectory
    )
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Reset()
    $openFileDialog.Title = $title
    $openFileDialog.Filter = $filter
    $openFileDialog.InitialDirectory = $initialDirectory
    $openFileDialog.ShowDialog() | Out-Null
    return $openFileDialog.FileName
}

function GetOrSelectGamePath {
    # Get Game Directory
    Write-Host "Browse and select Fallout 4 location."
    $OpenFo4FileName = Show-OpenFileDialog -title "Select Fallout4.exe" -filter "Fallout 4|Fallout4.exe" -initialDirectory $script:fo4regPath

    if ($OpenFo4FileName) {
        $script:fo4 = Split-Path -Path $OpenFo4FileName -Parent
    } else {
        Write-Host "`nERROR: Fallout 4 directory not found.`n"
        pause
        exit
    }
}

try {
    try {
        $script:fo4regPath = Get-ItemPropertyValue -Path "$script:regkey" -Name 'installed path' -ErrorAction Stop
    } catch {
        Write-Host "Fallout 4 registry key path location is missing at $script:regkey"
    }

    if (Test-Path $jsonFilePath) {
        $script:configfile = Get-Content  -Path $jsonFilePath | ConvertFrom-Json
        $script:fo4 = [string]$script:configfile.Fallout4Directory
        if (Test-Path $script:fo4) {
            Write-Host "Fallout 4 path: $script:fo4"
        } else {
            GetOrSelectGamePath
            Write-Host "Fallout 4 path: $script:fo4"
        }
    } else {
        GetOrSelectGamePath
        Write-Host "Fallout 4 path: $script:fo4"
    }
}
catch {
    Write-Host "`nAn unexpected error occurred.`n"
    Write-Error $_
    pause
    Write-Output "Done"
    exit
}


# Set needed paths
$script:data = Join-Path $fo4 "data"
$script:steamappidtxtfile = Join-Path $fo4 "steam_appid.txt"
$script:CK = Join-Path $fo4 "Creationkit.exe"
$script:Archive2 = Join-Path $script:fo4 "tools\archive2\archive2.exe"
$script:facegenpatch = Join-Path $script:data "Facegenpatch.esp"
$script:ElrichDir = Join-Path $script:fo4 "tools\elric"
$script:Elrich = Join-Path $script:fo4 "tools\elric\elrich.exe"
$script:Texconv = Join-Path $scriptDir "tools\texconv\texconv.exe"
$script:winhttp = Join-Path $script:fo4 "winhttp.dll"

$script:xEditPath = $scriptDir #set here as default for the file open dialog
$script:xEditExecutable = $null
$script:meshes = Join-Path $scriptDir -ChildPath "Temp\Meshes"
$script:textures = Join-Path $script:data -ChildPath "Textures"
$script:tempfolder = Join-Path $scriptDir -ChildPath "Temp"
$script:tempFaceGenMeshes = Join-Path $script:tempfolder "Meshes\Actors\Character\FaceGenData\FaceGeom"
$script:tempFaceGenTextures = Join-Path $script:tempfolder "Textures\Actors\Character\FaceCustomization"
$script:tempBaseFaceTextures = Join-Path $script:tempfolder -ChildPath "Textures"
$tempBaseFaceTexturesArchive = Join-Path $script:tempfolder "VEFS Face - Textures.ba2"
$script:FacesJson = Join-Path $scriptDir "Faces.json"

$script:FacegenMeshes = Join-Path $script:data "Meshes\Actors\Character\FaceGenData\FaceGeom"
$script:FacegenTextures = Join-Path $script:data "Textures\Actors\Character\FaceCustomization"
$meshesarchive = Join-Path $script:data "FaceGenPatch - Main.ba2"
$texturesarchive = Join-Path $script:data "FaceGenPatch - Textures.ba2"

#Set arguments for powershell file.

if ($args -contains "-zip") {
    Write-Output "-zip has been passed. All files will be compressed into a .zip file."
}

if ($args -contains "-clean") {
    # Automatically delete loose files without prompting
    Write-Output "-clean has been passed. All loose files will be automatically deleted."
}

# Function to get or select the xEdit/FO4Edit path and executable
function GetOrSelectxEditPath {
    # Check if the JSON file exists and read the stored path and executable
    if (Test-Path $jsonFilePath) {
        # Make sure we are getting the correct properties as strings
        $script:xEditPath = [string]$script:configfile.xEditDirectory
        $script:xEditExecutable = [string]$script:configfile.xEditExecutable
        Write-Host "Found stored path to xEdit/FO4Edit: $script:xEditPath"
        Write-Host "Found stored executable: $script:xEditExecutable"
        $fullPath = Join-Path -Path $script:xEditPath -ChildPath $script:xEditExecutable

        # Verify if the executable exists
        if (Test-Path -Path $fullPath) {
            return $fullPath
        } else {
            $script:xEditPath = $scriptDir #set here as default for the file open dialog
            $script:xEditExecutable = $null
            Write-Host "`nERROR: The stored executable does not exist. Please select a new one.`n"
        }
    }
    # Fetch xEdit location from registry HKCR\FO4Script\DefaultIcon
    try {
        $xEditRegKey = Get-ItemProperty -Path 'Registry::HKEY_CLASSES_ROOT\FO4Script\DefaultIcon' -ErrorAction Stop
        $script:xEditPath = [string] $xEditRegKey."(default)"
    } catch {
        Write-Host "`nCouldn't detect xEdit Location from the registry.`n"
    }


    # If JSON file doesn't exist or executable is not found, prompt the user to select it
    $OpenXEditFileName = Show-OpenFileDialog -title "Select FO4Edit or xEdit executable" -filter "FO4Edit or xEdit|fo4edit.exe;fo4edit64.exe;xedit.exe;xedit64.exe" -initialDirectory $script:xEditPath

    if ($OpenXEditFileName) {
        $selectedExe = $OpenXEditFileName
        $script:xEditPath = Split-Path -Path $selectedExe -Parent
        $script:xEditExecutable = [System.IO.Path]::GetFileName($selectedExe)

        return $selectedExe
    } else {
        Write-Host "`nERROR: FO4Edit or xEdit executable not selected.`n"
        pause
        exit
    }
}
function PatchArchive {
    param (
        [string]$file
    )
    if (Test-Path -Path $file) {
        $fileStream = [System.IO.File]::Open($file, [System.IO.FileMode]::Open, [System.IO.FileAccess]::ReadWrite)
        $fileStream.Seek(4, [System.IO.SeekOrigin]::Begin) | Out-Null
        $newByte = 0x01
        $fileStream.WriteByte($newByte)
        $fileStream.Close()
    } else { Write-Host "$file was not patched. It doesn't appear to have been made." }
}

function SaveSettings {
    # Save the settings
    $script:configfile = @{
        RunElric = $RunElric
        PluginName = $PluginName
        xEditDirectory = $script:xEditPath
        xEditExecutable = $script:xEditExecutable
        scriptDirectory = $scriptDir
        Fallout4Directory = $script:fo4
    }
    $script:configfile | ConvertTo-Json -Compress | Set-Content -Path $jsonFilePath -Force
    Write-Host "`nSaved settings successfully.`n"
}

function LaunchXEdit {
    # Launch xEdit
    $script:xEditProcess = Start-Process -FilePath $fo4EditExe -ArgumentList "-script:`"$pas`" -nobuildrefs -FO4 -D:`"$script:data`" -vefsdir:`"$scriptDir`"" -PassThru
    CheckForFacegenPatch
}

function CheckForFacegenPatch {

    while ($true) {
        if (Test-Path -Path $scriptDir\Faces.json) {
            Write-Host "xEdit script complete."
            break
        } else {
            Write-Host "Waiting for xEdit script to finish..."
            if ($script:xEditProcess.HasExited){
                Write-Host "xEdit was terminated prematurely. VEFS will now close."
                if (Test-Path -Path $script:facegenpatch) { Remove-Item -LiteralPath $script:facegenpatch }
                Pause
                Exit
            }
            Start-Sleep -Seconds 5
        }
    }

    Start-Sleep 1
    try {
        $script:xEditProcess.CloseMainWindow()
        $script:xEditProcess.WaitForExit()
    } catch {
        Write-Host 'xEdit was already closed by user.'
    }
    while ($true) {
        if (Test-Path -Path $script:facegenpatch) {
            Write-Host "facegenpatch.esp found."
            break
        } else {
            Write-Host "Waiting for facegenpatch.esp..."
            Start-Sleep -Seconds 5
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

function SteamAppIdTxt {
    param (
        [string]$appid
    )
    #377160 Fallout 4
    #1946160 Creation Kit
    $appid | Out-File -FilePath "$script:steamappidtxtfile" -Force
}

<# # Define the full registry key path
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
} #>

# if (-not ('WindowHelper' -as [Type])) {
#     Add-Type -TypeDefinition @"
#     using System;
#     using System.Runtime.InteropServices;
#     using System.Text;

#     public struct INPUT
#     {
#         public uint Type;
#         public KEYBDINPUT Data;
#     }

#     [StructLayout(LayoutKind.Sequential)]
#     public struct KEYBDINPUT
#     {
#         public ushort wVk;
#         public ushort wScan;
#         public uint dwFlags;
#         public uint time;
#         public IntPtr dwExtraInfo;
#     }

#     public class WindowHelper {
#         [DllImport("user32.dll", CharSet = CharSet.Auto, SetLastError = true)]
#         public static extern int GetWindowText(IntPtr hWnd, StringBuilder lpString, int nMaxCount);

#         [DllImport("user32.dll")]
#         public static extern bool SetForegroundWindow(IntPtr hWnd);

#         [DllImport("user32.dll")]
#         public static extern uint SendInput(uint nInputs, INPUT[] pInputs, int cbSize);
#     }
# "@
# }

# Main script execution
try {
    $fo4EditExe = GetOrSelectxEditPath
    $fo4EditProcessName = [System.IO.Path]::GetFileNameWithoutExtension($fo4EditExe)
    $script:PluginName = [string]$script:configfile.PluginName
    if (!($PluginName)) { $script:PluginName="FaceGen Output" }
    $script:RunElric = [string]$script:configFile.RunElric
    if (!($RunElric)) { $script:RunElric="false" }
    SaveSettings

    $fo4EditVer = (Get-Item $fo4EditExe).VersionInfo.FileVersionRaw

    if (Test-Path -Path $script:winhttp) {
        $ckpeVer = (Get-Item $script:winhttp).VersionInfo.FileVersionRaw
    } else { Write-Error "Creation Kit Platform Extended is not installed." }

    if (Test-Path -Path $script:CK) {
        $ckVer = (Get-Item $script:CK).VersionInfo.FileVersionRaw
    } else { Write-Error "Creation Kit is not installed." }

    if ($fo4EditVer -lt [Version]'4.1.5') {
        Write-Error "VEFS requires xEdit 4.1.5 or newer. Installed version is $fo4EditVer"
    } else {
        Write-Host "xEdit is version $fo4EditVer"
    }
    if ($ckpeVer -lt [Version]'0.4.0.116') {
        Write-Error "VEFS requires CKPE v0.4-b116 or newer. Installed version is $ckpeVer"
    } else {
        Write-Host "Creation Kit Platform Extended is version $ckpeVer"
    }
    Write-Host "Creation Kit version is $ckVer"

    $pas = Join-Path -Path $scriptDir -ChildPath "Edit Scripts\FaceGen Generator.pas"

    # Debug output to confirm the $pas path
    Write-Host "Path to .pas file: $pas"

    if (Test-Path -Path $script:steamappidtxtfile) {
        $steamappidoriginal = Get-Content -Path $script:steamappidtxtfile
        $bHasSteamAppIDTxt = $true
    } else { $bHasSteamAppIDTxt = $false }

    # Check if the .pas file exists before trying to run the process
    if (!(Test-Path -Path $pas)) {
        Write-Host "ERROR: The .pas file does not exist at the specified path: $pas"
        Write-Host "VEFS will now close."
        pause
        exit
    }
    $esp = [System.IO.Path]::GetFileName($script:facegenpatch)
    $script:elrichdir = Split-Path -Path $script:Elrich -Parent

    # Delete previous Faces.json
    if (Test-Path -Path $script:FacesJson) {
        Remove-Item -Path $script:FacesJson
        Write-Host "$script:FacesJson was deleted automatically"
    }

    # Start the xEdit process with the valid executable path
    if (!(Test-Path -Path $script:facegenpatch)) {
        LaunchXEdit
    } else {
        Remove-Item -LiteralPath $script:facegenpatch
        Write-Host "`"$script:facegenpatch`" was deleted."
        LaunchXEdit
    }

    #We must reread the config file to refresh its contents.
    $script:configfile = Get-Content  -Path $jsonFilePath | ConvertFrom-Json
    $NeedPlugin = [string]$script:configfile.NeedPlugin
    $FaceCount = [string]$script:configfile.Face_Count
    $Mode = [string]$script:configfile.Mode
    $script:RunElric = [string]$script:configFile.RunElric
    $MaxTextureSize = [string]$script:configFile.MaxTextureSize
    $LooseFaceTextures = [string]$script:configFile.LooseFaceTextures

    $script:FacesInfo = Get-Content -Path $FacesJson -Raw | ConvertFrom-Json
    $LooseFilesToDelete = $FacesInfo.LooseFilesToDelete
    $TexturesToProcess = $FacesInfo.textures
    $tintTexturesToProcess = $FacesInfo.tint_textures
    $bc5TexturesToProcess = $FacesInfo.bc5_textures
    $script:PluginName = [string]$script:configfile.PluginName
    $meshesarchive = Join-Path $script:data "$PluginName - Main.ba2"
    $texturesarchive = Join-Path $script:data "$PluginName - Textures.ba2"

    if ($FaceCount -eq "0") {
        Write-Host "No faces will be generated with the Creation Kit."
        if ($Mode -eq "Quick Face Fix") {
            Copy-Item $script:facegenpatch -Destination "$data\$PluginName.esp" -Force
            Remove-Item -LiteralPath $script:facegenpatch
            Write-Host "Quick Face Fix mode finished."
        }
        if ($NeedPlugin -eq "false") {
            Remove-Item -LiteralPath $script:facegenpatch
        }
        if ($Mode -eq "Fix Face Textures") {
            $TotalCount = $TexturesToProcess.Count + $tintTexturesToProcess.Count + $bc5TexturesToProcess.Count
            Write-Host "Converting $TotalCount textures to $MaxTextureSize resolution..."
            $count = 0

            $texconvProcess = @()
            foreach ($file in $TexturesToProcess) {
                if (Test-Path -LiteralPath $file) {
                    $outputpath = [System.IO.Path]::GetDirectoryName($file)
                    if ($LooseFaceTextures -eq "true") {
                        $texconvProcess += Start-Process -FilePath $script:Texconv -ArgumentList "-y -w $MaxTextureSize -h $MaxTextureSize -f BC3_UNORM -ft DDS -m 1 -o `"$outputpath`" `"$file`"" -PassThru -WindowStyle hidden
                    } else {
                        $texconvProcess += Start-Process -FilePath $script:Texconv -ArgumentList "-y -w $MaxTextureSize -h $MaxTextureSize -f BC7_UNORM -ft DDS -m 1 -o `"$outputpath`" `"$file`"" -PassThru -WindowStyle hidden
                    }
                    $count++
                    $percentComplete = [math]::Round(($count / $TotalCount) * 100)
                    Write-Progress -Activity "Converting Textures..." -Status "Processing $count of $TotalCount`: $file..." -PercentComplete $percentComplete
                } else {
                    Write-Host "File not found: $file"
                }
            }
            foreach ($file in $tintTexturesToProcess) {
                if (Test-Path -LiteralPath $file) {
                    $outputpath = [System.IO.Path]::GetDirectoryName($file)
                    $texconvProcess += Start-Process -FilePath $script:Texconv -ArgumentList "-y -w $MaxTextureSize -h $MaxTextureSize -f BC4_UNORM -ft DDS -m 1 -o `"$outputpath`" `"$file`"" -PassThru -WindowStyle hidden
                    $count++
                    $percentComplete = [math]::Round(($count / $TotalCount) * 100)
                    Write-Progress -Activity "Converting Textures..." -Status "Processing $count of $TotalCount`: $file..." -PercentComplete $percentComplete
                } else {
                    Write-Host "File not found: $file"
                }
            }
            foreach ($file in $bc5TexturesToProcess) {
                if (Test-Path -LiteralPath $file) {
                    $outputpath = [System.IO.Path]::GetDirectoryName($file)
                    $texconvProcess += Start-Process -FilePath $script:Texconv -ArgumentList "-y -w $MaxTextureSize -h $MaxTextureSize -f BC5_UNORM -ft DDS -m 1 -o `"$outputpath`" `"$file`"" -PassThru -WindowStyle hidden
                    $count++
                    $percentComplete = [math]::Round(($count / $TotalCount) * 100)
                    Write-Progress -Activity "Converting Textures..." -Status "Processing $count of $TotalCount`: $file..." -PercentComplete $percentComplete
                } else {
                    Write-Host "File not found: $file"
                }
            }
            $texconvProcess | ForEach-Object { $_ | Wait-Process }
            Write-Progress -Activity "Converting Textures..." -Status "Completed" -PercentComplete 100
            Write-Host "Done converting textures."

            if ($LooseFaceTextures -eq "false") {
                #Create textures archive
                Write-Host "Archiving textures..."
                $textureBaseArchiveProcess = Start-Process -FilePath $script:Archive2 -ArgumentList "`"$script:tempBaseFaceTextures`" -r=`"$script:tempfolder`" -c=`"$tempBaseFaceTexturesArchive`" -f=DDS" -PassThru
                if (!($textureBaseArchiveProcess.HasExited)) {
                    Wait-Process -InputObject $textureBaseArchiveProcess
                }
                try {
                    Get-Process -Name $textureBaseArchiveProcess -ErrorAction Stop
                    Read-Host "Press Any Key after Archive2 has closed"
                } catch {
                    Write-Host "Archive2 has exited."
                }
                Write-Host "Done archiving textures."
                PatchArchive -file "$tempBaseFaceTexturesArchive"
            }

            Write-Host "Creating VEFS Face Textures.zip..."
            if ($LooseFaceTextures -eq "false") {
                Compress-Archive -Path "$tempBaseFaceTexturesArchive", "$scriptDir\misc\VEFS Face.esp"  -DestinationPath "$scriptDir\VEFS Face Textures.zip" -Force
            } else {
                Compress-Archive -Path "$tempBaseFaceTextures" -DestinationPath "$scriptDir\VEFS Face Textures.zip" -Force
            }
            $wshell = New-Object -ComObject Wscript.Shell
            $decision = $wshell.Popup("Delete temporary files at `"$script:tempfolder`" ?",0,"Delete temporary files?",0x4 + 0x20)
            if ($decision -eq 6) {
                Remove-Item -LiteralPath "$script:tempfolder" -Recurse -Force
                Write-Host "`"$script:tempfolder`" was deleted."
            } else {
                Write-Host "`"$script:tempfolder`" was NOT deleted."
            }
            Write-Host "VEFS Mode Fix Face Textures Done. Please install VEFS Face Textures.zip in your mod manager."
        }
        Pause
        Exit
    } else {
        Write-Host "Faces to make: $FaceCount"
    }
    if ($Mode -eq "Quick Face Fix") {
        Copy-Item $script:facegenpatch -Destination "$data\$PluginName.esp" -Force
        Remove-Item -LiteralPath $script:facegenpatch
        Write-Host "Quick Face Fix mode finished."
        Pause
        Exit
    }

    ##############################################################################
    # Launch CK
    ##############################################################################

    HandleSteamApiMismatch
    SteamAppIdTxt -appid 19946160
    $process = Start-Process -FilePath $script:CK -WorkingDirectory $script:fo4 -ArgumentList "-ExportFaceGenData:$esp W32" -PassThru

    $filestomake = $LooseFilesToDelete
    $TotalCount = $LooseFilesToDelete.Count

    $i = 0
    $timeout = 0
    $bFirst = $true
    $stopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    while ($i -lt $TotalCount) {

        $filestomake = $filestomake | Where-Object { -not (Test-Path $_) }
        $i = $TotalCount - $filestomake.Count
        $percentComplete = [math]::Round(($i / $TotalCount) * 100)
        Start-Sleep -Seconds 5
        $timeout += 5

        try {
            Get-Process -Name "CreationKit" -ErrorAction Stop
        } catch {
            if ($timeout -ge 60) { break }
            #Times out after 1 minute if the Creation Kit process isn't detected.
        }

        # How much time has elapsed.
        $elapsedTime = $stopwatch.Elapsed
        $timespan = [TimeSpan]::FromSeconds($elapsedTime.TotalSeconds)
        $formattedTime = "{0:D2}:{1:D2}:{2:D2}" -f $timespan.Hours, $timespan.Minutes, $timespan.Seconds

        if ($i -ne 0) {
            if ($bFirst) { $timeToLaunch = $elapsedTime.TotalSeconds }
            $bFirst = $false

            $timer = $elapsedTime.TotalSeconds - $timeToLaunch + 3 #adding 3 seconds so as to not get hopes up.

            # Calculate the average time per item
            $averageTimePerItemSeconds = $timer / $i
            $remainingItems = $TotalCount - $i

            # Estimate the remaining time
            $remainingTimeSeconds = $averageTimePerItemSeconds * $remainingItems

            Write-Progress -Activity "Created $i out of $TotalCount Faces..." -Status "Elapsed time: $formattedTime" -PercentComplete $percentComplete -SecondsRemaining $remainingTimeSeconds
        } else {
            Write-Progress -Activity "Created $i out of $TotalCount Faces..." -Status "Elapsed time: $formattedTime" -PercentComplete $percentComplete
        }
    }
    Write-Progress -Activity "Creating Facegen..." -Status "Completed" -PercentComplete 100 -Completed
    $stopwatch.Stop()

    if (!($process.HasExited)) {
        Wait-Process -InputObject $process
    }
    try {
        Get-Process -Name "CreationKit" -ErrorAction Stop
        Read-Host "Press Any Key after Creation Kit has closed"
    } catch {
        Write-Host "Creation Kit has exited."
    }

    if ($script:steamapiWasReplaced) {
        Copy-Item $steamapiTempPath -Destination $steamapiPath
    }

    if ($bHasSteamAppIDTxt) {
        SteamAppIdTxt -appid $steamappidoriginal
    } else { Remove-Item -Path $script:steamappidtxtfile }

    Remove-Item -LiteralPath $script:facegenpatch


    #####################################################################################################
    # This Code was to convert textures, but perchik is now handling that inside the Creation Kit itself.
    #####################################################################################################
    # Write-Host "Converting textures..."
    # $files = Get-ChildItem "$script:FacegenTextures" -Recurse -Filter *_d.tga
    # foreach ($f in $files){
    #     $texturehere = $f.FullName
    #     Set-Location "$script:FacegenTextures"
    #     $relativepath = Get-Item $f.Directory | Resolve-Path -Relative
    #     $relativepath = $relativepath.ToString().Substring(2)
    #     $outputpath = Join-Path $script:tempFaceGenTextures $relativepath
    #     if (!(Test-Path -Path $outputpath)){
    #         New-Item -ItemType "directory" -Path $outputpath
    #     }
    #     Write-Host $texturehere
    #     Start-Process -FilePath $script:Texconv -ArgumentList "-w 1024 -h 1024 -f BC7_UNORM -ft DDS -m 1 -o `"$outputpath`" `"$texturehere`"" -Wait -WindowStyle hidden
    # }
    # $files = Get-ChildItem "$script:FacegenTextures" -Recurse -Filter *_msn.tga
    # foreach ($f in $files){
    #     $texturehere = $f.FullName
    #     Set-Location "$script:FacegenTextures"
    #     $relativepath = Get-Item $f.Directory | Resolve-Path -Relative
    #     $relativepath = $relativepath.ToString().Substring(2)
    #     $outputpath = Join-Path $script:tempFaceGenTextures $relativepath
    #     if (!(Test-Path -Path $outputpath)){
    #         New-Item -ItemType "directory" -Path $outputpath
    #     }
    #     Write-Host $texturehere
    #     Start-Process -FilePath $script:Texconv -ArgumentList "-w 1024 -h 1024 -f BC1_UNORM -ft DDS -m 1 -o `"$outputpath`" `"$texturehere`"" -Wait -WindowStyle hidden
    # }
    # $files = Get-ChildItem "$script:FacegenTextures" -Recurse -Filter *_s.tga
    # foreach ($f in $files){
    #     $texturehere = $f.FullName
    #     Set-Location "$script:FacegenTextures"
    #     $relativepath = Get-Item $f.Directory | Resolve-Path -Relative
    #     $relativepath = $relativepath.ToString().Substring(2)
    #     $outputpath = Join-Path $script:tempFaceGenTextures $relativepath
    #     if (!(Test-Path -Path $outputpath)){
    #         New-Item -ItemType "directory" -Path $outputpath
    #     }
    #     Write-Host $texturehere
    #     Start-Process -FilePath $script:Texconv -ArgumentList "-w 512 -h 512 -f BC5_UNORM -ft DDS -m 1 -o `"$outputpath`" `"$texturehere`"" -Wait -WindowStyle hidden
    # }
    #####################################################################################################
    #####################################################################################################

    #If temp path already exists, wipe it out.
    if (Test-Path -Path "$script:tempfolder") {
        Remove-Item -LiteralPath "$script:tempfolder" -Recurse -Force
        Write-Host "`"$script:tempfolder`" was deleted automatically"
    }

    $fixfacepas = Join-Path -Path $scriptDir -ChildPath "Edit Scripts\FixFacegen.pas"
    $FixMeshProcess = Start-Process -FilePath $fo4EditExe -ArgumentList "-autoload -script:`"$fixfacepas`" -nobuildrefs -FO4 -D:`"$script:data`" -vefsdir:`"$scriptDir`"" -PassThru
    Start-Sleep -Seconds 5
    $wshell = New-Object -ComObject wscript.shell;
    $wshell.AppActivate('Module Selection')
    Start-Sleep -Seconds 1
    $wshell.SendKeys('~')

    #Create textures archive
    $textureArchiveProcess = Start-Process -FilePath $script:Archive2 -ArgumentList "`"$script:textures`" -r=`"$script:data`" -c=`"$texturesarchive`" -f=DDS -includeFilters=(?i)textures\\actors\\character\\facecustomization\\" -PassThru

    #[System.Windows.Forms.SendKeys]::SendWait({'~'})

    while ($true) {
        if (Test-Path -Path $scriptDir\done.json) {
            Write-Host "FixFaceGen is done."
            Remove-Item -LiteralPath $scriptDir\done.json -Force
            break
        } else {
            Write-Host "Waiting for FixFaceGen to finish..."
            if ($FixMeshProcess.HasExited){
                break
            }
            Start-Sleep -Seconds 5
        }
    }

    Start-Sleep 1
    try {
        $FixMeshProcess.CloseMainWindow()
        $FixMeshProcess.WaitForExit()
    } catch {
        Write-Host 'xEdit was already closed by user.'
    }

    if (!($FixMeshProcess.HasExited)) {
        Wait-Process -InputObject $FixMeshProcess
    }
    try {
        Get-Process -Name $fo4EditProcessName -ErrorAction Stop
        Read-Host "Press Any Key after xEdit has closed"
    } catch {
        Write-Host "xEdit has exited."
    }


    #Run Elric only on the meshes.
    #This is now disabled effectively.
    # if ($RunElric -eq "true") {
    #     $ElricProcess = Start-Process -FilePath $script:Elrich -WorkingDirectory $ElrichDir `
    #     -ArgumentList "`"$script:elrichdir\Settings\PCMeshes.esf`" -ElricOptions.ConvertTarget=`"$script:tempfolder`" -ElricOptions.OutputDirectory=`"$script:tempfolder`" -ElricOptions.CloseWhenFinished=True" `
    #     -PassThru
    #     if (!($ElricProcess.HasExited)) {
    #         Wait-Process -InputObject $ElricProcess
    #     }
    #     try {
    #         Get-Process -Name "Elrich" -ErrorAction Stop
    #         Read-Host "Press Any Key after Elrich has closed"
    #     } catch {
    #         Write-Host "Elric has exited."
    #     }
    # }

    #Create meshes archive
    $meshesArchiveProcess = Start-Process -FilePath $script:Archive2 -ArgumentList "`"$script:meshes`" -r=`"$script:tempfolder`" -c=`"$meshesarchive`" -f=General -includeFilters=(?i)meshes\\actors\\character\\facegendata\\facegeom\\" -PassThru

    if (!($meshesArchiveProcess.HasExited)) {
        Wait-Process -InputObject $meshesArchiveProcess
    }
    if (!($textureArchiveProcess.HasExited)) {
        Wait-Process -InputObject $textureArchiveProcess
    }
    try {
        Get-Process -Name "Archive2" -ErrorAction Stop
        Read-Host "Press Any Key after Archive2 has closed"
    } catch {
        Write-Host "Archive2 has exited."
    }
    PatchArchive -file "$meshesarchive"
    PatchArchive -file "$texturesarchive"

    # Check if the -clean argument was passed
    if ($args -contains "-clean") {
        # Automatically delete loose files without prompting
        Write-Output "-clean has been passed. All loose files will be automatically deleted."
        Remove-Item -LiteralPath "$script:FacegenMeshes" -Recurse -Force
        Write-Host "`"$script:FacegenMeshes`" was deleted automatically by passing '-clean'"

        Remove-Item -LiteralPath "$script:FacegenTextures" -Recurse -Force
        Write-Host "`"$script:FacegenTextures`" was deleted automatically by passing '-clean'"

        # Remove-Item -LiteralPath "$script:tempfolder" -Recurse -Force
        # Write-Host "`"$script:tempfolder`" was deleted automatically by passing '-clean'"
    } else {
        # Existing code for user confirmation
        $wshell = New-Object -ComObject Wscript.Shell
        $decision = $wshell.Popup("Delete loose files at `"$script:FacegenMeshes`" ?",0,"Delete loose facegen meshes?",0x4 + 0x20)
        if ($decision -eq 6) {
            foreach ($file in $LooseFilesToDelete) {
                if (Test-Path -LiteralPath $file) {
                    Remove-Item -LiteralPath $file -Force
                } else {
                    Write-Host "File not found: $file"
                }
            }
            Write-Host "`"$script:FacegenMeshes`" was deleted."
        } else {
            Write-Host "`"$script:FacegenMeshes`" was NOT deleted."
        }

        $decision = $wshell.Popup("Delete loose files at `"$script:FacegenTextures`" ?",0,"Delete loose facegen textures?",0x4 + 0x20)
        if ($decision -eq 6) {
            Remove-Item -LiteralPath "$script:FacegenTextures" -Recurse -Force
            Write-Host "`"$script:FacegenTextures`" was deleted."
        } else {
            Write-Host "`"$script:FacegenTextures`" was NOT deleted."
        }

        $decision = $wshell.Popup("Delete temporary files at `"$script:tempfolder`" ?",0,"Delete temporary files?",0x4 + 0x20)
        if ($decision -eq 6) {
            Remove-Item -LiteralPath "$script:tempfolder" -Recurse -Force
            Write-Host "`"$script:tempfolder`" was deleted."
        } else {
            Write-Host "`"$script:tempfolder`" was NOT deleted."
        }
    }

    # Check if the -zip argument was passed
    if ($args -contains "-zip") {
        $date = Get-Date -Format "dd-MM-yyyy"
        Write-Output "-zip has been passed. All files will be compressed into a .zip file."
        # Zip the generated files
        Compress-Archive -Path "$script:facegenpatch", "$script:meshesarchive", "$script:texturesarchive" -DestinationPath "$script:data\Facegen-$date.zip"
        Write-Host "All generated files were compressed into GeneratedFiles.zip."
    }
    Write-Host "VEFS completed successfully."
    Pause
    exit
} catch {
    Write-Host "`nAn unexpected error occurred.`n"
    Write-Error $_
    pause
    Write-Output "Done"
    exit
}