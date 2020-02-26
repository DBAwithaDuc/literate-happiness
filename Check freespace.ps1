# Check freespace.ps1

$erroractionpreference = "SilentlyContinue"
$a = New-Object -comobject Excel.Application
$a.visible = $True 

$b = $a.Workbooks.Add()
$c = $b.Worksheets.Item(1)

$c.Cells.Item(1,1) = "Machine Name"
$c.Cells.Item(1,2) = "Drive"
$c.Cells.Item(1,3) = "Total size (GB)"
$c.Cells.Item(1,4) = "Free Space (GB)"
$c.Cells.Item(1,5) = "Free Space (%)"

$d = $c.UsedRange
$d.EntireColumn.AutoFit() | out-null
$d.Interior.ColorIndex = 19
$d.Font.ColorIndex = 11
$d.Font.Bold = $True


$intRow = 2

$colComputers = get-content C:\Temp\servers.txt
foreach ($strComputer in $colComputers)
{
$wql = "SELECT Name, Capacity, Freespace FROM Win32_Volume WHERE FileSystem='NTFS'"
$colDisks = Get-WmiObject -Query $wql -ComputerName $strComputer | Select-Object Name, Capacity, Freespace
} 
foreach ($objdisk in $colDisks)
{
 $c.Cells.Item($intRow, 1) = $strComputer.ToUpper()
 $c.Cells.Item($intRow, 2) = $objDisk.Name
 $c.Cells.Item($intRow, 3) = "{0:N0}" -f ($objDisk.Capacity/1GB)
 $c.Cells.Item($intRow, 4) = "{0:N0}" -f ($objDisk.FreeSpace/1GB)
 $x=$c.Cells.Item($intRow, 5) = "{0:P0}" -f ([double]$objDisk.FreeSpace/[double]$objDisk.Capacity)
# if 
##($x>95)
#{
# $d = $c.UsedRange
# $d.Interior.ColorIndex = 19
#$intRow = $intRow + 1
#}
#else
#{
$intRow = $intRow + 1
$d = $c.UsedRange
$d.EntireColumn.AutoFit() | out-null
}
#}
#}