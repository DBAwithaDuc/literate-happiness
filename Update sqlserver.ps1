<# Update sqlserver.ps1
 .DESCRIPTION 
    updates sqlserver
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-01-23 16:00 
    Version 1.0

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add support for diffrent port on the sqlinstance
    * Add logfile Path 
    * Add error handling 

Get connections
stop OP5 service
stop the 'ITDrift - Daily Maintenance Database Mon-Sun -Special'  agent job





#>


<# Get variable data to run the script#>



param(
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Targetserver
)

<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Set some default variables#>
$mainjob = 'ITDrift - Daily Maintenance Database Mon-Sun -Special'
$op5 = "nscp"
$whodatabase = 'itdrift'

# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'

<# Path to Patches #>
$patchpath1 = 'd$\ITIP'
$patchpath2 = 'c$\ITIP'

<# Convert server to instance #>
$sqlinstance = $Targetserver + ',11433'

<# Verifies that whoisactive exists#>
Install-DbaWhoIsActive -SqlInstance $sqlinstance -Database $whodatabase

<# Checks active connections #>
"Check active connections" |Write-Output
$connections = Invoke-DbaWhoIsActive -SqlInstance $sqlinstance -Database $whodatabase | Select-Object host_name

<# Check if patches are present and in correct path#>
"check for patches" | Write-Output
$path1 = Test-Path "\\$Targetserver\$patchpath1\*" -Include *.exe
$path2 = Test-Path "\\$Targetserver\$patchpath2\*" -Include *.exe

# Report if patches are found or not
If ($path1 -eq $true -or $path2 -eq $True ) { Write-Host 'Patchfile ar present och correct path' }

Else { Write-Host 'Patchfiles are missing or i wrong path' EXIT } 

<# Test if patches ar on c$ or d$ #>
if ($path1 -eq $True) {$patchpath = $patchpath1}

elseif ($path2 -eq $true) {
    $patchpath = $patchpath2  
}
else {
    exit
    
}

<# Disable autostart on OP5 Service#>
"stop Op5 service" | Write-Output
Set-Service -ComputerName $Targetserver -Name $op5 -StartupType Disabled

<#Stop OP5 Service#>
Get-Service -ComputerName $Targetserver -Name $op5 | Stop-Service -Force


<# disable indexjob #>
"disable indexjob" | Write-Output
Set-DbaAgentJob -SqlInstance $sqlinstance -Job $mainjob -Disabled



<# Upgrade sql server #>
"starting upgrade"  | Write-Output
Update-DbaInstance -ComputerName $Targetserver -Restart -Path \\$Targetserver\$patchpath -Credential corp\admu0146066



<# enable indexnjob #>
"enable indexjob" |Write-Output
Set-DbaAgentJob -SqlInstance $sqlinstance -Job $mainjob -Enabled

<# Check connection after upgrade#>
"check postupgrede connections" | Write-Output
$Postconnections = Get-DbaConnection -SqlInstance $sqlinstance

<# Compare connection before and after#>
$checklist = $connections | Where-Object {$Postconnections -notcontains $_}

Write-host ' Update completed'
Write-Host "the following servers that where connected before update hasn't connected again"
Write-host $checklist | Format-List

<#Start OP5 Service#>
"Start OP5 Service#" | Write-Output
Get-Service -ComputerName $Targetserver -Name $op5 | Start-Service
<# Set Service to automatic#>
Set-Service -ComputerName $Targetserver -Name $op5 -StartupType Automatic



<# Starts the Inverntory job on the target server #>
Write-Host 'Runs the Inventory SQL agent job'
Start-DbaAgentJob -SqlInstance $sqlinstance -job $job | Write-output

'Script is completed.' | Write-output

<#Script end #>
