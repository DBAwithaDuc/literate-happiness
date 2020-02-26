<# Create databasesnapshotjobs.ps1
.DESCRIPTION 
    Creates database snapshot jobs on a server
    
    

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

Write-Host "This script creates the database snapshot jobs on an server"

<# Collects variables from the console. either by prompted questions or i values is piped to the script #>
$Targetserver = Read-Host "The server the jobs be created on"
$Database = Read-Host "Database/s that the Database snapashot job should affect"
$Database='test2019'
$dest="\\$targetserver\c$\Program Files\WindowsPowershell\Modules\"
$dbatools="\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\Utilites\DBAtools\"
$copyscript="\\corp.saab.se\so\mgmt\L3_groups\L3_dbSQL\Script\Powershell\Database_snapshot\Databasesnapshotjobs\"
$scriptdest="\\$targetserver\c$\scripts"
$powershell="Powershell -file "
$scriptlocation='"c:\Scripts\Databasesnapshotjobs\'

$script1="create_databasesnapshotjob.ps1 -database $database"
$script2="view databasesnapshotsjob.ps1 -database $database"
$script3="Restores_databasesnapshotsjob.ps1 -database $database"
$script4="Removes_databasesnapshotsjob.ps1 -database $database"
$command1='"'+$Powershell+$scriptlocation+$script1+'""'
$command2='"'+$Powershell+$scriptlocation+$script2+'""'
$command3='"'+$Powershell+$scriptlocation+$script3+'""'
$command4='"'+$Powershell+$scriptlocation+$script4+'""'

$job1= "LIT Drift - Create Databasesnapshot"
$job2="LIT Drift - View Databasesnapshots"
$job3="LIT Drift - Restore databasesnapshots"
$job4="LIT Drift - Remove Databasesnapshot"
$desc1="SQL job to Create Databasesnapshots"
$desc2="SQL job to View Databasesnapshots"
$desc3="SQL job to Restore Databasesnapshots"
$desc4="SQL job to Remove Databasesnapshots"

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

Function Create-job
{
    param (
        $sqlinstance, $jobname, $description, $command
    )
New-DbaAgentJob -SqlInstance $sqlinstance -Description $description -Job $jobname -OwnerLogin sa -Force
New-DbaAgentJobStep -SqlInstance $sqlinstance -Job $jobname -Command $command -StepName $jobname -Subsystem CmdExec

}

Function Change-towarning 
{
    Param (
        $sqlinstance, $job
    )

    $query= "
    INSERT INTO [ITDrift].dbo.[tblSQLJobMonStatus]
                            ([job_id]
                            ,[MonStatus]
                            ,[MonMessage])
                            (SELECT SJ.job_id
                                    ,1 AS [MonStatus]
                                    ,'WARNING' AS [MonMessage]
                                FROM msdb.[dbo].sysjobs AS SJ 
                            WHERE SJ.name ='$job'
                              AND SJ.job_id NOT IN (SELECT job_id FROM [ITDrift].dbo.[tblSQLJobMonStatus] ))
    "
    
    Invoke-DbaQuery -SqlInstance $sqlinstance -Query $query
  }                                         


######################### CALLS ##################################


<# Convert servers to instances #>

$sqlinstance = Get-SqlInstance -Servername $Targetserver

## Clean servernames  ##
$Targetserver = $Targetserver.Split(",")[0]


<# copy DBAtools #>
Write-Host 'Copy needed powershell modules to the server'
#Copy-Item $dbatools -Recurse -Destination $dest -Force
#Invoke-Command  -ComputerName $Targetserver -ScriptBlock { Import-Module dbatools }

<# Copy scripts to the server #>
Write-Host 'Copy Scripts to the server'
Copy-Item $copyscript -Recurse -Destination $scriptdest -Force

<#Create snapshotsjobs #>
Write-Host 'Creating jobs'
Create-job -sqlinstance $sqlinstance -jobname $job1 -description $desc1 -command $command1
Create-job -sqlinstance $sqlinstance -jobname $job2 -description $desc2 -command $command2
Create-job -sqlinstance $sqlinstance -jobname $job3 -description $desc3 -command $command3
Create-job -sqlinstance $sqlinstance -jobname $job4 -description $desc4 -command $command4

<# Change OP5 to warning #>
Write-Host 'Changing op5 to warning for this jobs'
Change-towarning -sqlinstance $sqlinstance -job $job1
Change-towarning -sqlinstance $sqlinstance -job $job2
Change-towarning -sqlinstance $sqlinstance -job $job3
Change-towarning -sqlinstance $sqlinstance -job $job4


<# Starts the Inverntory job on the target server #>
Write-Host "Running Invent job"
Start-DbaAgentJob -SqlInstance $sqlinstance -Job $inventjob


'Script is completed. verify that the job is created on the server' | Write-output

<#Script end #>


