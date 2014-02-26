# Parameters
$delete_dropbox_days = 7
$delete_shortterm_days = 30
$config_file = '.\config.xml'
$log_file = '.\transcode.log'

# Setup Variable
[xml]$conf=Get-Content $config_file
$inbox = $conf.config.inbox_location
$dropbox = $conf.config.dropbox_location
$short_term =  $conf.config.short_term_archive_location
$long_term = $conf.config.long_term_archive_location
$handbrake = $conf.config.handbrakecli_location + "\HandBrakeCLI.exe"
$emails = $conf.config.notification_emails


$global:message = ""
$files = ls $inbox\*.mts
#$files = ls $short_term\*.mts
if ( $files -eq $null){
    $global:message += "No file in inbox: $inbox`n"
} 
else{
    $global:message += "The following files has been transcoded and is in the process of being uploaded to Vimeo`n"
        foreach($file in $files){
            $folder = $file.CreationTime.Year
                $mts = $file.name
                $mp4 = ($file.name).replace('.mts','.mp4').replace('.MTS','.mp4')
                $mts
                $mp4
                $global:message += "$inbcx\$mts`n"
                move-item $inbox\$mts $short_term -force

                "Transcode mts to mp4"
                &$handbrake -i $short_term\$mts -o $short_term\$mp4 --preset="Universal"
                if($LastExitCode -ne 0){ $global:message += "Transcode file failed: $mts`n"}

            "Move file around"
                if((Test-Path $long_term\$folder) -eq $false){
                    md $long_term\$folder
                }
            cp $short_term\$mp4 $long_term\$folder\$mp4 -force
                mv $short_term\$mp4 $dropbox\$mp4 -force
                rm $short_term\$mts -force -whatif
        }
}


$global:message += "`nClean Up...`n"
function delete_old_file($folder, $days_since_creation){
    $files = ls $folder
        if($files -eq $null){
            $global:message += "No file to deleted in: $folder`n"
        }
        else{
            "files: $files in $folder"
            $global:message += "File found in: $folder`n"
            foreach($file in $files){
                if($file.creationtime -lt (get-date).adddays(-$days_since_creation)){    
                    $msg = " - Delete: " + $file + " (created:" + $file.creationTime + ")"
                        $msg
                        $global:message += "$msg`n"
                        rm $file -force 
                }
                else{
                    $msg = " + Ignored: " + $file + " (created:" + $file.creationTime + ")"
                    $msg
                    $global:message += "$msg`n"
                }
            }
        }
}
delete_old_file $short_term $delete_shortterm_days
delete_old_file $dropbox $delete_dropbox_days

# Check dropbox folder size
$dropbox_size = [int]((ls $dropbox -r -force| Measure -property Length -sum).sum /1024/1024)
    $global:message += "`nCurrent dropbox folder size: $dropbox_size MB"


# Send Notification & write log
    $global:message > $log_file
    write-host $global:message
    .\send-mail.ps1 $emails "Newtown Video Processing Status" $global:message
