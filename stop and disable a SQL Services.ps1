<# stop and disable a SQL Services.ps1

* Creates an SQL Login and maps it to a database 
    * It also creates add it to secret
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-02-19  
      Version 0.9


   
   Changelog: 
    * 
    
   To Do: 
    * Add parameter handling to be able to pass variable values to the Script
    * Add logfile Path 
    * Add error handling 

#>


param(
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Targetserver
)


$services = Get-DbaService -ComputerName $Targetserver
$services.ChangeStartMode('disabled')

Stop-DbaService -ComputerName $Targetserver

