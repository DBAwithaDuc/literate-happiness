
## test dbabuild.ps1



#$server1 = Get-DbaCmsRegServer -sqlinstance 'corpdb4805,11433' -Group sqlversion\2017 | Select-Object -ExpandProperty servername #| Add-Content -Path C:\scripts\txt\servers.txt
#$server2 = Get-DbaCmsRegServer -sqlinstance 'corpdb4805,11433' -Group sqlversion\2016 | Select-Object -ExpandProperty servername # | Add-Content -Path C:\scripts\txt\servers.txt
#$servers = $server1 + $server2


$query="SELECT connectionstring
FROM [SQLDrift].[dbo].[tblSQLServer]
where domain='corp.saab.se' and indrift='Active'"



$connectionstring = Invoke-DbaQuery -SqlInstance "CORPDB4804.CORP.SAAB.SE,11433" -Query $query
$servers = $connectionstring.connectionstring 
#foreach ($server in $servers)
#{
    
    
    
    $servers |  Test-DbaBuild -Latest | Select-Object sqlinstance, culevel, compliant |  Add-Content -Path C:\scripts\txt\testedservers.txt
    #if ($test -eq $false) {$server | Add-Content -Path C:\scripts\txt\builds.txt}

#}

 #Add-Content -Path C:\scripts\txt\testedservers.txt

