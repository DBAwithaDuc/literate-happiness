<# Disable Guest.sp1
 .DESCRIPTION 
    Sets number of log files to 12 for all servers that are in sqldrift and not discontinued
    
    

.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-10-10 
    Version 0.1

   Requirements:
   Access to sqldrift to get connectionstrings
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
   
    
   To Do: 
    * Add error handling
    * 
    #>



<# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}


<#  Get connectionstrings       #>
$SQLDrift="CORPDB4804.CORP.SAAB.SE,11433"
    
$query1="SELECT connectionstring
FROM [SQLDrift].[dbo].[tblSQLServer]
where domain = 'corp.saab.se'
and country = 'Sweden'
and discontinued =0
and sqldrift =1
AND [ProductVersion] like '1%' AND (datalength(ZON) = 0 OR [ZON] is NULL) AND EnvironmentID != '2'"

$sqlinstances = invoke-dbaquery -SqlInstance $SQLDrift -Database master -Query $query

$denylogin"REVOKE CONNECT FROM guest"


foreach ($sqlinstance in $ $sqlinstances)
{
    Invoke-DbaQuery -SqlInstance $sqlinstance -Query $denylogin 
    $sqlinstance | Add-Content -Path c:\temp\guestservers.txt

}
