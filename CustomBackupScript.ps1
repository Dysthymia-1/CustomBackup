#Custom backup script 
#This script begins with a predefined set of folders the user needs to set.
#Once this is done, the script is run as admin and guides the user on backing up the folders.
#Version 0.2.1 - 0.2.2 - Amended element [3] within $Data to remove the '!' and successive characters from the path.
#Version 0.2.2 - 0.2.3 - Began adding the compression option.
#Version 0.2.3 - 0.3.1 - Finished initial compression implementation.
#Version 0.3.1 - 0.3.2 - Generalized the script and removed my son's name, whom the script was initially made for.

function Test-Administrator  
{  
    $user = [Security.Principal.WindowsIdentity]::GetCurrent();
    (New-Object Security.Principal.WindowsPrincipal $user).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator)  
}

$Data = @("C:\Temp", "E:\BookShare\BooksCollection", "C:\Unicorns") #User must populate this!
$Version = "0.3.2"
$7Zip = $false
$7z = "C:\Program Files\7-Zip\7z.exe"
$DataSize = 0
$AtLeastOneFolderIsFound = $null
Clear-Host
Write-Host "--==<(#####################)>==--" -ForegroundColor Green
Write-Host "   Custom backup script v$Version"
Write-Host "         By Dysthymia"
Write-Host "--==<(#####################)>==--" -ForegroundColor Green
Write-Host ""
Write-Host "Checking prerequisites..."
If (-not (Test-Administrator)) {
    Write-Host "Script not running in an administrator PowerShell session." -ForegroundColor Red
    Write-Host "Please run PowerShell as administrator before running the script."
    Write-Host "Exiting."
    Exit
} Else { Write-Host "Script running in an administrator PowerShell session." -ForegroundColor Green }
If (Test-Path $7z) {
    Write-Host "7-Zip is accessible." -ForegroundColor Green
    $7Zip = $true
} Else { Write-Host "7-Zip is not accessible." -ForegroundColor Red 
        $7Zip = $false
    }
Write-Host "This script depends on the user to first define a list of folder paths they want to be backed up. If you haven't already done this, please edit the script's `$Data variable on line 15."
Write-Host "Evaluating combined data size..."
forEach ($Folder in $Data) { #ForEachDataFolderOpen
    If (Test-Path $Folder) {
                                Write-Host $Folder 
                                $colItems = (Get-ChildItem $Folder -recurse | Measure-Object -property length -sum -ErrorAction Stop)
                                $MFolderSize = ($colItems.sum / (1024*1024*1024))
                                $DataSize += $MFolderSize
                                $AtLeastOneFolderIsFound = $true
    } Else { Write-Host "$Folder not found!" -ForegroundColor Red }
                              } #ForEachDataFolderClose
    If ($null -eq $AtLeastOneFolderIsFound) {
        Write-Host "No defined folders were found." -ForegroundColor Red
        Write-Host "Please edit the script and define the paths you want to be backed up using the `$Data variable on line 15."
        Write-Host "Exiting."
        Exit
    }
$DataSize = [math]::Round($DataSize,2)
Write-Host "Total data size is $DataSize GB."
Write-Host "(Example backup targets could be E:\, J:\Backup, etc. An all-encompassing timestamped folder will be created there.)"
$BackupTarget = "Z:\NotAFolder\Nope\Aaaaaaaaaaaaaaah"
While (-not (Test-Path $BackupTarget)) { $BackupTarget = Read-Host "Please enter the path of the target for the backup." }
If ($BackupTarget -like "C:\") { Write-Host "A target on the same disk as the data itself does not safeguard the data. Please consider copying the completed backup to a separate disk." -ForegroundColor Yellow }
Write-Host "$BackupTarget located. Determining free space..."
$BackupPath = $BackupTarget
$BDrive = $BackupTarget[0]
$Drive = New-Object System.IO.DriveInfo "$BDrive"
$FreeSpace = [math]::Round($Drive.AvailableFreeSpace / 1GB, 2)
Write-Host "Backup target free space is $FreeSpace GB."
If ($FreeSpace -lt $DataSize) {
    Write-Host "Insufficient space available on the backup target." -ForegroundColor Red
    Write-Host "Exiting."
    Exit
} Else { Write-Host "The backup target can accommodate the backup." -ForegroundColor Green }
#Can we compress? Then offer the option and select the compression level
If ($7Zip) {
    do { $Compress = Read-Host "Compress the backup? (y/n)" } while (($Compress -ne 'n') -and ($Compress -ne 'y'))
    if ($Compress -eq 'y') {
        Write-Host "Note that compression will increase backup time proportionally to the data size and compression level." -ForegroundColor Yellow
        Write-Host "If we compress the files, then instead of using robocopy we'll create an archive for each folder getting backed up."
        Write-Host "Enter 0 here to abandon compression and copy the data instead." -ForegroundColor Green
        do { $CompressionLevel = Read-Host "Input an integer from 1 to 9 for the compression level" } 
        until ($CompressionLevel -match '^[0-9]$')
        if ($CompressionLevel -eq 0) { 
            $Compress = 'n' 
            Write-Host "Compression option aborted." -ForegroundColor Green
        } 
    }
}
Write-Host "We're not checking if any files are in use. If they are, the backup could fail." -ForegroundColor Red
do { $Proceed = Read-Host "Proceed with the backup now? (y/n)" } while (($Proceed -ne 'y') -and ($Proceed -ne 'n'))
If ($Proceed -eq 'n') { 
    Write-Host "Abandoning backup. Exiting."
    Exit
} Else { #DoTheBackupOpen
########################################################################################
# Actual backup operations go here (Down) ##############################################
########################################################################################
Write-Host "Backup started." -ForegroundColor Green
$Date = (Get-Date -Format "yyyy-MM-dd HH.mm")
$BackupFolderName = "Backup "
$BackupFolderName += $Date
$BackupTarget = Join-Path $BackupTarget -ChildPath $BackupFolderName
    #Write-Host "[Diagnostic NFO] `$BackupTarget variable is $BackupTarget"
    #Write-Host "[Diagnostic NFO] `$BackupFolderName variable is $BackupFolderName"
New-Item -Path "$BackupPath" -Name "$BackupFolderName" -ItemType Directory
#So, $BackupPath is what was originally input and $BackupTarget includes the timestamped folder that contains the entirety of the backup.
$LogFile = Join-Path $BackupTarget -ChildPath "BackupLog.txt"
New-Item "$LogFile" -ItemType File
Add-Content "$LogFile" "Alex's backup script version $Version"
Add-Content "$LogFile" "Backup job started $Date. Backing up the following items:"
Add-Content "$LogFile" $Data
Add-Content "$LogFile" "Total backup size is $DataSize GB, target $BackupTarget has $FreeSpace GB available."
Add-Content "$LogFile" "##########################################################"
If ((-not $7Zip) -or ($Compress -eq 'n')) { #CopyDontCompressOpen
    foreach ($Folder in $Data) { #FolderLoopOpen
        $FolderName = $Folder.Replace(":", ".").Replace("\", ".")
        $BackupJob = Join-Path $BackupTarget -ChildPath $FolderName
        $FolderDate = (Get-Date -Format "yyyy-MM-dd HH:mm")
        If (Test-Path $Folder) { #SourceFolderExistsOpen
            Add-Content "$LogFile" "Backing up $Folder $FolderDate."
            robocopy $Folder $BackupJob /e /copy:DAT /mt:16 /r:3 /w:1
        } #SourceFolderExistsClose
        Else {
            Write-Host "$Folder not found." -ForegroundColor Red
            Add-Content "$LogFile" "$Folder not found. Skipping it."
        }
    } #FolderLoopClose
} #CopyDontCompressClose
    Else { #Compress_Dont_CopyOpen
        ###
        ######## 
        ######################
        #####################################################
        foreach ($Item in $Data){ #CompressLoopOpen
            If (-not (Test-Path $Item)) {
                Write-Host "$Item not found." -ForegroundColor Red
                Add-Content "$LogFile" "$Item not found. Skipping it."
            } Else { #FolderExistsCompressItOpen
                $ItemName = ($Item.TrimEnd('\') -replace '[:\\]', '_')
                $ArchivePath = Join-Path $BackupTarget -ChildPath "$ItemName.7z"
                Write-Host "[Diagnostic NFO] `$ArchivePath variable is $ArchivePath"
                Write-Host "[Diagnostic NFO] `$ItemName variable is $ItemName"
                $Date = (Get-Date -Format "yyyy-MM-dd HH.mm")
                Add-Content "$LogFile" "Compressing $Item $Date"
                Write-Host "Compressing $Item..."
                $Arguments = @('a', '-t7z', "-mx=$CompressionLevel", '-bso0', '-bsp1', "$ArchivePath", $Item)
                & $7z @Arguments
                $ExitCode = $LASTEXITCODE
                if ($ExitCode -gt 1) { #Failure!
                    $Date = (Get-Date -Format "yyyy-MM-dd HH.mm")
                    Add-Content "$LogFile" "Error compressing $Item $Date, exit code $ExitCode)."
                    Write-Host "Error compressing $Item, exit code $ExitCode)."
                } Else { #Success!
                    #$Date = (Get-Date -Format "yyyy-MM-dd HH.mm")
                    #Not adding this to the log file as the next item is timestamped.
                    Write-Host "Compressed $Item successfully." -ForegroundColor Green
                }
            } #FolderExistsCompressItClose
        } #CompressLoopClose
        #####################################################
        ######################
        ########
        ###
    } #Compress_Dont_CopyClose
########################################################################################
# Actual backup operations go here (Up) ################################################
########################################################################################
} #DoTheBackupClose
$Date = (Get-Date -Format "yyyy-MM-dd HH.mm")
Add-Content "$LogFile" "Backup completed $Date"
Write-Host "Backup complete."