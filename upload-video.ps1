# Read config file
[xml]$conf=Get-Content .\config.xml

# Setup Variable
$inbox = $conf.config.inbox_location
$dropbox = $conf.config.dropbox_location
$short_term =  $conf.config.short_term_archive_location
$long_term = $conf.config.long_term_archive_location
$handbrake = $conf.config.handbrakecli_location
$emails = $conf.config.notification_emails


$message = ""
$files = ls $inbox
if ( $files -eq $null){
    $message = $message + "No file found in inbox location"
}
else{
    $message = $message + "Process file: $files" 
}

write-host $message
