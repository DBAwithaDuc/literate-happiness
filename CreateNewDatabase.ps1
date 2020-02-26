# .\CreateNewDatabase.ps1 -dbName CustomerAdaptationTool_BR  -applicationName "CustomerAdaptationToolBR" -serverName "CORPDB10190.CORP.SAAB.SE,11433" -owner "a54044 " -BU "F"

##################### Configuration ##############################

param([string]$dbName,
[string]$applicationName,
[string]$serverName,
[string]$owner,
[string]$BU)

#Configuration for Secret API
$secretAccount = 'SVC-MSSQL-SECRET'
$secretBaseURL = 'https://secret.corp.saab.se/Secret/'
$secretURL = '/webservices/SSWebService.asmx'
$domainName = 'corp.saab.se'

################ Automatic configuration #########################
$QueryResult = Invoke-Sqlcmd -ServerInstance $serverName -Query "SELECT SERVERPROPERTY('ProductMajorVersion')"
$a = $QueryResult.Column1
$a = $a -as [int]

if ($a -eq 11) {
    $scriptFile = 'CreateNewDatabase-2012.sql'
    #Write-Host 'SQL Server 2012'
}
elseif ($a -eq 12) {
    $scriptFile = 'CreateNewDatabase-2014.sql'
    #Write-Host 'SQL Server 2014'
}
elseif ($a -eq 13) {
    $scriptFile = 'CreateNewDatabase-2016.sql'
    #Write-Host 'SQL Server 2016'
}
elseif ($a -eq 14) {
    $scriptFile = 'CreateNewDatabase-2017.sql'
    #Write-Host 'SQL Server 2017'
}
else {
    Write-Host 'Could not find SQL Version, script is now exit' -ForegroundColor Red
    break
}

$query = "select count(*) from sys.sql_logins where name = 'appl" + $applicationName + "'"
$QueryResult = Invoke-Sqlcmd -ServerInstance $serverName -Query $query
$b = $QueryResult.Column1
$b = $b -as [int]

if ($b -gt 0) {
    $applExist = 1
    Write-Host appl$applicationName exist -ForegroundColor Green
}
else {
    $applExist = 0
    Write-Host appl$applicationName missing -ForegroundColor Yellow
}

$query = "select count(*) from sys.databases where name = '" + $dbName + "'"
$QueryResult = Invoke-Sqlcmd -ServerInstance $serverName -Query $query
$c = $QueryResult.Column1
$c = $c -as [int]

if ($c -gt 0) {
    $dbExist = 1
    Write-Host 'Database' $dbName 'already exist' -ForegroundColor Green
}
else {
    $dbExist = 0
    Write-Host 'Database' $dbName 'missing' -ForegroundColor Yellow
}

$query = "select count(*) from sys.syslogins where name = 'CORP\AP-$BU-" + $applicationName + "-SQLdbOwner'"
$QueryResult = Invoke-Sqlcmd -ServerInstance $serverName -Query $query
$d = $QueryResult.Column1
$d = $d -as [int]

if ($d -gt 0) {
    $loginExist = 1
    Write-Host CORP\AP-$BU-$applicationName-SQLdbOwner exist on server -ForegroundColor Green
}
else {
    $loginExist = 0
    Write-Host CORP\AP-$BU-$applicationName-SQLdbOwner missing on server -ForegroundColor Yellow
}

if ($dbExist -eq 1) {
    $query = "use " + $dbName + "; select count(*) from sysusers where name = 'CORP\AP-$BU-" + $applicationName + "-SQLdbOwner'"
    $QueryResult = Invoke-Sqlcmd -ServerInstance $serverName -Query $query
    $e = $QueryResult.Column1
    $e = $e -as [int]

    if ($e -gt 0) {
        $userExist = 1
        Write-Host CORP\AP-$BU-$applicationName-SQLdbOwner exist in database -ForegroundColor Green
    }
    else {
        $userExist = 0
        Write-Host CORP\AP-$BU-$applicationName-SQLdbOwner missing in database -ForegroundColor Yellow
    }
}

if ($dbExist -eq 1) {
    $query = "use " + $dbName + "; select count(*) from sysusers where name = 'appl" + $applicationName + "'"
    $QueryResult = Invoke-Sqlcmd -ServerInstance $serverName -Query $query
    $f = $QueryResult.Column1
    $f = $f -as [int]

    if ($f -gt 0) {
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
	Return ($template.Fields | Where {$_.DisplayName -eq $name}).Id
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
    
	if($tokenResult.Errors.Count -gt 0) {
        $msg = "Authentication Error: " +  $tokenResult.Errors[0]
        Return
    }
	
    $token = $tokenResult.Token
    $templateName = "RPC - SQL Server Account"
    $template = $proxy.GetSecretTemplates($token).SecretTemplates | Where {$_.Name -eq $templateName}
    
	if($template.id -eq $null) {
        $msg = "Error: Unable to find Secret Template " +  $templateName
        Return
    }
	
    #enter the domain for the AD account you are creating
    if( $accountUserName -eq $null) {
        $accountUserName = "New User"
    }
    
    #Password is set to null so will generate a new one based on settings on template
    $newPass = $null
    if($newPass -eq $null) {
        $secretFieldIdForPassword = (GetFieldId $template "Password")
        $newPass = $proxy.GeneratePassword($token, $secretFieldIdForPassword).GeneratedPassword
    }
    $genNote = "SQL login for " + $accountUserName
    $secretName = "appl" + $applicationName + " " + $serverName
    $secretItemFields = ((GetFieldId $template "Server"), (GetFieldId $template "Username"), (GetFieldId $template "Password"), (GetFieldId $template "Notes"))
    $secretItemValues=($serverName,"sa",$newPass, $genNote)
    $secretItemValues = ($serverName,"appl$applicationName",$newPass, $genNote)
    $folderId = 121;
        
    $addResult = $proxy.AddSecret($token, $template.Id, $secretName, $secretItemFields, $secretItemValues, $folderId)
    
	if($addResult.Errors.Count -gt 0) {
        Write-Host "Add Secret Error: " +  $addResult.Errors[0] -ForegroundColor Red
		$logInfo = "Add Secret Error: " +  $addResult.Errors[0]
		Return
    }
	
    else {
        $logInfo = "Successfully added Secret: " +  $addResult.Secret.Name + " (Secret Id:" + $addResult.Secret.Id + ")"
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
    
	if ($result1.Errors.length -gt 0){
        $result1.Errors[0]
        Return
    } 
    
	else {
        $token = $result1.Token
    }

    # search secrets with our searchterm (authenticate by passing in our token)
    $result2 = $proxy.SearchSecrets($token, $searchterm,$null,$null)
    
	if ($result2.Errors.length -gt 0){
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
    try{
        $result = Get-ADGroup -Identity $name
        #Write-Host "Ingen GA skapas"
    }
    catch
    {
        $desc = "GroupAdmin group for " + $applicationName
        New-ADGroup -Path $path -Name $name -GroupScope DomainLocal -GroupCategory Security -Description $desc
        Set-AdGroup -Identity $name -ManagedBy $name
        Add-ADGroupMember -Identity $name -Members $owner
        #Write-Host "GA skapad"
    }

    $name = "AP-" + $BU + "-" + $applicationName + "-SQLdbOwner"
    try{
        $result = Get-ADGroup -Identity $name
        #Write-Host "Ingen Grupp skapas"
    }
    catch
    {
        $desc = $applicationName + " - MSSQL - SQL dbOwner"
        $managedBy = "AP-" + $BU + "-" + $applicationName + "-GA"
        New-ADGroup -Path $path -Name $name -GroupScope DomainLocal -GroupCategory Security -Description $desc -ManagedBy $managedBy
        #Write-Host "Grupp skapad"
    }
}

######################### CALLS ##################################

if ($dbExist -eq 0) {
    Write-Host "Creating database $dbName"
    sqlcmd -S $serverName -v dbName = $dbName -i $scriptFile -m 1
}

if ($applExist -eq 0) {
    $secretPassword = Read-Host "Add PWD for Secret Server" -AsSecureString
    $applPassword = GetPasswordExistingSecret appl$applicationName
    if ($appllPassword -eq $null) {
        $applPassword = CreateNewSecret $applicationName
        if ($applPassword -eq $null) {
            echo "Connection to secret failed"
		    Write-Host "Connection to secret failed (Serviceaccont-creation)"
		    exit
	    }
        $applKonto = "appl" + $applicationName
        Write-Host "Creating account appl$applicationName"
        sqlcmd -S $serverName -v dbName = $dbName -v applKonto = $applKonto -v passWord = $applPassword  -i AddSQLLogin.sql -m 1
        if ($sqlUserExist -eq 0) {
            sqlcmd -S $serverName -v dbName = $dbName -v applKonto = $applKonto -i AddSQLUser.sql -m 1
        }
    }
}
else {
    $applKonto = "appl" + $applicationName
    if ($sqlUserExist -eq 0) {
        sqlcmd -S $serverName -v dbName = $dbName -v applKonto = $applKonto -i AddSQLUser.sql -m 1
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
    sqlcmd -S $serverName -v dbName = $dbName -v BU = $BU -v applicationName = $applicationName -i AddADGroupLogin.sql -m 1
}
if ($userExist -eq 0) {
    Write-Host "Creating AD-group $groupName (user) on the server"
    sqlcmd -S $serverName -v dbName = $dbName -v BU = $BU -v applicationName = $applicationName -i AddADGroupUser.sql -m 1
}