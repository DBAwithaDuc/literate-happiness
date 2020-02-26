# Get-new-servers.ps1

$sqlinstance='corpdb17335.corp.saab.se,11433'
$sqldrift='sqldriftdb.corp.saab.se,11433'
$database='restoretestdb'

      
$query1="SELECT connectionstring
FROM [SQLDrift].[dbo].[tblSQLServer]
where domain = 'corp.saab.se'
and country = 'Sweden'
and discontinued =0
and sqldrift =1
AND [ProductVersion] like '1%' AND (datalength(ZON) = 0 OR [ZON] is NULL) AND EnvironmentID != '2'"

$serverlist = Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query1
$serverlist | Write-DbaDbTableData -SqlInstance $sqlinstance -Database $database -Table tblnewserverlist

