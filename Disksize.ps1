<#Get-CimInstance -ComputerName bobPC win32_logicaldisk | Where-Object caption -eq "C:" | foreach-object {write-object " $($_.caption) $('{0:N2}' -f ($_.Size/1gb)) GB total, $('{0:N2}' -f ($_.FreeSpace/1gb)) GB free "}  

Get-DiskFree -Credential $cred -Format | Format-Table -GroupBy Name -AutoSize

Invoke-Command -ComputerName  LAPTOP-QL66IFHN {Get-PSDrive C} | Select-Object PSComputerName,Used,Free

$disk = ([wmi]"\\127.0.01\root\cimv2:Win32_logicalDisk.DeviceID='c:'") | 

$free = [math]::round($disk.FreeSpace/1GB, 0)


clear-Host
# PowerShell Else example
[System.Int32]$Integer = Read-Host "Enter Number"
If ($Integer -gt 0) {"$Integer is a positive number"} 
Else {"$Integer is negative"} 

Ideer : Bygga om copy database för  parameters
bygga in stöd för olika portar
bygga in disksize test i copy database
bygga in test för att backupytan går att nå i copy database
Läsa ut defasult diskar för data och log på målservern

Detta skript behöver testa både datadisk och logdisk




#>

$server1=""
$server2="localhost"
$disksize1= 10000
$datadisk= 'e:'
$logdisk='f:'


param(
    [Parameter(Mandatory = $True,valueFromPipeline=$true)][String] $server1,
    [Parameter(Mandatory = $True,valueFromPipeline=$true)][String] $database,
    [Parameter(Mandatory = $True,valueFromPipeline=$true)][String] $server2,
    [Parameter(Mandatory = $false,valueFromPipeline=$true)][String] $datadisk,
    [Parameter(Mandatory = $false,valueFromPipeline=$true)][String] $logdisk
)


$sqlinstance1 = $server1+',11433'     

$disksize1 = Get-DbaDbFile -SqlInstance $sqlinstance1


$disk = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername $server2 | Where-Object deviceid -eq c:
$disksize2 = [math]::round($disk.FreeSpace/1MB, 0)

$freespace= $disksize2-$disksize1

If ($freespace -gt 0) {"$freespace is a positive number"} 
Else {"$freespace is negative"} 






