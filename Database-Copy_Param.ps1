<# Database-Copy_Param.ps1
 .DESCRIPTION 
    Copies one or more database from one Sqlserver "Source" to an other SQL server "target" using a netshare
    
    The process is as follows 
    - Collect variables from the console. either by prompted questions or i values is piped to the script
    - Checks if the Powershell module DBATOOLS exist
    - Set values for some needed variables
    - Check if both SQL instances got permissions on the networkshare
    - Check if the targetdatabase exists
    - If the target exist copy the permissons on the existing database
    - If the targetdatabase doesn't exit check if the database fits on the target server.
    - Starts the database copy using backup-Restore and a netshare
    - Set owner of the copied database to SA
    - Runs checks and update stats on the copied database
    - if the target database existed and has been overwritten add the copied permissons  
    - Resync the users in the copied database with existing logins on the target server
    - Runs the the ITDrift - SQL Inventory job  om the targetserver

.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-10-01 08:30 
    Version 2.45

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * Added value for $job variable
    * Updated the dokumentation and corrected some cosmetic bugs
    * Added check of disk size on the target if the database fits (merged script with the check disk size before db copy.ps1)
    * Added permissions coping if the databae exist on the target server
    * Rewriten the whole script using functions
    * Added check if the netshare can be accessed from the source and target servers
    * Change the construction of the connectionstrings (SQLinstance1,SQLinstance2)
    * Fetches netshare from backupshare info in the sqldrift database instead of enter it manually
    * Added checks for sourceserver and Targetserver if anyone uses sqlinstance name instead of servername
    * Change check for freespace on the targetserver to remove the demand for using VMI(RPC-calls)
    * Activate backupcompression before backup
    * added loop the script if you want to copy multiple databases
    * Handle FQDN servername when getting Netshare from SQlDrift
    * added Check if I can get any netshare from SQLDrift
    * CHange SQLDRIFT to the new server and change it to a glob al variable
    
   To Do: 
    * Add error handling
    * Add an option to copy the permissions from the source server if the datababase don't allready exist on the taget 
    * Add an anybox grafical interface
    * Add options to copy multiple databases(loop the script now)
    * Set permissions on the netshare if the serviceaccount on the two servers don't have access
    #>


param ($Sourceserver, $database, $Targetserver, $Newdbname, $mail)



<# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) { Import-module dbatools }

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'


#########################  Functions ###################################################


Function Get-netshare
{
    param($server, $SQLDrift
    )
    
    $server = $server.Split(".")[0]
  
    
    $query = "SELECT BackupAreaLink
FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$server'"

    $Netshare = Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query

    IF ($Netshare -notmatch "\S") { $netshare = Read-Host "Can't reach SQLDrift to get an netshare to use. Pkease enter an netshare that both servers can reach" }


    Return $netshare
}

Function Get-permissions # Copies permissons of an database in to the variable $query #
{
    param($sqlinstance, $database)

    Write-Host 'Get Permissions from the existing database'
    $query = Export-DbaUser -SqlInstance $sqlinstance -Database $database -Passthru
    Return $query
}

Function databasecopy # Copies the database between source and target using a netshare and backup-restore. sets new name on the databse on the target. It replaces an existing database with the same name#

{
    param($sqlinstance1, $database, $sqlinstance2, $Newdbname, $Netshare)

    Write-Host 'Starting the database copying'
    copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database $database -newname $Newdbname -backupRestore -SharedPath $Netshare  -withReplace | Write-output <# Add -UseLastBackup if you want to use lastbackup #>

    <# Set owner of the database to SA #>
    Write-Host 'Set DBowner for ' $newdbname ' to SA'
    set-dbadbowner -sqlinstance $sqlinstance2 -database $newdbname | Write-output <# Sets DBowner for $newdbname to SA #>
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


function CheckforDB # Checks i a database exist on a server #
{
    param ($sqlinstance, $database
    )
    

    Write-Host 'Checking if the database allready exist and the permissions should be recreated after the database coping'
    $present = Get-DbaDatabase -SqlInstance $sqlinstance -Database $database | Select-Object name


    if ($present) { $Dbexists = $true } 
    else
    { $Dbexists = $false }

    if ($Dbexists -eq $true) { Write-host  "The database exist on the target" }
    else { if ($Dbexists -eq $false) { write-host "No database with that name exist checking diskspace" } }
    Return $Dbexists
}

Function Copy-users
{
    param ($sqlinstance1, $database, $sqlinstance2
    )


    $User = Get-DbaDbUser -SqlInstance $sqlinstance -Database $database
    foreach ($usr in $User)
    {
        Copy-DbaLogin -Source $sqlinstance -Destination $Destination -Login $Usr.Name
    }  

}




function DBFileSize # Checks if and database fits on the target server #
{
    param ($sqlinstance1, $database, $sqlinstance2
    )
            
 
    <# Get sizes on primary datafile and log file for the database on the source #>
    write-host "Checking the size of the database"
    $Datadisk1 = Get-DbaDbFile -SqlInstance $sqlinstance -Database $database | Where-Object filegroupname -EQ PRIMARY | Select-Object size
    $logdisk1 = Get-DbaDbFile -SqlInstance $sqlinstance -Database $database | Where-Object typedescription -eq log | Select-Object size

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
    If ($Datafreespace -gt 0) { $dataok = $True }
    Else { $dataok = $false }


    <#Sets an true/false flag if the log disk is ok#>
    If ($logfreespace -gt 0) { $logok = $True }
    Else { $logok = $false }


    IF ($dataok -EQ $true -AND $logok -EQ $True) { write-host "The database $database fits on the targetserver" -f Green }
    else { $freeok = $false }



    <#Convert negative size to a positive number#>
    $Datafreespace = - ($Datafreespace)
    $logfreespace = - ($logfreespace)

    <# Print the missing size on the datadisk #>
    if ($dataok -eq $false) { Write-Host $Datafreespace "GB is missing on the Data disk" -ForegroundColor Red }
    else
    {
        Write-Host "The datadisk is ok" 
    
    }

    <# Print the missing size on the log disk #>
    if ($logok -eq $false) { Write-Host $logfreespace "GB is missing on the Log disk" -ForegroundColor Red }
    else { Write-Host "The Log disk is ok" }

    if ($dataok -eq $false -or $logok -eq $false) { Write-Host "Please order more disk" }
    


    if ($freeok -eq $True) { write-host "continuing" }
    elseif ($freeok = $false) { exit }
    Return $freeok
}

function test-Netsharepaths # tests if a networkshare can be accessed from two sqlinstances#
{
    param ($sqlinstance1, $sqlinstance2, $Netshare
    )


    $path1ok = Test-DbaPath -SqlInstance $sqlinstance1 -Path $Netshare

    $path2ok = Test-DbaPath -SqlInstance $sqlinstance2 -Path $Netshare

    if ($path1ok -eq $false) { Write-host "The netshare can't be reached from " $Sourceserver " please check" }

    If ($path2ok -eq $false) { Write-host "The netshare can't be reached from " $Targetserver " please check" }

    if ($path1ok -eq $true -and $path2ok -eq $true) { $pathok = $true }

    Return $pathok
}


function netshare # Get a share to be use for the coping #
{
    param ($Sourceserver, $Targetserver, $sqlinstance1, $sqlinstance2, $sqldrift
    )


    $getshare1 = Get-netshare -server $Sourceserver -SQLDrift $sqldrift | Select-Object -ExpandProperty BackupAreaLink
    $getshare2 = Get-netshare -server $Targetserver -SQLDrift $sqldrift | Select-Object -ExpandProperty BackupAreaLink
    $netshare1 = $getshare1 + "\MSSQL\" + $Sourceserver
    $netshare2 = $getshare2 + "\MSSQL\" + $Targetserver

    $testshare1 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $netshare1
    $testshare2 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $netshare2


    if ($testshare1 -eq $true) { $netshare = $netshare1 }
    elseif ($testshare2 -eq $true)
    {
        $netshare = $netshare2   
    }

    if ($testshare1 -eq $false -and $testshare2 -eq $false)
    {
        $share = Read-Host  "Service account cant use backupshare for coping please enter a share to use"
        $Testshare3 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $share
    }


    if ($Testshare3 -eq $true) { $netshare = $share }
    elseif ($testshare1 -eq $false -and $testshare2 -eq $false -and $Testshare3 -eq $false ) { write-host "Please check that share is ok and try again" exit }

    Return $netshare
}


Function Set-folderpermission # Gives Serviceaccount access to a folder
{
    param($Serviceaccount, $netshare)

    $acl = Get-Acl $netshare
    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Serviceaccount, "Modify", "Allow")
    $acl.SetAccessRule($AccessRule)
    $acl | Set-Acl $netshare
    $permset = $true
    Write-Host  $Serviceaccount +"now has modify on "+$netshare

    Return $permset
}

Function remove-folderpermission # removes a Serviceaccount access to a folder
{
    param($Serviceaccount, $netshare)
    $acl = Get-Acl $netshare

    $AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Serviceaccount, "Modify", "Allow")

    $acl.RemoveAccessRule($AccessRule)

    $acl | Set-Acl $netshare

}


function get-sqlinstance
{
    param (
        $Servername
    )
 


    IF ($servername -like "*,*") { $gotport = $true }
    else
    {
        $gotport = $false
    }
    IF ($servername -like "*.*" ) { $gotdomain = $true }
    else
    {
        $gotdomain = $false 
    }
    IF ($gotport -eq $false) { $Port = Get-DbaTcpPort -SqlInstance $Servername -All }
    IF ($gotdomain -eq $false) { $Domain = (Get-WmiObject -ComputerName $Servername Win32_ComputerSystem).Domain }

    IF ($gotdomain -eq $false) { $sqlinstance = $Servername + "." + $Domain }
    else
    {
        $sqlinstance = $Servername
    }
    IF ($gotport -eq $false)
    {
        $sqlinstance = $sqlinstance + "," + ($Port.port | Get-Unique) 
    }
    else
    {
        $sqlinstance = $sqlinstance
    }


   
    Return $sqlinstance
}

Function get-freespace
{
    param (
        $sqlinstance, $file
    )
    If ($file -eq "Data") { $Device = 1 }
    elseif ($file -eq "log")
    {
        $Device = 2      
    }

    $query = "select available_bytes /1024/1024/1024 as Free_GB from sys.dm_os_volume_stats (5, $Device)"
    
    $freespace = Invoke-DbaQuery -SqlInstance $sqlinstance -Query $query
        
    Return $freespace.Free_GB
}
    
 
Function Enable-backupcompression # changes backupcompression default to enabled
{
    param($sqlinstance)



    $BCOnquery =
    "EXEC sys.sp_configure N'backup compression default', N'1'
    GO
    RECONFIGURE WITH OVERRIDE
    GO"

    Invoke-DbaQuery -SqlInstance $sqlinstance -Database master -Query $BConquery


}


Function Disable-backupcompression # changes backupcompression default to disable
{
    param($sqlinstance)



    $BCOfquery =
    "EXEC sys.sp_configure N'backup compression default', N'0'
    GO
    RECONFIGURE WITH OVERRIDE
    GO"

    Invoke-DbaQuery -SqlInstance $sqlinstance -Database master -Query $BCofquery


}


Function Get-connectionstring
{
    param ($computername, $sqldrift
    )
    
    $computername = $computername.Split(".")[0]
    
    $Cquery =
    "Select Connectionstring FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$computername'"

    $connectionstring = Invoke-DbaQuery -SqlInstance $sqldrift -Database sqldrift -Query $Cquery | Select-Object -ExpandProperty Connectionstring

    Return $connectionstring

}



    



######################### CALLS ##################################

## Start Config ###
$smtpserver = 'smtp.saabgroup.com'
$sqldrift = 'SQLDRIFTDB.CORP.SAAB.SE,11433'
#$multicopy='Y'
#$copyno='N'

####  Start Loop ##############
<#while($multicopy -eq 'Y' )
{
Clear-host
Write-Host "This script copies a database from one SQL server (Source) to an other SQL Server (Target) using a Netshare"
Write-Host "If the target database exist it copies the permissions overwrite it and apply the permissions again when the copying is completed"
<# Collects variables from the console. either by prompted questions or i values is piped to the script #
$Sourceserver = IF($Sourceserver =( Read-Host "The server you want copy from ? [$defaultsource]" )){$Sourceserver}else{$defaultsource}
$database = Read-Host "The database you want to copy"
$Targetserver = IF($Targetserver =( Read-Host "The server you want copy to ? [$defaulttarget]" )){$Targetserver}else{$defaulttarget}
$Newdbname = Read-Host "The name the database will have on the target server"
#>
### Reset som variables  ##

$freeok = $false
$Dbexists = $false

<# Convert servers to instances #>

$sqlinstance1 = Get-SqlInstance -Servername $Sourceserver
$sqlinstance2 = Get-SqlInstance  -Servername $Targetserver

## Clean servernames  ##
$Sourceserver = $Sourceserver.Split(",")[0]
$Targetserver = $Targetserver.Split(",")[0]

# Get-netshare to use #
$netshare = netshare -Sourceserver $Sourceserver -Targetserver $Targetserver -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -sqldrift $sqldrift

<#Test if netshare can be used #>
$Netshareok = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $Netshare

if ($Netshareok -eq $false) { write-host "Please verify permissions on the networkshare" $Netshare exit }
else
{
    Write-Host " Permissons on the networkshare ok"

}
#>

# Check if the targetdatabase exists #
$Dbexists = CheckforDB -sqlinstance $sqlinstance2 -database $Newdbname

# IF Targetdatabase exist get current permissions else check for diskspace on Targetserver #
if ($Dbexists -eq $true) { $perm = Get-permissions -sqlinstance $sqlinstance2 -database $Newdbname }

if ($Dbexists -eq $false)
{
    $freeok = DBFileSize -sqlinstance1 $sqlinstance1 -database $database -sqlinstance2 $sqlinstance2
}

############### Starting Database coping ############################
Enable-backupcompression -sqlinstance $sqlinstance1


databasecopy -sqlinstance1 $sqlinstance1 -database $database -sqlinstance2 $sqlinstance2 -Newdbname $Newdbname -Netshare $netshare

Disable-backupcompression -sqlinstance $sqlinstance1

# Runs checks and update stats on the copied database #
DBAupgrade -sqlinstance $sqlinstance2 -database $Newdbname

#If the database did exist set the same permissons on the copied database #
if ($Dbexists -eq $true) { Set-Permission -sqlinstance $sqlinstance2 -database $Newdbname -Query $perm }


# Resyncs the users in the copied database with existing logins on the target server#
Write-Host 'Repairs Orphanusers'
Repair-DbaDbOrphanUser -sqlinstance $sqlinstance2 -database $newdbname -RemoveNotExisting -Force 


$exists = Get-DbaDatabase -SqlInstance $sqlinstance2 -Database $Newdbname | Select-Object name

$subject = 'The database ' + $database + ' has now been copied to ' + $targetserver + ' as ' + $Newdbname 
    
if ($exists -match "\S") { Send-MailMessage -From 'MSSQL@saabgroup.com' -To $mail -Subject $subject -SmtpServer $smtpserver }

<# Starts the Inverntory job on the target server #>
Start-DbaAgentJob -SqlInstance $sqlinstance2 -Job $job


Send-MailMessage -From 'MSSQL@saabgroup.com' -To $mail -Subject $subject -SmtpServer $smtpserver 
<#

$multicopy = IF($multicopy =( Read-Host "Copy more databases (Y/N) [$copyno] ?" )){$multicopy}else{$copyno}

$multicopy = $multicopy.ToUpper()

$defaultsource=$Sourceserver.toupper()
$defaulttarget=$Targetserver.toupper()

}







'Script is completed. Remember to check permission on the copied database' | Write-output

<#Script end #>

