# set serviceaccount permissions.sp1

<#
.DESCRIPTION 
    give Serviceaccount permissions on folder (Using your permissions) 
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-06-12
   Version 0.02  

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * Added parameter handling to be able to pass variable values to the Script
    
   To Do: 
     Add logfile Path 
    * Add error handling 

#>

<# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'



function netshare # Get a share to be use for the coping #
{
    param ($Sourceserver, $Targetserver, $sqlinstance1,$sqlinstance2
    )


$getshare1 = Get-netshare -server $Sourceserver | Select-Object -ExpandProperty BackupAreaLink
$getshare2 = Get-netshare -server $Targetserver | Select-Object -ExpandProperty BackupAreaLink
$netshare1 =  $getshare1 + "\MSSQL\" + $Sourceserver
$netshare2 =  $getshare2 + "\MSSQL\" + $Targetserver

$testshare1 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $netshare1
$testshare2 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $netshare2


if ($testshare1 -eq $true) {$netshare = $netshare1}
elseif ($testshare2 -eq $true) {$netshare = $netshare2   
}



}




Return $netshare
}

Function Set-folderpermission
{
param($Serviceaccount, $netshare)

$acl = Get-Acl $netshare
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Serviceaccount,"Modify","Allow")
$acl.SetAccessRule($AccessRule)
$acl | Set-Acl $netshare

Write-Host  $Serviceaccount +"now has modify on "+$netshare

}

Function remove-folderpermission
{
param($Serviceaccount, $netshare)
$acl = Get-Acl $netshare

$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Serviceaccount,"Modify","Allow")

$acl.RemoveAccessRule($AccessRule)

$acl | Set-Acl $netshare


}









### Calls ## 



if ($testshare1 -eq $false -and $testshare2 -eq $false) {$setaccess = $true}

If ($setaccess -eq $true)
{
$Serviceaccount = Get-DbaService -Server $Sourceserver  | Where-Object servicetype -eq "Engine" | Select-Object -ExpandProperty startname
Set-folderpermission -Serviceaccount $Serviceaccount -netshare $netshare2
$testshare2 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $netshare2






# Get serviceaccount #
$server= "corpdb4044"
$netshare="\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb4044\MSSQL\testing"
#$Serviceaccount = Get-DbaService -Server $server  | Where-Object servicetype -eq "Engine" | Select-Object -ExpandProperty startname
$Serviceaccount = "corp\u046066"
Set-folderpermission -Serviceaccount $Serviceaccount -netshare $netshare

get-acl -Path "\\corp.saab.se\so\Services\SQLBCK\SE\LKP\corpdb4044\MSSQL\testing"



remove-folderpermission -Serviceaccount $Serviceaccount -netshare $netshare


$acl = Get-Acl $netshare

$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Serviceaccount,"Modify","Allow")

$acl.SetAccessRule($AccessRule)

$acl | Set-Acl $netshare



$acl = Get-Acl $netshare

$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Serviceaccount,"Modify","Allow")

$acl.RemoveAccessRule($AccessRule)

$acl | Set-Acl $netshare

$haspermisson = Get-Acl $netshare | Select-Object -ExpandProperty accesstostring
if ($haspermisson -contains "*$($Serviceaccount)*" ) { Write-Host " has permissions"}
else {Write-Host "No permissions"}

$haspermisson | Get-Member
$haspermisson = Get-Acl $netshare | Select-Object -ExpandProperty accesstostring





