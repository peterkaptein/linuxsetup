# RSYNC
# https://download.samba.org/pub/rsync/rsync.1
# COPY 
# https://man7.org/linux/man-pages/man1/cp.1.html
# FIND
# https://man7.org/linux/man-pages/man1/find.1.html
# https://snapshooter.com/learn/linux/find

# ABOUT
# ============================================================
# This script makes a Time Machine like backup of all files in the given directories.
# Based on the timeslots you define, backups can be dayly, weekly, hourly and so on.
# Backups are based on symbolic links to the actual files.
# Each version of the file is only stored once, based on the time-stamp it has.
# A new time stamp is also a new file version.

# Using symbolic links for this purpose 
# - is not new or revolutionary.
# - Saves an immense amount of space, while creating a "Time machine" for all your data in the backup, 
# Using symbolic links assures that each time-based backup acts like it is the real thing.
# Assure to:
# 1: make a full backup from time to time.
# 2: NOT delete any of the backups in the "timemachine" folder.
# Here is why: If you delete a folder that contains the concrete file, 
# then the symbolic link will be broken, and your backup of that file is broken as well


# RUNNING THE TIME MACHINE
# ============================================================
# We run: makeTimeMachineBackup at the end of this file, 
# - using mySourceDirNames as input

# MAIN SETTINGS:
# =============================================================
# What sub-directories do we backup from the directory this file is in?
mySourceDirNames=("source" "3D") # Array, separated with spaces: ("sourcedir1" "sourcedir2")

# =============================================================
# Variables from system
weekNumber=$(date +%U) 
year=$(date +%Y)

# Where do we start from?
myBaseDirectory="$(pwd)" # pwd is the path that this file is in.

# SECONDARY DEFINITIONS
# ==============================================================
# You can leave this as is, to run the Time Machine.


# Definition of time slots. One option for now. 
# Arrays make it possible to do dayly, weekly and monthly. Not implemented yet
# We use the directory this script is in as a base,
# so you can create multiple time machines by copying this file into other directories 
myCurrentTimeSlot="week/$year-$weekNumber"
myTimeMachineFolder="$myBaseDirectory/timemachine/"

# Subfolders to make the backups in. No need to change this. Unless you feel like.
myBackupFolder="$myTimeMachineFolder/$myCurrentTimeSlot-snapshot"
myCurrentSnapshot="$myTimeMachineFolder/00-currentsnapshot"

# Current Snapshot contains the most recent backup state. 
# This simplifies the code, as we do not need to keep track 
# of what is the most recent backup.

# Current Snapshot assures that we can make multiple backups
# Of the same data (daily, weekly, etc), using symbolic links only

# How it works:
# Each new timeslot first gets a copy of all the links in the current snapshot
# Then we update the timeslot, and copy the symbolic links from the new state 
# into Current Snapshot

# Each symbolic link links directly to the actual file. No link-chaining.

# CODE
# ==============================================================
ensureDirForFileCopy() {
    # Parameter  based, like Bash-file. $1 is first item in input
    directoryAndFilename="$1" # based on input

    # Ensures a directory is there when needed
    # 1: Get path
    path=$(dirname "$directoryAndFilename") # Standard Bash function to get directory name fron string

    # 2: Create dir if not there yet
    mkdir -p "$path" # Recursive, so if parents are not there, they will be created as well
}

deleteEmptyFolders(){
    startDir="$1"

    # Find empty directories and delete them
    find "$startDir" -type d -empty -print # -delete
}

# Our time machine!
makeTimeMachineBackup(){

    mySourceDirName="$1" # The first parameter given in the function call. Find it at the end of this file
    mySource="$myBaseDirectory/$mySourceDirName"

    # Start of process
    echo "==================================================="
    echo "Copy from         : $mySource"
    echo "Copy to           : $myBackupFolder"
    echo "Snapshot dir      : $myCurrentSnapshot"

    if ! test -d $myBackupFolder
    then
        mkdir -p $myBackupFolder
    fi

    echo "Starting backup"
    echo "Make snapshot into: $myBackupFolder"
    echo "==================================================="
    echo "Check if snapshot dir exists"
    if test -d "$myCurrentSnapshot"
    then # We have done this before
        # 1: Copy snapshot
        echo "Snapshot dir exists: copy snapshot to $myBackupFolder"

        # Use last snapshot to fill the initial structure
        # This might include deleted files.

        # First time?
        # Create new dir and copy current snapshot
        if ! test -d "$myBackupFolder/$mySourceDirName"
        then
            echo "First time, full snapshot copy"
            rsync -aruvP -lHk "$myCurrentSnapshot/$mySourceDirName" "$myBackupFolder"
        else
            echo "Full snapshot copy already there, just update"
        fi

        echo "==================================================="
        # Step 2: Only copy newer files from source
        echo "Copy new and updated files "
        echo "from : $mySource "
        echo "into : $myBackupFolder"
        echo "======"
        # rsync will overwrite symbolic links as it checks filesize as well. 
        # CP will only look at date/time
        cp -aruv "$mySource" "$myBackupFolder"

        echo "Backup done of new and updated files."
        echo "==================================================="

        #2.1 Remove links to all deleted files from current backup folder
        echo "Cleanup: remove deleted files from $myBackupFolder"
        
        # We do not have records, so we need to check per file
        myDir="$myBackupFolder/$mySourceDirName"
        myBackupFolderLen=${#myDir}+1
        # Get all links in backup. New files we leave intact, as a safety measure
        # We do not yet clean up empty folders
        find $myBackupFolder  -type l -print0 |
        while IFS= read -r -d '' file
        do
            # Cut containing folder from string 
            fileName=${file:myBackupFolderLen}

            # Check if it exists in source
            if [ ! -f "$mySource/$fileName" ]; then
                echo "$mySource/$fileName does not exist"
                echo "Remove link: $fileName from backup"
                rm "$file"
            fi

        done   

        echo "Done with cleanup."

        # PART 3: UPDATE SNAPSHOT
        # What it covers:
        # 1: The new snapshot can contain both links to files backed up a while ago
        #    and concrete files the used created or updated recently
        # 2: The user might have deleted files and directories
        # 3: Folders in our current snapshot might be empty due to file-deletions

        # The current snapshot in our time machine 
        # is a MIRROR of  the current state of the directories we backup.

        # So we need to take 4 steps:
        # 1: Remove all deleted files from our current snapshot
        # 2: Copy all the existing symbolic links from the snapshot we made now
        # 3: Create new symbolic links from the concrete files we added to this snapshot
        # 4: Remove all the empty folders from our snapshot

        # But first we delete the old 00 snapshot data, so we have clean start

        echo "==================================================="
        echo "Update 00 snapshot"
        echo "1: Delete old snapshot in 00" # STep 1
        rm -r "$myCurrentSnapshot/$mySourceDirName"

        mkdir "$myCurrentSnapshot/$mySourceDirName"
        
        echo "2: Create new snapshot from $myBackupFolder/$mySourceDirName"

        myBackupFolderLen=${#myBackupFolder}+1
        
        echo "2.a: Copy all symbolic links to 00 snapshot" # Step 2
        # Copy all links verbatim, using rsync, so that we do not create new files
        # Or create symbolic links to symbolic links

        find "$myBackupFolder"  -type l -print0 |
        while IFS= read -r -d '' file
        do
            # Cut containing folder from string 
            fileName=${file:myBackupFolderLen}
            echo "- copy link  : $fileName"
            rsync -aruP -s --mkpath "$file" "$myCurrentSnapshot/$fileName"
        done    
        
        echo "2.b: Copy new and updated files as new links to 00 snapshot" # Step 3

        # Copy all new files as a link to snapshot, 
        # so that our snapshot is clean from real files
        find "$myBackupFolder"  -type f -print0 |
        while IFS= read -r -d '' file
        do
            # Work relative from startposition,  
            fileName=${file:myBackupFolderLen} # takes substring from given postion :myBackupFolderLen
            echo "- create link: $fileName"

            # Individual file copy is stupid and needs you to create the containing folder
            ensureDirForFileCopy "$myCurrentSnapshot/$fileName"
            cp -ar -s "$file" "$myCurrentSnapshot/$fileName" 
            # It would be nice if cp had a -mkpath flag like rsync has
        done   

        echo "2.c: Remove empty folders from snapshot, so next backup in new week is cleaner" # Step 4
        deleteEmptyFolders "$myCurrentSnapshot"
        # We can do this for the current backup, but the risk is that folders are removed that contain data
        # Now we will have empty folders in the previous backup, and a clean stucture in the next.
        # Better some empty directory dirt than accidental folder removal.

    else # First time ever!
        # Make first snapshot

        # Step 1: Make dir
        echo "First time: create dir for snapshot"
        mkdir -p "$myCurrentSnapshot" # -p is recursive. 

        # Step 2: Make first backup
        # No symbolic links!
        echo "Copy files to $myBackupFolder"
        cp -ar "$mySource" "$myBackupFolder/" # -ar = archive / keep date/time, and do copy recursive

        # Step 3: Make our first snapshot
        echo "Create snapshot"
        cp -ar -s "$myBackupFolder/$mySourceDirName" "$myCurrentSnapshot"
        # All symbolic links. Since we have no other data yet, this can be kept simple.

    fi

}

for sourcedir in ${mySourceDirNames[@]}
do
    echo  "$sourcedir"
    makeTimeMachineBackup "$sourcedir"
done



#cp -ar -s ./source/ $myBackupFolder

#/mnt/backup/peter/www/novascriber/novaeditor

# https://download.samba.org/pub/rsync/rsync.1

# BASIC BACKUP
# rsync -aruvP
# -a - Archive - keep dates of source file
# -r - recurse into directories (default)
# -u - Update only when source is newer
# -v - Verbose, show what you are doing
# -P - show --partial --progress


# MIRROR BACKUP
# A mirror backup reflects the source exactly. 
# - Files removed from source will also be removed from dest
#
# rsync -aruvP --delete
# -auvP - See basic backup for what it does
# --delete - delete extraneous files (files that do not exist on source) from dest dirs

# EXCLUDE FILES
# rsync --exclude

# Example: --exclude={'some/subdir/linuxconfig','some/other/dir','somedirname', '*.suffix'}

# CREATE TIME MACHINE LIKE BACKUP WITH SYMLINKS AND HARD LINKS
# cp --archive --recursive --symbolic-link
# OR: 
# cp -ar -s 

# -a - Archive - preserve all / preserve links as well
# -r - Recursive
# -s - Make symbolic link

# --keep-directory-symlink - follow existing symlinks to directories
# --preserve=links - included in -a

# rsync -lHk 
# -l    copy symlinks as symlinks
# -H    preserve hard links
# -k    causes the sending side to treat a symlink to a directory as though it were a real directory

# EXTRAS
# -n  - Dry run: perform a trial run with no changes made
# -q  - Run quietly, suppress non-error messages

# SSH KEY
# rsync -auvP --delete -e "ssh"
# -e "ssh" - Use SSH + key to authenticate
#
# How to generate SSH key (from local machine)
#  ssh-keygen -t ecdsa 
#  - ecdsa is identifier name of key file, 
#  - create several if you want to keep things separated (different parties)
#  - (enter enter) accept all defaults
#  - Key will contain name of local machine, and username

# Copy public key to server
#   scp ~/.ssh/id_ecdsa.pub yourname@yourserver:.ssh/authorized_keys 
#
# And done

