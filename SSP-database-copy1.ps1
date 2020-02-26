<# SSP-database-copy1.ps1
.DESCRIPTION 
    Copies a database from one Sqlserver "Source" to an other SQL server "target" using a netshare
    
    
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-09-012 16:00 
    Version 0.9

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    *

    To Do: 
    * Add error handling


<# Collects variables from the console. either by prompted questions or i values is piped to the script #>
$Sourceserver = "SSPDB3PROD" #"SSPDB4PROD"
$databases = Get-Content -Path C:\Scripts\Powershell\SESP_databases3PROD.txt
$Targetserver = "SSPDB16892"  #"SSPDB16495"
$netshare"\\ssp.local\SO\Services\SQLBCK\SE\LKP\SSPDB16892\MSSQL"
#$netshare="\\ssp.local\SO\Services\SQLBCK\SE\LKP\SSPDB16495\MSSQL"


$sqlinstance1 = 'SSPDB3PROD,11433'
$sqlinstance2 = 'SSPDB16892,11433'




<# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'

$freeok = $True
$Dbexists = $false

$dbperm="IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'SSP\SVC-SESP-PROD-Farm')
CREATE USER [SSP\SVC-SESP-PROD-Farm] FOR LOGIN [SSP\SVC-SESP-PROD-Farm] WITH DEFAULT_SCHEMA=[DBO]
GO
ALTER ROLE [DB_owner] ADD MEMBER [SSP\SVC-SESP-PROD-Farm]
GO
GRANT CONNECT TO [SSP\SVC-SESP-PROD-Farm]  AS [dbo];
GO
IF NOT EXISTS (SELECT * FROM sys.database_principals WHERE name = N'SSP\SVC-SESP-PROD-Admin')
CREATE USER [SVC-SESP-PROD-Admin] FOR LOGIN [SVC-SESP-PROD-Admin ] WITH DEFAULT_SCHEMA=[DBO]
GO
ALTER ROLE [db_owner] ADD MEMBER [SSP\SVC-SESP-PROD-Farm]
GO
GRANT CONNECT TO [SVC-SESP-PROD-Admin]  AS [dbo];
GO
USE [PROD_Config]
GO
"


#########################  Functions ###################################################


Function Get-permissions # Copies permissons of an database in to the variable $query #
{
    param($sqlinstance, $database)

    Write-Host 'Get Permissions from the existing database'
    $query = Export-DbaUser -SqlInstance $sqlinstance -Database $database -Passthru
    Return $query
}

Function databasecopy # Copies the database between source and target using a netshare and backup-restore. sets new name on the databse on the target. It replaces an existing database with the same name#

{
    param($sqlinstance1, $database, $sqlinstance2, $newname, $Netshare)

    Write-Host 'Starting the database copying'
    copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database $database -newname $newname -backupRestore -SharedPath $Netshare  -withReplace | Write-output <# Add -UseLastBackup if you want to use lastbackup #>

    <# Set owner of the database to SA #>
    Write-Host 'Set DBowner for ' $newname ' to SA'
    set-dbadbowner -sqlinstance $sqlinstance2 -database $newname  | Write-output <# Sets DBowner for $database to SA #>
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
    Write-Host 'Sets Permissions on database'+ $database
    Invoke-DbaQuery  -SqlInstance $sqlinstance -Database $database -Query $query | Write-Output

}


function CheckforDB # Checks i a database exist on a server #
{
    param ($sqlinstance, $database
    )
    

    Write-Host 'Checking if the database allready exist and the permissions should be recreated after the database coping'
    $present = Get-DbaDatabase -SqlInstance $sqlinstance -Database $database | Select-Object name


    if ($present) {$Dbexists = $true} 
    else
    {$Dbexists = $false}

    if ($Dbexists -eq $true) { Write-host  "The database exist on the target"}
    else {if ($Dbexists -eq $false) {write-host "No database with that name exist checking diskspace"}}
    Return $Dbexists
}

Function Copy-users
{
    param ($sqlinstance1, $database, $sqlinstance2
    )


$User = Get-DbaDbUser -SqlInstance $sqlinstance1 -Database $database
foreach ($usr in $User)
{
Copy-DbaLogin -Source $sqlinstance1 -Destination $sqlinstance2 -Login $Usr.Name
}  

}




function DBFileSize # Checks if and database fits on the target server #
{
    param ($sqlinstance1, $database, $sqlinstance2
    )
            
 
    <# Get sizes on primary datafile and log file for the database on the source #>
    write-host "Checking the size of the database"
  $Datadisk1 = Get-DbaDbFile -SqlInstance $sqlinstance -Database $database | Where-Object filegroupname -EQ PRIMARY | Select-Object size
  $logdisk1 = Get-DbaDbFile -SqlInstance $sqlinstance -Database $database |  Where-Object typedescription -eq log | Select-Object size

    <# Convert it to GB#>
    $datasize1 = $Datadisk1.size.gigabyte
    $logsize1 = $logdisk1.size.gigabyte

    <#Get Disksizes on targetserver #>
    Write-Host "Checking the size of the data and log disk"
    $datasize2 = get-freespace -sqlinstance 'corpdb4044,11433' -file 'data'
    $logsize2 = get-freespace -sqlinstance 'corpdb4044,11433' -file 'LOG'

    #$datadisk2 = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername $Targetserver | Where-Object deviceid -eq E: | Select-Object FreeSpace
    #$logdisk2 = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername $Targetserver | Where-Object deviceid -eq F: | Select-Object FreeSpace

    <# Convert it to GB#>
    #$datasize2 = [math]::round($datadisk2.FreeSpace / 1GB, 0)
    #$logsize2 = [math]::round($logdisk2.FreeSpace / 1GB, 0)

    <# Check if the database fits#>
    write-host "checking if the database fits"
    $Datafreespace = $datasize2 - $datasize1
    $logfreespace = $logsize2 - $logsize1

    <#Sets an true/false flag if the data disk is ok#>
    If ($Datafreespace -gt 0) {$dataok = $True}
    Else {$dataok = $false}


    <#Sets an true/false flag if the log disk is ok#>
    If ($logfreespace -gt 0) {$logok = $True}
    Else {$logok = $false}


    IF ($dataok -EQ $true -AND $logok -EQ $True) {write-host "The database $database fits on the targetserver" -f Green}
    else {$freeok = $false}



    <#Convert negative size to a positive number#>
    $Datafreespace = - ($Datafreespace)
    $logfreespace = - ($logfreespace)

    <# Print the missing size on the datadisk #>
    if ($dataok -eq $false) {Write-Host $Datafreespace "GB is missing on the Data disk" -ForegroundColor Red}
    else
    {
        Write-Host "The datadisk is ok" 
    
    }

    <# Print the missing size on the log disk #>
    if ($logok -eq $false) {Write-Host $logfreespace "GB is missing on the Log disk" -ForegroundColor Red}
    else { Write-Host "The Log disk is ok" }

    if ($dataok -eq $false -or $logok -eq $false) {Write-Host "Please order more disk"}
    


    if ($freeok -eq $True)  {write-host "continuing"}
    elseif ($freeok = $false) {exit}
    Return $freeok
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


function netshare # Get a share to be use for the coping #
{
    param ($Sourceserver, $Targetserver, $sqlinstance1,$sqlinstance2
    )


$getshare1 = Get-netshare -server $Sourceserver | Select-Object -ExpandProperty BackupAreaLink
$getshare2 = Get-netshare -server $Targetserver | Select-Object -ExpandProperty BackupAreaLink
$netshare1 =  $getshare1 + "\MSSQL\" + $Sourceserver
$netshare2 =  $getshare2 + "\MSSQL\" + $Targetserver

$testshare1 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $netshare1
$testshare2 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $netshare2


if ($testshare1 -eq $true) {$netshare = $netshare1}
elseif ($testshare2 -eq $true) {$netshare = $netshare2   
}

if ($testshare1 -eq $false -and $testshare2 -eq $false) {$share = Read-Host  "Service account cant use backupshare for coping please enter a share to use"
$Testshare3 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $share
}


if ($Testshare3 -eq $true) {$netshare = $share}
elseif ($testshare1 -eq $false -and $testshare2 -eq $false -and $Testshare3 -eq $false ) {write-host "Please check that share is ok and try again" exit}

Return $netshare
}


Function Set-folderpermission # Gives Serviceaccount access to a folder
{
param($Serviceaccount, $netshare)

$acl = Get-Acl $netshare
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Serviceaccount,"Modify","Allow")
$acl.SetAccessRule($AccessRule)
$acl | Set-Acl $netshare

Write-Host  $Serviceaccount +"now has modify on "+$netshare

}

Function remove-folderpermission # removes a Serviceaccount access to a folder
{
param($Serviceaccount, $netshare)
$acl = Get-Acl $netshare

$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Serviceaccount,"Modify","Allow")

$acl.RemoveAccessRule($AccessRule)

$acl | Set-Acl $netshare

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
IF ($gotport -eq $false) {$Port = '11433' }
IF ($gotdomain -eq $false) {$Domain = (Get-WmiObject -ComputerName $Servername Win32_ComputerSystem).Domain}

IF ($gotdomain -eq $false) {$sqlinstance = $Servername + "." + $Domain}
else {
    $sqlinstance = $Servername
}
IF ($gotport -eq $false)  {
    $sqlinstance = $sqlinstance +  "," + $Port}
    else {
        $sqlinstance = $sqlinstance
    }


   
Return $sqlinstance
}


Function get-freespace {
    param (
        $sqlinstance,$file
    )
    If ($file -eq "Data") {$Device=1}
    elseif ($file -eq "log") {$Device=2      
    }

        $query="select available_bytes /1024/1024/1024 as Free_GB from sys.dm_os_volume_stats (5, $Device)"
    
        $freespace= Invoke-DbaQuery -SqlInstance $sqlinstance -Query $query
        
    Return $freespace.Free_GB
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

Foreach ($database in $databases)
{

# Check if the targetdatabase exists #
$Dbexists = CheckforDB -sqlinstance $sqlinstance2 -database $database

# IF Targetdatabase exist get current permissions else check for diskspace on Targetserver #
if ($Dbexists -eq $true) {$perm = Get-permissions -sqlinstance $sqlinstance2 -database $database}

if ($Dbexists -eq $false)
{
    $freeok = DBFileSize -sqlinstance1 $sqlinstance1 -database $database -sqlinstance2 $sqlinstance2
}

############### Starting Database coping ############################

databasecopy -sqlinstance1 $sqlinstance1 -database $database -sqlinstance2 $sqlinstance2 -Newdbname $database -Netshare $netshare


# Runs checks and update stats on the copied database #
DBAupgrade -sqlinstance $sqlinstance2 -database $database

#If the database did exist set the same permissons on the copied database #
if ($Dbexists -eq $true) {Set-Permission -sqlinstance $sqlinstance2 -database $database -Query $perm}

# Set Service account perm
Set-Permission -sqlinstance $sqlinstance2 -database $database -query $dbperm


# Resyncs the users in the copied database with existing logins on the target server#
Write-Host 'Repairs Orphanusers'
Repair-DbaDbOrphanUser -sqlinstance $sqlinstance2 -database $database -RemoveNotExisting -Force 



}


Write-Host 'Copy logins'
Copy-DbaLogin -Source $sqlinstance1 -Destination $sqlinstance2 -ExcludeSystemLogins

<#
Write-Host 'Renaming Databases'
Rename-DbaDatabase -SqlInstance $sqlinstance2 -Database SSP_PROD_SSP2013TEST_Content -DatabaseName SSP_PROD_SSPTEST_Content
Rename-DbaDatabase -SqlInstance $sqlinstance2 -Database SX_PROD_Content_ASP -DatabaseName SX_PROD_Dedicated1
Rename-DbaDatabase -SqlInstance $sqlinstance2 -Database SX_PROD_Content_SASP -DatabaseName SX_PROD_Content5
Rename-DbaDatabase -SqlInstance $sqlinstance2 -Database SSP_PROD_2013_Saab3402000_Content -DatabaseName SSP_PROD_Saab3402000_Content
Rename-DbaDatabase -SqlInstance $sqlinstance2 -Database SSP_PROD_2013_SSPRapid_Content -DatabaseName SSP_PROD_SSPRapid_Content

#>

Start-DbaAgentJob -SqlInstance $sqlinstance2 -Job $job


'Script is completed. Remember to check permission on the copied databases' | Write-output

Get-Date | out-file -FilePath c:\scripts\SSPcopy1time.txt

<#Script end #>

