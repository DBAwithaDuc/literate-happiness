<# Create database.ps1
 .DESCRIPTION 
    Creates a database on a remote server
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-01-15 08:02 
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

#>


<# Get variable data to run the script#>



param(
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Targetserver,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $database

)

<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Set some default variables#>

$Datasize = 100
$datagroth = 100
$Logsize = 100 
$loggrowth = 100
$owner = 'SA'
$job = 'ITDrift - SQL Inventory to SQL Drift'


<# Convert server to instance #>
$sqlinstance = $Targetserver + ',11433'

 
<# Creating Database #>
New-DbaDatabase -SqlInstance $sqlinstance -Name $database -PrimaryFilesize $Datasize -PrimaryFileGrowth $datagroth -LogSize $Logsize -LogGrowth $loggrowth -Owner $owner

<# checks the target server if the database exist #>
$item = Get-DbaDatabase -SqlInstance $sqlinstance -Database $database | Select-Object Name
'Database ' + $Item.Name + ' now succesfully Created' | Write-output

<# Starts the Inverntory job on the target server #>
Write-Host 'Runs the Inventory SQL agent job'
Start-DbaAgentJob -SqlInstance $sqlinstance -job $job | Write-output


"script complete" | Write-output
<#Script end #>


