<# restore database to a restoretime.PS1
 .DESCRIPTION 
    Restores a database to a specific time 
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-01-16 15:48 
    Version 0.9

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add support for diffrent ports on the sqlinstance
    * Add logfile Path 
    * Add error handling
    
  
#>





<# Get variable data to run the script#>



param(
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Targetserver,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $database,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $restoretime
)

<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Set some default variables#>

<# NAme of the job that vill be runned after completion #>
$job = 'ITDrift - SQL Inventory to SQL Drift'

<# Convert server to instance #>
$sqlinstance = $Targetserver + ',11433'

<#Convert restoretime to date format#>
$restoreto = get-date($restoretime)

<# Checks if the user wants to continue #>
Write-Host 'will restore the database ' $database' on '$targetserver ' to the closed time to ' $restoreto' as possible'""
$response = read-host "Press a to abort, any other key to continue."
$aborted = $response -eq "a"

If ($aborted -eq $false) {Write-Host 'Starting'}
else {
    EXIT
}


<# Get backupfile info#>
Write-Host 'Scanning through backupfiles ' ""
$backuphistory = Get-DbaBackupHistory -SqlInstance $sqlinstance -Database $database

<# Starting restore of the the database from the backupfiles that matches#>
Write-Host 'Starting Restore of ' $database' on '$Targetserver
$BackupHistory | Restore-DbaDatabase -SqlInstance $sqlinstance -TrustDbBackupHistory -RestoreTime $restoreto -WithReplace 


<# checks the target server if the database exist #>
$item = Get-DbaDatabase -SqlInstance $sqlinstance -Database $database | Select-Object Name
'Database ' + $Item.Name + ' now succesfully Created' | Write-output

<# Resync users#>
Write-Host "Resyncing users" ""
Repair-DbaDbOrphanUser -SqlInstance $sqlinstance -Database $database

<# Set owner of the database to SA #>
Write-Host 'Set DBowner for ' $database ' to SA' ""
set-dbadbowner -sqlinstance $sqlinstance -database $database  | Write-output <# Sets DBowner for $database to SA #>


<# Running the inventory job #>
Write-Host "Running inventory job" ""
Start-DbaAgentJob -SqlInstance $sqlinstance -Job $job


Write-Host "Check the permission on the database i correct after the restore" ""
Write-Host "script completed"
<# Script End #>
