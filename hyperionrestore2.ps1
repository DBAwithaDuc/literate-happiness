<# hyperionrestore2.ps1
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
$server="Corpdb9367"
$SQLInstance= "Corpdb9367.corp.saab.se,11433"




$databases=  Get-DbaDatabase -sqlinstance $SQLInstance -excludesystem -excludedatabase itdrift,HypOBIEEParam 
$netshare='\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb9367\MSSQL\CORPDB9367'

<#Convert restoretime to date format#>
$restoreto = get-date($restoretime)
#########################  Functions ###################################################

Function Get-netshare
{
    param($server, $SQLDrift
    )
    
    $server = $server.Split(".")[0]
  
    
$query="SELECT BackupAreaLink
FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$server'"

$Netshare=Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query

IF  ($Netshare -eq "" -or $Netshare -eq $null) {$netshare = Read-Host "Can't reach SQLDrift to get an netshare to use. Pkease enter an netshare that both servers can reach" }


Return $netshare
}


Function get-restorepath 
{
    param($netshare,$database
 
    )
    
    

$path= $netshare+'\'+$database+'\FULL'
$files = Get-ChildItem $path -Recurse
$restorepath = $files  | Where-Object {$_.LastWriteTime -gt '12/16/2019' -and $_.LastWriteTime -lt '12/17/2019'} 

Return $restorepath.FullName

 }



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


function Restore-Database-path {
    param ($restorepath, $sqlinstance,$database,$newname
    )
    
<# Starting restore of the the database from the backupfiles that matches#>
Write-Host 'Starting Restore of ' $database' on '$sqlinstance' as '$newname
Restore-DbaDatabase -Path $restorepath -SqlInstance $sqlinstance -DatabaseName $newname -ReplaceDbNameInFile -WithReplace


}



######################### CALLS ##################################

## Start Config ###
$sqldrift = 'SQLDRIFTDB.CORP.SAAB.SE,11433'

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'


Write-Host "This script restore a det Hyperiondatabases for audit"
#Write-Host "If the target database exist it copies the permissions overwrite it and apply the permissions again when the copying is completed"
<# Collects variables from the console. either by prompted questions or i values is piped to the script #>




### loop##

Foreach ($database in $databases.name)
{


<# Get backupfile info#>
Write-Host 'Scanning through backupfiles ' ""
$restorepath = get-restorepath -netshare $netshare -database $database


<# get Permissions #>
$perm= Get-permissions -sqlinstance $SQLInstance -database $database

<# Set newname of DB  #>
$newname = $database+'_Audit'


<# Starting restore of the the database from the backupfiles that matches#>
Write-Host 'Starting Restore of ' $database' on '$server
Restore-Database-path -sqlinstance $SQLInstance -newname $newname -database $database -restorepath $restorepath

<# ser permission on new database from old  #>
Set-Permission -sqlinstance $SQLInstance -database $newname -query $perm

<# repair ophanlogins #>
Repair-DbaDbOrphanUser -SqlInstance $SQLInstance -Database $newname


# Runs checks and update stats on the copied database #
DBAupgrade -sqlinstance $sqlinstance2 -database $newname


}


