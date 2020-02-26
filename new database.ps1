<# new database.ps1 -dbName CustomerAdaptationTool_BR  -applicationName "CustomerAdaptationToolBR" -serverName "CORPDB10190.CORP.SAAB.SE,11433" -owner "a54044 " -BU "F"
 .DESCRIPTION 
    * Creates a database on Sqlserver $sqlinstance  and updates Dbowner
    * Sets premissions on the the database. If the Ad-groups exist it maps, if not it creates the groups and then map it to the database
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-11-19  
      Version 0.9


    Credit to Andreas Selguson for the AD and Secret integration
   Requirements:
   Have the Powershell module DBAtools installed
   See https://dbatools.io for instructions    
 
   Changelog: 
    * 
    
   To Do: 
    * Add parameter handling to be able to pass variable values to the Script
    * Add logfile Path 
    * Add error handling 

#>


<# Collects variables from the console. either by prompted questions or i values is piped to the script #>

# .\CreateNewDatabase.ps1 -dbName CustomerAdaptationTool_BR  -applicationName "CustomerAdaptationToolBR" -serverName "CORPDB10190.CORP.SAAB.SE,11433" -owner "a54044 " -BU "F"


##################### Configuration ##############################
<# Collects variables from the console. either by prompted questions or i values is piped to the script #>



param([string]$dbName,
    [string]$applicationName,
    [string]$collation,
    [string]$serverName,
    [string]$owner,
    [string]$BU)


#Configuration for Secret API
$secretAccount = 'SVC-MSSQL-SECRET'
$secretBaseURL = 'https://secret.corp.saab.se/Secret/'
$secretURL = '/webservices/SSWebService.asmx'
$domainName = 'corp.saab.se'

################ Automatic configuration #########################


<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'

<# Convert server to instance #>
$sqlinstance = $serverName



<# Default setting for the database#>

$filesize = 100
$FileGrowth = 100
$LogSize = 100
$LogGrowth = 100
$Owner = 'SA'

<# Default groups to be created #>
$role1 = 'Owner'
$role2 = 'Datawriter'
$role3 = 'Datareader'

<# Scriptpath to the create adgroups script#>





$applKonto = "appl" + $applicationName
$b = Get-DbaLogin -SqlInstance $sqlinstance -IncludeFilter $applKonto

if ($b = $true) {
    $applExist = 1
    Write-Host appl$applicationName exist -ForegroundColor Green
}
else {
    $applExist = 0
    Write-Host appl$applicationName missing -ForegroundColor Yellow
}

$c = Get-DbaDatabase -SqlInstance $sqlinstance -Database $dbName

if ($c = $true) {
    $dbExist = 1
    Write-Host 'Database' $dbName 'already exist' -ForegroundColor Green
}
else {
    $dbExist = 0
    Write-Host 'Database' $dbName 'missing' -ForegroundColor Yellow
}

$SQLdbOwner = 'CORP\AP-' + $BU + '-' + $applicationName + '-SQLdbOwner'

$d = Get-DbaLogin -SqlInstance $sqlinstance -IncludeFilter $sqlinstance- login $SQLdbOwner


if ($d = $true) {
    $loginExist = 1
    Write-Host CORP\AP-$BU-$applicationName-SQLdbOwner exist on server -ForegroundColor Green
}
else {
    $loginExist = 0
    Write-Host CORP\AP-$BU-$applicationName-SQLdbOwner missing on server -ForegroundColor Yellow
}


if ($dbExist -eq 1) {
    e= Get-DbaDbUser -sqlinstance $sqlinstance -Database $dbName -IncludeFilter $SQLdbOwner

    if ($e = $true) {
        $userExist = 1
        Write-Host CORP\AP-$BU-$applicationName-SQLdbOwner exist in database -ForegroundColor Green
    }
    else {
        $userExist = 0
        Write-Host CORP\AP-$BU-$applicationName-SQLdbOwner missing in database -ForegroundColor Yellow
    }
}

if ($dbExist -eq 1) {
    $f = Get-DbaDbUser -SqlInstance $sqlinstance -Database $dbName -IncludeFilter $appl
 
    if ($f -= $true) {
        $sqlUserExist = 1
        Write-Host appl$applicationName exist in database -ForegroundColor Green
    }
    else {
        $sqlUserExist = 0
        Write-Host appl$applicationName missing in database -ForegroundColor Yellow
    }
}



####################### Functions ################################

function GetFieldId($template, [string]$name) {
    Return ($template.Fields | Where-Object {$_.DisplayName -eq $name}).Id
}


function CreateNewSecret {
    param($accountUserName)

    $username = $secretAccount
    $secretPassword = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretPassword)
    $secretPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($secretPassword)
    $password = $secretPassword
    $domain = $domainName
    $baseUrl = $secretBaseURL
    $url = $baseUrl + $secretURL
    $proxy = New-WebServiceProxy -uri $url -UseDefaultCredential 
    $tokenResult = $proxy.Authenticate($username, $password, '', $domain)
    
    if ($tokenResult.Errors.Count -gt 0) {
        $msg = "Authentication Error: " + $tokenResult.Errors[0]
        Return
    }
	
    $token = $tokenResult.Token
    $templateName = "RPC - SQL Server Account"
    $template = $proxy.GetSecretTemplates($token).SecretTemplates | Where-Object {$_.Name -eq $templateName}
    
    if ($null -eq $template.id) {
        $msg = "Error: Unable to find Secret Template " + $templateName
        Return
    }
	
    #enter the domain for the AD account you are creating
    if ( $null -eq $accountUserName) {
        $accountUserName = "New User"
    }
    
    #Password is set to null so will generate a new one based on settings on template
    $null = $newPass
    if ($null -eq $newPass) {
        $secretFieldIdForPassword = (GetFieldId $template "Password")
        $newPass = $proxy.GeneratePassword($token, $secretFieldIdForPassword).GeneratedPassword
    }
    $genNote = "SQL login for " + $accountUserName
    $secretName = "appl" + $applicationName + " " + $serverName
    $secretItemFields = ((GetFieldId $template "Server"), (GetFieldId $template "Username"), (GetFieldId $template "Password"), (GetFieldId $template "Notes"))
    $secretItemValues = ($serverName, "sa", $newPass, $genNote)
    $secretItemValues = ($serverName, "appl$applicationName", $newPass, $genNote)
    $folderId = 121;
        
    $addResult = $proxy.AddSecret($token, $template.Id, $secretName, $secretItemFields, $secretItemValues, $folderId)
    
    if ($addResult.Errors.Count -gt 0) {
        Write-Host "Add Secret Error: " +  $addResult.Errors[0] -ForegroundColor Red
        $logInfo = "Add Secret Error: " + $addResult.Errors[0]
        Return
    }
	
    else {
        $logInfo = "Successfully added Secret: " + $addResult.Secret.Name + " (Secret Id:" + $addResult.Secret.Id + ")"
        Write-Host $logInfo -ForegroundColor Green
        Return $newPass
    }
}

function GetPasswordExistingSecret {
    param($searchterm)

    $domain = $domainName
    $baseUrl = $secretBaseURL
    $url = $baseUrl + $secretURL
    $username = $secretAccount
    $secretPassword = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretPassword)
    $secretPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($secretPassword)
    $password = $secretPassword
    
    $proxy = New-WebServiceProxy -uri $url -UseDefaultCredential

    # get a token for further use by authenticating using username/password
    $result1 = $proxy.Authenticate($username, $password, '', $domain)
    
    if ($result1.Errors.length -gt 0) {
        $result1.Errors[0]
        Return
    } 
    
    else {
        $token = $result1.Token
    }

    # search secrets with our searchterm (authenticate by passing in our token)
    $result2 = $proxy.SearchSecrets($token, $searchterm, $null, $null)
    
    if ($result2.Errors.length -gt 0) {
        $result2.Errors[0]
        Return
    }
    else {
        $secretObject = $proxy.GetSecret($token, $result2.SecretSummaries[0].SecretId, $false, $null)
        $secretObject.Secret.Items | foreach-object {if ($_.FieldName -eq "Password") { $pwd = $_.Value }}
        Return $pwd
    }
}

function CreateADGroup {
    

    $path = "OU=AP,OU=Groups,OU=Global,DC=corp,DC=saab,DC=se"

    $name = "AP-" + $BU + "-" + $applicationName + "-GA"
    try {
        $result = Get-ADGroup -Identity $name
        #Write-Host "Ingen GA skapas"
    }
    catch {
        $desc = "GroupAdmin group for " + $applicationName
        New-ADGroup -Path $path -Name $name -GroupScope DomainLocal -GroupCategory Security -Description $desc
        Set-AdGroup -Identity $name -ManagedBy $name
        Add-ADGroupMember -Identity $name -Members $owner
        #Write-Host "GA skapad"
    }

    $name = "AP-" + $BU + "-" + $applicationName + "-SQLdbOwner"
    try {
        $result = Get-ADGroup -Identity $name
        #Write-Host "Ingen Grupp skapas"
    }
    catch {
        $desc = $applicationName + " - MSSQL - SQL dbOwner"
        $managedBy = "AP-" + $BU + "-" + $applicationName + "-GA"
        New-ADGroup -Path $path -Name $name -GroupScope DomainLocal -GroupCategory Security -Description $desc -ManagedBy $managedBy
        #Write-Host "Grupp skapad"
    }
}



######################### CALLS ##################################

if ($dbExist -eq 0) {
    Write-Host "Creating database $dbName"
    New-DbaDatabase -SqlInstance $sqlinstance -Name $dbName -Collation $collation -Owner $owner -PrimaryFilesize $filesize -PrimaryFileGrowth $FileGrowth -LogSize $LogSize -LogGrowth $LogGrowth -ErrorAction stop
    #sqlcmd -S $serverName -v dbName = $dbName -i $scriptFile -m 1
}

if ($applExist -eq 0) {
    $secretPassword = Read-Host "Add PWD for Secret Server" -AsSecureString
    $applPassword = GetPasswordExistingSecret appl$applicationName
    if ($appllPassword -eq $null) {
        $applPassword = CreateNewSecret $applicationName
        if ($applPassword -eq $null) {
            Write-Output "Connection to secret failed"
            Write-Host "Connection to secret failed (Serviceaccont-creation)"
            exit
        }
        $applKonto = "appl" + $applicationName
        Write-Host "Creating account appl$applicationName"
        New-DbaLogin -SqlInstance $sqlinstance -Login $applKonto -PasswordExpiration $false -PasswordPolicy $false -SecurePassword $applPassword -DefaultDatabase $dbName
        #sqlcmd -S $serverName -v dbName = $dbName -v applKonto = $applKonto -v passWord = $applPassword  -i AddSQLLogin.sql -m 1
        if ($sqlUserExist -eq 0) {
            New-DbaDbUser -SqlInstance $sqlinstance -Database $dbName -Login $applKonto
            # sqlcmd -S $serverName -v dbName = $dbName -v applKonto = $applKonto -i AddSQLUser.sql -m 1
        }
    }
}
else {
    $applKonto = "appl" + $applicationName
    if ($sqlUserExist -eq 0) {
        New-DbaDbUser -SqlInstance $sqlinstance -Database $dbName -Login $applKonto 
        # sqlcmd -S $serverName -v dbName = $dbName -v applKonto = $applKonto -i AddSQLUser.sql -m 1
    }
}

try {
    $groupName = "AP-" + $BU + "-" + $applicationName + "-SQLdbOwner"
    $result = Get-ADGroup -Identity $groupName
}

catch {
    CreateADGroup
}

do {
    $groupName = "AP-" + $BU + "-" + $applicationName + "-SQLdbOwner"
    $result = Get-ADGroup -Identity $groupName
    Start-sleep -s 5
} while (!$result)

if ($loginExist -eq 0) {
    Write-Host "Creating AD-group $groupName (login) on the server"
    New-DbaLogin -SqlInstance $sqlinstance -DefaultDatabase $dbName -Login $groupName
    #sqlcmd -S $serverName -v dbName = $dbName -v BU = $BU -v applicationName = $applicationName -i AddADGroupLogin.sql -m 1
}
if ($userExist -eq 0) {
    Write-Host "Creating AD-group $groupName (user) on the server"
    $query = "ALTER ROLE [db_owner] ADD MEMBER " + $groupName
    New-DbaDbUser -SqlInstance $sqlinstance -Database $dbName -Login $groupName
    Invoke-DbaQuery -SqlInstance $sqlinstance -Database $dbName -Query $query
    #sqlcmd -S $serverName -v dbName = $dbName -v BU = $BU -v applicationName = $applicationName -i AddADGroupUser.sql -m 1
}





<# checks the target server i the database exist #>
$item = Get-DbaDatabase -SqlInstance $sqlinstance -Database $dbName | Select-Object Name
IF ($item -eq $true)
{'Database ' + $Item + ' now succesfully created' | Write-output}

<# Starts the Inverntory job on the target server #>
Write-Host 'Runs the Inventory SQL agent job'
Start-DbaAgentJob -SqlInstance $sqlinstance -job $job | Write-output

'Script is completed. Remember to verify permission on the created database' | Write-output

<#Script end #>


<#
 $applKonto = "appl" + $applicationName
        Write-Host "Creating account appl$applicationName"
        
        



ALTER USER [CORP\AP-$(BU)-$(applicationName)-SQLdbOwner] WITH DEFAULT_SCHEMA=[dbo]
GO
USE [$(dbName)]
GO
ALTER ROLE [db_owner] ADD MEMBER [CORP\AP-$(BU)-$(applicationName)-SQLdbOwner]
GO


'Creating AD-groups' | Write-Output
& $scriptpath\CreateADGroups.ps1 -applicationName $application -role $role1 -owner $Groupowner -BU $BU -serverName $sqlinstance -dbName $database | write-output
& $scriptpath\CreateADGroups.ps1 -applicationName $application -role $role2 -owner $Groupowner -BU $BU -serverName $sqlinstance -dbName $database | write-output
& $scriptpath\CreateADGroups.ps1  -applicationName $application -role $role3 -owner $Groupowner -BU $BU -serverName $sqlinstance -dbName $database | write-output

'Runs the Inventory SQL agent job' | write-output
Start-DbaAgentJob -SqlInstance $sqlinstance -job $job | write-output

<#
#function CreateADGroup {
param([string]$applicationName,
    [string]$role,
    [string]$owner,
    [string]$BU,
    [string]$dbName,
    [string]$serverName)





##################### Configuration ##############################

$path = "OU=AP,OU=Groups,OU=Global,DC=corp,DC=saab,DC=se"
$name = "AP-" + $BU + "-" + $applicationName + "-GA"
$sqlRole = "db_" + $role.ToLower()
$role = "SQLdb" + $role

################ Automatic configuration #########################

$query = "select count(*) from sys.syslogins where name = 'CORP\AP-CO-" + $applicationName + "-" + $role + "'"
$QueryResult = Invoke-Sqlcmd -ServerInstance $serverName -Query $query
$d = $QueryResult.Column1
$d = $d -as [int]
    
if ($d -gt 0) {
    $loginExist = 1
    Write-Host CORP\AP-CO-$applicationName-$role exist on server -ForegroundColor Green
}
else {
    $loginExist = 0
    Write-Host CORP\AP-CO-$applicationName-$role missing on server -ForegroundColor Yellow
}
    
$query = "use " + $dbName + "; select count(*) from sysusers where name = 'CORP\AP-CO-" + $applicationName + "-" + $role + "'"
$QueryResult = Invoke-Sqlcmd -ServerInstance $serverName -Query $query
$e = $QueryResult.Column1
$e = $e -as [int]
    
if ($e -gt 0) {
    $userExist = 1
    Write-Host CORP\AP-CO-$applicationName-$role exist in database -ForegroundColor Green
}
else {
    $userExist = 0
    Write-Host CORP\AP-CO-$applicationName-$role missing in database -ForegroundColor Yellow
}

######################### CALLS ##################################

try {
    $result = Get-ADGroup -Identity $name
    #Write-Host "Ingen GA skapas"
}
catch {
    $desc = "GroupAdmin group for " + $applicationName
    New-ADGroup -Path $path -Name $name -GroupScope DomainLocal -GroupCategory Security -Description $desc
    Set-AdGroup -Identity $name -ManagedBy $name
    Add-ADGroupMember -Identity $name -Members $owner
    #Write-Host "GA skapad"
}

$name = "AP-" + $BU + "-" + $applicationName + "-" + $role
try {
    $result = Get-ADGroup -Identity $name
    #Write-Host "Ingen Grupp skapas"
}
catch {
    $desc = $applicationName + " - MSSQL - " + $sqlRole
    $managedBy = "AP-" + $BU + "-" + $applicationName + "-GA"
    New-ADGroup -Path $path -Name $name -GroupScope DomainLocal -GroupCategory Security -Description $desc -ManagedBy $managedBy
    #Write-Host "Grupp skapad"
    Start-sleep -s 60
}
if ($loginExist -eq 0) {
    Write-Host "Creating AD-group $name (login) on the server"
    sqlcmd -S $serverName -v dbName = $dbName -v applicationName = $applicationName -v role = $role -i AddADGroupLogin.sql -m 1
}
if ($userExist -eq 0) {
    Write-Host "Creating AD-group $name (user) on the server"
    sqlcmd -S $serverName -v dbName = $dbName -v applicationName = $applicationName -v role = $role -v sqlRole = $sqlRole -i AddADGroupUser.sql -m 1
}
#}

#>