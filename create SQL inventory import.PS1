<# create SQL inventory import.PS1
 .DESCRIPTION 
    creates an sqlsqript fil to import in sqlsdrift for remote servers
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-08-07 15:48 
    Version 0.1

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add error handling
    
  
#>
<# Configurations #>
$sqldriftscript = Get-Content C:\temp\'SQLDrift - R - SQL Inventory DMZ network - LITE-2005-V1.84.sql'
$servers= Get-Content C:\temp\Servers.txt


<# Convert server to instance 
$Domain = (Get-WmiObject -ComputerName $serverName Win32_ComputerSystem).Domain
$Port = Get-DbaTcpPort -SqlInstance $serverName -All 
$sqlinstance = $serverName + "." + $Domain + "," + ($Port.port | Get-Unique) 
#>

#########################  Functions ###################################################


function Create-sqlimport {
    param ($servers, $sqldriftscript)
   
    foreach ($server in $servers)
{
    Invoke-DbaQuery -SqlInstance $server -Query $sqldriftscript | Add-Content c:\temp\sqldriftimport.sql

    
}



Start-DbaAgentJob 


}