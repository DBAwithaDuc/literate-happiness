#Delete databases.ps1

Write-Host "This script deletes on or more databases from one SQL server" 
Write-Host "Remember to verify that you got backups on thet database before"

$server = Read-Host "The server you want delete databasesfrom"
$deldatabase = Read-Host "The database you want to delete"

<# Convert server to instance #>
#$Server = Read-Host "Input servername"
$Domain = (Get-WmiObject -ComputerName $Server Win32_ComputerSystem).Domain
$Port = Get-DbaTcpPort -SqlInstance $Server -All 
$ConnectionString = $Server + "." + $Domain + "," + ($Port.port | Get-Unique) 


    # Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'



#########################  Functions ###################################################



Function Get-permissions # Copies permissons of an database in to the variable $query #
{
    param($ConnectionString, $database)

    Write-Host 'Get Permissions from the existing database'
    $query = Export-DbaUser -SqlInstance $ConnectionString -Database $database
    Return $query
}



###################  Calls  #################

<# Starts the Inverntory job on the target server #>
Start-DbaAgentJob -SqlInstance $ConnectionString -Job $job



$databases= Get-DbaDatabase -sqlinstance $ConnectionString -ExcludeDatabase itdrift -ExcludeSystem -Database $deldatabase

foreach ($database in $databases)  
  {
      
 $users = Get-permissions -sqlinstance $ConnectionString -database $database

 $users | Add-Content -Path c:\scripts\users.txt
  }

  
