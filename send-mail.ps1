Param($emails, $subject, $message)

$email = "alert.me.jason@gmail.com"
$password_file = "C:\VideoUpload\lib\video_uploader\enc_pw.txt"

# TO GENERATE ENCRYPTED PASSWORD
# $credential = Get-Credential
# $credential.Password | ConvertFrom-SecureString | Set-Content c:\scripts\encrypted_password1.txt

#$encrypted = Get-Content $password_file | ConvertTo-SecureString
#$credential = New-Object System.Management.Automation.PsCredential($email, $encrypted)
$pw = gc $password_file
$pw
$EmailFrom = "alert.me.jason@gmail.com"
$EmailTo = $emails 
$Subject = $subject 
$Body = $message
$SMTPServer = "smtp.gmail.com" 
$SMTPClient = New-Object Net.Mail.SmtpClient($SmtpServer, 587) 
$SMTPClient.EnableSsl = $true 
$SMTPClient.Credentials = $credential;
$SMTPClient.Credentials = New-Object System.Net.NetworkCredential($email, (gc $password_file)); 
$SMTPClient.Send($EmailFrom, $EmailTo, $Subject, $Body)

write-host "Email Sent: $emails"
