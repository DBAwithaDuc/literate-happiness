

 
#your SQL Server Instance Name
$SQLInstanceName = "corpdb4044.corp.saab.se,11433"
$Server = New-Object -TypeName Microsoft.SqlServer.Management.Smo.Server -ArgumentList $SQLInstanceName
 
#provide your database name where you want to change database properties
$DatabaseName = "test1"
 
#create SMO handle to your database
$DBObject = $Server.Databases[$DatabaseName]



#Set your database ReadOnly with DatabaseOptions
$DBObject.DatabaseOptions.ReadOnly = $true
$DBObject.Alter()


Get-ADUser u046066 -properties msDS-UserPasswordExpiryTimeComputed | select @{N="PasswordExpiryDate";E={[DateTime]::FromFileTime($_."msDS-UserPasswordExpiryTimeComputed")}}


$sqlinstance='corpdb4044.corp.saab.se,11433'
$database='restotest'

$serverquery="
    select top 1  connectionstring from dbo.tblserverlist
    where runed = 0 or  runed is null
    "
    $server= Invoke-DbaQuery -SqlInstance $sqlinstance -Database $database -Query $serverquery
