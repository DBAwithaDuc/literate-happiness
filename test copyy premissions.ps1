<# test copyy premissions.ps1
 .DESCRIPTION 
    Copies a database from one Sqlserver "Source" to an other SQL server "target" using a netshare
    
    The process is as follows 
    - Collect variables from the console. either by prompted questions or i values is piped to the script
    - Checks if the Powershell module DBATOOLS exist
    - Set values for some needed variables
    - Starts the database copy using backup-Restore and a netshare
    - Resyncs the users in the copied database with existing logins on the target server
    - Check if any orphan users still exists i the database
    - Sets the owner of the databse to SA
    - Runs checks and update stats on the copied database
    - Verify that the database exist on the target server
    - Compares the users in the source database and the copied databases 
    - Prints out the users the is in the source database but not in the copied database
    - Runs the the ITDrift - SQL Inventory job  och the targetserver
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-01-11 11:32 
    Version 1.02

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * Added value for $job variable
    * Updated the dokumentation and corrected some cosmetic bugs 
    
   To Do: 
    * Add check of disk size on the target if the database fits (merge script with the check disk size before db copy.ps1)
    * Add logfile Path 
    * Add error handling
    * add check if the netshare can be accessed from the source and target server 
    #>


<# Collects variables from the console. either by prompted questions or i values is piped to the script #>
<##>
param(
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Sourceserver,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $database,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Targetserver,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Newdbname,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Netshare
    
)
#>
<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'

$Newdbname = 'itdrift'
$Targetserver = 'corpdb4044'


<# Convert server to instance #>
$sqlinstance1 = $Sourceserver + ',11433'
$sqlinstance2 = $Targetserver + ',11433'


$exists = Get-DbaDatabase -SqlInstance $sqlinstance2 -Database $Newdbname | Select-Object name

if ($exists -eq $Newdbname) {Export-DbaLogin -SqlInstance $sqlinstance2 -Database $Newdbname -PipelineVariable $permissions}

Write-Host $permissions