# labb.ps1



$Servername= "corpdb44.corp.saab.se,11433"

function Test-servername {
    param (
        $servername 
    )
    #$Domain = (Get-WmiObject -ComputerName $Sourceserver Win32_ComputerSystem).Domain
    #$Port = Get-DbaTcpPort -SqlInstance $Sourceserver -All 
    $port="11433"
    #$sqlinstance1 = $Sourceserver + "." + $Domain + "," + ($Port.port | Get-Unique)

If ($Servername -like "*corp.saab.se*") {$corp = $true}
IF ($Servername -like "*,11433*") {$defaultport= $true}

if ($corp -eq $true -and $defaultport -eq $true) {$sqlinstance= $Servername}
else {
    $sqlinstance = $Sourceserver + "." + $Domain + "," + ($Port)    
}
Return $sqlinstance
}

$sqlinstance1 = Test-servername -servername $Servername
$sqlinstance1'
'



