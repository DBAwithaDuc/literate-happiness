<# Backup database.PS1
 .DESCRIPTION 
    Backups a database to default backup share 
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-07-09 15:48 
    Version 0.1

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add logfile Path 
    * Add error handling
    
  
#>

$serverName = Read-Host "The server you want backup on"
$databases = Read-Host "The database/s you want to backup"

<# Convert server to instance #>
$Domain = (Get-WmiObject -ComputerName $serverName Win32_ComputerSystem).Domain
$Port = Get-DbaTcpPort -SqlInstance $serverName -All 
$sqlinstance = $serverName + "." + $Domain + "," + ($Port.port | Get-Unique) 


#########################  Functions ###################################################


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
}

function backup-databases {
      param (
            $sqlinstance,$databases,$backupshare
        )

    foreach ($database in $databases)
       { Backup-DbaDatabase -SqlInstance $sqlinstance -Database $database -Path $backupshare -CopyOnly -CompressBackup

       } 

    }
    





######################### CALLS ##################################

<# Convert server to instance #>

    
$sqlinstance = Get-SqlInstance -Servername $Servername


## Clean servernames  ##
$Servername = $Servername.Split(",")[0]


# Get-netshare to use #
$backupshare = Get-netshare -server $serverName

$Netshareok = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $Netshare

if ($Netshareok -eq $false) {write-host "Please verify permissions on the networkshare" $Netshare exit }
else
{
    Write-Host " Permissons on the networkshare ok"

}
#>


$query = Export-DbaUser -SqlInstance 'corpdb4044,11433' -Database AdventureworksDW2016CTP3 -Passthru