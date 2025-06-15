# This script synchronizes and mirrors client and server, so that you can use the same files on any machine you work on.
# Server is initial in the lead. Server will be called first by copying all files newer than what is local.
# Once that is done, the client is checked for discrepancies. 

# Rules:
# 1: Files deleted on another client, should also be deleted on this client.
# 2: Files newer than what is on the server, should be copied to the server (standard rsync option)
# 3: Files deleted locally should also be deleted remote

# The problem: 
# - The linux file-system does not keep history of file deltions.
# To solve this problem, the following is done:
# - All clients create a deletion log in the folder /.deleted/, which is uploaded on sync


# To execute rule 1, the following is done:
# 1: The client downloads the /.deleted folder from the server and deletes all files listed, if they exist
# 2: Once the client is up to date it will dry-run a backup to the server, 
#    - This is to let rsync report all files it will delete on the server, based on compares of local and remote
# 3: The result of that dry-run compare is stored in a new file in the loal /.deleted/ folder 
# 4: The content of /.deleted/ is then copied to the server on sync
# Thus the server has all information on what files were deleted locally. 

# ================================================================================
# This script uses basic functionalities of the Linux Bash commands,
# As that framework is mature enough to do almost everything you can imagine
# No dependencies on fancy libraries.

# WORK IN PROGRESS, NOT TESTED
deleteFilesInDeletedLog(){

    deletedLogFileName="$1"

    # Open file from /.deleted
    
    # Read theough each line, and delete the associated file if it exists

    

}

deleteDeletedFiles(){

    # Go through /.deleted lists from server
    # - This is a log of all files delted from the server by rsync
    # - As time passes, this list will increase
    # - We will keep a local score on what date/time the last check was, 
    #   so we only do from most recent to that point

    find "$sourceDire/.deleted"  anything atfter given date |
        while IFS= read -r -d '' file
        do
            deleteFilesInDeletedLogFile "$file"
        done
}

downloadDeletedListAndSynchronizeLocalDirs(){

    sourceDir="$1"
    destinationDir="$2"

    # Check "doanloaded" log file
    # Older than a day? This machine is probably out of sync. Get server data

    # Copy from server to client.
    # Do NOT delete local files not present on server
    downloaded= rsync -aruvP --info=ALL0,DEL "$destinationDir/.deleted" "$sourceDir"

    # Get date of "most recent bakup" file
    mostRecentBakcupDate=

    deleteDeletedFiles "$mostRecentBakcupDate"
    # Store "downloaded" in "mostrecentbackup" somewhere our sync script will not backup
    # For instance where the script itself lives 
    # This will also update the date of the file

    # Done. The local client is now synchronized

}

updateOutdatedClient(){
    sourceDir="$1"
    destinationDir="$2"

    # Check "doanloaded" log file
    # Older than a day? This machine is probably out of sync. Get server data

    # Copy from server to client.
    # Do NOT delete local files not present on server
    downloaded= rsync -aruvP --info=ALL0,DEL "$destinationDir/.deleted" "$sourceDir"    
}

mirrorClientToServer(){
    # We already removed files that were also removed from the server
    # So our system is reflecting the server PLUS possible local changes anmd additions

    # Now we can make the backups

    sourceDir="$1"
    destinationDir="$2"

    # https://askubuntu.com/questions/706903/get-a-list-of-deleted-files-from-rsync

    # First determine what files WE will delete on the server, before doing anything
    filesToBeDeleted=rsync --dry-run --delete -aruvP --info=ALL0,DEL  "$sourceDir" "$destinationDir"

    # Store filesToBeDeleted as a file in local $sourceDir/.deleted and let sync process copy it to the server
    COde here

    # Run sync process, 
    # - Copy all changes from local to server.
    # - Delete all files on the server, that were deleted on the client
    # - Then read the server, and delete all local files no longer present on the server
    # - If several users work in the same folder (team) then the team is always syncrhonized

    # We assume that a time-machine backup is running on the server, to safeguard accidental deletes 

    # Update server, delete deleted files there as well
    rsync --delete -aruvP "$sourceDir" "$destinationDir"

    # Update client, delete files that were deleted on the server since last time
    rsync --delete -aruvP "$destinationDir" "$sourceDir"

}

runBackup(){
    sourceDir="$1"
    destinationDir="$2"

    # We run this:
    # 1: When the user logs in
    # 2: Every X hours, based on a chron job

    # Step 1: Check if we are out of date, and take action
    updateOutdatedClient "$sourceDir" "$destinationDir"

    # Step 2: Clean all remotely deleted files from here as well
    # So we stay in sync with remote source
    downloadDeletedListAndSynchronizeLocalDirs "$sourceDir" "$destinationDir"
    # This also prevents a loop where we upload files that were deleted on the server

    # Step 3: Mirror client to server
    mirrorClientToServer "$sourceDir" "$destinationDir"
}
