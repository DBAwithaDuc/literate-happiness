<# FIXlogfiles.ps1
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
<#
$SQLDrift="CORPDB4804.CORP.SAAB.SE,11433"
    
$query="SELECT connectionstring
FROM [SQLDrift].[dbo].[tblSQLServer]
where domain = 'corp.saab.se'
and country = 'Sweden'
and discontinued =0
and sqldrift =1
AND [ProductVersion] like '1%' AND (datalength(ZON) = 0 OR [ZON] is NULL) AND EnvironmentID != '2'"

$sqlinstances = invoke-dbaquery -SqlInstance $SQLDrift -Query $query
#>

<# Configurations #>


$CMSregserver='corpdb4789.corp.saab.se,11433'


$servers2008 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group SQLVersion\2008
$servers2008R2 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group 'SQLVersion\2008 R2'
$servers2012 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group SQLVersion\2012
$servers2014 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group SQLVersion\2014
$servers2016 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group SQLVersion\2016
$servers2017 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group SQLVersion\2017

$sqlinstances = $servers2016 + $servers2017



foreach ($sqlinstance in $ $sqlinstances)
{
    Set-SqlErrorLog -ServerInstance $sqlinstance -MaxLogCount 12
    $sqlinstance | Add-Content -Path c:\temp\errorlogservers.txt

}
