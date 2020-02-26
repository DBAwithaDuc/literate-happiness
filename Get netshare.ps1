Get netshare.ps1


<# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}


### Functions  ##############



Function Get-netshare 
{
    param($server
    )
    
    $server = $server.Split(".")[0]
  
$SQLDrift="CORPDB4804.CORP.SAAB.SE,11433"
    
$query="SELECT BackupAreaLink
FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$server'"

$Netshare=Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query

IF  ($Netshare -eq "" -or $Netshare -eq $null) {$netshare = Read-Host "Can't reach SQLDrift to get an netshare to use. Pkease enter an netshare that both servers can reach" }


Return $netshare
}



function Test-Netsharepaths # tests if a networkshare can be accessed from two sqlinstances#
{
    param ($sqlinstance1, $sqlinstance2, $Netshare
    )


$path1ok = Test-DbaPath -SqlInstance $sqlinstance1 -Path $Netshare

$path2ok = Test-DbaPath -SqlInstance $sqlinstance2 -Path $Netshare

if ($path1ok -eq $false) {Write-host "The netshare can't be reached from " $Sourceserver " please check"}

If ($path2ok -eq $false) {Write-host "The netshare can't be reached from " $Targetserver " please check"}

if ($path1ok -eq $true -and $path2ok -eq $true) {$pathok = $true}

Return $pathok
}




Function Set-folderpermission # Gives Serviceaccount access to a folder
{
param($Serviceaccount, $netshare)

$acl = Get-Acl $netshare
$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Serviceaccount,"Modify","Allow")
$acl.SetAccessRule($AccessRule)
$acl | Set-Acl $netshare

Write-Host  $Serviceaccount +"now has modify on "+$netshare

}

Function remove-folderpermission # removes a Serviceaccount access to a folder
{
param($Serviceaccount, $netshare)
$acl = Get-Acl $netshare

$AccessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($Serviceaccount,"Modify","Allow")

$acl.RemoveAccessRule($AccessRule)

$acl | Set-Acl $netshare

}




Function get-serviceaccount # get Serviceaccount for the MSSQLServer service on a server
{
param($servername
)
$serviceaccount = Get-DbaService -ComputerName $servername -ServiceName MSSQLSERVER | Select-Object -ExpandProperty startname

Return $serviceaccount
}




function netshare # Get a share to be use for the coping #
{
    param ($Sourceserver, $Targetserver, $sqlinstance1,$sqlinstance2
    )


$getshare1 = Get-netshare -server $Sourceserver | Select-Object -ExpandProperty BackupAreaLink
$getshare2 = Get-netshare -server $Targetserver | Select-Object -ExpandProperty BackupAreaLink
$netshare1 =  $getshare1 + "\MSSQL\" + $Sourceserver
$netshare2 =  $getshare2 + "\MSSQL\" + $Targetserver

$testshare1 = Test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $netshare1
$testshare2 = Test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $netshare2


if ($testshare1 -eq $true) {$netshare = $netshare1}
elseif ($testshare2 -eq $true) {$netshare = $netshare2   
}

if ($testshare1 -eq $false -and $testshare2 -eq $false) {$createshare = $true}

If ($createshare -eq $true)

{$netshare = Enable-netsharepermission -Sourceserver $Sourceserver -Targetserver $Targetserver -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -netshare1 $netshare1 -netshare2 $netshare2}



Return $netshare

}
    
    
    
    
    
    
    <#$share = Read-Host  "Service account cant use backupshare for coping please enter a share to use"
$Testshare3 = Test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $share
}


if ($Testshare3 -eq $true) {$netshare = $share}
elseif ($testshare1 -eq $false -and $testshare2 -eq $false -and $Testshare3 -eq $false ) {write-host "Please check that share is ok and try again" exit}


#>



Function enable-netsharepermission  # Fix permissions to be able copy the database
{
param($Sourceserver,$Targetserver,$sqlinstance1, $sqlinstance2 ,$netshare1,$netshare2
)
$sourceaccount = get-serviceaccount -servername $Sourceserver

$Targetaccount = get-serviceaccount -servername $Targetserver

$testshareSource = Test-DbaPath -SqlInstance $sqlinstance1 -Path $netshare2

$testshareTarget = Test-DbaPath -SqlInstance $sqlinstance2 -Path $netshare2

If ($testshareSource -eq $false) {Set-folderpermission -Serviceaccount $sourceaccount -netshare $netshare2}
If ($testshareTarget -eq $false) {Set-folderpermission -Serviceaccount $Targetaccount -netshare $netshare2}

Return $netshare
}



## Calls ###


