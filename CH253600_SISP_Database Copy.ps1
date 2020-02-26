<# CH253600_SISP_Database Copy.ps1
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

$Logname = 'CH253600'       <# Name on the logfile that logs everything #>
$sqlinstance1 = 'corpdb6426,11433'  <# From sqlinstance don't forget port  servername,port #>
$sqlinstance2 = 'corpdb16399,11433'  <# to sqlinstance #>
$fromdatabase = 'SPP_PROD_PortalContent'  <# Database to be copied #>
$todatabase = 'SISP_UAT16_PortalContent'    <# databasename on $Sqlinstance2 #>
$backupshare = '\\corp.saab.se\so\Services\SQLBCK\SE\LKP\CORPDB16399\MSSQL\CORPDB16399'   <# Backupshare to be used#>
$job = 'ITDrift - SQL Inventory to SQL Drift' <# Job to be run after completion#>


Write-Host 'Starting the database copying'
copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database $fromdatabase -backupRestore -SharedPath $backupshare  -withReplace -NewName $todatabase| add-content c:\changes\$Logname.log <# Add -UseLastBackup if you want to use lastbackup #>

Write-Host 'Repairs Orphanusers'
'Repairs Orphanusers' | add-content c:\changes\$Logname.log
Repair-DbaDbOrphanUser -sqlinstance $sqlinstance2 -database $todatabase -RemoveNotExisting | add-content c:\changes\$Logname.log <# Repair orphanusers #>

Write-Host 'Writes Orphanusers that remains that couldnot be mapped or deleted to the log'
'Orphanusers that remains that couldnot be mapped or deleted' | add-content c:\changes\$Logname.log
Get-DbaDbOrphanUser -sqlinstance $sqlinstance2 -database $todatabase| add-content c:\changes\$Logname.log <# Checks if any orphanusers remains that couldnot be mapped or deleted #>

Write-Host 'Set DBowner for ' + $todatabase + ' to SA'
'Set DBowner for ' + $todatabase + ' to SA' | add-content c:\changes\$Logname.log
set-dbadbowner -sqlinstance $sqlinstance2 -database $todatabase  | add-content c:\changes\$Logname.log <# Sets DBowner for $todatabase to SA #>

Write-Host 'Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views.'
'Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views.' | add-content c:\changes\$Logname.log
Invoke-DbaDbUpgrade -SqlInstance $sqlinstance2 -database $todatabase <#Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views #>

Write-Host 'Runs the Inventory SQL agent job'
'Runs the Inventory SQL agent job' | add-content c:\changes\$Logname.log
Start-DbaAgentJob -SqlInstance $sqlinstance2 -job $job | add-content c:\changes\$Logname.log

$item = Get-DbaDatabase -SqlInstance $sqlinstance2 -Database $todatabase | Select-Object Name
Write-Host 'Database ' + $Item + ' now succesfully copied'
'Database ' + $Item + ' now succesfully copied' | add-content c:\changes\$Logname.log

$rolemembers1 = Get-DbaDbRoleMember -SqlInstance $sqlinstance1 -Database $fromdatabase
$rolemembers2 = Get-DbaDbRoleMember -SqlInstance $sqlinstance2 -Database $todatabase 

$list = $rolemembers1 | Where-Object {$rolemembers2 -notcontains $_}
Write-Host 'The following users ' + $list + ' on ' + $fromdatabase + ' are not in the ' + $todatabase + ' Database' | Out-GridView
'The following users ' + $list + ' on ' + $fromdatabase + ' are not in the ' + $todatabase + ' Database' | add-content c:\changes\$Logname.log

<# Uncomment this if a backup should be done after the move #>

<#
'Backups the the database after move and places it in $targetbackupshare' | add-content c:\changes\$Logname.log
Backup-DbaDatabase -SqlInstance $sqlinstance2 -Database $todatabase -BackupDirectory  $targetbackupshare -BackupFileName $BackupFileName -CopyOnly | add-content c:\changes\$Logname.log
#>

Write-Host 'Script is completed'
'Script is completed' | add-content c:\changes\$Logname.log

<#Script end #>
