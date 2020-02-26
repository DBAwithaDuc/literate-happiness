<# Starts failed inventory jobs.PS1
 .DESCRIPTION 
    Starts failed jobs 
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
<# Configurations #>

$job = 'ITDrift - SQL Inventory to SQL Drift'
$CMSregserver='corpdb4805.corp.saab.se,11433'


<# Convert server to instance 
$Domain = (Get-WmiObject -ComputerName $serverName Win32_ComputerSystem).Domain
$Port = Get-DbaTcpPort -SqlInstance $serverName -All 
$sqlinstance = $serverName + "." + $Domain + "," + ($Port.port | Get-Unique) 
#>

#########################  Functions ###################################################

Function Start-failedjob
{
    param($CMSregserver,$job
    )

   $isfailed = Get-DbaRegServer -SqlInstance $CMSregserver -Group sqlversion | Find-DbaAgentJob -IsFailed -JobName $job 
   Write-Host $isfailed
   $IsFailed| Start-DbaAgentJob 

}



<# Calls #>

Start-failedjob -CMSregserver $CMSregserver -job $job