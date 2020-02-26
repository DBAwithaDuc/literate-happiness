<# Detect and fix VLFS.PS1
 .DESCRIPTION 
    Checks databaser on a server for high number of VLFS, it then tries to reduce them
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-01-16 08:02 
    Version 0.1

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add support for diffrent ports on the sqlinstance
    * Add logfile Path 
    * Add error handling 

  
Expand-DbaDbLogFile -SqlInstance sqlcluster -Database (Get-Content D:\DBs.txt) -TargetLogSize 50000

 [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $database


#>





<# Get variable data to run the script#>



param(
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Targetserver
)

<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Set some default variables#>


$job = 'ITDrift - SQL Inventory to SQL Drift'
$max = 500 <# MAX number of VLFS#>
$counter = 0

<# Convert server to instance #>
$sqlinstance = $Targetserver + ',11433'

<# Get databses with more the $max vlfs on the Target server #>
$vlf = Get-DbaDbVirtualLogFile -SqlInstance $sqlinstance| Group-Object -Property Database | Where-Object Count -gt $max | Select-Object Name

ForEach ($VLF in $VLF) {
    $database | Select-Object $vlf.Name

    
    $database
    


}

exit



$Selected = Get-DbaDbFile -SqlInstance $sqlinstance -Database $vlf | Select-Object database, logicalname, Size 


$Selected

New-Object -Type PSCustomObject -Property @{
    'freePercent' = $freePercent
    'freeGB'      = $freeGB
    'system'      = $system
    'disk'        = $disk
}
           




<#

Invoke-DbaDbShrink -SqlInstance $sqlinstance  -Database $database -ShrinkMethod TruncateOnly  -StepSizeMB 1000 -FileType Log

Expand-DbaDbLogFile -SqlInstance sqlcluster -Database (Get-Content D:\DBs.txt) -TargetLogSize 50000

#>