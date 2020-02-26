<#  CH264644 Disk inventory.ps1

.DESCRIPTION 
    Checks disk size on target server befor a database copy
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-01-10 07:58 

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 

    #>

    $Domain = "CORP.saab.se"
    $servers = Get-Content -Path "C:\scripts\txt\CH264644.txt"
    $exclude= "itdrift"



    # Loop through servers
    ForEach ($server in $servers)
    {

    $sqlinstance  = $server + '.' + $Domain + ',11433'
   
    <#Get Disksizes on targetserver #>
    $sysdisk = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername $server | Where-Object deviceid -eq C: | Select-Object FreeSpace
    $Bindisk = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername $server | Where-Object deviceid -eq D: | Select-Object FreeSpace
    $datadisk = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername $server | Where-Object deviceid -eq E: | Select-Object FreeSpace
    $logdisk = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername $server | Where-Object deviceid -eq F: | Select-Object FreeSpace
    $tempdisk = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername $server | Where-Object deviceid -eq G: | Select-Object FreeSpace

    <# Convert it to GB#>
    $sysSize = [math]::round($sysdisk.FreeSpace / 1GB, 0)
    $BinSize = [math]::round($bindisk.FreeSpace / 1GB, 0)
    $datasize = [math]::round($datadisk.FreeSpace / 1GB, 0)
    $logsize = [math]::round($logdisk.FreeSpace / 1GB, 0)
    $tempsize = [math]::round($tempdisk.FreeSpace / 1GB, 0)

    $databases = Get-DbaDatabase -sqlinstance $sqlinstance -ExcludeSystem -ExcludeDatabase $exclude | Select-Object -namespace

    foreach ($database in $databases)
    {
    <# Get sizes on primary datafile and log file for the database on the source #>    
    $Dbdisk = Get-DbaDbFile -SqlInstance $sqlinstance -Database $database | Where-Object filegroupname -EQ PRIMARY | Select-Object size
    $logdisk = Get-DbaDbFile -SqlInstance $sqlinstance -Database $database |  Where-Object typedescription -eq log | Select-Object size
       
    <# Convert it to GB#>
    $dbsize = $dbdisk.size.gigabyte
    $dblogsize = $logdisk.size.gigabyte

        $server, $database, $dbsize, $datadisk, $dblogsize | Add-Content -Path 'C:\scripts\txt\$server.txt'

    }   

    $server, $sysSize , $BinSize, $datasize, $logsize, $tempsize | Add-Content -Path 'C:\scripts\txt\$server.txt'

}