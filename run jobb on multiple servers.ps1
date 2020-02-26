<# run jobb on multiple servers.ps1

.DESCRIPTION 
    runs a job on the servers in the 

    .NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-03-28 11:00 
    Version 2.1

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * Added value for $job variable

       To Do: 
    * Add error handling


<# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned #>
$job = 'ITDrift - SQL Inventory to SQL Drift'


    <# Convert server to instance #>
    $Domain = "corp.saab.se"
$servers = Get-Content -Path C:\scripts\txt\servers.txt

 foreach ($server in $servers)  
  {
      
 $sqlinstance  = $Server + '.' + $Domain + ',11433'
Start-DbaAgentJob -SqlInstance $sqlinstance -Job $job
  }




'Script is completed.' | Write-output

<#Script end #>
