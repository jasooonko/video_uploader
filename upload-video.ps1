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


function print($msg){
    write-host $msg -foreground yellow
    $global:message += $msg + "`n"
}

$global:message = ""

# -------------------------------------------------------------------
# if $inbox contains directories, merge all mts within the directory
# -------------------------------------------------------------------

$directories  = Get-ChildItem $inbox | ?{ $_.PSIsContainer }
foreach($dir in $directories){
  print("Directory found: $dir")
  $files = ls $dir.fullname/*.mts |sort Name
  $file_list = ''
  foreach($file in $files){
    $file_list = $file_list + $file.name + '+'
  }
  $file_list = $file_list.Substring(0,$filelist.Length-1)
  print("Merge: $file_list")
  $export_mts = "$inbox" + $dir.name + ".mts"
  cd $dir
  copy /b $file_list $export_mts 
}

# ------------------------------------------------------------------
# Process MTS files inside $inbox
# ------------------------------------------------------------------

$files = ls $inbox\*.mts
#$files = ls $short_term\*.mts
if ( $files -eq $null){
    print("No file in inbox: $inbox")
} 
else{
    print("The following files has been transcoded and is in the process of being uploaded to Vimeo")
    foreach($file in $files){
        $year = $file.CreationTime.Year
        $mts = $file.name
        $mp4 = ($file.name).replace('.mts','.mp4').replace('.MTS','.mp4')
        print("$inbox\$mts")
        move-item $inbox\$mts $short_term -force

        "Transcode mts to mp4"
        &$handbrake -i $short_term\$mts -o $short_term\$mp4 --preset="Universal"
        if($LastExitCode -ne 0){ print("Transcode file failed: $mts")}

        "Move file around"
        if((Test-Path $long_term\$year) -eq $false){
            md $long_term\$year
        }
        cp $short_term\$mp4 $long_term\$year\$mp4 -force
        mv $short_term\$mp4 $dropbox\$mp4 -force
        rm $short_term\$mts -force -whatif
    }
}


# ------------------------------------------------------------------
print("`nClean Up...")
# ------------------------------------------------------------------

function delete_old_file($folder, $days_since_creation){

    $files = ls $folder
    if($files -eq $null){
        print("No file to deleted in: $folder")
    }
    else{
        print("File found in: $folder")
        foreach($file in $files){
            if($file.creationtime -lt (get-date).adddays(-$days_since_creation)){    
                print(" - Delete: " + $file + " (created:" + $file.creationTime + ")")
                rm $file -force 
            }
            else{
                print(" * Ignored: " + $file + " (created:" + $file.creationTime + ")")
            }
        }
    }
}
delete_old_file $short_term $delete_shortterm_days
delete_old_file $dropbox $delete_dropbox_days

# ------------------------------------------------------------------
# Check dropbox folder size
# ------------------------------------------------------------------
$dropbox_size = [int]((ls $dropbox -r -force| Measure -property Length -sum).sum /1024/1024)
print("`nCurrent dropbox folder size: $dropbox_size MB")


# ------------------------------------------------------------------
# Send Notification & write log
# ------------------------------------------------------------------
$global:message > $log_file
#write-host $global:message
.\send-mail.ps1 $emails "Newtown Video Transcode Status" $global:message
