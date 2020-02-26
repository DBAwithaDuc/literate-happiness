<# Check disksize.ps1
 .DESCRIPTION 
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
    * Get default data and logfile location on target server the default is now E: and F:
    * Add support for diffrent port on the sqlinstance
    * Add logfile Path 
    * Add error handling 

#>


<# Get variable data to run the script#>



param(
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Sourceserver,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $database,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Targetserver,
    [Parameter(Mandatory = $false, valueFromPipeline = $true)][String] $datadisk,
    [Parameter(Mandatory = $false, valueFromPipeline = $true)][String] $logdisk
)

<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}


<# Convert server to instance #>
$sqlinstance1 = $Sourceserver + ',11433'     

<# Get sizes on primary datafile and log file for the database on the source #>
write-host " Checks the size of the database"
$Datadisk1 = Get-DbaDbFile -SqlInstance $sqlinstance1 -Database $database | Where-Object filegroupname -EQ PRIMARY | Select-Object size
$logdisk1 = Get-DbaDbFile -SqlInstance $sqlinstance1 -Database $database |  Where-Object typedescription -eq log | Select-Object size

<# Convert it to GB#>
$datasize1 = $Datadisk1.size.gigabyte
$logsize1 = $logdisk1.size.gigabyte

<#Get Disksizes on targetserver #>
Write-Host "Checks the size of the data and log disk"
$datadisk2 = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername $Targetserver | Where-Object deviceid -eq E: | Select-Object size
$logdisk2 = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername $Targetserver | Where-Object deviceid -eq F: | Select-Object size

<# Convert it to GB#>
$datasize2 = [math]::round($datadisk2.FreeSpace / 1GB, 0)
$logsize2 = [math]::round($logdisk2.FreeSpace / 1GB, 0)

<# Check if the database fits#>
write-host "checks if the database fits"
$Datafreespace = $datasize2 - $datasize1
$logfreespace = $logsize2 - $logsize1

<#Sets an true/false flag if the data disk is ok#>
If ($Datafreespace -gt 0) {$dataok=$True}
Else {$dataok=$false}


<#Sets an true/false flag if the log disk is ok#>
If ($logfreespace -gt 0) {$logok=$True}
Else {$logok=$false}


IF ($dataok -EQ $true -AND $logok -EQ $True) {write-host"The database $database fits on the targetserver" -f Green}
else {$freeok=$false}



<#Convert negative size to a positive number#>
$Datafreespace = -($Datafreespace)
$logfreespace =-($logfreespace)

<# Print the missing size on the datadisk #>
if ($dataok -eq $false) {Write-Host $Datafreespace "GB is missing on the Data disk" -ForegroundColor Red}
else { Write-Host "The datadisk is ok" 
    
}

<# Print the missing size on the log disk #>
if ($logok -eq $false) {Write-Host $logfreespace "GB is missing on the Log disk" -ForegroundColor Red}
else { Write-Host "The Log disk is ok" }

if ($dataok -eq $false -or $logok -eq $false) {Write-Host "Please order more disk"}
else {write-host "You can proside with the database copy"}


if ($freeok -eq $false) {Exit}
else {"script complete"}
