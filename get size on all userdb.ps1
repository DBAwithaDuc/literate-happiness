<#get size on all userdb.ps1

DESCRIPTION 
    Checks disk size on target server befor a database copy
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-01-10 07:58 

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add checks for default data and logfile location on target server
    * Add support for diffrent port on the sqlinstance
    * Add logfile Path 
    * Add error handling 

#>


<# Set variables to run the script#>

<# Collects variables from the console. either by prompted questions or i values is piped to the script #>
$Sourceserver = Read-Host "The server you want check:"

# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'

$Sourceserver ='corpdb16398'

<# Convert server to instance #>
$Domain = "corp.saab.se"
$sqlinstance  = $Sourceserver + '.' + $Domain + ',11433'
$exclude= "Master,msdb,model,tempdb,itdrift"

#Where-Object { $_.Name -notin $excluded }


$databases = Get-DbaDatabase -SqlInstance $sqlinstance -ExcludeDatabase itdrift -ExcludeSystem
$Datadisk = Get-DbaDbFile -SqlInstance $sqlinstance | Where-Object {$_.database -notin $exclude}  | Where-Object filegroupname -EQ PRIMARY | Select-Object size

#(gci Downloads | measure Length -s).Sum /1GB
$datasize1= $Datadisk | Measure-Object Size -Sum

$datasize1
$datasize
$datadisk | Out-GridView

