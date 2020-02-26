# run sql script on multiple servers.ps1




$instances ="USE [master]
GO
CREATE LOGIN [CORP\ICT-OP5] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
use [master]
GO
GRANT VIEW SERVER STATE TO [CORP\ICT-OP5]
GO "

$query="USE [master]
GO
CREATE LOGIN [CORP\ICT-OP5] FROM WINDOWS WITH DEFAULT_DATABASE=[master]
GO
use [master]
GO
GRANT VIEW SERVER STATE TO [CORP\ICT-OP5]
GO "

foreach ($instance in $instances)
{
    invoke-dbaquery -SqlInstance $instance,11433 -Query $query

}