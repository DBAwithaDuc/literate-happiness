<# copy files.ps1
    * Copy files from one folder on a share or server to an other folder on a share or folder
    
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-02-20  
      Version 0.1


    
   Requirements:
   Powershell and access to both shares
 
   Changelog: 
    * 
    
   To Do: 
    * Add parameter handling to be able to pass variable values to the Script
    * Add logfile Path 
    * Add error handling 

#>


##################### Configuration ##############################
<# Collects variables from the console. either by prompted questions or i values is piped to the script #>



param(
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $share1,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $share2

)


#Configuration 

$createtargetfolder = 1
$targetfolder = "ITIP"
$filter = "*.exe"


################ Automatic configuration #########################


<# Tests of shares#>
$share1ok = Test-Path $share1
if ($share1ok -ne $true) { Write-host "can't reach "$share1 " or it doesn't exist"}

$share2ok = Test-Path $share2
if ($share2ok -ne $true) { Write-host "can't reach "$share2 " or it doesn't exist"}




<# Create folder#>
if ($createtargetfolder -eq 1) {New-Item -Path $share2\$targetfolder -type directory -Force }

New-Item -Path $share2\$targetfolder -type directory -Force 



<# Coping of files#>
if ($createtargetfolder -eq 1) {Get-ChildItem -Path $share1 -Filter *.exe | Copy-Item -Destination $share2\$targetfolder}
else
{
    Get-ChildItem -Path $share1 -Filter *.exe | Copy-Item -Destination $share2
    
}

Write-host " This files exist in " $share2 
Get-ChildItem -Path $share2\$targetfolder | Write-Output






























<#

<# Checks if the user wants to continue 
Write-Host 'Continue and restore the database ' $database' on '$targetserver ""
$response = read-host "Press a to abort, any other key to continue."
$aborted = $response -eq "a"

If ($aborted -eq $false) {Write-Host 'Starting'}
else {
    EXIT
}


#>



