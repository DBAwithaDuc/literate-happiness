<# CH253279_QuantumDatabase Copy from prod to test.ps1
 .DESCRIPTION 
    Copies a database from one Sqlserver (Prod) to an other SQL server (test) and updates Dbowner, fixes Orphanusers fixes Compatibility and after completion runs the ITDrift - SQL Inventory job 
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2018-09-17 10:58 

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add parameter handling to be able to pass variable values to the Script
    * Add logfile Path 
    * Add error handling 

#>


if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Set variables to run the script#>

$Logname = 'CH253279_Quantum'       <# Name on the logfile that logs everything #>
$sqlinstance1 = 'corpdb10985,11433'  <# From sqlinstance don't forget port  servername,port #>
$sqlinstance2 = 'corpdb10985,11433'  <# to sqlinstance #>
$database1 = 'AGQProd'  <# Database to be copied #>
$database2 = 'AGRProd'   <# Database to be copied #> 
$todatabase1 = 'AGQVal'  <# databasename on $Sqlinstance2 #>
$todatabase2 = 'AGRVal' <# databasename on $Sqlinstance2 #>
$backupshare = '\\corp.saab.se\so\Services\SQLBCK\SE\LKP\CORPDB10985\MSSQL\CORPDB10985'   <# Backupshare to be used#>
$job = 'ITDrift - SQL Inventory to SQL Drift' <# Job to be run after completion#>



Write-Host 'Starting the database copying'
'Starting the database copying' | add-content C:\Changes\$logname.log
copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database $database1 -backupRestore -SharedPath $backupshare  -withReplace -NewName $todatabase1 | add-content c:\changes\$Logname.log <# Add -UseLastBackup if you want to use lastbackup #>
copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database $database2 -backupRestore -SharedPath $backupshare  -withReplace -NewName $todatabase2 | add-content c:\changes\$Logname.log <# Add -UseLastBackup if you want to use lastbackup #>


'List all orphanusers' | add-content c:\changes\$Logname.log
get-DBAorphanUser -sqlinstance $sqlinstance2 | add-content c:\changes\$Logname.log <# check for orphanusers #>

Write-Host 'Repairs Orphanusers'
'Repairs Orphanusers' | add-content c:\changes\$Logname.log
repair-DBAorphanUser -sqlinstance $sqlinstance2  | add-content c:\changes\$Logname.log <# Repair orphanusers #>

Write-Host 'Delete Orphanusers that could not be mapped'
'Delete Orphanusers that could not be mapped' | add-content c:\changes\$Logname.log
remove-DBAorphanusers -sqlinstance $sqlinstance2 -database $database1 | add-content c:\changes\$Logname.log <#Delete Orphanusers that could not be mapped#>

'Orphanusers that remains that couldnot be mapped or deleted' | add-content c:\changes\$Logname.log
get-DBAorphanUser -sqlinstance $sqlinstance2 | add-content c:\changes\$Logname.log <# Checks if any orphanusers remains that couldnot be mapped or deleted #>

Write-Host 'Set DBowner for' + $todatabase1 + 'and' + $todatabase2 + ' to SA'
'Set DBowner for ' + $database1 + ' to SA' | add-content c:\changes\$Logname.log
set-dbadbowner -sqlinstance $sqlinstance2   | add-content c:\changes\$Logname.log <# Sets DBowner for $database1 to SA #>

Write-Host 'Test if Database Compatibility is the same as the new server' 
'Test if Database Compatibility is the same as the new server' | add-content c:\changes\$Logname.log
Test-DbaDbCompatibility -sqlinstance $sqlinstance2  | add-content c:\changes\$Logname.log <#Test if Database Compatibility is the same as the new server#>

Write-Host 'Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views.'
'Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views.' | add-content c:\changes\$Logname.log
invoke-dbadbupgrade -SqlInstance $sqlinstance2 -AllUserDatabases <#Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views #>

Write-Host 'Backup of databases'+ $todatabase1 + 'and' + $todatabase2 + 'to create backupfiles'
'Backup of databases' + $todatabase1 + 'and' + $todatabase2 + 'to create backupfiles' | add-content c:\changes\$Logname.log
Backup-DbaDatabase -SqlInstance $sqlinstance2 -Database $todatabase1, $todatabase2 -BackupDirectory $backupshare | add-content c:\changes\$Logname.log

Write-Host 'Runs the Inventory SQL agent job'
'Runs the Inventory SQL agent job' | add-content c:\changes\$Logname.log
Start-DbaAgentJob -SqlInstance $sqlinstance2 -job $job | add-content c:\changes\$Logname.log


<# Uncomment this if a backup should be done after the move #>

<#
'Backups the the database after move and places it in $targetbackupshare' | add-content c:\changes\$Logname.log
Backup-DbaDatabase -SqlInstance $sqlinstance2 -Database $database1 -BackupDirectory  $targetbackupshare -BackupFileName $BackupFileName -CopyOnly | add-content c:\changes\$Logname.log
#>

Write-Host 'Script is completed'
'Script is completed' | add-content c:\changes\$Logname.log

<#Script end #>
