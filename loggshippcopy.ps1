#Invoke-DbaDbLogShipping -SourceSqlInstance 'corpdb4044.corp.saab.se,11433' -DestinationSqlInstance 'corpdb4045.corp.saab.se,11433' -Database AdventureworksDW2016CTP3 -SharedPath "\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb4044\MSSQL\AdventureworksDW2016CTP3" -CopyDestinationFolder "\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb4045\MSSQL\Logshipp\AdventureworksDW2016CTP3"  -CompressBackup  


$Source = "corpdb4044.corp.saab.se,11433"
$Destination = "corpdb4044.corp.saab.se,11433"
$Sourcedb = "AdventureworksDW2016CTP3"
$Destdb = "AdventureworksDW2016CTP32"
$targetfolder = "\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb4044\MSSQL\CORPDB4044\AdventureworksDW2016CTP3\LOG"  ##Source of logfiles
 

# Copy SSP databases.ps1

$Sourceserver = ""
$Targetserver = ""
$netshare="\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb4044\MSSQL\"
$targetfolder = "$netshare\$sourceserver\CORPDB4044\AdventureworksDW2016CTP3\LOG"  ##Source of logfiles
$database = get-content -path c:\scripts\databases.txt
$login1="SVC-SESP-PROD-ADMIN"
$login2="SVC-SESP-PROD-FARM"
$ADgroup= 'AP-CO-SHAREPOINT_PROD-SQLdbOwner' # Not implemeted 
$sqlRole="db_Owner"

<# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'

#########################  Functions ###################################################


Function databasecopy # Copies the database between source and target using a netshare and backup-restore. sets new name on the databse on the target. It replaces an existing database with the same name#

{
    param($sqlinstance1, $database, $sqlinstance2, $Newdbname, $Netshare)

    Write-Host 'Starting the database copying'
    copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database $database -newname $Newdbname -backupRestore -SharedPath $Netshare  -withReplace -NoRecovery| Write-output <# Add -UseLastBackup if you want to use lastbackup #>

    <# Set owner of the database to SA #>
    Write-Host 'Set DBowner for ' $newdbname ' to SA'
    set-dbadbowner -sqlinstance $sqlinstance2 -database $newdbname  | Write-output <# Sets DBowner for $newdbname to SA #>
}


Function DBAupgrade # Runs checks and update stats #
{
    param($sqlinstance, $database)

    
    Write-Host 'Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views.'
    Invoke-DbaDbUpgrade -SqlInstance $sqlinstance -database $database | Write-output <#Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views #>

}

Function Set-DBPermission
{  param($sqlinstance, $database, $Name, $sqlRole )

$Query= 
"ALTER USER [$name] WITH DEFAULT_SCHEMA=[dbo]
 ALTER ROLE [$sqlrole] ADD MEMBER [$name]
GO"

Invoke-DbaQuery -SqlInstance $sqlinstance -Database $database -Query $Query
}


function test-Netsharepaths # tests if a networkshare can be accessed from two sqlinstances#
{
    param ($sqlinstance1, $sqlinstance2, $Netshare
    )


$path1ok = Test-DbaPath -SqlInstance $sqlinstance1 -Path $Netshare

$path2ok = Test-DbaPath -SqlInstance $sqlinstance2 -Path $Netshare

if ($path1ok -eq $false) {Write-host "The netshare can't be reached from " $Sourceserver " please check"}

If ($path2ok -eq $false) {Write-host "The netshare can't be reached from " $Targetserver " please check"}

if ($path1ok -eq $true -and $path2ok -eq $true) {$pathok = $true}

Return $pathok
}



function get-sqlinstance {
    param (
        $Servername
    )
 


IF ($servername -like "*,*") {$gotport= $true}
else {$gotport =$false
}
IF ($servername -like "*.*" ) {$gotdomain= $true}
else {$gotdomain =$false 
}
IF ($gotport -eq $false) {$Port = Get-DbaTcpPort -SqlInstance $Servername -All }
IF ($gotdomain -eq $false) {$Domain = (Get-WmiObject -ComputerName $Servername Win32_ComputerSystem).Domain}

IF ($gotdomain -eq $false) {$sqlinstance = $Servername + "." + $Domain}
else {
    $sqlinstance = $Servername
}
IF ($gotport -eq $false)  {
    $sqlinstance = $sqlinstance +  "," + ($Port.port | Get-Unique) }
    else {
        $sqlinstance = $sqlinstance
    }


   
Return $sqlinstance
}


function logrestore {
    param ($source, $Destination, $Sourcedb, $Destdb, $netshare
        
    }

$Sourcegetrestore = @"
select top 1 B.backup_finish_date from msdb.dbo.backupset B 
join msdb.dbo.restorehistory RH  on RH.backup_set_id = B.backup_set_id 
where B.type = 'L' and RH.destination_database_name =  '$Destdb' order by B.backup_set_id desc
"@

 $servername = $source.Split(".")[0]

$targetfolder=$netshare+$servername+'\'+$Sourcedb+'\'+'log'
 
$result = Invoke-DbaQuery -SqlInstance $Destination -Database "MSDB" -Query $Sourcegetrestore
 
$lastdate = [datetime] $result.backup_finish_date #| Get-Date -Format "MM/dd/yyyy HH:mm:ss"
 
$lastbackuptime = ($lastdate).AddMinutes(1) <#Restore files after previous#>
 
Get-ChildItem -path $TargetFolder -filter *.trn -recurse | Where-Object {$_.LastWriteTime -ge $lastbackuptime -and !$_.PsIsContainer} | Sort-Object lastwritetime | ForEach-Object { 
      $sqlquery = "RESTORE LOG [$Destdb]  from  DISK = N'" + $_.fullname + "' WITH  FILE = 1, NOUNLOAD, STATS = 10, NORECOVERY"; 
                 Write-Output $sqlquery
      #Invoke-DbaQuery $sqlInstance $Destination -Database "MSDB" -Query $sqlquery -QueryTimeout 900;
} 


Function Enable-backupcompression # changes backupcompression default to enabled
{
    param($sqlinstance)



    $BCOnquery=
    "EXEC sys.sp_configure N'backup compression default', N'1'
    GO
    RECONFIGURE WITH OVERRIDE
    GO"

Invoke-DbaQuery -SqlInstance $sqlinstance -Database master -Query $BConquery


}


Function Disable-backupcompression # changes backupcompression default to disable
{
    param($sqlinstance)



    $BCOfquery=
    "EXEC sys.sp_configure N'backup compression default', N'0'
    GO
    RECONFIGURE WITH OVERRIDE
    GO"

Invoke-DbaQuery -SqlInstance $sqlinstance -Database master -Query $BCofquery


}



    



######################### CALLS ##################################

<# Convert servers to instances #>

## Clean servernames  ##
$Sourceserver = $Sourceserver.Split(",")[0]
$Targetserver = $Targetserver.Split(",")[0]

#Test if netshare can be used #>
$Netshareok = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $Netshare

if ($Netshareok -eq $false) {write-host "Please verify permissions on the networkshare" $Netshare exit }
else
{
    Write-Host " Permissons on the networkshare ok"

}
$Time=Get-Date -Format "yyyy-MM-dd HH:mm"
'Copy Starting ' + $time | Add-Content $logfile


Enable-backupcompression -sqlinstance $sqlinstance1

Foreach ($database in $databases)
{

$Dbexists = CheckforDB -sqlinstance $sqlinstance2 -database $database.new

# IF Targetdatabase exist get current permissions else check for diskspace on Targetserver #
if ($Dbexists -eq $true) {$perm = Get-permissions -sqlinstance $sqlinstance2 -database $database.new}

if ($Dbexists -eq $false)
{
    #$freeok = DBFileSize -sqlinstance1 $sqlinstance1 -database $database.old -sqlinstance2 $sqlinstance2
}

############### Starting Database coping ############################

databasecopy -sqlinstance1 $sqlinstance1 -database $database.old -sqlinstance2 $sqlinstance2 -Newdbname $database.new -Netshare $netshare

#If the database did exist set the same permissons on the copied database #
if ($Dbexists -eq $true) {Set-Permission -sqlinstance $sqlinstance2 -database $database.new -Query $perm}

# Set Service account perm
Set-Permission -sqlinstance $sqlinstance2 -database $database.new -query $dbperm


# Resyncs the users in the copied database with existing logins on the target server#
Write-Host 'Repairs Orphanusers'
Repair-DbaDbOrphanUser -sqlinstance $sqlinstance2 -database $database.new -RemoveNotExisting -Force 

logrestore -source $sqlinstance1 -Destination $sqlinstance2 -Sourcedb $database.old -Destdb $database.new -netshare $netshare


}

Disable-backupcompression

Write-Host 'Copy logins'
Copy-DbaLogin -Source $sqlinstance1 -Destination $sqlinstance2 -ExcludeSystemLogins

Foreach ($database in $databases)
{
# Runs checks and update stats on the copied database #
DBAupgrade -sqlinstance $sqlinstance2 -database $database.new
$Time=Get-Date -Format "yyyy-MM-dd HH:mm"
$database.new+' '+ $time | Add-Content $logfile
}





Disable-backupcompression

#Start-DbaAgentJob -SqlInstance $sqlinstance2 -Job $job

'Script is completed. Remember to check permission on the copied databases' | Write-output
$Time=Get-Date -Format "yyyy-MM-dd HH:mm"
'Copy Finnished ' + $time | Add-Content $logfile

<#Script end #>





