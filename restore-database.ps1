<# restore-database.PS1
 .DESCRIPTION 
    Restores a database to a specific time 
.NOTES 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-12-21 
    Version 0.9

   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add logfile Path 
    * Add error handling

    IN progress
  
#>




<# Load the dbatools module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}


#########################  Functions ###################################################



Function Get-netshare
{
    param($server, $SQLDrift
    )
    
    $server = $server.Split(".")[0]
  
    
$query="SELECT BackupAreaLink
FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$server'"

$Netshare=Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query

IF  ($Netshare -eq "" -or $Netshare -eq $null) {$netshare = Read-Host "Can't reach SQLDrift to get an netshare to use. Pkease enter an netshare that both servers can reach" }


Return $netshare
}


Function get-restorepath 
{
    param($netshare,$database
 
    )
    
    

$path= $netshare+'\'+$database+'\FULL'
$files = Get-ChildItem $path -Recurse
$restorepath = $files  #| Where-Object {$_.LastWriteTime -gt '12/16/2019' -and $_.LastWriteTime -lt '12/17/2019'} 

Return $restorepath.FullName

 }

 
 Function Get-permissions # Copies permissons of an database in to the variable $query #
 {
     param($sqlinstance, $database)
 
     Write-Host 'Get Permissions from the existing database'
     $query = Export-DbaUser -SqlInstance $sqlinstance -Database $database -Passthru
     Return $query
 }


 

Function DBAupgrade # Runs checks and update stats #
{
    param($sqlinstance, $database)

    
    Write-Host 'Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views.'
    Invoke-DbaDbUpgrade -SqlInstance $sqlinstance -database $database | Write-output <#Updates compatibility level, then runs CHECKDB with data_purity, DBCC updateusage, sp_updatestats and finally sp_refreshview against all user views #>

}


Function Set-Permission # Set permissions on a database using script in the variable $query
{
    Param ($sqlinstance, $database, $query)
    Write-Host 'Sets Permissions on database'+ $Newdbname
    Invoke-DbaQuery  -SqlInstance $sqlinstance -Database $database -Query $query | Write-Output

}


function Restore-Database-path {
    param ($restorepath, $sqlinstance,$database,$newname
    )
    
<# Starting restore of the the database from the backupfiles that matches#>
Write-Host 'Starting Restore of ' $database' on '$sqlinstance' as '$newname
Restore-DbaDatabase -Path $restorepath -SqlInstance $sqlinstance -DatabaseName $newname -ReplaceDbNameInFile -WithReplace


}



function CheckforDB # Checks i a database exist on a server #
{
    param ($sqlinstance, $database
    )
    

    Write-Host 'Checking if the database allready exist and the permissions should be recreated after the database coping'
    $present = Get-DbaDatabase -SqlInstance $sqlinstance -Database $database | Select-Object name


    if ($present) {$Dbexists = $true} 
    else
    {$Dbexists = $false}

    if ($Dbexists -eq $true) { Write-host  "The database exist on the target"}
    else {if ($Dbexists -eq $false) {write-host "No database with that name exist checking diskspace"}}
    Return $Dbexists
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



