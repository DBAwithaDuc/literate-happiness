# ch260261 get_filesiszes.ps1



$sqlinstance ="SSPDB4DEV.SSP.LOCAL,11433"
$databases = Get-Content -Path c:\scripts\txt\databases.txt

# loop through all databases with the same name #
foreach ($database in $databases)
{

$Datadisk1 = Get-DbaDbFile -SqlInstance $sqlinstance -Database $database | Where-Object filegroupname -EQ PRIMARY | Select-Object size
$logdisk1 = Get-DbaDbFile -SqlInstance $sqlinstance -Database $database |  Where-Object typedescription -eq log | Select-Object size

$datadisk = $datadisk + $Datadisk1

$logdisk = $logdisk + $logdisk1
}

$datadisk

$logdisk
