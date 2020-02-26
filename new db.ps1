<# new db.ps1 -dbName "database" -applicationName "appname" -serverName "CORPDB4044.CORP.SAAB.SE,11433" -owner "a54044 " -BU "CO" -collation "Finnish_Swedish_CI_AS" -environment "TEST" applaccount "N"
 .DESCRIPTION 
    * Creates a database on Sqlserver $sqlinstance 
    * Creates AD-groups for db_owner, Datareader and Datawriter and maps it to the database
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-05-06  
      Version 0.9


    Credit to Andreas Selguson for the AD and Secret integration
   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * 
    * 
    * 

#>

##################### Input ##############################

# Collects variables from the console. either by prompted questions or i values is piped to the script #>
$serverName = Read-Host "The server the database should be creasted on"
$dbName = Read-Host "Name of the Database"
$collation = Read-Host "Collation of the database:"
$applicationName = Read-Host "The application the database is used for"
$owner = Read-Host "The owner of the application the database is used for"
$BU = Read-Host "business unit"
$environment = Read-Host "Environment(PROD,TEST,UAT,DEV)"
#$applaccount=if($applaccount=(Read-Host "Create an applaccount (Y/N) [$DefaultValue]")){$applaccount}else{$DefaultValue}



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

<# Convert server to instance #>
$Domain = "CORP.saab.se"
$sqlinstance  = $serverName + '.' + $Domain + ',11433'
$database = $dbName
<# Default groups to be created #>
$role1 = 'Owner'
$role2 = 'Datawriter'
$role3 = 'Datareader'


 ##################### Configuration ##############################

 $environmentOrg = $environment
 $gaName    = "AP-" + $BU + "-" + $applicationName + "-GA"
 $path = "OU=AP,OU=Groups,OU=Global,DC=CORP,DC=saab,DC=se"
 $sqlRole1 = "db_" + $role1.ToLower()
 $sqlRole2 = "db_" + $role2.ToLower()
 $sqlRole3 = "db_" + $role3.ToLower()

 $role1 = "SQLdb" + $role1
 $role2 = "SQLdb" + $role2
 $role3 = "SQLdb" + $role3   

$Name1 = "AP-" + $BU + "-" + $applicationName + $environment + "-" + $role1
$Name2 = "AP-" + $BU + "-" + $applicationName + $environment + "-" + $role2
$Name3 = "AP-" + $BU + "-" + $applicationName + $environment + "-" + $role3
$gaName= "AP-" + $BU + "-" + $applicationName + "-GA"
#$applKonto = "appl" + $applicationName

####################### Functions ################################

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

$Query= 
"ALTER USER [$name] WITH DEFAULT_SCHEMA=[dbo]
 ALTER ROLE [$sqlrole] ADD MEMBER [$name]
GO"

Invoke-DbaQuery -SqlInstance $sqlinstance -Database $database -Query $Query
}


############### Create Database  ###################

$Dbexist = CheckforDB -sqlinstance $sqlinstance -Database $database

IF ($Dbexist -eq $true) {Write-Host 'The database' + $database + 'allready exist'}
Else {new-database -sqlinstance $sqlinstance -Database $database -Collation $collation}


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

## Set permissions on the database #
Start-sleep -s 60
Set-DBPermission -sqlinstance $sqlinstance -database $database -Name CORP\$Name1 -sqlRole $sqlRole1
Set-DBPermission -sqlinstance $sqlinstance -database $database -Name CORP\$Name2 -sqlRole $sqlRole2
Set-DBPermission -sqlinstance $sqlinstance -database $database -Name CORP\$Name3 -sqlRole $sqlRole3



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
