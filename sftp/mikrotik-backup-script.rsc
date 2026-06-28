### Set local variables. Change the value between "" to reflect your environment.
:local ftpserver "n100d"
:local username "ftp-files"
:local password "ftp-files"

### Set Local and Remote Filename variables.
### "local file name" is always the same to avoid filling up flash storage.
### "remote file name" uploaded to SFTP server includes the date.
:local hostname [/system identity get name]
:local date ([:pick [/system clock get date] 0 4] \
  . [:pick [/system clock get date] 5 7] \
  . [:pick [/system clock get date] 8 10])
:local localfilename "$hostname-Backup-Daily"
:local remotefilename "$hostname-$date"

### Enable for debug by removing the leading # from the following lines
#:log info "$localfilename"
#:log info "$remotefilename"
#:log info "$hostname"
#:log info "$date"

:log info "Backup STARTING BACKUP"

### Create backup file and export the config.
export compact file="$localfilename"
/system backup save name="$localfilename"
:log info "Backup Backup Created Successfully"

### Upload .backup file to SFTP server.
/tool fetch address=$ftpserver port=2222 src-path="$localfilename.backup" \
  user=$username mode=sftp password=$password \
  dst-path=("upload/" . $remotefilename . ".backup") upload=yes
:log info "Backup Config Uploaded Successfully"

### Upload .rsc file to SFTP server.
/tool fetch address=$ftpserver port=2222 src-path="$localfilename.rsc" \
  user=$username mode=sftp password=$password \
  dst-path=("upload/" . $remotefilename . ".rsc") upload=yes
:log info "Backup Backup Uploaded Successfully"

:delay 2

### Delete local copies after upload.
/file remove "$localfilename.backup"
/file remove "$localfilename.rsc"
:log info "Backup Local Backup Files Deleted Successfully"

:log info "Backup BACKUP FINISHED"
