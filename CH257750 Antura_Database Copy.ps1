<# CH257750 Antura_Database Copy.ps1
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

$Logname = 'CH257750'       <# Name on the logfile that logs everything #>
$sqlinstance1 = 'corpdb9783,11433'  <# From sqlinstance don't forget port  servername,port #>
$sqlinstance2 = 'corpdb9723,11433'  <# to sqlinstance #>
$backupshare = '\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb9723\MSSQL\corpdb9723'   <# Backupshare to be used#>
$fromdatabase = 'AnturaProjectsProd,AnturaIntegrationsProd,AnturaSupportServiceProd,AnturaIntegrationsProd_Temp'
$todatabase = 'AnturaProjectsTest,AnturaIntegrationsTest,AnturaSupportServiceTest,AnturaIntegrationsTest_Temp'
$job = 'ITDrift - SQL Inventory to SQL Drift' <# Job to be run after completion#>


Write-Host 'Starting the database copying'
copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database AnturaProjectsProd -backupRestore -SharedPath $backupshare  -withReplace -NewName AnturaProjectsTest | add-content c:\changes\$Logname.log <# Add -UseLastBackup if you want to use lastbackup #>
copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database AnturaIntegrationsProd	-backupRestore -SharedPath $backupshare  -withReplace -NewName AnturaIntegrationsTest | add-content c:\changes\$Logname.log <# Add -UseLastBackup if you want to use lastbackup #>
copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database AnturaSupportServiceProd -backupRestore -SharedPath $backupshare  -withReplace -NewName AnturaSupportServiceTest | add-content c:\changes\$Logname.log <# Add -UseLastBackup if you want to use lastbackup #>
copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database AnturaIntegrationsProd_Temp -backupRestore -SharedPath $backupshare  -withReplace -NewName AnturaIntegrationsTest_Temp | add-content c:\changes\$Logname.log <# Add -UseLastBackup if you want to use lastbackup #>







Write-Host 'Repairs Orphanusers'
'Repairs Orphanusers' | add-content c:\changes\$Logname.log
Repair-DbaDbOrphanUser -sqlinstance $sqlinstance2  -RemoveNotExisting | add-content c:\changes\$Logname.log <# Repair orphanusers #>

W
Write-Host 'Set DBowner for ' + $todatabase + ' to SA'
'Set DBowner for ' + $todatabase + ' to SA' | add-content c:\changes\$Logname.log
set-dbadbowner -sqlinstance $sqlinstance2  | add-content c:\changes\$Logname.log <# Sets DBowner for $todatabase to SA #>

Write-Host 'Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views.'
'Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views.' | add-content c:\changes\$Logname.log
Invoke-DbaDbUpgrade -SqlInstance $sqlinstance2 -database AnturaProjectsTest  <#Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views #>
Invoke-DbaDbUpgrade -SqlInstance $sqlinstance2 -database AnturaIntegrationsTest	 <#Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views #>
Invoke-DbaDbUpgrade -SqlInstance $sqlinstance2 -database AnturaSupportServiceTest	 <#Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views #>
Invoke-DbaDbUpgrade -SqlInstance $sqlinstance2 -database AnturaIntegrationsTest_Temp	 <#Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views #>





Write-Host 'Runs the Inventory SQL agent job'
'Runs the Inventory SQL agent job' | add-content c:\changes\$Logname.log
Start-DbaAgentJob -SqlInstance $sqlinstance2 -job $job | add-content c:\changes\$Logname.log

$item = Get-DbaDatabase -SqlInstance $sqlinstance2 -Database AnturaProjectsTest, AnturaIntegrationsTest, AnturaSupportServiceTest, AnturaIntegrationsTest_Temp | Select-Object Name
Write-Host 'Databases ' + $Item + ' now succesfully copied'
'Databases ' + $Item + ' now succesfully copied' | add-content c:\changes\$Logname.log

$rolemembers1 = Get-DbaDbRoleMember -SqlInstance $sqlinstance1 -Database $fromdatabase
$rolemembers2 = Get-DbaDbRoleMember -SqlInstance $sqlinstance2 -Database $todatabase 

$list = $rolemembers1 | Where-Object {$rolemembers2 -notcontains $_}
Write-Host 'The following users ' + $list + ' on ' + $fromdatabase + ' are not in the ' + $todatabase + ' Database' | Out-GridView
'The following users ' + $list + ' on ' + $fromdatabase + ' are not in the ' + $todatabase


