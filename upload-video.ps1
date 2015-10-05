$debug = $FALSE

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
$handbrake = $conf.config.handbrakecli_location + "HandBrakeCLI.exe"
$preset = $conf.config.preset
$additional_enc_flags = $conf.config.additional_enc_flags
$emails = $conf.config.notification_emails
$cwd = pwd

function print($msg){
  $date = (Get-Date).toString("yyyy-MM-dd HH:mm:ss")
  write-host $msg -foreground yellow
  $global:message += "[$date] $msg" + "`n"
}

$global:message = ""

print("Process starts...")
print("Using preset: $preset")
print("Using preset: $additional_enc_flags")
# -------------------------------------------------------------------
# if $inbox contains directories, merge all mts within the directory
# -------------------------------------------------------------------

$directories  = @(Get-ChildItem $inbox | ?{ $_.PSIsContainer })
if($directories.length -gt 0){
foreach($dir in $directories){
  $dir_full = $dir.fullname
  $dir_name = $dir.name
  if((ls $dir_full\*.mts|measure-object).count -eq 0){
    print "Ignore empty folder: $dir_full"
	break
  }
  print("Directory found: $dir_full")
  $files = ls $dir_full/*.mts |sort Name
    $file_list = ''
	if($files.length -gt 0){
      print("Merge: $files")
      $export_mts = "$inbox" + $dir_name + ".mts"
      cd $dir_full
	  get-content $files -Enc Byte -Read 512 | set-content $export_mts -Enc Byte
      cd $cwd
      #if($LastExitCode -eq 0){
        mv $dir_full $short_term        
      #}
      #else{
      #  print("Something went wrong during merge...exit!")
      #  exit 1
      #}
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
		print("$handbrake $additional_enc_flags -i $short_term$mts -o $short_term$mp4")
        Invoke-Expression -command "$handbrake '$additional_enc_flags' -i '$short_term$mts' -o '$short_term$mp4'"
        if($LastExitCode -ne 0){ print("Transcode file failed: $mts")}

        "Move file around"
        if((Test-Path $long_term\$year) -eq $false){
            md $long_term\$year
        }
        cp "$short_term\$mp4" "$long_term\$year\$mp4" -force
		print("Upload File $short_term\$mp4")
		cd C:\VideoUpload\lib\simple-vimeo-uploader\bin
        php C:\VideoUpload\lib\simple-vimeo-uploader\bin\upload.php	"$short_term\$mp4"
        cd $cwd
        #mv "$short_term\$mp4" "$dropbox\$mp4" -force
        rm "$short_term\$mts" -force -whatif
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
                rm $folder\$file -force -recurse
            }
            else{
                print(" * Ignored: " + $file + " (created:" + $file.creationTime + ")")
            }
        }
    }   
}       
delete_old_file $short_term $delete_shortterm_days
#delete_old_file $dropbox $delete_dropbox_days
delete_old_file $log_folder $delete_log_days
        
# ------------------------------------------------------------------
$vimeo_rss = 'http://vimeo.com/user25324109/videos/rss'
print("Clean up dropbox base on rss feed: $vimeo_rss") 
# ------------------------------------------------------------------
        
$files = ls $dropbox
$rssFeed = [xml](New-Object System.Net.WebClient).DownloadString($vimeo_rss)
$n=0    
if($files -ne $null){
  foreach($file in $files){
    if($rssFeed.rss.channel.item |select-object title|select-string $file){
      print("dropbox remove: $dropbox\$file")
      rm "$dropbox\$file" -force
	  $n = $n+1
    }   
  }     
}       
print("$n file(s) were deleted from dropbox folder")
        
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
if(!$debug){
  .\send-mail.ps1 $emails "Newtown Video Transcode Status" $global:message
}       