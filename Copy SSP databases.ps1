# Copy SSP databases.ps1

$Sourceserver = ""
$Targetserver = ""
$netshare=""
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
    copy-dbadatabase -source $sqlinstance1 -destination $sqlinstance2 -database $database -newname $Newdbname -backupRestore -SharedPath $Netshare  -withReplace | Write-output <# Add -UseLastBackup if you want to use lastbackup #>

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



######################### CALLS ##################################

<# Convert servers to instances #>

$sqlinstance1 = Get-SqlInstance -Servername $Sourceserver
$sqlinstance2 = Get-SqlInstance  -Servername $Targetserver

# Clean servernames  ##
$Sourceserver = $Sourceserver.Split(",")[0]
$Targetserver = $Targetserver.Split(",")[0]


<#Test if netshare can be used #>
$Netshareok = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $Netshare

if ($Netshareok -eq $false) {write-host "Please verify permissions on the networkshare" $Netshare exit }
else
{
    Write-Host " Permissons on the networkshare ok"

}
#>




########## Create users ###############
New-DbaLogin -SqlInstance $sqlinstance2 -Login SSP\$login1
New-DbaLogin -SqlInstance $sqlinstance2 -Login SSP\$login2


############## Starting Database coping ############################
foreach ($database in $databases)
{
databasecopy -sqlinstance1 $sqlinstance1 -database $database -sqlinstance2 $sqlinstance2 -Newdbname $database -Netshare $netshare

###  Adding users ##
New-DbaDbUser -SqlInstance $sqlinstance2 -Database $database -Login SSP\$login1
New-DbaDbUser -SqlInstance $sqlinstance2 -Database $database -Login SSP\$login2
Set-DBPermission -sqlinstance $sqlinstance2 -database $database -Name SSP\$login1 -sqlRole $sqlRole
Set-DBPermission -sqlinstance $sqlinstance2 -database $database -Name SSP\$login2 -sqlRole $sqlRole

# Runs Checks and update stats #
DBAupgrade -sqlinstance $sqlinstance2 -database $database

}

'Script is completed. Remember to check permission on the copied database' | Write-output

<#Script end #>








}
