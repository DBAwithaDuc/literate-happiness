# Remove databasesnapshotjobs.ps1
<#.DESCRIPTION 
    remove database snapshot jobs on a server
    
    

.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-08-29 16:00 
    Version 0.1

   Requirements:

   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    

   For the targetserver:
   For Standard SQL Server 2016 Sp1 or later
   For Enterprise SQL Server 2008R2 or later 
   
 
   Changelog: 
    * 
   To Do: 
    * 

    #>


#

Write-Host "This script removes the database snapshot jobs on an server"

<# Collects variables from the console. either by prompted questions or i values is piped to the script #>
$Targetserver = Read-Host "The server the jobs removed from"

$removescript="\\$targetserver\c$\scripts\Databasesnapshotjobs\"
$job1= "LIT Drift - Create Databasesnapshot"
$job2="LIT Drift - View Databasesnapshots"
$job3="LIT Drift - Restore databasesnapshots"
$job4="LIT Drift - Remove Databasesnapshot"

$inventjob = 'ITDrift - SQL Inventory to SQL Drift'

#########################  Functions #################################################
##

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

Function remove-job
{
    param (
        $sqlinstance, $jobname
    )
Write-host "Tries to remove $jobname from server $targetserver"
$checKjob=Get-DbaAgentJob -SqlInstance $sqlinstance -Job $jobname 
IF ($checkjob) {Get-DbaAgentJob -SqlInstance $sqlinstance -Job $jobname | remove-DbaAgentJob -SqlInstance $sqlinstance}
else {Write-Host "Can't find $jobname on $targetserver"
     }
    }




######################### CALLS ##################################


<# Convert servers to instances #>

$sqlinstance = Get-SqlInstance -Servername $Targetserver

## Clean servernames  ##
$Targetserver = $Targetserver.Split(",")[0]


<# remove scripts #>
Write-Host "try to remove snapshot scripts from $targetserver"
try {
    remove-Item $removescript -Recurse -Force
}
catch {Write-Host " Can't find scripts on $targetserver"
    
}


<#Create snapshotsjobs #>
Write-Host 'Remove jobs'
Remove-Job -sqlinstance $sqlinstance -jobname $job1 
Remove-Job -sqlinstance $sqlinstance -jobname $job2
Remove-Job -sqlinstance $sqlinstance -jobname $job3
Remove-Job -sqlinstance $sqlinstance -jobname $job4


<# Starts the Inverntory job on the target server #>
Write-Host "Running Invent job"
Start-DbaAgentJob -SqlInstance $sqlinstance -Job $inventjob


'Script is completed. verify that the jobs is reomved from the server' | Write-output

<#Script end #>