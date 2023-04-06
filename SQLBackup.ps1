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
$InstallPath = "C:\OLA\Instance1"
Start-Transcript -Append $InstallPath\log.txt
Write-Host $(Get-Date)"[INFO]Start Logging:"

Write-Host $(Get-Date)"[INFO]Install path:"$InstallPath


#Check if sqlcmd is installed
$software = "Microsoft Befehlszeilenprogramme 15 für SQL Server";
$installed = $null -ne (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where-Object { $_.DisplayName -eq $software })

If(-Not $installed) {Write-Host $(Get-Date)"[ERROR]'$software' or SQLCmd couldn't be found. This Software is needed for this Skript to work. Continue only if you know it is installed and working!" -ForegroundColor Red;} else {Write-Host $(Get-Date)"[INFO]'$software' or SQLcmd is installed"}

#Read Config if available
$configfile = Test-Path $InstallPath\config.cfg
if ($configfile -eq "True") {
    $username = Get-Content $InstallPath\config.cfg -TotalCount 1
    $deletebackupafter = (Get-Content $InstallPath\config.cfg -TotalCount 2)[-1]
    $PathBackup = (Get-Content $InstallPath\config.cfg -TotalCount 3)[-1]
    $sqldatabase = (Get-Content $InstallPath\config.cfg -TotalCount 4)[-1]
    $SQLLogDir = (Get-Content $InstallPath\config.cfg -TotalCount 5)[-1]
    $SQLInstanz = (Get-Content $InstallPath\config.cfg -TotalCount 6)[-1]
    $Time = (Get-Content $InstallPath\config.cfg -TotalCount 7)[-1]
} 
else {
    $username = "$env:USERDomain\$env:USERNAME"
    $deletebackupafter = "72"
    $PathBackup = "Please Choose"
    $sqldatabase = "master"
    $SQLLogDir = "C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Log"
    $SQLInstanz = "SQL Instance"
    $Time = "05:00"

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
$textbox.Text = "$PathBackup"
$main.Controls.Add($textbox)
# Button Backuplocation
$Button = New-Object System.Windows.Forms.Button
$Button.Location = '310,50'
$Button.Size = New-Object System.Drawing.Size(30,20)
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
$textboxLogDir.Width += 300
$textboxLogDir.Text = "$SQLLogDir"
$main.Controls.Add($textboxLogDir)
# Button LogDir
$ButtonLogDir = New-Object System.Windows.Forms.Button
$ButtonLogDir.Location = '800,50'
$ButtonLogDir.Size = New-Object System.Drawing.Size(30,20)
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

#SQLDB
#Label SQLDB
$LabelSQLDB = New-Object System.Windows.Forms.Label
$LabelSQLDB.Text = "SQL Datenbank"
$LabelSQLDB.Location  = '10,130'
$LabelSQLDB.AutoSize = $true
$main.Controls.Add($LabelSQLDB)
#Textbox SQLDB
$textboxSQLDB = New-Object System.Windows.Forms.TextBox
$textboxSQLDB.Location = '10,150'
$textboxSQLDB.Width += 50
$TextboxSQLDB.Text = "$sqldatabase"
$main.Controls.Add($textboxSQLDB)

#SQLInst
#Label SQLInst
$LabelSQLInst = New-Object System.Windows.Forms.Label
$LabelSQLInst.Text = "SQL Instance"
$LabelSQLInst.Location  = '250,130'
$LabelSQLInst.AutoSize = $true
$main.Controls.Add($LabelSQLInst)
#Textbox SQLDB
$textboxSQLInst = New-Object System.Windows.Forms.TextBox
$textboxSQLInst.Location = '250,150'
$textboxSQLInst.Text = "$SQLInstanz"
$textboxSQLInst.Width += 200
$main.Controls.Add($textboxSQLInst)

#checkSQLSkript
$checkSQLSkript = new-object System.Windows.Forms.checkbox
$checkSQLSkript.Location = '600,145'
$checkSQLSkript.Size = '250,30'
$checkSQLSkript.Text = "Run SQL-Skript on specified database automatically"
$checkSQLSkript.Checked = $true
$main.Controls.Add($checkSQLSkript) 

#LabelTitleUser
$LabelTitleTime = New-Object System.Windows.Forms.Label
$LabelTitleTime.Text = "User"
$LabelTitleTime.Location  = '5,200'
$LabelTitleTime.AutoSize = $true
$LabelTitleTime.Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
$main.Controls.Add($LabelTitleTime)

#User
#Label User
$Label1 = New-Object System.Windows.Forms.Label
$Label1.Text = "Windows User(has to be able to login to MSSQL):"
$Label1.Location  = '10,225'
$Label1.AutoSize = $true
$main.Controls.Add($Label1)
#Textbox User
$textbox1 = New-Object System.Windows.Forms.TextBox
$textbox1.Location = '10,245'
$textbox1.Width += 50
$textbox1.Text = "$username"
$main.Controls.Add($textbox1)

#Label TitleTime
$LabelTitleTime = New-Object System.Windows.Forms.Label
$LabelTitleTime.Text = "Time"
$LabelTitleTime.Location  = '5,290'
$LabelTitleTime.AutoSize = $true
$LabelTitleTime.Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
$main.Controls.Add($LabelTitleTime)

#Time
#Label Time
$LabelTime = New-Object System.Windows.Forms.Label
$LabelTime.Text = "Time to start the Backup"
$LabelTime.Location  = '10,320'
$LabelTime.AutoSize = $true
$main.Controls.Add($LabelTime)
#Textbox Time
$textboxTime = New-Object System.Windows.Forms.TextBox
$textboxTime.Location = '10,340'
$textboxTime.Width += 50
$textboxTime.Text = $Time
$main.Controls.Add($textboxTime)

#Deletebackupafter
#Label Deletebackupafter
$Label2 = New-Object System.Windows.Forms.Label
$Label2.Text = "Delete backup after(hours):"
$Label2.Location  = '200,320'
$Label2.AutoSize = $true
$main.Controls.Add($Label2)
#Textbox Deletebackupafter
$textbox2 = New-Object System.Windows.Forms.TextBox
$textbox2.Location = '200,340'
$textbox2.Text = "$deletebackupafter"
$textbox2.Width += 50
$main.Controls.Add($textbox2)

#Label Info
$LabelInfo = New-Object System.Windows.Forms.Label
$LabelInfo.Text = "[i]Scripts and Logs will be written to $InstallPath"
$LabelInfo.Location  = '5,550'
$LabelInfo.AutoSize = $true
#$LabelInfo.Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
$main.Controls.Add($LabelInfo)

#Label Info2
if ($configfile -eq "True") {
    $LabelInfo2 = New-Object System.Windows.Forms.Label
    $LabelInfo2.Text = "[i]Config has been read from $InstallPath\config.cfg"
    $LabelInfo2.Location  = '5,570'
    $LabelInfo2.AutoSize = $true
    #$LabelInfo2.Font = New-Object System.Drawing.Font("Arial",12,[System.Drawing.FontStyle]::Bold)
    $main.Controls.Add($LabelInfo2)
}

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
$PathScripts = Test-Path $InstallPath\Scripts\
$PathLogs = Test-Path $InstallPath\Logs\
If($PathScripts -eq "True") {} else {mkdir $InstallPath\Scripts\ | Out-Null}
If($PathLogs -eq "True") {} else {mkdir $InstallPath\Logs\ | Out-Null}
Invoke-WebRequest -Uri https://ola.hallengren.com/scripts/MaintenanceSolution.sql -OutFile C:\Users\$env:USERNAME\Downloads\MaintananceSolution.sql
# Check if paths are created
$PathScripts = Test-Path $InstallPath\Scripts\
$PathLogs = Test-Path $InstallPath\Logs\
if($PathScripts -eq "True") { Write-Host $(Get-Date)"[INFO]$InstallPath\Scripts is available"} else {Write-Host $(Get-Date)"[ERROR]$InstallPath\Scripts clould not be created. Check privilege or drive letter!" -ForegroundColor Red}
if($PathLogs -eq "True") { Write-Host $(Get-Date)"[INFO]$InstallPath\Logs is available"} else {Write-Host $(Get-Date)"[ERROR]$InstallPath\Scripts clould not be created. Check privilege or drive letter" -ForegroundColor Red}

# Check if the file has been downloaded
$PathSQLScript = Test-Path C:\Users\$env:USERNAME\Downloads\MaintananceSolution.sql
if($PathSQLScript -eq "True") { Write-Host $(Get-Date)"[INFO]MaintananceSolution.sql successfully downloaded to" C:\Users\$env:USERNAME\Downloads\MaintananceSolution.sql} else {Write-Host $(Get-Date)"[ERROR]MaintanenceSolution.sql could not be downloaded. Check your internet connection!" -ForegroundColor Red}

#Log Message
Write-Host $(Get-Date)"[WARN]The SQL Script is going to be written to $InstallPath\Scripts\MaintananceSolutionEdited.sql and has to be run manually after creation" -ForegroundColor Yellow

#set variables from userinput
$username = $textbox1.Text
$deletebackupafter = $textbox2.Text
$PathBackup = $textbox.Text
$PathBackup2 = Test-Path $textbox.Text
If($PathBackup2 -eq "True") {}
else { mkdir $textbox.Text | Out-Null}
$PathBackup2 = Test-Path $textbox.Text
if($PathBackup2 -eq "True") { Write-Host $(Get-Date)"[INFO]"$textbox.Text" is available"} else {Write-Host $(Get-Date)"[ERROR]"$textbox.Text" clould not be created. Check privilege or drive letter!" -ForegroundColor Red}
$sqldatabase = $TextboxSQLDB.Text
$SQLLogDir = $textboxLogDir.Text
$SQLInstanz = $textboxSQLInst.Text
$Time = $textboxTime.Text
$runsql = $checkSQLSkript.Checked

#Write configfile
Out-File $InstallPath\config.cfg -Encoding ascii -InputObject $username
Add-Content $InstallPath\config.cfg $deletebackupafter
Add-Content $InstallPath\config.cfg $PathBackup
Add-Content $InstallPath\config.cfg $sqldatabase
Add-Content $InstallPath\config.cfg $SQLLogDir
Add-Content $InstallPath\config.cfg $SQLInstanz
Add-Content $InstallPath\config.cfg $Time
Write-Host $(Get-Date)"[INFO]Config has been written to $InstallPath\config.cfg"

#Edit MaintananceSolution.sql
Get-Content C:\Users\$env:USERNAME\Downloads\MaintananceSolution.sql | Foreach-Object {$_.Replace('DECLARE @BackupDirectory nvarchar(max)     = NULL', "DECLARE @BackupDirectory nvarchar(max)     = '$PathBackup'")} | Set-Content C:\Users\$env:USERNAME\AppData\Local\Temp\result.sql
Get-Content C:\Users\$env:USERNAME\AppData\Local\Temp\result.sql | Foreach-Object {$_.Replace('DECLARE @CleanupTime int                   = NULL', "DECLARE @CleanupTime int                   = $deletebackupafter")} | Set-Content $InstallPath\Scripts\MaintananceSolutionEdited.sql

#run edited MaintananceSolution.sql on specified instance
if ($runsql -eq $true){
    sqlcmd -S $SQLInstanz -i $InstallPath\Scripts\MaintananceSolutionEdited.sql
    Write-Host $(Get-Date)"[INFO]Edited SQL-Skript has been run on $SQLInstanz check Log under $InstallPath\log.txt if run correctly"
}

#Edit and create Scripts
Set-Location $InstallPath\Scripts\
$CommandLogCleanup = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""DELETE FROM dbo.CommandLog WHERE StartTime < DATEADD(dd, -30, GETDATE());"" -b -o $InstallPath\Logs\CommandLogCleanup.txt"
$CommandLogCleanup | out-file CommandLogCleanup.cmd -Encoding ascii

$OutFileCleanup = @"
@echo off
set _SQLLOGDIR_=$SQLLogDir
set _LOGFILE_=$InstallPath\Logs\OutputFileCleanup.txt
if exist %_LOGFILE_% del %_LOGFILE_% > nul:
cmd /q /c "For /F "tokens=1 delims=" %%v In ('ForFiles /P "%_SQLLOGDIR_%" /m *_*_*_*.txt /d -30 2^>^&1') do if EXIST "%_SQLLOGDIR_%"\%%v echo del "%_SQLLOGDIR_%"\%%v& del "%_SQLLOGDIR_%"\%%v" >> %_LOGFILE_%
"@
$OutFileCleanup | out-file OutFileCleanup.cmd -Encoding ascii

$DeleteBackupHistory = "sqlcmd -E -S $SQLInstanz -d msdb -Q ""DECLARE @CleanupDate datetime; SET @CleanupDate = DATEADD(dd, -30, GETDATE()); EXECUTE dbo.sp_delete_backuphistory @oldest_date = @CleanupDate;"" -b -o $InstallPath\Logs\DeleteBackupHistory.txt"
$DeleteBackupHistory | out-file DeleteBackupHistory.cmd -Encoding ascii

$PurgeJobHistory = "sqlcmd -E -S $SQLInstanz -d msdb -Q ""DECLARE @CleanupDate datetime; SET @CleanupDate = DATEADD(dd, -30, GETDATE()); EXECUTE dbo.sp_purge_jobhistory @oldest_date = @CleanupDate;"" -b -o $InstallPath\Logs\PurgeJobHistory.txt"
$PurgeJobHistory | out-file PurgeJobHistory.cmd -Encoding ascii

$DatabaseBackupSystemDatabasesFull = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.DatabaseBackup @Databases = 'SYSTEM_DATABASES', @Directory = '$PathBackup', @BackupType = 'FULL', @Verify = 'Y', @CleanupTime = 72, @CheckSum = 'Y', @LogToTable = 'Y';"" -b -o $InstallPath\Logs\DatabaseBackupSystemDatabasesFull.txt"
$DatabaseBackupSystemDatabasesFull | out-file DatabaseBackupSystemDatabasesFull.cmd -Encoding ascii

$DatabaseBackupUserDatabasesFull = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.DatabaseBackup @Databases = 'USER_DATABASES', @Directory = '$PathBackup', @BackupType = 'FULL', @Verify = 'Y', @CleanupTime = 72, @CheckSum = 'Y', @LogToTable = 'Y';"" -b -o $InstallPath\Logs\DatabaseBackupUserDatabasesFull.txt"
$DatabaseBackupUserDatabasesFull | out-file DatabaseBackupUserDatabasesFull.cmd -Encoding ascii

$DatabaseBackupUserDatabasesLog = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.DatabaseBackup @Databases = 'USER_DATABASES', @Directory = '$PathBackup', @BackupType = 'LOG', @Verify = 'Y', @CleanupTime = 72, @CheckSum = 'Y', @LogToTable = 'Y';"" -b -o $InstallPath\Logs\DatabaseBackupUserDatabasesLog.txt"
$DatabaseBackupUserDatabasesLog | out-file DatabaseBackupUserDatabasesLog.cmd -Encoding ascii

$DatabaseIntegrityCheckSystemDatabases = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.DatabaseIntegrityCheck @Databases = 'SYSTEM_DATABASES', @LogToTable = 'Y';"" -b -o $InstallPath\Logs\DatabaseIntegrityCheckSystemDatabases.txt"
$DatabaseIntegrityCheckSystemDatabases | out-file DatabaseIntegrityCheckSystemDatabases.cmd -Encoding ascii

$DatabaseIntegrityCheckUserDatabases = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.DatabaseIntegrityCheck @Databases = 'USER_DATABASES', @LogToTable = 'Y';"" -b -o $InstallPath\Logs\DatabaseIntegrityCheckUserDatabases.txt"
$DatabaseIntegrityCheckUserDatabases | out-file DatabaseIntegrityCheckUserDatabases.cmd -Encoding ascii

$IndexOptimizeSystemDatabases = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.IndexOptimize @Databases = 'master,msdb', @MSShippedObjects = 'Y', @LogToTable = 'Y';"" -b -o $InstallPath\Logs\IndexOptimizeSystemDatabases.txt"
$IndexOptimizeSystemDatabases | out-file IndexOptimizeSystemDatabases.cmd -Encoding ascii

$IndexOptimizeUserDatabases = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""EXECUTE dbo.IndexOptimize @Databases = 'USER_DATABASES', @LogToTable = 'Y';"" -b -o $InstallPath\Logs\IndexOptimizeUserDatabases.txt"
$IndexOptimizeUserDatabases | out-file IndexOptimizeUserDatabases.cmd -Encoding ascii

$Monitoring = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""SELECT cl.ID, cl.DatabaseName, cl.CommandType, cl.StartTime, cl.EndTime, cl.ErrorNumber FROM master.dbo.CommandLog AS cl WHERE (cl.ErrorNumber <> 0) ORDER BY cl.ID DESC;"" -b -o $InstallPath\Logs\monitoring.txt"
$Monitoring | out-file Monitoring.cmd -Encoding ascii

##Create MS Tasks
#IndexOptimizeSystemDatabases
$Time = [DateTime]$Time
$PathName = $InstallPath -creplace '(?s)^.*\\', ''
[string]$TaskName = "Index Optimization - System Databases_$PathName"
[string]$TaskBeschrieb = "Diese Aufgabe Optimiert den Index der master und msdb"
[string]$TaskPfad = "\OLA - SQL Mantenance Tasks - $PathName"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "$InstallPath\Scripts\IndexOptimizeSystemDatabases.cmd"
$TaskBenutzer = New-ScheduledTaskPrincipal -UserId "$username" -RunLevel Highest
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#IndexOptimizeUserDatabases
[string]$TaskName = "Index Optimization - User Databases_$PathName"
[string]$TaskBeschrieb = "Diese Aufgabe Optimiert den Index der Benutzerdatenbanken"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "$InstallPath\Scripts\IndexOptimizeUserDatabases.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DatabaseIntegrityCheckSystemDatabases
[string]$TaskName = "Database Integrity Check - System Databases_$PathName"
[string]$TaskBeschrieb = "Database Integrity Check - System Databases"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "$InstallPath\Scripts\DatabaseIntegrityCheckSystemDatabases.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DatabaseIntegrityCheckUserDatabases
[string]$TaskName = "Database Integrity Check - User Databases_$PathName"
[string]$TaskBeschrieb = "Database Integrity Check - User Databases"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "$InstallPath\Scripts\DatabaseIntegrityCheckUserDatabases.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(30)
#Command Log Cleanup
[string]$TaskName = "Command Log Cleanup_$PathName"
[string]$TaskBeschrieb = "Diese Aufgabe löscht Logs älter als 30 Tage"
$TaskAusloeser = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "$InstallPath\Scripts\CommandLogCleanup.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#Output File Cleanup
[string]$TaskName = "Output File Cleanup_$PathName"
[string]$TaskBeschrieb = "Diese Aufgabe löscht dateien mit dem Namen *_*_*_*.txt aus dem angegebenen SQL Log Verzeichnis"
$TaskAusloeser = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "$InstallPath\Scripts\OutFileCleanup.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DeleteBackupHistory
[string]$TaskName = "Delete Backup History_$PathName"
[string]$TaskBeschrieb = "Diese Aufgabe löscht backup history records, welche älter als 30 Tage sind"
$TaskAusloeser = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "$InstallPath\Scripts\DeleteBackupHistory.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#PurgeJobHistory
[string]$TaskName = "Purge Job History_$PathName"
[string]$TaskBeschrieb = "Diese Aufgabe löscht SQL Server Agenten Jobs älter als 30 Tage (Nicht relevant für SQL Express)"
$TaskAusloeser = New-ScheduledTaskTrigger -Weekly -WeeksInterval 1 -DaysOfWeek Sunday -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "$InstallPath\Scripts\PurgeJobHistory.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DatabaseBackupSystemDatabasesFull
[string]$TaskName = "Database Backup - System Databases Full_$PathName"
[string]$TaskBeschrieb = "Diese Aufgabe sichert alle Systemdatenbanken komplett"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "$InstallPath\Scripts\DatabaseBackupSystemDatabasesFull.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DatabaseBackupUserDatabasesFull
[string]$TaskName = "Database Backup - User Databases Full_$PathName"
[string]$TaskBeschrieb = "Diese Aufgabe sichert alle Userdatenbanken komplett"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm") 
$TaskAktion = New-ScheduledTaskAction -Execute "$InstallPath\Scripts\DatabaseBackupUserDatabasesFull.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb

$Time = ($Time).AddMinutes(05)
#DatabaseBackupUserDatabasesLog
[string]$TaskName = "Database Backup - User Databases Log_$PathName"
[string]$TaskBeschrieb = "Diese Aufgabe sichert alle Userdatenbanken Transaktionssicherung mit dem Full recovery model"
$TaskAusloeser = New-ScheduledTaskTrigger -Once -At ($Time).tostring("HH:mm") -RepetitionInterval  (New-TimeSpan -Minutes 30)
$TaskAktion = New-ScheduledTaskAction -Execute "$InstallPath\Scripts\DatabaseBackupUserDatabasesLog.cmd"
if (Get-ScheduledTask $TaskName -ErrorAction SilentlyContinue) {Unregister-ScheduledTask $TaskName}
Register-ScheduledTask -TaskName $TaskName -TaskPath $TaskPfad -Action $TaskAktion -Trigger $TaskAusloeser -Principal $TaskBenutzer -Description $TaskBeschrieb