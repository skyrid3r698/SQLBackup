#check for admin
$IsAdmin=[Security.Principal.WindowsIdentity]::GetCurrent()
If ((New-Object Security.Principal.WindowsPrincipal $IsAdmin).IsInRole([Security.Principal.WindowsBuiltinRole]::Administrator) -eq $FALSE) {
"ERROR: Das Script muss als Administrator gestartet werden!"
pause
exit
}

#Check if sqlcmd is installed
$software = "Microsoft Befehlszeilenprogramme 15 für SQL Server";
$installed = (Get-ItemProperty HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\* | Where { $_.DisplayName -eq $software }) -ne $null

If(-Not $installed) {
	Write-Host "'$software' bzw. SQLCmd konnte nicht gefunden werden. Die Software ist, für ein funktionierendes Backup, zwingend notwendig. Fortfahren auf eigene Verantwortung!" -ForegroundColor Red; 
} else {
	Write-Host "'$software' bzw. SQLcmd ist installiert." -ForegroundColor Green
}

#Download SQL Script + Anlage erforderlicher Pfade
$PathScripts = Test-Path C:\OLA\Scripts\
$PathLogs = Test-Path C:\OLA\Logs\
If($PathScripts -eq "True") {
}
else { 
	mkdir C:\OLA\Scripts\
	Write-Host "Skript-Pfad C:\OLA\Scripts angelegt!" -ForegroundColor Green
}
If($PathLogs -eq "True") {
}
else { 
	mkdir C:\OLA\Logs\
	Write-Host "Logs-Pfad C:\OLA\Logs angelegt!" -ForegroundColor Green
}
Invoke-WebRequest -Uri https://ola.hallengren.com/scripts/MaintenanceSolution.sql -OutFile C:\Users\$env:USERNAME\Downloads\MaintananceSolution.sql




#backuppfad festlegen
Write-Host "Das SQL-Skript wird nach dem Setup in C:\OLA\Scripts\MaintananceSolutionEdited.sql geschrieben und muss nach diesem Setup manuell in dem SQL-Server ausgeführt werden!" -ForegroundColor Yellow

$location = Read-Host 'Backupziel(Schreibweise D:\ELOBACKUP\BACKUP)'
$deletebackupafter = Read-Host 'Nach wie vielen Stunden soll das Backup gelöscht werden (Schreibweise 72)'
$PathBackup = Test-Path $location
If($PathBackup -eq "True") {
}
else { 
	mkdir $location
	Write-Host "Backup-Pfad $location angelegt!" -ForegroundColor Green
}

#Edit MaintananceSolution.sql
Get-Content C:\Users\$env:USERNAME\Downloads\MaintananceSolution.sql | Foreach-Object {$_.Replace('DECLARE @BackupDirectory nvarchar(max)     = NULL', "DECLARE @BackupDirectory nvarchar(max)     = '$location'")} | Set-Content C:\Users\$env:USERNAME\AppData\Local\Temp\result.sql
Get-Content C:\Users\$env:USERNAME\AppData\Local\Temp\result.sql | Foreach-Object {$_.Replace('DECLARE @CleanupTime int                   = NULL', "DECLARE @CleanupTime int                   = $deletebackupafter")} | Set-Content C:\OLA\Scripts\MaintananceSolutionEdited.sql

#Edit and create Scripts
$sqluser = Read-Host 'Benutzer für Anmeldung an den SQL Server (Aktuell angemeldet:'"$env:USERDomain\$env:USERNAME"')'
if ($sqluser -eq [string]::empty) { $sqluser = "$env:USERDomain\$env:USERNAME" }
$sqldatabase = Read-Host 'Auf welche Datenbank wird das SQL-Skript geschrieben? (Aktuell ausgewählt: master)'
if ($sqluser -eq [string]::empty) { $sqldatabase = "master" }
$SQLInstanz = Read-Host 'SQL-Server (Schreibweise: '"$env:COMPUTERNAME\INSTANZNAME"')'
cd C:\OLA\Scripts\
$CommandLogCleanup = "sqlcmd -E -S $SQLInstanz -d $sqldatabase -Q ""DELETE FROM dbo.CommandLog WHERE StartTime < DATEADD(dd, -30, GETDATE());"" -b -o C:\OLA\Logs\CommandLogCleanup.txt"
$CommandLogCleanup | out-file CommandLogCleanup.cmd -Encoding ascii

$SQLLogDir = Read-Host 'LogDir des MSSQL Servers(Bsp. C:\Program Files\Microsoft SQL Server\MSSQL13.MSSQLSERVER\MSSQL\Log)'
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



[DateTime]$Time = Read-Host 'Uhrzeit des Starts der Maintenance Skripte(Bsp.: 05:00)'

##Create MS Tasks
#IndexOptimizeSystemDatabases
[string]$TaskName = "Index Optimization - System Databases"
[string]$TaskBeschrieb = "Diese Aufgabe Optimiert den Index der master und msdb"
[string]$TaskPfad = "\OLA - SQL Mantenance Tasks"
$TaskAusloeser = New-ScheduledTaskTrigger -Daily -DaysInterval 1 -At ($Time).tostring("HH:mm")
$TaskAktion = New-ScheduledTaskAction -Execute "C:\OLA\Scripts\IndexOptimizeSystemDatabases.cmd"
$TaskBenutzer = New-ScheduledTaskPrincipal -UserId "$sqluser" -RunLevel Highest
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
