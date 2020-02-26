<# CH260261 - kopiering av UAT databaser steg 2.ps1
 .DESCRIPTION 
    Restores a SESP databases an rename them
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-07-05 15:48 
    Version 0.2

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * 
    
  
#>




#$Sourceserver ="SSPDB4DEV"
$Targetserver ="SSPDB16893"
$backupshare = "\\sspbck20prod\sspdevtoprodnobck "

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'


<# Convert servers to instances #>

#$Domain = (Get-WmiObject -ComputerName $Sourceserver Win32_ComputerSystem).Domain
#$Port = Get-DbaTcpPort -SqlInstance $Sourceserver -All
$port='11433' 
#$sqlinstance1 = $Sourceserver + "." + $Domain + "," + $port #($Port.port | Get-Unique) 

$Domain = (Get-WmiObject -ComputerName $Targetserver Win32_ComputerSystem).Domain
#$Port = Get-DbaTcpPort -SqlInstance $Targetserver -All 
$sqlinstance = $Targetserver + "." + $Domain + "," + $port #($Port.port | Get-Unique) 


#########################  Functions ###################################################

Function Set-DBPermission
{  param($sqlinstance, $database, $Name, $sqlRole )

$Query= 
"ALTER USER [$name] WITH DEFAULT_SCHEMA=[dbo]
 ALTER ROLE [$sqlrole] ADD MEMBER [$name]
GO"

Invoke-DbaQuery -SqlInstance $sqlinstance -Database $database -Query $Query
}



### CALLS #####



$databases = Get-Content -Path C:\Scripts\Powershell\databases.txt

# loop through all databases with the same name #
foreach ($database in $databases)
{
Restore-DbaDatabase -SqlInstance $sqlinstance -Database $database -BackupDirectory $backupshare -WithReplace


}


# Databases that changes name #

Rename-DbaDatabase -SqlInstance $sqlinstance -Database SSP_UAT_Portal_SP2010_Test -DatabaseName SSP_UAT_Portal_Test
Rename-DbaDatabase -SqlInstance $sqlinstance -Database SSP_UAT_SSPRapid2013_Content -DatabaseName SSP_UAT_SSPRapid_Content
Rename-DbaDatabase -SqlInstance $sqlinstance -Database SSP_UAT_2013TEST_Content -DatabaseName SSP_UAT_TEST_Content
Rename-DbaDatabase -SqlInstance $sqlinstance -Database SSP_UAT_SSP2013test2_Content -DatabaseName SSP_UAT_SSPtest2_Content


## Set permissions on the databases

$sqlRole='Db_Owner'
$ADgroup= 'AP-CO-SHAREPOINT_UAT-SQLdbOwner'

foreach ($database in $databases)
{
Set-DBPermission -sqlinstance $sqlinstance -database $database -Name $ADgroup -sqlRole $sqlRole
}


Start-DbaAgentJob -SqlInstance $sqlinstance -Job 'ITDrift - AutoPermission Create db Users'


<# Starts the Inverntory job on the target server #>
Start-DbaAgentJob -SqlInstance $sqlinstance -Job $job

'Script is completed. Remember to check permission on the copied database' | Write-output

<#Script end #>