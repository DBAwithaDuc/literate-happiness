<# Create applaccount.ps1
.DESCRIPTION 
    * Creates an applaccount, add it to secret and maps it to a database
    * 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-05-07  
      Version 0.9


    Credit to Andreas Selguson for the Secret integration
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
$serverName = Read-Host "The server the appluser should be created on"
$dbName = Read-Host "The Database the user should be connected to"
$applicationName = Read-Host "The application the database is used for"


#################### Configuration ##############################

#Configuration for Secret API
$secretAccount = 'SVC-MSSQL-SECRET'
$secretBaseURL = 'https://secret.CORP.saab.se/Secret/'
$secretURL = '/webservices/SSWebService.asmx'
$domainName = 'CORP.saab.se'


################ Automatic configuration #########################


<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'

<# Convert server to instance #>
$Domain = "CORP.saab.se"
$sqlinstance  = $serverName + '.' + $Domain + ',11433'
$database = $dbName
$applKonto = "appl" + $applicationName
$role = 'Owner'
$sqlRole = "db_" + $role.ToLower()

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
    
	if($tokenResult.Errors.Count -gt 0) {
        $msg = "Authentication Error: " +  $tokenResult.Errors[0]
        Return
    }
	
    $token = $tokenResult.Token
    $templateName = "RPC - SQL Server Account"
    $template = $proxy.GetSecretTemplates($token).SecretTemplates | Where-Object {$_.Name -eq $templateName}
    
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


Function CheckforDB # Checks if a database exist on a server #
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

Function Checkforappl
{
    param ($sqlinstance, $applname
    )
    $present = Get-DbaLogin -SqlInstance $sqlinstance -Login $applname

if ($present) {$applexist = $true} 
else
{$applexist = $false}
Return $applexist

}

function DBuserexists {
    param ($sqlinstance, $database, $applname
          )
        $present =  Get-DbaDbUser -SqlInstance $sqlinstance -Database $database | Where-Object name -eq $applname
      
if ($present) {$sqlUserExist = $true} 
        else
        {$sqlUserExist = $false}
 Return $sqlUserExist

}
Function Set-DBPermission
{  param($sqlinstance, $database, $Name, $sqlRole )

$Query= 
"ALTER USER [$name] WITH DEFAULT_SCHEMA=[dbo]
 ALTER ROLE [$sqlrole] ADD MEMBER [$name]
GO"

Invoke-DbaQuery -SqlInstance $sqlinstance -Database $database -Query $Query
}



#################### Calls ##############

$Dbexist = CheckforDB -sqlinstance $sqlinstance -Database $database

IF ($Dbexist -eq $true) {Write-Host 'The database '$database 'exists'}
Else {Write-Host 'The database' $database' is missing'
exit 
}

$applexist = Checkforappl -sqlinstance $sqlinstance -applname $applKonto
Write-host "applexist" $applexist

$sqlUserExist = DBuserexists -sqlinstance $sqlinstance -database $database -applname $applKonto
Write-host "sqlUserExist" $sqlUserExist

If ($applexist -eq $true) {Write-Host appl$applicationName exist -ForegroundColor Green
}
else {if ($applexist -eq $false){
       Write-Host appl$applicationName missing -ForegroundColor Yellow}
}

$applPassword =""
if ($applExist -eq $False) {
    $secretPassword = Read-Host "Add PWD for Secret Server" -AsSecureString
    $applPassword = GetPasswordExistingSecret appl$applicationName
    Write-Output "Seaching in Secret"  $applPassword " end"
     IF(-not $applPassword) {
        $applPassword = CreateNewSecret $applicationName
        Write-Output "Creating Secret" $applPassword
        if (-not $applPassword) {
            Write-Output "Connection to secret failed"
		    Write-Host "Connection to secret failed (Serviceaccont-creation)"
		    
	    }
        $applKonto = "appl" + $applicationName
        Write-Host "Creating account appl$applicationName"
        $appPassword = (ConvertTo-SecureString -AsPlainText $applPassword -Force)
        New-DbaLogin -SqlInstance $sqlinstance -Login $applKonto -SecurePassword $appPassword -Verbose
        #sqlcmd -S $serverName -v dbName = $dbName -v applKonto = $applKonto -v passWord = $applPassword  -i AddSQLLogin.sql -m 1
        if ($sqlUserExist -eq $false) {
            New-DbaDbUser -SqlInstance $sqlinstance -Database $database -Login $applKonto
            Set-DBPermission -sqlinstance $sqlinstance -database $database -Name $applKonto -sqlRole $sqlRole
            # sqlcmd -S $serverName -v dbName = $dbName -v applKonto = $applKonto -i AddSQLUser.sql -m 1
        }
    }
}
else {
    $applKonto = "appl" + $applicationName
    if ($sqlUserExist -eq $false) {
        New-DbaDbUser -SqlInstance $sqlinstance -Database $database -Login $applKonto
        Set-DBPermission -sqlinstance $sqlinstance -database $database -Name $applKonto -sqlRole $sqlRole
         }
}

#Start-DbaAgentJob -SqlInstance $sqlinstance -Job $job
Write-Host "Script completed"

#$Password = (ConvertTo-SecureString -AsPlainText $pass -Force)

#$null -eq $accountUserName
$test=""
if(-not $test){Write-Output "tomt "}