<# update tools on all servers.PS1
 .DESCRIPTION 
    Update whoisactive and firstresponderkit on all servers (2008 an newer)
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-08-09 15:48 
    Version 0.1

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add logfile Path 
    * Add error handling
    
  
#>
<# Configurations #>


$CMSregserver='corpdb4804.corp.saab.se,11433'


$servers2008 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group SQLVersion\2008
$servers2008R2 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group 'SQLVersion\2008 R2'
$servers2012 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group SQLVersion\2012
$servers2014 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group SQLVersion\2014
$servers2016 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group SQLVersion\2016
$servers2017 = Get-DbaRegisteredServer -SqlInstance $CMSregserver -Group SQLVersion\2017

$servers = $servers2008 + $servers2008R2 + $servers2012 + $servers2014 + $servers2016 + $servers2017




#$servers | Install-DbaWhoIsActive -Database ITDrift -LocalFile C:\temp\SP_whoisactive\sp_whoisactive-11.33.zip
$servers | Install-DbaFirstResponderKit -Database ITDrift -LocalFile C:\temp\Firstresponderkit\FirstResponderKit.zip





