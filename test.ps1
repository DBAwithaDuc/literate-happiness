
param(
    [Parameter(Mandatory = $True,valueFromPipeline=$true)][String] $server1 ,
    [Parameter(Mandatory = $True,valueFromPipeline=$true)][String] $database,
     [Parameter(Mandatory = $True,valueFromPipeline=$true)][String] $server2,
     [Parameter(Mandatory = $false,valueFromPipeline=$true)][String] $datadisk,
     [Parameter(Mandatory = $false,valueFromPipeline=$true)][String] $logdisk
)

If ($datadisk -eq $null) {$datadisk='e:'} 
Else {"datadisk is $datadisk"} 

Write-Host $server1, $database, $server2, $datadisk, $logdisk
