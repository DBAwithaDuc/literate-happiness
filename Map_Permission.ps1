<# Map_Permission.ps1
 .DESCRIPTION 
    * maps existing AD-groups for db_owner, Datareader and Datawriter and maps it to a database. also add it to the server if it missing
    
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-12-03  
      Version 0.1


    Credit to Andreas Selguson for the AD and Secret integration
   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * 

#>


############### Automatic configuration #########################


<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'


####################### Functions ################################

############### Automatic configuration #########################


<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'


####################### Functions ################################


Function Get-connectionstring {
    param ($computername, $sqldrift
    )
    
    $computername = $computername.Split(".")[0]
    
    $Cquery=
    "Select Connectionstring FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$computername'"

$connectionstring = Invoke-DbaQuery -SqlInstance $sqldrift -Database sqldrift -Query $Cquery #| Select-Object -ExpandProperty Connectionstring

Return $connectionstring

}


Function CheckforDB # Checks i a database exist on a server #
{
    param ($sqlinstance, $database
    )
    

    Write-Host 'Checking if the database exist'
    $present = Get-DbaDatabase -SqlInstance $sqlinstance -Database $database | Select-Object name


    if ($present) {$Dbexists = $true} 
    else
    {$Dbexists = $false}

    Return $Dbexists
}


## Set Permission Function ##
Function Set-DBPermission
{  param($sqlinstance, $database, $Name, $sqlRole )

    Add-DbaDbRoleMember -SqlInstance $sqlinstance -Database $database -Role $sqlRole -User $Name
    
$Query= 
"ALTER USER [$name] WITH DEFAULT_SCHEMA=[dbo]
 ALTER ROLE [$sqlrole] ADD MEMBER [$name]
GO"

Invoke-DbaQuery -SqlInstance $sqlinstance -Database $database -Query $Query
}


## Get dbrols in a database ##
Function Fetch-Roles
{  param($sqlinstance, $database)

   $roles= Get-DbaDbRole -SqlInstance $sqlinstance -Database $database | Select-Object -ExpandProperty Name 


Return $roles
}  



## Start Config ###

$multi='Y'
$role='X'
$SQLDrift="SQLDRIFTDB.CORP.SAAB.SE,11433"


<# Default permissions  that can be created #>
$role1 = 'db_Owner'
$role2 = 'db_Datawriter'
$role3 = 'db_Datareader'

<######## CallS ###############>

##################### Input ##############################

####  Start Loop ##############
#while($multicopy -eq 'Y' )
#{
Clear-host
Write-Host "This script maps an existing AD-group to an database"
Write-Host "If its missing on the server it creates the login"
<# Collects variables from the console. either by prompted questions or i values is piped to the script #>
$server = IF($server =( Read-Host "Server? [$defaultsource]" )){$server}else{$defaultserver}
$database = IF($Database =( Read-Host "Database? [$defaultdatabase]" )){$database}else{$defaultdatabase}
$Permission = Read-Host "The Ad-group you want to map"

### Reset som variables  ##


$Dbexists = $false
<######## CallS ###############>

## Clean servernames  ##
$server = $server.Split(",")[0]

$connectionstring = Get-connectionstring -computername $server -sqldrift $SQLDrift

$sqlinstance = $connectionstring 


IF ($Permission -contains 'Owner') {$role=$role1}
IF ($Permission -contains 'Datawriter') {$role=$role2}
IF ($Permission -contains 'Datareader') {$role=$role3}
IF ($role -eq 'X') {$fetchroles = Fetch-Roles -sqlinstance $sqlinstance -database $database}





# * $Database = $DataBases.Name | Out-GridView -PassThru  -Title "Choose database to encrypt"
$Menu = @{ }
for ($i = 1; $i -le $fetchroles.count; $i++) 
{
    Write-Host "$i. $($fetchroles[$i-1].Name)" 
    $Menu.Add($i, ($fetchroles[$i - 1].name))
}
 
[int]$ans = Read-Host 'Choose role to add'
$role = $Menu.Item($ans) 



$role





