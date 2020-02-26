# LabbSecret.ps1

################### Configuration ##############################

#Configuration for Secret API
$secretAccount = 'SVC-MSSQL-SECRET'
$secretBaseURL = 'https://secret.CORP.saab.se/Secret/'
$secretURL = '/webservices/SSWebService.asmx'
$domainName = 'CORP.saab.se'

$applicationName='Kardex'
$applKonto = "appl" + $applicationName
$serverName='corpdb4044'


### Create applaccount ##
<#function Create-applaccount {
    param ($sqlinstance,$database,$name,$appPassword)
    Write-Host "Creating account appl$applicationName"


    $appPassword = (ConvertTo-SecureString -AsPlainText $applPassword -Force)
    New-DbaLogin -SqlInstance $sqlinstance -Login $name -SecurePassword $appPassword
        
    )
    
}
#>

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




$applKonto = "appl" + $applicationName
 $secretPassword = Read-Host "Add PWD for Secret Server" -AsSecureString
 $applPassword = GetPasswordExistingSecret appl$applicationName
    Write-Output "Seaching in Secret"
$applPassword = GetPasswordExistingSecret appl$applicationName
If ($applPassword) { $secret=1 
    Write-host "account already exist"}
else {$secret=0 
    $applPassword = CreateNewSecret $applicationName }
$applKonto
$secret
$applPassword