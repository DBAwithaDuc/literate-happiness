<# Copy data between SSPProd and SSPDEV.PS1
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


Param(
    [parameter(Mandatory = $true)]
    [ValidateSet("Backup", "restore")]
    [String[]]$Choice
)
<# Get variable data to run the script#>



$Targetserver = 'SSPDB5DEV'
$Newdbname = 'Saab_Externweb_Content_4'
$Netsharetarget = '\\sspbck14dev\sspprodtodevnobck'
$user = 'ssp\ICT-SQLEPIUAT'

<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Set some default variables#>

<# NAme of the job that vill be runned after completion #>
$job = 'ITDrift - SQL Inventory to SQL Drift'

<# Convert server to instance #>
$sqlinstance1 = $Targetserver + ',11433'
$sqlinstance2 = $Sourceserver + ',11433'


<# Checks if the user wants to continue #>
Write-Host 'Continue and restore the database ' $database' on '$targetserver ""
$response = read-host "Press a to abort, any other key to continue."
$aborted = $response -eq "a"

If ($aborted -eq $false) {Write-Host 'Starting'}
else {
    EXIT
}

<# Check if backupfiles are present in the $netsharetarget path#>

$path = Test-Path "$netsharetarget\*" -Include *.bak -Credential $user

# Report if templates are found or not
If ($path -eq $true ) { Write-Host 'Backupfiles are present'}
    
Else { Write-Host 'Backupfiles are missing' EXIT } 

<#Restore the database #>
"starting backup" | Write-Output
Restore-DbaDatabase -SqlInstance $sqlinstance2 -DatabaseName $Newdbname -WithReplace -Path $Netsharetarget -SqlCredential $user

<# Resyncs the users in the copied database with existing logins on the target server#>
Write-Host 'Repairs Orphanusers'
Repair-DbaDbOrphanUser -sqlinstance $sqlinstance2 -database $newdbname -RemoveNotExisting -SqlCredential $user| Write-output <# Repair orphanusers #>


<# Set owner of the database to SA #>
Write-Host 'Set DBowner for ' $newdbname ' to SA'
set-dbadbowner -sqlinstance $sqlinstance2 -database $newdbname -SqlCredential $user | Write-output <# Sets DBowner for $newdbname to SA #>

<# Runs checks and update stats after the coping is completed  #>
Write-Host 'Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views.'
Invoke-DbaDbUpgrade -SqlInstance $sqlinstance2 -database $newdbname -SqlCredential $user | Write-output <#Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views #>


<# checks the target server i the database exist #>
$item = Get-DbaDatabase -SqlInstance $sqlinstance2 -Database $newdbname -SqlCredential $user| Select-Object Name
'Database ' + $Item + ' now succesfully copied' | Write-output

<# Starts the Inverntory job on the target server #>
Write-Host 'Runs the Inventory SQL agent job'
Start-DbaAgentJob -SqlInstance $sqlinstance2 -job $job -SqlCredential $user | Write-output

'Script is completed. Remember to check permission on the copied database' | Write-output

<#Script end #>





