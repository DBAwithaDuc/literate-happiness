<# new db and ADgroups.ps1 -dbName "database" -applicationName "appname" -serverName "CORPDB4044.CORP.SAAB.SE,11433" -owner "a54044 " -BU "CO" -collation "Finnish_Swedish_CI_AS" -environment "TEST" applaccount "N"
 .DESCRIPTION 
    * Creates a database on Sqlserver $sqlinstance if it doesn't exist
    * Creates AD-groups for db_owner, Datareader and Datawriter and maps it to the database. checks if it allready exist then it only maps
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2020-01-23  
      Version 1.25


    Credit to Andreas Selguson for the AD integration
   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * Corrected a spelling error
    * Gets the servers Collation as Default collation for the database
    * Check if $enviroment is null then skip envroment in the groupname
    * Change to get connectionstring throught SQLdrift instead
    * Handle FQDN servername when getting connectionstring from SQlDrift
    * Added backup of database after creation
    * Default schema was missing. corected that
    * Change Connectionstring fo SQL drift to the new alias
	* Corrected spelling errors and change handling of when enviroment or netshare is null
    
   To Do: 
    * Add option to create applaccount with integration to Secret
    * Add anybox GUI
    * option to not create groups
    * option to mapp a existing group to the created database
    * Option to create an group with specified name and permissons

#>


<# Get sqlinstance connectionstring for that server#>
$SQLDrift="SQLDRIFTDB.CORP.SAAB.SE,11433"


##################### Configuration ##############################
<#
#Configuration for Secret API
$secretAccount = 'SVC-MSSQL-SECRET'
$secretBaseURL = 'https://secret.CORP.saab.se/Secret/'
$secretURL = '/webservices/SSWebService.asmx'
$domainName = 'CORP.saab.se'

#>
################ Automatic configuration #########################


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

$connectionstring = Invoke-DbaQuery -SqlInstance $sqldrift -Database sqldrift -Query $Cquery | Select-Object -ExpandProperty Connectionstring

Return $connectionstring

}




Function CheckforDB # Checks i a database exist on a server #
{
    param ($sqlinstance, $database
    )
    

    Write-Host 'Checking if the database allready exist'
    $present = Get-DbaDatabase -SqlInstance $sqlinstance -Database $database | Select-Object name


    if ($present) {$Dbexists = $true} 
    else
    {$Dbexists = $false}

    Return $Dbexists
}

###### New database function ##
Function new-database
{  param($sqlinstance, $database, $collation )

<# Default settings for the database#>

$filesize = 100
$FileGrowth = 100
$LogSize = 100
$LogGrowth = 100
$databaseOwner = 'SA'

New-DbaDatabase -SqlInstance $sqlinstance -Name $database -Collation $collation -Owner $databaseOwner -PrimaryFilesize $filesize -PrimaryFileGrowth $FileGrowth -LogSize $LogSize -LogGrowth $LogGrowth -ErrorAction stop
$present = Get-DbaDatabase -SqlInstance $sqlinstance -Database $database | Select-Object name


if ($present) {$Dbcreated = $true} 
else
{$Dbcreated = $false}
Return $Dbcreated
}

############## Create Ad-group  function ###########
Function New-Group
{  param($sqlinstance, $database, $Name, $gaName, $sqlRole, $role, $applicationName, $path, $create )


    $Sname = Get-DbaLogin -SqlInstance $sqlinstance -Login CORP\$Name

    IF ($Sname) {$create=0 
        Write-Host The Group corp\$name exists in the server}
    else
     {$create=1 
         Write-Host The Group corp\$name is missing in the server}
    
         $Dname = Get-DbaDbUser -SqlInstance $sqlinstance -Database $database | Where-Object name -eq corp\$name

    


    Try{
       $result = Get-ADGroup -Identity $Name
            Write-Host "Ingen Grupp skapas"
        }
        catch
        {
            $desc = $applicationName + " - MSSQL - " + $sqlRole
            #$managedBy = "AP-" + $BU + "-" + $applicationName + "-GA"
            New-ADGroup -Path $path -Name $name -GroupScope DomainLocal -GroupCategory Security -Description $desc -ManagedBy $gaName
            Write-Host "Grupp skapad"
            Start-sleep -s 120
        }
        if ($create -eq 1) {
            Write-Host "Creating AD-group $name (login) on the server"
            New-DbaLogin -SqlInstance $sqlinstance -DefaultDatabase $database -Login CORP\$Name
           
        }
        if ($create -eq 1) {
            Write-Host "Creating AD-group $name (user) in database"
            New-DbaDbUser -SqlInstance $sqlinstance -Database $database -Login CORP\$Name
            
           
        }
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


function backup-newdatabase
 {
    param ($sqlinstance,$database,$netshare)
    
    $backup = Backup-DbaDatabase -SqlInstance $sqlinstance -Database $database -CompressBackup -Checksum
    
    return $backup
}


Function Get-netshare
{
    param($server,$SQLDrift
    )
    
    $server = $server.Split(".")[0]
  
 
$query="SELECT BackupAreaLink
FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$server'"

$netshare1=Invoke-DbaQuery -SqlInstance $SQLDrift -Query $query

$Netshare = $netshare1 | Select-Object -ExpandProperty BackupAreaLink

If ($environment )
IF  ($Netshare -notmatch "\S") {$netshare = Read-Host "Can't reach SQLDrift to get an netshare to use. Pkease enter an netshare that both servers can reach" }


Return $netshare
}

Function Set-DBPermission_old
{  param($sqlinstance, $database, $Name, $sqlRole )

$Query= 
"ALTER USER [$name] WITH DEFAULT_SCHEMA=[dbo]
 ALTER ROLE [$sqlrole] ADD MEMBER [$name]
GO"

Invoke-DbaQuery -SqlInstance $sqlinstance -Database $database -Query $Query
}

<######## CallS ###############>
$applicationName=$null

##################### Input ##############################
# Collects variables from the console. either by prompted questions or i values is piped to the script #>
$serverName = Read-Host "The server the database should be creasted on"

<# Get sqlinstance connectionstring for that server#>
$SQLDrift="SQLDRIFTDB.CORP.SAAB.SE,11433"

$connectionstring = Get-connectionstring -computername $serverName -sqldrift $SQLDrift

$sqlinstance = $connectionstring 

<# Get the servers collation #>
$defaultcollation = Test-DbaDbCollation -SqlInstance $sqlinstance -Database master | Select-Object -ExpandProperty servercollation

$dbName = Read-Host "Name of the Database"
$collation = IF($collation =( Read-Host "Collation of the database [$Defaultcollation]" )){$collation}else{$Defaultcollation}
$applicationName = Read-Host "The application the database is used for"
$owner = Read-Host "The owner of the application the database is used for (userid)"
$BU = Read-Host "business unit"
$environment = Read-Host "Environment(PROD,TEST,UAT,DEV)"
#$applaccount=if($applaccount=(Read-Host "Create an applaccount (Y/N) [$DefaultValue]")){$applaccount}else{$DefaultValue}

$applicationName=$applicationName.ToUpper()
$BU=$bu.ToUpper()
$environment= $environment.ToUpper()
$database = $dbName.ToUpper()

<# Default groups to be created #>
$role1 = 'Owner'
$role2 = 'Datawriter'
$role3 = 'Datareader'


 ##################### Configuration ##############################

 
 $gaName    = "AP-" + $BU + "-" + $applicationName + "-GA"
 $path = "OU=AP,OU=Groups,OU=Global,DC=CORP,DC=saab,DC=se"
 $sqlRole1 = "db_" + $role1.ToLower()
 $sqlRole2 = "db_" + $role2.ToLower()
 $sqlRole3 = "db_" + $role3.ToLower()

 $role1 = "SQLdb" + $role1
 $role2 = "SQLdb" + $role2
 $role3 = "SQLdb" + $role3   

 $gaName= "AP-" + $BU + "-" + $applicationName + "-GA"
 
 If ($environment -notmatch "\S")
   { 
   $Name1 = "AP-" + $BU + "-" + $applicationName + "-" + $role1
$Name2 = "AP-" + $BU + "-" + $applicationName  + "-" + $role2
$Name3 = "AP-" + $BU + "-" + $applicationName  + "-" + $role3
}
else
{
$Name1 = "AP-" + $BU + "-" + $applicationName + "-" + $environment + "-" + $role1
$Name2 = "AP-" + $BU + "-" + $applicationName  + "-" + $environment + "-" + $role2
$Name3 = "AP-" + $BU + "-" + $applicationName  + "-" + $environment + "-" + $role3 
}



############### Create Database  ###################

$Dbexist = CheckforDB -sqlinstance $sqlinstance -Database $database

IF ($Dbexist -eq $true) {Write-Host 'The database' + $database + 'allready exist'}
Else {new-database -sqlinstance $sqlinstance -Database $database -Collation $collation
Set-DbaDbOwner -SqlInstance $sqlinstance -Database $database
}


######################### Create AD groups ############################################################


try{
    $result = Get-ADGroup -Identity $gaName
    #Write-Host "Ingen GA skapas"
}
catch
{
    $desc = "GroupAdmin group for " + $applicationName
    New-ADGroup -Path $path -Name $gaName -GroupScope DomainLocal -GroupCategory Security -Description $desc
    Set-AdGroup -Identity $gaName -ManagedBy $gaName
    Add-ADGroupMember -Identity $gaName -Members $owner
    #Write-Host "GA skapad"
}

### Create $name1 group ##
New-Group -sqlinstance $sqlinstance -database $database -Name $name1 -sqlRole $sqlrole1 -role $role1 -applicationName $applicationName -path $path

### Create $name2 group ##
New-Group -sqlinstance $sqlinstance -database $database -Name $Name2 -sqlRole $sqlRole2 -role $role2 -applicationName $applicationName -path $path

### Create $name3 group ##
New-Group -sqlinstance $sqlinstance -database $database -Name $Name3 -sqlRole $sqlRole3 -role $role3 -applicationName $applicationName -path $path

#### Fetch backupshare to create a database backup ####

$netshare = Get-netshare -server $serverName -SQLDrift $SQLDrift

$serverName = $serverName.Split(".")[0]

$backupshare = $netshare + "\MSSQL\" + $serverName + "\" + $database

## Set permissions on the database #
Start-sleep -s 60
Set-DBPermission -sqlinstance $sqlinstance -database $database -Name CORP\$Name1 -sqlRole $sqlRole1
Set-DBPermission -sqlinstance $sqlinstance -database $database -Name CORP\$Name2 -sqlRole $sqlRole2
Set-DBPermission -sqlinstance $sqlinstance -database $database -Name CORP\$Name3 -sqlRole $sqlRole3

### Do a first Backup of the database after creations###
$backup = backup-newdatabase -sqlinstance $sqlinstance -database $database -netshare $backupshare

#>
#Runs the inventory job #
Start-DbaAgentJob -SqlInstance $sqlinstance -Job $job

Write-Host 'Created Ad groups ' 
                            $Name1
                            $Name2
                            $Name3  
                            

Write-Host "Script completed"

#Script End #

#[ValidateSet('Y','N')]$Answer = Read-Host "Create an applaccount?"

#$Value=if($Value=(Read-Host "Create an applaccount (Y/N) (N) [$DefaultValue]")){$Value}else{$DefaultValue}


<#
"Select Connectionstring FROM [SQLDrift].[dbo].[tblSQLServer]
where ServerName='$server'"


$Domain = (Get-WmiObject -ComputerName $serverName Win32_ComputerSystem).Domain
$Port = Get-DbaTcpPort -SqlInstance $serverName -All 
$sqlinstance = $serverName + "." + $Domain + "," + ($Port.port | Get-Unique) 

#$applaccount=if($applaccount=(Read-Host "Create an applaccount (Y/N) [$DefaultValue]")){$applaccount}else{$DefaultValue}
#$collation = Read-Host "Collation of the database"



#>