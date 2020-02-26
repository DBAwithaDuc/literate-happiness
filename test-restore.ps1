<# test-restore.ps1
 .DESCRIPTION 
    Script to test last backup on multiple databases on multiple servers
    
    
    - 

.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-10-14  
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

#########################  Functions ###################################################

<#

    
$query1="SELECT connectionstring
FROM [SQLDrift].[dbo].[tblSQLServer]
where domain = 'corp.saab.se'
and country = 'Sweden'
and discontinued =0
and sqldrift =1
AND [ProductVersion] like '1%' AND (datalength(ZON) = 0 OR [ZON] is NULL) AND EnvironmentID != '2'"

$serverlist = Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query1

$serverlist | Write-DbaDbTableData -SqlInstance 'corpdb4044,11433' -Database restotest -AutoCreateTable

#>

function Get-server {
    param ($sqlinstance,$database
        
    )
    $serverquery="
    select top 1  connectionstring from dbo.tblserverlist
    where runed = 0 or runed is null and removed is null
    "
    $server= Invoke-DbaQuery -SqlInstance $sqlinstance -Database $database -Query $serverquery

Return $server.connectionstring
}


function Test-backup {
    param ($source, $Destination
            )
    $log= Test-DbaLastBackup -SqlInstance $source -Destination $Destination -Prefix Restoretest_ 
    write-host $log
Return $log
}

function Write-logdatabase {
    param ($sqlinstance, $database, $log
            )
    $log |ConvertTo-DbaDataTable   | Write-DbaDataTable -SqlInstance $sqlinstance -Database $database -Table tblrestorelog
    $log | Out-GridView
}

function  set-serverlistmark {
    param ($sqlinstance, $database, $server
            )
    
            $updatequery="
            update dbo.tblserverlist
            set runed=1 
            where connectionstring = '$server'"            
         
Invoke-DbaQuery -SqlInstance $sqlinstance -database $database -Query $updatequery
}


function Set-resetserverlist ($sqlinstance,$database) {

 $resetquery="
 Update dbo.tblserverlist
 set runed =0
 where runed = 1
 "

 Invoke-DbaQuery -SqlInstance $sqlinstance -Database $database -Query $resetquery

 $reseted = $true

 Return $reseted
   
}

function Get-newservers {
    param ($sqldrift
            )
     $newserversquery="SELECT connectionstring
            FROM [SQLDrift].[dbo].[tblSQLServer]
            where domain = 'corp.saab.se'
            and country = 'Sweden'
            and discontinued =0
            and sqldrift =1
            AND [ProductVersion] like '1%' AND (datalength(ZON) = 0 OR [ZON] is NULL) AND EnvironmentID != '2'"
            
            $serverlist = Invoke-DbaQuery -SqlInstance $SQLDrift -Query $newserversquery
  
            Return $serverlist
}

function Set-timestamp {
    param ($sqlinstance,$database
        
    )

    $date = Get-Date -format "yyyy-MM-dd HH:mm"

    $timestampquery=
    "Insert into tblcounter (Date)
    Values ('$date')"    

    Invoke-DbaQuery -SqlInstance $sqlinstance -Database $database -Query $timestampquery

    $timestamp = $true
Return $ti
}

function Update-serverlist {
    param ($sqlinstance, $database, $newservers, $SQLDrift
       
    )
       
$query1="SELECT connectionstring
FROM [SQLDrift].[dbo].[tblSQLServer]
where domain = 'corp.saab.se'
and country = 'Sweden'
and discontinued =0
and sqldrift =1
AND [ProductVersion] like '1%' AND (datalength(ZON) = 0 OR [ZON] is NULL) AND EnvironmentID != '2'"

$serverlist = Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query1
$serverlist | Write-DbaDbTableData -SqlInstance $sqlinstance -Database $database -Table tblnewserverlist

$query2='
MERGE tblserverlist OLD USING tblnewserverlist NEW ON (new.connectionstring = old.connectionstring) WHEN NOT matched BY target THEN
INSERT (connectionstring)
VALUES (NEW.CONNECTIONSTRING) WHEN NOT matched BY SOURCE THEN
UPDATE
SET old.removed =1;
'
Invoke-DbaQuery -SqlInstance $sqlinstance -Query $query2 -Database $database

$updated = $true

 return $updated
}










####### Configurations ######################
$destinationserver ="corpdb17335.corp.saab.se,11433" ####  Server that restoretest is runned on
$logserver="corpdb17335.corp.saab.se,11433" ## Serverlist and logs ##########
$Restodatabase="Restoretestdb"  ## Serverlist and logs ##########
$counter=0
$continue = $true
$SQLDrift="SQLDRIFTDB.CORP.SAAB.SE,11433"
$runnumber=2

###########  CALL ##########################

### Check for new servers ###
#$newservers = Get-newservers -sqldrift $SQLDrift

## Update Serverlist ####



while($continue -ne $false)
  {

 ####  Get a server to test ###########   
$connectionstring = Get-server -sqlinstance $logserver -database $Restodatabase
Write-Host $connectionstring 'Connectionstring'

### Check if all servers has been checked and reset the list ############
if ($connectionstring -notmatch "\S" ) {$restart = Set-resetserverlist -sqlinstance $logserver -database $Restodatabase
  }

 
### Log a timestamp for when a reset was made ####
IF ($restart -eq $true) {$timestamp= Set-timestamp -sqlinstance $logserver -database $Restodatabase}
    
IF ($restart -eq $true) {$connectionstring = Get-server -sqlinstance $logserver -database $Restodatabase }


## Run restore test of sql server##
$log = Test-backup -source $connectionstring -Destination $destinationserver 

## MArk Server as checked ##
set-serverlistmark -server $connectionstring -sqlinstance $logserver -database $Restodatabase

## Run log to tabel ##
Write-logdatabase -sqlinstance $logserver -database $Restodatabase -log $log


$counter++

Write-Host " one server done"

if ($counter -ne $runnumber) {$continue = $true} 
else {$continue = $false}
    
}







     
