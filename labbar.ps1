labb.ps1

$dbs= Import-Csv -Path C:\scripts\test.csv 


foreach ($db in $dbs)
{
Write-Host $db.old, $db.new
write-host "Next"

}
$db.old

-source db.old -newname



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
$Time=Get-Date -Format "yyyy-MM-dd HH:mm"
$test+' '+ $time | Add-Content C:\scripts\testaruttillfil.txt



Get-date |  C:\scripts\testaruttillfil.txt

Test-DbaPath -SqlInstance 'corpappl15181,11433' -Path \\CORP.SAAB.SE\APPS\Biztalk\SSAS\BACKUP

$computername='corpdb4044'
$SQLDrift="CORPDB4804.CORP.SAAB.SE,11433"
$Cquery=
"Select Connectionstring FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$computername'"

$connectionstring = Invoke-DbaQuery -SqlInstance $sqldrift -Database sqldrift -Query $Cquery | Select-Object -ExpandProperty Connectionstring


$getshare1 = Get-netshare -server $Sourceserver | Select-Object -ExpandProperty BackupAreaLink


Function Get-netshare
{
    param($server
    )
    
$SQLDrift="CORPDB4804.CORP.SAAB.SE,11433"
    
$query="SELECT BackupAreaLink
FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$server'"

$Netshare=Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query

Return $netshare
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




Function get-serviceaccount # get Serviceaccount for the MSSQLServer service on a server
{
param($servername
)
$serviceaccount = Get-DbaService -ComputerName $servername -ServiceName MSSQLSERVER | Select-Object -ExpandProperty startname

Return $serviceaccount
}



Function Fix-netshare  # Fix permissions to be able copy the database
{
param($servername
)


$server='corpdb4044'




Function Get-netshare
{
    param($server
    )
    
    $server = $server.Split(".")[0]
  
$SQLDrift="CORPDB4804.CORP.SAAB.SE,1143"
    
$query="SELECT BackupAreaLink
FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$server'"

$Netshare=Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query

IF  ($Netshare -eq "" -or $Netshare -eq $null) {$netshare = Read-Host "Can't reach SQLDrift to get an netshare to use. Pkease enter an netshare that both servers can reach" }


Return $netshare
}

$server='corpdb4044.CORP.SAAB.SE,11433'

$test = get-netshare -server $server

$sqlinstance1 = 'corpdb4044,11433'
$sqlinstance2 = 'corpdb4045,11433'

$params = @{
    SourceSqlInstance= $sqlinstance1
    DestinationSqlInstance = $sqlinstance2
    Database = 'AdventureworksDW2016CTP3'
    SharedPath= '\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb4044\MSSQL\CORPDB4044'
     LocalPath= 'D:\Data\logshipping'
     BackupScheduleFrequencyType = 'daily'
     BackupScheduleFrequencyInterval = 1
     CompressBackup = $true
     CopyScheduleFrequencyType = 'daily'
     CopyScheduleFrequencyInterval = 1
     GenerateFullBackup = $true
     RestoreScheduleFrequencyType = 'daily'
     RestoreScheduleFrequencyInterval = 1
     SecondaryDatabaseSuffix = 'DR'
     CopyDestinationFolder = '\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb4045\MSSQL\logshipp'
     Force = $true
     }
    
Invoke-DbaDbLogShipping @params






Invoke-DbadbLogShipping -SourceSqlInstance 'corpdb4044,11433' -DestinationSqlInstance 'corpdb4045,11433' -Database AdventureworksDW2016CTP3 -BackupNetworkPath "\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb4044\MSSQL\CORPDB4044" -BackupLocalPath "E:\logshipping\backup" -CompressBackup -GenerateFullBackup -Force






Function Get-netshare
{
    param($server
    )
    
    $server = $server.Split(".")[0]
  
$SQLDrift="CORPDB4804.CORP.SAAB.SE,11433"
    
$query="SELECT BackupAreaLink
FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$server'"

$Netshare=Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query

IF  ($Netshare -eq "" -or $Netshare -eq $null) {$netshare = Read-Host "Can't reach SQLDrift to get an netshare to use. Pkease enter an netshare that both servers can reach" }


Return $netshare
}

$sqlinstance1='corpdb4044,11433'
$sqlinstance2='corpdb6053,11433'
$netshare='\\corp.saab.se\so\Services\SQLBCK\SE\LKP\CORPDB4044'

function test-Netsharepaths # tests if a networkshare can be accessed from two sqlinstances#
{
    param ($sqlinstance1, $sqlinstance2, $Netshare
    )

    


Return $pathok
}

$Netshareok = test-Netsharepaths -sqlinstance1 $sqlinstance2 -sqlinstance2 $sqlinstance2 -Netshare $netshare


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


######################### CALLS ##################################

## Start Config ###

$multicopy='Y'
$copyno='N'

####  Start Loop ##############
#while($multicopy -eq 'Y' )
#{
#Clear-host
Write-Host "This script copies a database from one SQL server (Source) to an other SQL Server (Target) using a Netshare"
Write-Host "If the target database exist it copies the permissions overwrite it and apply the permissions again when the copying is completed"
<# Collects variables from the console. either by prompted questions or i values is piped to the script #>
$Sourceserver = IF($Sourceserver =( Read-Host "The server you want copy from ? [$defaultsource]" )){$Sourceserver}else{$defaultsource}
$database = Read-Host "The database you want to copy"
$Targetserver = IF($Targetserver =( Read-Host "The server you want copy to ? [$defaulttarget]" )){$Targetserver}else{$defaulttarget}
$Newdbname = Read-Host "The name the database will have on the target server"

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
$netshare = netshare -Sourceserver $Sourceserver -Targetserver $Targetserver -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2

<#Test if netshare can be used #>
$Netshareok = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $Netshare

if ($Netshareok -ne $true {write-host "Please verify permissions on the networkshare" $Netshare exit }
else
{
    Write-Host " Permissons on the networkshare ok"

}
#}



$database='SPS_UAT_Managed_Metadata'
$sqlinstance='SSPDB16893,11433'
$Path='\\sspbck20prod\sspdevtoprodnobck'

Restore-DbaDatabase -SqlInstance $sqlinstance -DatabaseName $database -Path $Path





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

function Update-serverlist {
    param ($sqlinstance, $database, $newservers, $SQLDrift
       
    )
    $sqlinstance = $logserver
    $database = $Restodatabase
    $newservers=$serverlist

    Write-DbaDbTableData -SqlInstance $sqlinstance -Database $database -Table tblnewservers -Truncate
    $newservers | Write-DbaDbTableData -SqlInstance $sqlinstance -Database $database -Table tblnewservers
    
    
    $currentlistquery = "select connectionstring from dbo.tblserverlist"
    $currentlist= Invoke-DbaQuery -SqlInstance $sqlinstance -Database $database -Query $currentlistquery

    $updatelist = $newservers| Where-Object {$newservers -notcontains $currentlist}

  }


  ####### Configurations ######################
$destinationserver ="corpdb4045.corp.saab.se,11433" ####  Server that restoretest is runned on
$logserver="corpdb4044.corp.saab.se,11433" ## Serverlist and logs ##########
$Restodatabase="Restotest"  ## Serverlist and logs ##########
$counter=0
$continue = $true
$SQLDrift="CORPDB4804.CORP.SAAB.SE,11433"


$serverlist = Get-newservers -sqldrift $SQLDrift

$newservers= Update-serverlist -sqlinstance $logserver -database $Restodatabase -newservers $serverlist





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
$servername='corpdb4044.corp.saab.se'
$SQLDrift="CORPDB4804.CORP.SAAB.SE,11433"
$database='test1'


$netshare = Get-netshare -server $serverName -SQLDrift $SQLDrift

$serverName = $serverName.Split(".")[0]

$backupshare = $netshare + "\MSSQL\" + $serverName + "\" + $database
