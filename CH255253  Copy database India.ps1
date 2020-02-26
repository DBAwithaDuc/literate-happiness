<# CH255253  Copy database India.PS1
 .DESCRIPTION 
    Restores a database to a specific time 
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-01-16 15:48 
    Version 0.9

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add support for diffrent ports on the sqlinstance
    * Add logfile Path 
    * Add error handling
    
  
#>

<# NAme of the job that vill be runned after completion #>
$job = 'ITDrift - SQL Inventory to SQL Drift'

$Sourceserver = 'corpdb9710'
$Targetserver = 'corpappl10693'
$deletedb = 'SITC_MoveTest'
$database = 'SITC_PROD'
$newname = 'SITC_PROD_OLD'
$netshare = '\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb9710\MSSQL\CORPDB9710'

<# Convert server to instance #>
$sqlinstance1 = $Sourceserver + ',11433'
$sqlinstance2 = $Targetserver + ',11433'



<# rename database#>
Write-Host 'Continue and rename the database ' $newname' on '$targetserver ""
$response = read-host "Press a to abort, any other key to continue."
$aborted = $response -eq "a"

If ($aborted -eq $false) {Write-Host 'Starting'}
else
{
    EXIT
}

Rename-DbaDatabase -SqlInstance $sqlinstance2 -Database $database -DatabaseName $newname |Write-Output
"Database renamed" | Write-Output


<# Delete database#>
Write-Host 'Continue and delete the database ' $deletedb' on '$targetserver ""
$response = read-host "Press a to abort, any other key to continue."
$aborted = $response -eq "a"

If ($aborted -eq $false) {Write-Host 'Starting'}
else
{
    EXIT
}

Remove-DbaDatabase -SqlInstance $sqlinstance2 -Database $deletedb |Write-Output
"Database deleted" | Write-Output

<# Delete database#>
Write-Host 'Continue and copy the database ' $database' to '$targetserver ""
$response = read-host "Press a to abort, any other key to continue."
$aborted = $response -eq "a"

If ($aborted -eq $false) {Write-Host 'Starting'}
else
{
    EXIT
}


# Copies the database between source and target using a netshare and backup-restore. sets new name on the databse on the target. It replaces an existing database with the same name#>
Write-Host 'Starting the database copying'
copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database $database -backupRestore -SharedPath $Netshare  -withReplace | Write-output <# Add -UseLastBackup if you want to use lastbackup #>

<# Resyncs the users in the copied database with existing logins on the target server#>
Write-Host 'Repairs Orphanusers'
Repair-DbaDbOrphanUser -sqlinstance $sqlinstance2 -database $database-RemoveNotExisting | Write-output <# Repair orphanusers #>

<# Set owner of the database to SA #>
Write-Host 'Set DBowner for ' $database' to SA'
set-dbadbowner -sqlinstance $sqlinstance2 -database $database | Write-output <# Sets DBowner for $databaseto SA #>

<# Runs checks and update stats after the coping is completed  #>
Write-Host 'Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views.'
Invoke-DbaDbUpgrade -SqlInstance $sqlinstance2 -database $database| Write-output <#Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views #>


<# checks the target server i the database exist #>
$item = Get-DbaDatabase -SqlInstance $sqlinstance2 -Database $database| Select-Object Name
'Database ' + $Item + ' now succesfully copied' | Write-output

<# Compares the users in the source and the target databases #>
$rolemembers1 = Get-DbaDbRoleMember -SqlInstance $sqlinstance1 -Database $database
$rolemembers2 = Get-DbaDbRoleMember -SqlInstance $sqlinstance2 -Database $database

<# Prints out users that was in the sourece database and missing in the target database#>
$list = $rolemembers1 | Where-Object {$rolemembers2 -notcontains $_}
Write-Host 'The following users : ' + $list + ' on ' $database  ' are not in the '  $database' Database' | Out-GridView

<# Starts the Inverntory job on the target server #>
Write-Host 'Runs the Inventory SQL agent job'
Start-DbaAgentJob -SqlInstance $sqlinstance2 -job $job | Write-output

'Script is completed. Remember to check permission on the copied database' | Write-output

<#Script end #>

