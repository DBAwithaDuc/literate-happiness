# backup-databases.ps1
 .DESCRIPTION 
    Backups one or more databases in default location with compress and copyOnly
    
    
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-10-15
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
$SQLDrift="CORPDB4804.CORP.SAAB.SE,11433"

#########################  Functions ###################################################



Function Get-netshare
{
    param($server,$SQLDrift
    )
    
    $server = $server.Split(".")[0]
  
 
$query="SELECT BackupAreaLink
FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$server'"

$netshare1=Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query

$Netshare = $netshare1 | Select-Object -ExpandProperty BackupAreaLink


IF  ($Netshare -eq "" -or $Netshare -eq $null) {$netshare = Read-Host "Can't reach SQLDrift to get an netshare to use. Pkease enter an netshare that both servers can reach" }


Return $netshare
}



Function Get-connectionstring {
    param ($computername, $sqldrift
    )
    
    $computername = $computername.Split(".")[0]
    
    $Cquery=
    "Select Connectionstring FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$computername'"

$connectionstring = Invoke-DbaQuery -SqlInstance $sqldrift -Database sqldrift -Query $Cquery | Select-Object -ExpandProperty Connectionstring

Return $connectionstring

}

function Backup-database {
    param ($sqlinstance,$databases,$netshare)
        
        Backup-DbaDatabase -SqlInstance $sqlinstance -Database $databases -Path $netshare+'\MSSQL\' -CopyOnly -CompressBackup   
    
}


################### Start Config ##################

$multicopy='Y'
$copyno='N'

####  Start Loop ##############
while($multicopy -eq 'Y' )
{
#Clear-host
Write-Host "This script backup one or more databases on a SQL server (Source) to the defaultbackupshare"

<# Collects variables from the console. either by prompted questions or i values is piped to the script #>
$Sourceserver = IF($Sourceserver =( Read-Host "The server that the databases you want to backup is hosted on? [$defaultsource]" )){$Sourceserver}else{$defaultsource}
$database = Read-Host "The database(s) you want to backup seperated by comma"

### Reset som variables  ##


<# Convert server to instance #>

$sqlinstance = Get-connectionstring -computername $Sourceserver -sqldrift $SQLDrift


## Clean servernames  ##
$Sourceserver = $Sourceserver.Split(",")[0]

# Get-netshare to use #

$netshare = Get-netshare -server $Sourceserver

$serverName = $Sourceserver.Split(".")[0]

$backupshare = $netshare + "\MSSQL\" + $serverName + "\"

## Starting Backup ###################
Backup-database -sqlinstance $sqlinstance -databases $database -netshare $backupshare


$multicopy = IF($multicopy =( Read-Host "backup more databases (Y/N) [$copyno] ?" )){$multicopy}else{$copyno}

$multicopy = $multicopy.ToUpper()

$defaultsource=$Sourceserver.toupper()

}



'Script is completed. Remember to check permission on the copied database' | Write-output

<#Script end #>
