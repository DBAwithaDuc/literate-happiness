<# new SQL Login.ps1 -dbName CustomerAdaptationTool_BR  -applicationName "CustomerAdaptationToolBR" -serverName "CORPDB10190.CORP.SAAB.SE,11433" 
    * Creates an SQL Login and maps it to a database 
    * It also creates add it to secret
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2019-02-19  
      Version 0.9


    Credit to Andreas Selguson for the Secret integration
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

# new SQL Login.ps1 -dbName CustomerAdaptationTool_BR  -applicationName "CustomerAdaptationToolBR" -serverName "CORPDB10190.CORP.SAAB.SE,11433" 


##################### Configuration ##############################
<# Collects variables from the console. either by prompted questions or i values is piped to the script #>



param(
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $serverName,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $dbName,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $applicationName
)


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



$applKonto = "appl" + $applicationName
$b = Get-DbaLogin -SqlInstance $sqlinstance -IncludeFilter $applKonto

if ($b -eq $true) {
    $applExist = 1
    Write-Host appl$applicationName exist -ForegroundColor Green
}
else {
    $applExist = 0
    Write-Host appl$applicationName missing -ForegroundColor Yellow
}

$c = Get-DbaDatabase -SqlInstance $sqlinstance -Database $dbName

if ($c -eq $true) {
    $dbExist = 1
    Write-Host 'Database' $dbName 'exist' -ForegroundColor Green
}
else {
    $dbExist = 0
    Write-Host 'Database' $dbName 'missing' -ForegroundColor Yellow
    Exit 
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
    $newPass = $null
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



if ($applExist -eq 0) {
    $secretPassword = Read-Host "Add PWD for Secret Server" -AsSecureString
    $applPassword = GetPasswordExistingSecret appl$applicationName
    if ($null -eq $appllPassword) {
        $applPassword = CreateNewSecret $applicationName
        if ($null -eq $applPassword) {
            Write-Output "Connection to secret failed"
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


######################### CALLS ##################################


if ($applExist -eq 0) {
    $secretPassword = Read-Host "Add PWD for Secret Server" -AsSecureString
    $applPassword = GetPasswordExistingSecret appl$applicationName
    if ($null -eq $appllPassword) {
        $applPassword = CreateNewSecret $applicationName
        if ($null -eq $appllPassword) {
            Write-Output "Connection to secret failed"
            Write-Host "Connection to secret failed (account-creation)"
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
<# Starts the Inverntory job on the target server #>
Write-Host 'Runs the Inventory SQL agent job'
Start-DbaAgentJob -SqlInstance $sqlinstance -job $job | Write-output

'Script is completed. Remember to verify permission on the database' | Write-output

