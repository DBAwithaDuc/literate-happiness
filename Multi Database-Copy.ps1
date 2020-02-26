<# multi Database-Copy.ps1
 .DESCRIPTION 
    Copies a database from one Sqlserver "Source" to an other SQL server "target" using a netshare
    
    The process is as follows 
    - Collect variables from the console. either by prompted questions or i values is piped to the script
    - Checks if the Powershell module DBATOOLS exist
    - Set values for some needed variables
    - Check if both SQL instances got permissions on the networkshare
    - Check if the targetdatabase exists
    - If the target exist copy the permissons on the existing database
    - If the targetdatabase doesn't exit check if the database fits on the target server.
    - Starts the database copy using backup-Restore and a netshare
    - Set owner of the copied database to SA
    - Runs checks and update stats on the copied database
    - if the target database existed and has been overwritten add the copied permissons  
    - Resync the users in the copied database with existing logins on the target server
    - Runs the the ITDrift - SQL Inventory job  om the targetserver

.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-03-28 11:00 
    Version 2.11

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add error handling
    * Add an option to copy the permissions from the source server if the datababase don't allready exist on the taget 
    * Add an anybox grafical interface
    * Add options to copy multiple databases
    *
    #>


Write-Host "This script copies a database from one SQL server (Source) to an other SQL Server (Target) using a Netshare"
Write-Host "If the target database exist it copies the permissions over write it ana apply the permissions again when the copying is completed"
<# Collects variables from the console. either by prompted questions or i values is piped to the script #>
$Sourceserver = Read-Host "The server you want copy from"
$database = Read-Host "The database you want to copy"
$Targetserver = Read-Host "The server you copy to"
$Newdbname = Read-Host "The name the database will have on the target server"
$Netshare = Read-Host "The netshare to be used for the coping"

<# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'


<# Convert servers to instances #>

$Domain = (Get-WmiObject -ComputerName $Sourceserver Win32_ComputerSystem).Domain
$Port = Get-DbaTcpPort -SqlInstance $Sourceserver -All 
$sqlinstance1 = $Sourceserver + "." + $Domain + "," + ($Port.port | Get-Unique) 

$Domain = (Get-WmiObject -ComputerName $Targetserver Win32_ComputerSystem).Domain
$Port = Get-DbaTcpPort -SqlInstance $Targetserver -All 
$sqlinstance2 = $Targetserver + "." + $Domain + "," + ($Port.port | Get-Unique) 
