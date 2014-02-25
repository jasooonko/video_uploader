# Parameters
$delete_dropbox_days = 7
$delete_shortterm_days = 30
$config_file = '.\config.xml'

# Setup Variable
[xml]$conf=Get-Content $config_file
$inbox = $conf.config.inbox_location
$dropbox = $conf.config.dropbox_location
$short_term =  $conf.config.short_term_archive_location
$long_term = $conf.config.long_term_archive_location
$handbrake = $conf.config.handbrakecli_location + "\HandBrakeCLI.exe"
$emails = $conf.config.notification_emails


$message = ""
$files = ls $inbox\*.mts
if ( $files -eq $null){
    $message = $message + "No file found in inbox locationi: $inbox"
}
else{
    foreach($file in $files){
        $mts = $file.name
        $mp4 = ($file.name).replace('mts','mp4')
        $mts
        $mp4
        $message = $message + "Process file: " + $mts + "`n"
        move-item $mts $short_term -whatif 
        
        # Transcode mts to mp4
        #$hadbrake -i $short_term\$mts -o $short_term\$mp4
        
        # Move file around
        #copy-item $short_term\$mp4 $long_term\$mp4 -whatif
        #move-item $short_term\$mp4 $dropbox\$mp4 -whatif
        #delete-item $short_term\$mts -force -whatif
    }
}

# Clean Up


# Send Notification

write-host $message
