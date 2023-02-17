$IsAdmin=[Security.Principal.WindowsIdentity]::GetCurrent()
If ((New-Object Security.Principal.WindowsPrincipal $IsAdmin).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) -eq $FALSE) {
    $ElevatedProcess = New-Object System.Diagnostics.ProcessStartInfo "PowerShell";
    # Specify the current script path and name as a parameter
    $ElevatedProcess.Arguments = "& '" + $script:MyInvocation.MyCommand.Path + "'"
    #Set the Process to elevated
    $ElevatedProcess.Verb = "runas"
    #Start the new elevated process
    [System.Diagnostics.Process]::Start($ElevatedProcess)
    #Exit from the current, unelevated, process
    Exit
}
Write-Host $(Get-Date)"[INFO]Start Logging:"
Start-Transcript -Append C:\OLA\Logs\log2.txt

#Check if sqlcmd is installed
$software = "Microsoft Befehlszeilenprogramme 15 für SQL Server";
$installed = $null -ne (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -eq $software })

If(-Not $installed) {
	Write-Host $(Get-Date)"[ERROR]'$software' or SQLCmd couldn't be found. This Software is needed for this Skript to work. Continue only if you know it is installed and working!" -ForegroundColor Red; 
} else {
	Write-Host $(Get-Date)"[INFO]'$software' or SQLcmd is installed"
}

# GUI Window
Add-Type -assembly System.Windows.Forms
$main = New-Object System.Windows.Forms.Form
$main.Text ='MSSQL Backup GUI'
$main.Width = 800
$main.Height = 600
$main.AutoSize = $true

#Label Title
$LabelTitle = New-Object System.Windows.Forms.Label
$LabelTitle.Text = "Location"
$LabelTitle.Location  = '5,5'
$LabelTitle.AutoSize = $true
$LabelTitle.Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
$main.Controls.Add($LabelTitle)

# Backuplocation
# Label Backuplocation
$Label = New-Object System.Windows.Forms.Label
$Label.Text = "Backup location:"
$Label.Location  = '10,30'
$Label.AutoSize = $true
$main.Controls.Add($Label)
# Textbox Backuplocation
$textbox = New-Object System.Windows.Forms.TextBox
$textbox.Location = '10,50'
$textbox.Width += 200
$main.Controls.Add($textbox)
# Button Backuplocation
$Button = New-Object System.Windows.Forms.Button
$Button.Location = '310,50'
$Button.Size = New-Object System.Drawing.Size(30,23)
$Button.Text = "..."
$Button.Add_Click({
    $browse = New-Object system.windows.forms.FolderBrowserDialog
    $script:foldername1 = 'not found'
    if($browse.ShowDialog() -eq 'Ok'){
        $script:foldername1 =  $textbox.Text = $browse.SelectedPath
    }    
})
$main.Controls.Add($Button)

# LogDir
# Label LogDir
$LabelLogDir = New-Object System.Windows.Forms.Label
$LabelLogDir.Text = "Log Directory:"
$LabelLogDir.Location  = '400,30'
$LabelLogDir.AutoSize = $true
$main.Controls.Add($LabelLogDir)
# Textbox LogDir
$textboxLogDir = New-Object System.Windows.Forms.TextBox
$textboxLogDir.Location = '400,50'
$textboxLogDir.Width += 200
$textboxLogDir.Text = "C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Log"
$main.Controls.Add($textboxLogDir)
# Button LogDir
$ButtonLogDir = New-Object System.Windows.Forms.Button
$ButtonLogDir.Location = '700,50'
$ButtonLogDir.Size = New-Object System.Drawing.Size(30,23)
$ButtonLogDir.Text = "..."
$ButtonLogDir.Add_Click({
    $browseLogDir = New-Object system.windows.forms.FolderBrowserDialog
    $script:foldername2 = 'not found'
    if($browseLogDir.ShowDialog() -eq 'Ok'){
        $script:foldername2 =  $textboxLogDir.Text = $browseLogDir.SelectedPath
    }    
})
$main.Controls.Add($ButtonLogDir)

#Label TitleSQL
$LabelTitleSQL = New-Object System.Windows.Forms.Label
$LabelTitleSQL.Text = "SQL Information"
$LabelTitleSQL.Location  = '5,100'
$LabelTitleSQL.AutoSize = $true
$LabelTitleSQL.Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
$main.Controls.Add($LabelTitleSQL)

#User
#Label User
$Label1 = New-Object System.Windows.Forms.Label
$Label1.Text = "User(has to be able to login to MSSQL):"
$Label1.Location  = '10,125'
$Label1.AutoSize = $true
$main.Controls.Add($Label1)
#Textbox User
$textbox1 = New-Object System.Windows.Forms.TextBox
$textbox1.Location = '10,145'
$textbox1.Width += 50
$textbox1.Text = "$env:USERDomain\$env:USERNAME"
$main.Controls.Add($textbox1)

#SQLDB
#Label SQLDB
$LabelSQLDB = New-Object System.Windows.Forms.Label
$LabelSQLDB.Text = "SQL Datenbank"
$LabelSQLDB.Location  = '10,180'
$LabelSQLDB.AutoSize = $true
$main.Controls.Add($LabelSQLDB)
#Textbox SQLDB
$textboxSQLDB = New-Object System.Windows.Forms.TextBox
$textboxSQLDB.Location = '10,200'
$textboxSQLDB.Width += 100
$TextboxSQLDB.Text = "master"
$main.Controls.Add($textboxSQLDB)

#SQLInst
#Label SQLInst
$LabelSQLInst = New-Object System.Windows.Forms.Label
$LabelSQLInst.Text = "SQL Instance"
$LabelSQLInst.Location  = '250,180'
$LabelSQLInst.AutoSize = $true
$main.Controls.Add($LabelSQLInst)
#Textbox SQLDB
$textboxSQLInst = New-Object System.Windows.Forms.TextBox
$textboxSQLInst.Location = '250,200'
$textboxSQLInst.Width += 200
$main.Controls.Add($textboxSQLInst)

#Time
#Label Time
$LabelTime = New-Object System.Windows.Forms.Label
$LabelTime.Text = "Time to start the Backup"
$LabelTime.Location  = '10,300'
$LabelTime.AutoSize = $true
$main.Controls.Add($LabelTime)
#Textbox Time
$textboxTime = New-Object System.Windows.Forms.TextBox
$textboxTime.Location = '10,325'
$textboxTime.Width += 100
$textboxTime.Text = "05:00"
$main.Controls.Add($textboxTime)

#Deletebackupafter
#Label Deletebackupafter
$Label2 = New-Object System.Windows.Forms.Label
$Label2.Text = "Delete backup after(hours):"
$Label2.Location  = '10,500'
$Label2.AutoSize = $true
$main.Controls.Add($Label2)
#Textbox Backuplocation
$textbox2 = New-Object System.Windows.Forms.TextBox
$textbox2.Location = '160,500'
$textbox2.Text = "72"
$textbox2.Width += 150
$main.Controls.Add($textbox2)

#Label Info
$LabelInfo = New-Object System.Windows.Forms.Label
$LabelInfo.Text = "[i]Scripts and Logs will be written to C:\OLA\"
$LabelInfo.Location  = '5,550'
$LabelInfo.AutoSize = $true
#$LabelInfo.Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
$main.Controls.Add($LabelInfo)

# OK Button
$okButton = New-Object System.Windows.Forms.Button
$okButton.Location = New-Object System.Drawing.Point(550,500)
$okButton.Size = New-Object System.Drawing.Size(75,23)
$okButton.Text = 'OK'
$okButton.DialogResult = [System.Windows.Forms.DialogResult]::OK
$main.AcceptButton = $okButton
$main.Controls.Add($okButton)

# Cancel Button
$cancelButton = New-Object System.Windows.Forms.Button
$cancelButton.Location = New-Object System.Drawing.Point(675,500)
$cancelButton.Size = New-Object System.Drawing.Size(75,23)
$cancelButton.Text = 'Cancel'
$cancelButton.DialogResult = [System.Windows.Forms.DialogResult]::Cancel
$main.CancelButton = $cancelButton
$main.Controls.Add($cancelButton)

#Show GUI with result
$result = $main.ShowDialog()
if ($result -eq [System.Windows.Forms.DialogResult]::OK)
{
    Write-Host "[INFO]" $textbox1.Text
}
else {
    Write-Host $(Get-Date)"[INFO]Setup cancelled!" -ForegroundColor Red
    exit
}

#Download SQL Script + Create paths
$PathScripts = Test-Path C:\OLA\Scripts\
$PathLogs = Test-Path C:\OLA\Logs\
If($PathScripts -eq "True") {} else {mkdir C:\OLA\Scripts\ | Out-Null}
If($PathLogs -eq "True") {} else {mkdir C:\OLA\Logs\ | Out-Null}
Invoke-WebRequest -Uri https://ola.hallengren.com/scripts/MaintenanceSolution.sql -OutFile C:\Users\$env:USERNAME\Downloads\MaintananceSolution.sql
# Check if paths are created
$PathScripts = Test-Path C:\OLA\Scripts\
$PathLogs = Test-Path C:\OLA\Logs\
if($PathScripts -eq "True") { Write-Host $(Get-Date)"[INFO]C:\OLA\Scripts is available"} else {Write-Host $(Get-Date)"[ERROR]C:\OLA\Scripts clould not be created. Check privilege or drive letter!" -ForegroundColor Red}
if($PathLogs -eq "True") { Write-Host $(Get-Date)"[INFO]C:\OLA\Logs is available"} else {Write-Host $(Get-Date)"[ERROR]C:\OLA\Scripts clould not be created. Check privilege or drive letter" -ForegroundColor Red}

# Check if the file has been downloaded
$PathSQLScript = Test-Path C:\Users\$env:USERNAME\Downloads\MaintananceSolution.sql
if($PathSQLScript -eq "True") { Write-Host $(Get-Date)"[INFO]MaintananceSolution.sql successfully downloaded to" C:\Users\$env:USERNAME\Downloads\MaintananceSolution.sql} else {Write-Host $(Get-Date)"[ERROR]MaintanenceSolution.sql could not be downloaded. Check your internet connection!" -ForegroundColor Red}

#Log Message
Write-Host $(Get-Date)"[WARN]The SQL Script is going to be written to C:\OLA\Scripts\MaintananceSolutionEdited.sql and has to be run manually after creation" -ForegroundColor Yellow

#set variables from userinput
$username = $textbox1.Text
$deletebackupafter = $textbox2.Text
$PathBackup = Test-Path $foldername1
If($PathBackup -eq "True") {}
else { mkdir $foldername1 | Out-Null}
$PathBackup = Test-Path $foldername1
if($PathBackup -eq "True") { Write-Host $(Get-Date)"[INFO]'$foldername1' is available"} else {Write-Host $(Get-Date)"[ERROR]'$foldername1' clould not be created. Check privilege or drive letter!" -ForegroundColor Red}
$sqldatabase = $TextboxSQLDB.Text
$SQLLogDir = $textboxLogDir.Text
$SQLInstanz = $textboxSQLInst.Text
[DateTime]$Time = $textboxTime.Text

#Write configfile
Out-File C:\OLA\config.cfg -Encoding ascii -InputObject $username
Add-Content C:\OLA\config.cfg $deletebackupafter
Add-Content C:\OLA\config.cfg $PathBackup
Add-Content C:\OLA\config.cfg $sqldatabase
Add-Content C:\OLA\config.cfg $SQLLogDir
Add-Content C:\OLA\config.cfg $SQLInstanz
Add-Content C:\OLA\config.cfg $Time

#Edit MaintananceSolution.sql
Get-Content C:\Users\$env:USERNAME\Downloads\MaintananceSolution.sql | Foreach-Object {$_.Replace('DECLARE @BackupDirectory nvarchar(max)     = NULL', "DECLARE @BackupDirectory nvarchar(max)     = '$location'")} | Set-Content C:\Users\$env:USERNAME\AppData\Local\Temp\result.sql
Get-Content C:\Users\$env:USERNAME\AppData\Local\Temp\result.sql | Foreach-Object {$_.Replace('DECLARE @CleanupTime int                   = NULL', "DECLARE @CleanupTime int                   = $deletebackupafter")} | Set-Content C:\OLA\Scripts\MaintananceSolutionEdited.sql

#Edit and create Scripts
Set-Location C:\OLA\Scripts\
$CommandLogCleanup = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""DELETE FROM dbo.CommandLog WHERE StartTime < DATEADD(dd, -30, GETDATE());"" -b -o C:\OLA\Logs\CommandLogCleanup.txt"
$CommandLogCleanup | out-file CommandLogCleanup.cmd -Encoding ascii

$OutFileCleanup = @"
@echo off
set _SQLLOGDIR_=$SQLLogDir
set _LOGFILE_=C:\OLA\Logs\OutputFileCleanup.txt
if exist %_LOGFILE_% del %_LOGFILE_% > nul:
cmd /q /c "For /F "tokens=1 delims=" %%v In ('ForFiles /P "%_SQLLOGDIR_%" /m *_*_*_*.txt /d -30 2^>^&1') do if EXIST "%_SQLLOGDIR_%"\%%v echo del "%_SQLLOGDIR_%"\%%v& del "%_SQLLOGDIR_%"\%%v" >> %_LOGFILE_%
"@
$OutFileCleanup | out-file OutFileCleanup.cmd -Encoding ascii

$DeleteBackupHistory = "sqlcmd -E -S $SQLInstanz -d msdb -Q ""DECLARE @CleanupDate datetime; SET @CleanupDate = DATEADD(dd, -30, GETDATE()); EXECUTE dbo.sp_delete_backuphistory @oldest_date = @CleanupDate;"" -b -o C:\OLA\Logs\DeleteBackupHistory.txt"
$DeleteBackupHistory | out-file DeleteBackupHistory.cmd -Encoding ascii

$PurgeJobHistory = "sqlcmd -E -S $SQLInstanz -d msdb -Q ""DECLARE @CleanupDate datetime; SET @CleanupDate = DATEADD(dd, -30, GETDATE()); EXECUTE dbo.sp_purge_jobhistory @oldest_date = @CleanupDate;"" -b -o C:\OLA\Logs\PurgeJobHistory.txt"
$PurgeJobHistory | out-file PurgeJobHistory.cmd -Encoding ascii

$DatabaseBackupSystemDatabasesFull = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.DatabaseBackup @Databases = 'SYSTEM_DATABASES', @Directory = '$location', @BackupType = 'FULL', @Verify = 'Y', @CleanupTime = 72, @CheckSum = 'Y', @LogToTable = 'Y';"" -b -o C:\OLA\Logs\DatabaseBackupSystemDatabasesFull.txt"
$DatabaseBackupSystemDatabasesFull | out-file DatabaseBackupSystemDatabasesFull.cmd -Encoding ascii

$DatabaseBackupUserDatabasesFull = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.DatabaseBackup @Databases = 'USER_DATABASES', @Directory = '$location', @BackupType = 'FULL', @Verify = 'Y', @CleanupTime = 72, @CheckSum = 'Y', @LogToTable = 'Y';"" -b -o C:\OLA\Logs\DatabaseBackupUserDatabasesFull.txt"
$DatabaseBackupUserDatabasesFull | out-file DatabaseBackupUserDatabasesFull.cmd -Encoding ascii

$DatabaseBackupUserDatabasesLog = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.DatabaseBackup @Databases = 'USER_DATABASES', @Directory = '$location', @BackupType = 'LOG', @Verify = 'Y', @CleanupTime = 72, @CheckSum = 'Y', @LogToTable = 'Y';"" -b -o C:\OLA\Logs\DatabaseBackupUserDatabasesLog.txt"
$DatabaseBackupUserDatabasesLog | out-file DatabaseBackupUserDatabasesLog.cmd -Encoding ascii

$DatabaseIntegrityCheckSystemDatabases = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.DatabaseIntegrityCheck @Databases = 'SYSTEM_DATABASES', @LogToTable = 'Y';"" -b -o C:\OLA\Logs\DatabaseIntegrityCheckSystemDatabases.txt"
$DatabaseIntegrityCheckSystemDatabases | out-file DatabaseIntegrityCheckSystemDatabases.cmd -Encoding ascii

$DatabaseIntegrityCheckUserDatabases = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.DatabaseIntegrityCheck @Databases = 'USER_DATABASES', @LogToTable = 'Y';"" -b -o C:\OLA\Logs\DatabaseIntegrityCheckUserDatabases.txt"
$DatabaseIntegrityCheckUserDatabases | out-file DatabaseIntegrityCheckUserDatabases.cmd -Encoding ascii

$IndexOptimizeSystemDatabases = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.IndexOptimize @Databases = 'master,msdb', @MSShippedObjects = 'Y', @LogToTable = 'Y';"" -b -o C:\OLA\Logs\IndexOptimizeSystemDatabases.txt"
$IndexOptimizeSystemDatabases | out-file IndexOptimizeSystemDatabases.cmd -Encoding ascii

$IndexOptimizeUserDatabases = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.IndexOptimize @Databases = 'USER_DATABASES', @LogToTable = 'Y';"" -b -o C:\OLA\Logs\IndexOptimizeUserDatabases.txt"
$IndexOptimizeUserDatabases | out-file IndexOptimizeUserDatabases.cmd -Encoding ascii

$Monitoring = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""SELECT cl.ID, cl.DatabaseName, cl.CommandType, cl.StartTime, cl.EndTime, cl.ErrorNumber FROM master.dbo.CommandLog AS cl WHERE (cl.ErrorNumber <> 0) ORDER BY cl.ID DESC;"" -b -o C:\OLA\Logs\monitoring.txt"
$Monitoring | out-file Monitoring.cmd -Encoding ascii

##Create MS Tasks
#IndexOptimizeSystemDatabases
[string]$TaskName = "Index Optimization - System Databases"
[string]$TaskBeschrieb = "Diese Aufgabe Optimiert den Index der master und msdb"
[string]$TaskPfad = "\OLA - SQL Mantenance Tasks"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\IndexOptimizeSystemDatabases.cmd"
$TaskBenutzer = New-ScheduledTaskPrincipal -UserId "$username" -RunLevel Highest
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#IndexOptimizeUserDatabases
[string]$TaskName = "Index Optimization - User Databases"
[string]$TaskBeschrieb = "Diese Aufgabe Optimiert den Index der Benutzerdatenbanken"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\IndexOptimizeUserDatabases.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DatabaseIntegrityCheckSystemDatabases
[string]$TaskName = "Database Integrity Check - System Databases"
[string]$TaskBeschrieb = "Database Integrity Check - System Databases"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\DatabaseIntegrityCheckSystemDatabases.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DatabaseIntegrityCheckUserDatabases
[string]$TaskName = "Database Integrity Check - User Databases"
[string]$TaskBeschrieb = "Database Integrity Check - User Databases"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\DatabaseIntegrityCheckUserDatabases.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(30)
#Command Log Cleanup
[string]$TaskName = "Command Log Cleanup"
[string]$TaskBeschrieb = "Diese Aufgabe löscht Logs älter als 30 Tage"
$TaskAusloeser = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\CommandLogCleanup.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#Output File Cleanup
[string]$TaskName = "Output File Cleanup"
[string]$TaskBeschrieb = "Diese Aufgabe löscht dateien mit dem Namen *_*_*_*.txt aus dem angegebenen SQL Log Verzeichnis"
$TaskAusloeser = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\OutFileCleanup.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DeleteBackupHistory
[string]$TaskName = "Delete Backup History"
[string]$TaskBeschrieb = "Diese Aufgabe löscht backup history records, welche älter als 30 Tage sind"
$TaskAusloeser = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\DeleteBackupHistory.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#PurgeJobHistory
[string]$TaskName = "Purge Job History"
[string]$TaskBeschrieb = "Diese Aufgabe löscht SQL Server Agenten Jobs älter als 30 Tage (Nicht relevant für SQL Express)"
$TaskAusloeser = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\PurgeJobHistory.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DatabaseBackupSystemDatabasesFull
[string]$TaskName = "Database Backup - System Databases Full"
[string]$TaskBeschrieb = "Diese Aufgabe sichert alle Systemdatenbanken komplett"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\DatabaseBackupSystemDatabasesFull.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DatabaseBackupUserDatabasesFull
[string]$TaskName = "Database Backup - User Databases Full"
[string]$TaskBeschrieb = "Diese Aufgabe sichert alle Userdatenbanken komplett"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm") 
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\DatabaseBackupUserDatabasesFull.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DatabaseBackupUserDatabasesLog
[string]$TaskName = "Database Backup - User Databases Log"
[string]$TaskBeschrieb = "Diese Aufgabe sichert alle Userdatenbanken Transaktionssicherung mit dem Full recovery model"
$TaskAusloeser = New-ScheduledTaskTrigger -Once -At ($Time).tostring("HH:mm") -RepetitionInterval  (New-TimeSpan -Minutes 30)
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\DatabaseBackupUserDatabasesLog.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb