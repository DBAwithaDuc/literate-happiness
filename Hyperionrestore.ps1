# HYperionrestore.ps1
.DESCRIPTION 
Script to do restore of Hyperiondatabases for aduit


- 

.NOTES 
Created by: Mattias Gunnmo @DBAwithaDuc
Modified: 2020-01-08  
Version 0.1

Requirements:
Have the Powershell module DBAtools installed
See https://dbatools.io for instructions    

Changelog: 
* 

To Do: 
* Add error handling
*



#>




<# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'


# Set Start values
#$server="Corpdb9367"
#$SQLInstance= "Corpdb9367.corp.saab.se,11433"

$server="Corpdb4044"
$SQLInstance= "Corpdb4044.corp.saab.se,11433"


$databases=  Get-DbaDatabase -sqlinstance $SQLInstance -excludesystem -excludedatabase itdrift,HypOBIEEParam
$restoretime = "2019-12-16 13:00"


<#Convert restoretime to date format#>
$restoreto = get-date($restoretime)
#########################  Functions ###################################################


Function Get-permissions # Copies permissons of an database in to the variable $query #
{
    param($sqlinstance, $database)

    Write-Host 'Get Permissions from the existing database'
    $query = Export-DbaUser -SqlInstance $sqlinstance -Database $database -Passthru
    Return $query
}



Function DBAupgrade # Runs checks and update stats #
{
    param($sqlinstance, $database)

    
    Write-Host 'Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views.'
    Invoke-DbaDbUpgrade -SqlInstance $sqlinstance -database $database | Write-output <#Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views #>

}


Function Set-Permission # Set permissions on a database using script in the variable $query
{
    Param ($sqlinstance, $database, $query)
    Write-Host 'Sets Permissions on database'+ $Newdbname
    Invoke-DbaQuery  -SqlInstance $sqlinstance -Database $database -Query $query | Write-Output

}


function Get-backupinfo {
    param ($sqlinstance,$database      
    ) 

<# Get backupfile info#>
Write-Host 'Scanning through backupfiles ' ""
$backuphistory = Get-DbaDbBackupHistory -SqlInstance $sqlinstance -Database $database

Return $backuphistory

}


function Restore-Database-tonewname {
    param ($backuphistory, $sqlinstance,$database,$restoreto,$newname,$Prefix
    )
    
<# Starting restore of the the database from the backupfiles that matches#>
Write-Host 'Starting Restore of ' $database' on '$sqlinstance
$BackupHistory | Restore-DbaDatabase -SqlInstance $sqlinstance -TrustDbBackupHistory -RestoreTime $restoreto -DestinationFileSuffix -RestoredDatabaseNamePrefix

}




######################### CALLS ##################################

## Start Config ###
$sqldrift = 'SQLDRIFTDB.CORP.SAAB.SE,11433'

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'


Write-Host "This script restore a database on a SQL server (Source) to specifictime"
#Write-Host "If the target database exist it copies the permissions overwrite it and apply the permissions again when the copying is completed"
<# Collects variables from the console. either by prompted questions or i values is piped to the script #>




### loop##

Foreach ($database in $databases)
{

 $database 

<# Get backupfile info#>
Write-Host 'Scanning through backupfiles ' ""
$backuphistory = get-backupinfo -sqlinstance $sqlinstance -database $database

# get Permissions #
$perm= Get-permissions -sqlinstance @SQLInstance -database $database


<# Starting restore of the the database from the backupfiles that matches#>
Write-Host 'Starting Restore of ' $database' on '$server
$BackupHistory | Restore-Database-tonewname -SqlInstance $sqlinstance -database $database -backuphistory $backuphistory -restoreto $restoreto -Prefix "Audit" -newname 


<# checks the target server if the database exist #>
$item = Get-DbaDatabase -SqlInstance $sqlinstance -Database $database | Select-Object Name
'Database ' + $Item.Name + ' now succesfully restored' | Write-output

# set the same permissons on the restored database #
Set-Permission -sqlinstance $sqlinstance -database $database -Query $perm

# Runs checks and update stats on the copied database #
DBAupgrade -sqlinstance $sqlinstance2 -database $database


}




Restore-DbaDatabase -SqlInstance $sqlinstance -