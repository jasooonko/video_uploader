# Parameters
$delete_dropbox_days = 7
$delete_shortterm_days = 30
$delete_log_days = 30
$config_file = '.\config.xml'
$log_folder = '.\log\'
$log_file = $log_folder + 'transcode-' + (get-date).toString('yyyyMMdd') + '.log'

$log_file

# Setup Variable
[xml]$conf=Get-Content $config_file
$inbox = $conf.config.inbox_location
$dropbox = $conf.config.dropbox_location
$short_term =  $conf.config.short_term_archive_location
$long_term = $conf.config.long_term_archive_location
$handbrake = $conf.config.handbrakecli_location + "\HandBrakeCLI.exe"
$emails = $conf.config.notification_emails
$cwd = pwd

function print($msg){
  $date = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
  write-host $msg -foreground yellow
  $global:message += "[$date] $msg" + "`n"
}

$global:message = ""

print("Process starts...")

# -------------------------------------------------------------------
# if $inbox contains directories, merge all mts within the directory
# -------------------------------------------------------------------

$directories  = @(Get-ChildItem $inbox | ?{ $_.PSIsContainer })
if($directories.length -gt 0){
foreach($dir in $directories){
  $dir_full = $dir.fullname
  $dir_name = $dir.name
  print("Directory found: $dir_full")
  $files = ls $dir_full/*.mts |sort Name
    $file_list = ''
    foreach($file in $files){
      $file_list = $file_list + $file.name + '+'
    }
    if($file_list.length -gt 0){
      $file_list = $file_list.Substring(0,$file_list.Length-1)
      print("Merge: $file_list")
      $export_mts = "$inbox" + $dir_name + ".mts"
      cd $dir_full
      cmd /c copy /b $file_list $export_mts
      cd $cwd
      if($LastExitCode -eq 0){
        mv $dir_full $short_term        
      }
      else{
        print("Something went wrong during merge...exit!")
        exit 1
      }
      print("export_file: $export_mts")
    }
    else{
      print("No MTS found in: $dir")
    }
}
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
        print("$inbox$mp4")
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
print("Clean Up...")
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
                rm $folder\$file -force 
            }
            else{
                print(" * Ignored: " + $file + " (created:" + $file.creationTime + ")")
            }
        }
    }
}
delete_old_file $short_term $delete_shortterm_days
delete_old_file $dropbox $delete_dropbox_days
delete_old_file $log_folder $delete_log_days

# ------------------------------------------------------------------
# Check dropbox folder size
# ------------------------------------------------------------------

$dropbox_size = [int]((ls $dropbox -r -force| Measure -property Length -sum).sum /1024/1024)
print("Current dropbox folder size: $dropbox_size MB")
print("Process end...`n`n")

# ------------------------------------------------------------------
# Send Notification & write log
# ------------------------------------------------------------------
if((test-path $log_folder) -eq $false){
  md $log_folder
}
$global:message >> $log_file
#write-host $global:message
.\send-mail.ps1 $emails "Newtown Video Transcode Status" $global:message
