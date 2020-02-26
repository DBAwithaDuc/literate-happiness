# test netshare.ps1


#>
$Sourceserver= "corpdb4044"
$Targetserver= "corpdb4045"


<# Convert servers to instances #>
<#
$Domain = (Get-WmiObject -ComputerName $Sourceserver Win32_ComputerSystem).Domain
$Port = Get-DbaTcpPort -SqlInstance $Sourceserver -All 
$sqlinstance1 = $Sourceserver + "." + $Domain + "," + ($Port.port | Get-Unique) 

$Domain = (Get-WmiObject -ComputerName $Targetserver Win32_ComputerSystem).Domain
$Port = Get-DbaTcpPort -SqlInstance $Targetserver -All 
$sqlinstance2 = $Targetserver + "." + $Domain + "," + ($Port.p-ort | Get-Unique) 

#>

$sqlinstance1="CORPDB4044.CORP.SAAB.SE,11433"
$sqlinstance2="CORPDB4045.CORP.SAAB.SE,11433"
### Functions ###
Function Get-netshare
{
    param($server
    )
    
$SQLDrift="CORPDB4804.CORP.SAAB.SE,11433"
    
$query="SELECT BackupAreaLink
FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$server'"

$Netshare=Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query

Return $netshare
}


function test-Netsharepaths # tests if a networkshare can be accessed from two sqlinstances#
{
    param ($sqlinstance1, $sqlinstance2, $Netshare)


$path1ok = Test-DbaPath -SqlInstance $sqlinstance1 -Path $Netshare

$path2ok = Test-DbaPath -SqlInstance $sqlinstance2 -Path $Netshare

if ($path1ok -eq $false) {Write-host "The netshare can't be reached from " $Sourceserver " please check"}

If ($path2ok -eq $false) {Write-host "The netshare can't be reached from " $Targetserver " please check"}

if ($path1ok -eq $true -and $path2ok -eq $true) {$pathok = $true}

Return $pathok
}


function netshare # Get a share to be use for the coping #
{
    param ($Sourceserver, $Targetserver, $sqlinstance1,$sqlinstance2
    )


$getshare1 = Get-netshare -server $Sourceserver | Select-Object -ExpandProperty BackupAreaLink
$getshare2 = Get-netshare -server $Targetserver | Select-Object -ExpandProperty BackupAreaLink
$netshare1 =  $getshare1 + "\MSSQL\" + $Sourceserver
$netshare2 =  $getshare2 + "\MSSQL\" + $Targetserver

$testshare1 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $netshare1
$testshare2 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $netshare2


if ($testshare1 -eq $true) {$netshare = $netshare1}
elseif ($testshare2 -eq $true) {$netshare = $netshare2   
}

if ($testshare1 -eq $false -and $testshare2 -eq $false) {$share = Read-Host  "Service account cant use backupshare for coping please enter a share to use"
$Testshare3 = test-Netsharepaths -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2 -Netshare $share
}


if ($Testshare3 -eq $true) {$netshare = $share}
elseif ($testshare1 -eq $false -and $testshare2 -eq $false -and $Testshare3 -eq $false ) {write-host "Please check that share is ok and try again" exit}

Return $netshare
}



######  Calls ###########

$netshare = netshare -Sourceserver $Sourceserver -Targetserver $Targetserver -sqlinstance1 $sqlinstance1 -sqlinstance2 $sqlinstance2


$netshare

$server="corpdb4044"
$Serviceaccount = Get-DbaService -Server $server  | Where-Object servicetype -eq "Engine" | Select-Object -ExpandProperty startname





function Test-servername {
    param (
        $Servername
    )
 


IF ($servername -like "*,*") {$gotport= $true}
else {$gotport =$false
}
$stserver= $servername.Split(",")[0]



   
Return $server
}

$servername1="corpdb4044"
$servername2="corpdb4044.corp.saab.se"
$servername3="corpdb4044.corp.saab.se,11433"
$server1 = Test-servername -Servername $servername1
$server2 = Test-servername -Servername $servername2
$server3 = Test-servername -Servername $servername3
$server1
$server2
$server3


#$sqlinstance1 = $Sourceserver + "." + $Domain + "," + ($Port)


$Port = Get-DbaTcpPort -SqlInstance $servername -All 
$port=""
#$sqlinstance1 = $Sourceserver + "." + $Domain + "," + ($Port.port | Get-Unique) 

#$sqlinstance = $Servername + "." + $Domain + "," + ($Port.port | Get-Unique) 
#IF($gotport -eq $false -and $gotdomain -eq $false) {}

$string="corpdb4044.corp.saab.se,11433"
$string="corpdb4044.corp.saab.se"
$stserver= $string.Split(",")[0]



