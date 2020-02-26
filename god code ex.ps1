$pc = "localhost"

$disks = get-wmiobject -class "Win32_LogicalDisk" -namespace "root\CIMV2" -computername $pc

$results = foreach ($disk in $disks) {
    if ($disk.Size -gt 0) {
        $size = [math]::round($disk.Size / 1MB, 0)
        $free = [math]::round($disk.FreeSpace / 1MB, 0)
        [PSCustomObject]@{
            Drive             = $disk.Name
            Name              = $disk.VolumeName
            "Total Disk Size" = $size
            "Free Disk Size"  = "{0:N0} ({1:P0})" -f $free, ($free / $size)
        }
    }
}
# Sample outputs
$results | Out-GridView
$results | Format-Table -AutoSize
$results | Export-Csv -Path .\disks.csv -NoTypeInformation -Encoding ASCII

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

 param(
      [Parameter(Mandatory = $True,valueFromPipeline=$true)][String] $value1,
      [Parameter(Mandatory = $True,valueFromPipeline=$true)][String] $value2
      )
aram(
    [Parameter(Mandatory=$true, Position=0, HelpMessage="Password?")]
    [SecureString]$password
  )

write-host "Hello"
$PSScriptRoot 

$ScriptToRun= $PSScriptRoot+"\goodbuy.ps1"

&$ScriptToRun

$command = “.\test2.ps1"
Invoke-Expression $command

#>