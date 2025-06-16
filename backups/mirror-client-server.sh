# This script synchronizes and mirrors client and server, so that you can use the same files on any machine you work on.
# Server is initial in the lead. Server will be called first by copying all files newer than what is local.
# Once that is done, the client is checked for discrepancies. 

# Rules:
# 1: Files deleted on another client, should also be deleted on this client.
# 2: Files newer than what is on the server, should be copied to the server (standard rsync option)
# 3: Files deleted locally should also be deleted remote

# The problem: 
# - The linux file-system does not keep history of file deletions.

# To solve this problem, the following is done:
# - All clients create a deletion log in the folder /.deleted/, which is uploaded on sync
# - State is maintained in ./.backups, with logs per destination folder

# Limitations of this version
# - If the destination folder is used multiple times in this script, for different 


# To execute rule 1, and to create a deletion log, the following is done:
# 1: The client first assures it has all files from the server, based on an "outdated" state
# 2: The client downloads the /.deleted folder from the server and assures all deleted files are indeed deleted
# 3: Once the client is up to date it will dry-run a backup to the server, 
#    - This is to let rsync report all files it will delete on the server, based on deletions locally
# 4: The result of that dry-run  is stored in a new "deleted-YYYYMMMDDD-HHMM" file in the loal /.deleted/ folder 
# 5: The content of /.deleted/ is then copied to the server on sync
# Thus the server (and all other clients) has all information on what files were deleted locally. 

# ================================================================================
# This script uses basic functionalities of the Linux Bash commands,
# As that framework is mature enough to do almost everything you can imagine
# No dependencies on fancy libraries.

# WORK IN PROGRESS, NOT TESTED

# https://www.ubuntumint.com/systemd-run-script-on-shutdown/
# To run the script right before the system powers off, 
# you need to place the script in the /usr/lib/systemd/system-shutdown
# System sleep has same: /usr/lib/systemd/system-sleep

# So script needs to be of following components
# Setup script to: 
# 1: Copy main backup script to include in all local scripts, to assure one behavior only
# 2: Copy sleep and shutdown scripts, to backup computer on sleep and shutdown - Let them notify user!
# 3: Copy chron-script to chron, to start chron job every X hours
# 4: Create a .backup.config file in ~/ Home directory, for the user to fill in.

# The user needs to:
# 1: Modify the backup.config to state which folders need to be backed up
# 2: Be able to run a testrun of the full backup, with clear feedback on the job
# 3: Be able to indicate what backup it wants to run/test from the list

# The backup.config file 
# Can have lines that are comments. These lines will be ignored when reading line by line

# Using a wnotify : notify-send "Notification" "Long running command \"$(echo $@)\" took $(($(date +%s) - start)) seconds to finish"
# https://askubuntu.com/questions/409611/desktop-notification-when-long-running-commands-complete

# Local
gl_backupLogDir="./.backups"
gl_mostRecentBackupFile="$gl_backupLogDir/.mostrecentbackup"

gl_into_warning="
Brief intro:
==========================
This backup will mirror source and destinaion.
- Files deleted on the destination will also be deleted locally
- Files deleted locally will be deleted remotely
- Files updated on the server will be updated locally, and the other way around.

It can be used to:
- Share local mirrored folders between project members
- Work from multiple machines, with an exact mirror of all files as long as the software runs
- Backup your work

Running a Time Machine backup
===========================
To keep all files on the backup-location, consider running a Time Machine backup. 
This will save a state of your folders, in specific time slots. 

How this mirror-backup works
===========================

1: Identifiers:
===============
Each backup requires an identifier, so the system knows what logs to query.

2: Local deletes:
=================
To keep track of local deletes, 
the mirror-backup will first do a dry run to the destination.
This to compare the source-state with that of the destination.
All files missing in the source, will be marked as "deleted".

3: First run:
=============
On first run, it will copy all files from destination to source, 
to assure your source has all files already backed up, 
and to avoid the system to think that all files have been deleted locally.

After this first run, it will start the mirroring, making your source leading.

4: Successive runs:
===================
Each successive run will first download the list of deleted files from the destination.
Using this list, it will delete everything that was deleted from the destination.

Once your source is up to date, the system will start file-mirroring 
source and destination.

Source already a copy from destination?
=======================================
If you are 100% sure your source is 100% the same as the destination, 
and that the destination mirrors your source, you can run the intial setup.

    Local and remote deletes will be undone:
    =======================================
    Keep in mind that deletes will be undone if these files 
    still exist in the destination or on the source.

    Best solution: choose one and start fresh:
    ==========================================
    To assure you do not undo deletes, choose which version is leading and start from there.
    Leave either the original source or orignal destination as a backup.

WARNING: Tested, but not produciton ready:
==========================================
While tested, this code is not production ready. 
This means that use is for your own risk.

It also means that you should always run a separate backup 
to assure that you can recover your work in case this code messes things up.

Usage:
======
runMirrorBackup 'backup-id' 'your/source/dir/' 'your/destination/dir/' 'yourfolder' 

To run the mirror-backup without this warning, add 'no-warning' as the 5th parameter
To run the mirror-backup without this warning and confirm, add 'no-confirm' as the 5th parameter

Chron-job:
==========
To run the mirror-backup every hour, day, week, or to change your Chron-settings, run:

sudo runMirrorBackup 'configure-chron'

"

downloadDeletedList(){
    # Cases we cover
    # - Destination can be updated from multiple sources
    # - Source can run out of sync due to this
    # - Files on this source (s1), might have been deleted from another source (s2) since

    # Precondition: 
    # - We already checked if the sourcedir and dest dir have trailing slash

    sourceDir="$1"      # has trailing /
    destinationDir="$2" # has trailing /


    # Copy .deleted/ log from server to client, so we know what the status is on that
    rsync -aruvP "$destinationDir.deleted/" "$sourceDir.deleted/"
    # We will first cleanup this source

}

deleteFilesInDeletedFilesLog(){

    sourceDir="$1" # Has trailing slash
    deleteLog_FileName="$2"

    foldersDelCount=0
    fileDelCount=0
    foldersAlreadyDeletedCount=0
    fileAlreadyDeletedCount=0
    totals=0

    cat "$deleteLog_FileName"|
    while IFS= read -r line
    do
        # line reads: "deleted folder/filename"
        # Remove "deleted "
        fileName=${line:9} # hardcoded length is tricky. What if different implementation. Better is to find first space
        fullPath="$sourceDir$fileName"

        # Check if file exists
        if [ -f "$fullPath" ]
        then
            fileDelCount=$( fileDelCount+1 )
            echo "- remove file     : $fullPath"
            #rm "$fullPath" # remove all content 
        else
            fileAlreadyDeletedCount=$(( fileAlreadyDeletedCount+1 ))
        fi

        if [ -d "$fullPath" ]
        then
            foldersDelCount=$(( foldersDelCount+1 ))
            echo "- remove dir      : $fullPath"
            #rm "$fullPath" # remove all content 
        else
            foldersAlreadyDeletedCount=$(( foldersAlreadyDeletedCount+1 ))
        fi
    done 

    # Scoping issue. All report 0
    # echo "Total delete-references $totals"
    # echo "We deleted $fileDelCount files and $foldersDelCount folders"
    # echo "Files already deleted: $fileAlreadyDeletedCount. Folders already deleted $foldersAlreadyDeletedCount"
    # Open file from /.deleted
    
    # Read theough each line, and delete the associated file if it exists

}

executeDestinationDeletions(){
    sourceDir="$1"      # has trailing /
    identifier=$2

    # Most recent date?
    mostRecentBackupDate="0000000000" # Do all files

    # Do we have a most recent backup date?
    if [[ -f "$gl_mostRecentBackupFile-$identifier" ]]
    then
        # Get date of most recent backup
        mostRecentBackupDate=$(<"$gl_mostRecentBackupFile-$identifier")
    fi
    
    compareString="deleted-$mostRecentBackupDate"
    # Go through /.deleted lists from server
    # - This is a log of all files delted from the server by rsync
    # - As time passes, this list will increase
    # - We will keep a local score on what date/time the last check was, 
    #   so we only do from most recent to that point

    echo "=============================="
    echo "Execute all deletions, after : $mostRecentBackupDate"
    echo "Using compare-string         : '$compareString'"

    find "$sourceDir.deleted/" -print0 |
    while IFS= read -r -d '' deleteLog_FileName
    do
    
        # Compare file with comare string
        if [ "$deleteLog_FileName" \> "$sourceDir.deleted/$compareString" ]
        then
            echo "========="
            echo "Execute : $deleteLog_FileName"
            echo "========="
            deleteFilesInDeletedFilesLog "$sourceDir" "$deleteLog_FileName"
        fi
        
    done 

    # Store "downloaded" in "mostrecentbackup" somewhere our sync script will not backup
    # For instance where the script itself lives 
    # This will also update the date of the file

    # Done. The local client is now synchronized

}

runFirstTime(){
    sourceDir="$1"      # has trailing /
    destinationDir="$2" # has trailing /
    identifier="$3"

    echo "=============================="
    echo "Check if this is first run for: $sourceDir"
    # Check "doanloaded" log file
    # Older than a day? This machine is probably out of sync. Get server data

    if [[ -f "$gl_mostRecentBackupFile-$identifier" ]]
    then
        echo "We already initiated this location, no action taken"
    else
        echo "This is the first run. Download all files from server."
        # Copy from server to client.
        rsync -aruvP "$destinationDir" "$sourceDir"
        # We do NOT delete local files that are not present on server 
    fi
  
}

mirrorClientToServer(){
    # Cases we cover
    # - Destination can be updated from multiple sources
    # - Source can run out of sync due to this
    # - Files on this source (s1), might have been deleted from another source (s2) since

    # Precondition: 
    # - We already checked if the sourcedir and dest dir have trailing slash
    # - We already removed the files that are in our .deleted/ logs
    #   So that our system is reflecting the server PLUS possible local changes and additions

    # Next steps:
    # - None in code

    # Now we can make the backups

    sourceDir="$1"      # has trailing /
    destinationDir="$2" # has trailing /
    identifier="$3"

    # Where do we store the logs?

    # https://askubuntu.com/questions/706903/get-a-list-of-deleted-files-from-rsync

    # Step 1: Determine what files were deleted locally, by running a compare with the server
    date=$(date '+%Y-%m%d-%H%M%S')                # Date/time of logging
    deletedLogFile="$sourceDir.deleted/deleted-$date.txt"  # File to store compare in
    outgoingLogFile="$gl_backupLogDir/$date-out.txt"
    incomingLogFile="$gl_backupLogDir/$date-in.txt"

    # Assure the logging-directories are there
    mkdir -p "$sourceDir.deleted"
    mkdir -p "$gl_backupLogDir"

    # Remove empty files
    find "$sourceDir.deleted/" -type f -size -10c -delete
    # when a backup did not lead to deletes, the file is empty
    # -size -10c = any file less than 10 bytes will be deleted

    # Do a dry-run of rsync to get list of locally deleted files. 
    rsync --dry-run --delete -ar --info=DEL  "$sourceDir" "$destinationDir" >> "$deletedLogFile"
    # --info=DEL  : Only register/log locally deleted files.
    # >> $deletedLogFile : Store result of dry run in deletedLogFile location

    # Step 2: Run sync process, 
    # - Copy all changes from local to server.
    # - Delete all files on the server, that were deleted on the client
    # - Then read the server, and delete all local files no longer present on the server
    # - If several users work in the same folder (team) then the team is always syncrhonized

    # We assume that a time-machine backup is running on the server, to safeguard accidental deletes 

    # Step 2.1: First update server, delete locally deleted files also on destination 
    rsync --delete -aruvP --info=BACKUP "$sourceDir" "$destinationDir" >> "$outgoingLogFile"
    # This assures that files we removed from source are also removed on the destination, 
    # before dowloading all changes from the server 

    # Step 2.2: Then update client, delete files in source that were deleted on the destination
    rsync --delete -aruvP --info=BACKUP "$destinationDir" "$sourceDir" >> "$incomingLogFile"
    # -aruvP = archive with creation / modify dates intact, recursive, only updates, P
    # --info=BACKUP = only log files backed up

    # In theory we already removed all destination-deleted files in source
    # But as this is a standard flag on rsy# -aruvP = archive with creation / modify dates intact, recursive, only updates, Pnc we use --delete as a double measure 
    
    # Step 3: Rgister the date of this most recent backup
    echo "$(date '+%Y-%m%d-%H%M%S')" > "$gl_mostRecentBackupFile-$identifier"
}

runMirrorBackup(){
    identifier="$1"
    sourceDir="$2"
    destinationDir="$3"
    destinationFolder="$4"
    runWithoutConfirm="$5"
    
    
    echo "
RUN MIRROR-BACKUP:
==================
Backup-ID : '$identifier'
From      : $sourceDir
To        : $destinationDir
Into      : '$destinationFolder'"

    # Skip this if the user states "no confirmation needed"
    if [[ "$runWithoutConfirm" != "no-confirm" ]]
        then 

        if [[ "$runWithoutConfirm" != "no-warning" ]]
        then # Run warning

        # Tell the user what is going to happen.
            echo "$gl_into_warning"
            echo "
Your settings:
==============
Backup-ID : '$identifier'  - Changing this ID will initiate the first run again.
From      : $sourceDir
To        : $destinationDir
Into      : $destinationFolder
"
        fi

        # Ask for confirmation
        read -p "Continue? (Y/N): " confirm

        if  [[  $confirm == [nN] ]]
        then # No: exit
            echo "You stopped the backup
Exiting."
            return
        fi
    fi

    echo ""
    echo "Starting the backup"  

    if  [[ "$sourceDir" != *"/" ]]
    then 
        echo "ERROR: The source dir should end with a /"
        return
    fi

    if  [[ "$destinationDir" != *"/" ]]
    then 
        echo "ERROR: The dest dir should end with a /"
        return
    fi

    if  [[ ! -d "$sourceDir" ]]
    then 
        echo "ERROR: The source dir does not exist. Exit backup."
        return
    fi
    if  [[ ! -d "$destinationDir" ]]
    then 
        echo "ERROR: Desitnation dir does not exist. 
The backup can only be made to an existing location. Exit backup."
        return
    fi

    # Assure the destination folder exists
    destination_Dir="$destinationDir$destinationFolder/"

    if [[ "$destinationDir" == "$sourceDir" ]]
    then 
        echo "ERROR: The backup folder cannot be the same as the source folder."
        return
    fi
    if [[ "$destination_Dir" == "$sourceDir" ]]
    then 
        echo "ERROR: The backup folder cannot be the same as the source folder."
        return
    fi

    if ! [[ -d "$destination_Dir" ]]
    then 
        echo "================================"
        echo "Creating the folder for the backup."
        mkdir -p "$destination_Dir"
    fi


    # Notify user https://ss64.com/bash/notify-send.html
    notify-send -t 5000 'Running backup' "Running the backup...."

    # We run this:
    # 1: When the user logs in
    # 2: Every X hours, based on a chron job

    # Step 1: Check if this is the first time for source, and take action
    runFirstTime "$sourceDir" "$destination_Dir" "$identifier"

    return

    # Step 2: Clean all remotely deleted files from here as well
    # So we stay in sync with remote source
    downloadDeletedList "$sourceDir" "$destination_Dir"
    executeDestinationDeletions "$sourceDir" "$identifier"
    # This also prevents a loop where we upload files that were deleted on the server

    # Step 3: Mirror client to server
    mirrorClientToServer "$sourceDir" "$destination_Dir" "$identifier"
    # destinationfolder is an identifier for the last download date/time

    notify-send -t 5000 'Done running backup' "All files are safe on server"

}

# Parameters are: 
# 1: Backup-ID - any string value to help you and the system to identify the backup, 
#    - for instance: "workfiles", "projects", "my-photos"
# 2: The path to the source that you want to backup
# 3: The path to the destination folder, in which to create the backup
#    - This folder has to exist.
# 4: The name of the folder in which to make the backup
# 5: If confoirm is needed. 
#    - 'no-confirm' will run the script without user confirmation - good for chron jobs
#    - 'no-warning' will ask for confirmation, but will not show the warning. 
#      Useful if you run several mirror-backups

runMirrorBackup "bckp-id-001" "./source/" "./backup/" "source" "no-confirm"
# This setup allows you to configure and manage multiple backups from one script
