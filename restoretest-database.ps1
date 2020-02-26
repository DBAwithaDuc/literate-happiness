<# restoretest-database.ps1
 .DESCRIPTION 
    Runs a restore test on a multiple databases on an multiple servers
    
    The process is as follows 
    - 

.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-09-09 16:00 
    Version 0.1

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * 

    #>



<# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}


$SQLDrift="CORPDB4804.CORP.SAAB.SE,11433"

$Restoringserver='Corpdb4045,11433'
$logserver="CORPDB4044.CORP.SAAB.SE,11433"
$logdatabase="test2019"
$server="CORPDB4044"


#########################  Functions ###################################################


Function Get-server
{
    param($SQLDrift,$server
    )

    $query="SELECT Connectionstring
    FROM [SQLDrift].[dbo].[tblSQLServer]
    where ServerName=$server"

$Connectionstring = Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query

Return $Connectionstring

}

Function Check-Backup
{
    param($sqlinstance, $destination
    )

    $backupinfo = Test-DbaLastBackup -SqlInstance $sqlinstance -Destination $destination -Prefix testrestore- -ExcludeDatabase master

Return $backupinfo

}


Function Log-ToTable
{
    param($logserver,$logdatabase, $data
    )
    Write-DbaDbTableData -SqlInstance $logserver -Database $logdatabase -Table TBLRestoreHistory -InputObject $data

}

######################### CALLS ##################################

#$sqlinstance = Get-server -SQLDrift $SQLDrift -server $server
$sqlinstance="CORPDB4044.CORP.SAAB.SE,11433"

$logdata = Check-Backup -sqlinstance $sqlinstance -destination $Restoringserver

#Log-ToTable -logserver $logserver -logdatabase $logdatabase -data $logdata

$logdata | Out-GridView

