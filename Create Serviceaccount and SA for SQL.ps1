#Create Serviceaccount and SA for SQL.ps1

# Define parameters
Param(
[string]$siteName,
[string]$applicationName,
[string]$changeNumber,
[bool]$ssis,
[bool]$ssas
)


#Terminalerver to run CA checks and if needed mount CD from
$runServer = 'CORPTS6975'

#Other configuration
$sqlPortNumber = 11433
$sqlSVC = "CORP\ICT-SQL$applicationName"
$agSVC = "CORP\ICT-SQL$applicationName"
$isSVC = "CORP\ICT-SSIS$applicationName"
$asSVC = "CORP\ICT-SSAS$applicationName"

#Ca server for CA querys
$caServer = 'CORPDB9216.CORP.SAAB.SE,11433'

#Configuration for Secret API
$secretAccount = 'SVC-MSSQL-SECRET'
$secretPassword = Read-Host "Add PWD for Secret Server" -AsSecureString
$secretBaseURL = 'https://secret.corp.saab.se/Secret/'
$secretURL = '/webservices/SSWebService.asmx'
$domainName = 'corp.saab.se'


################# Functions ######################



function CheckHeadTypeinCA {
	Param([string]$changeNumber)
    $number = $null
    $sqlQuery = 'use mdb; select count(*) from dbo.chg where chg_ref_num = ''' + $changeNumber + ''' and summary like ''%application server%'';'
    $scriptString = "{Invoke-Sqlcmd -Query """ + $sqlQuery + """ -ServerInstance """ + $caServer + """ | select -expand Column1}"
    $script = [ScriptBlock]::Create($scriptstring)
    $number = Invoke-Command -ScriptBlock {Invoke-Sqlcmd -Query $($args[0]) -ServerInstance $($args[1]) | select -expand Column1} -ComputerName $runServer -ArgumentList $sqlQuery, $caServer
    Return $number
}


function CheckTypeinCA {
	Param([string]$changeNumber)
    $result = $null
    $sqlQuery = 'use mdb; DECLARE @st1 nvarchar(max), @st2 nvarchar(max), @len int; SET @st1 =  (select description from chg where chg_ref_num = ''' + $changeNumber + '''); SET @st2 = (SELECT SUBSTRING(@st1, CHARINDEX(''SQL Type:'', @st1)  + 10, LEN(@st1))); SELECT SUBSTRING(@st2,0, CHARINDEX('' '', @st2)  -3);'
    $scriptString = "{Invoke-Sqlcmd -Query """ + $sqlQuery + """ -ServerInstance """ + $caServer + """ | select -expand Column1}"
    $script = [ScriptBlock]::Create($scriptstring)
    $result = Invoke-Command -ScriptBlock {Invoke-Sqlcmd -Query $($args[0]) -ServerInstance $($args[1]) | select -expand Column1} -ComputerName $runServer -ArgumentList $sqlQuery, $caServer
    Return $result
}

function CheckCIinCA {
	Param([string]$changeNumber)
    $result = $null
    $sqlQuery = 'use mdb; select has_CI from dbo.chg where chg_ref_num = ''' + $changeNumber + ''';'
    $scriptString = "{Invoke-Sqlcmd -Query """ + $sqlQuery + """ -ServerInstance """ + $caServer + """ | select -expand Column1}"
    $script = [ScriptBlock]::Create($scriptstring)
    $result = Invoke-Command -ScriptBlock {Invoke-Sqlcmd -Query $($args[0]) -ServerInstance $($args[1]) | select -expand has_CI} -ComputerName $runServer -ArgumentList $sqlQuery, $caServer
    Return $result
}




#Start with manual checks
Write-Host "Current name: " $env:COMPUTERNAME -ForegroundColor Yellow
$logInfo = "Current name: " +  $env:COMPUTERNAME
logFunction $logInfo
$applicationServerValue = CheckHeadTypeinCA $changeNumber
if ($applicationServerValue -eq 1) {
	$logInfo = "Seems like the server is ordered as Applicationserver, the server name is: " + $env:COMPUTERNAME + " seems correct?"
	Write-Host $logInfo
	pause
	logFunction "Pressed continue about correct servername"
}
$sqlType = CheckTypeinCA $changeNumber
$sqlType = "SQLType: " + $sqlType
Write-Host $sqlType
Write-Host "Check how you should install the server after “SQL Type:”. If that information is missing, return the change order to the person\group who has prepared the change order, and cancel this script" -ForegroundColor Yellow
pause
logFunction $sqlType
logFunction "Pressed continue about SQL type in CA ticket"
$hasCI = CheckCIinCA $changeNumber
if ($hasCI -eq 0) {
	$logInfo = "CI is missing, correct it before continue."
	Write-Host $logInfo -ForegroundColor Yellow
	logFunction $logInfo
}
else {
	$logInfo = "CI is present."
	logFunction $logInfo
}

#Helper Function
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
    $templateName = "RPC - Active Directory Account"
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
	if($module -eq "SQL"){
        $genNote = "MS" + $module + " Service Account for " + $accountUserName
    }
    else {
        $genNote = $module + " Service Account for " + $accountUserName
    }
    $secretName = "CORP\ICT-" + $module + $accountUserName
    $secretItemFields = ((GetFieldId $template "Domain"), (GetFieldId $template "Username"), (GetFieldId $template "Password"), (GetFieldId $template "Notes"))
    $secretItemValues=($domain,"CORP\ICT-$module$accountUserName",$newPass, $genNote)
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
   
function CreateNewSA {
	param($application)

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
    $templateName = "RPC - DIR-C-060 SQL Server SA Account"
    $template = $proxy.GetSecretTemplates($token).SecretTemplates | Where {$_.Name -eq $templateName}
    
	if($template.id -eq $null) {
        $msg = "Error: Unable to find Secret Template " +  $templateName
        Return
    }
    
	if( $accountUserName -eq $null) {
        $accountUserName = "New User"
    }
    
    #Password is set to null so will generate a new one based on settings on template
    $newPass = $null
    
	if($newPass -eq $null) {
        $secretFieldIdForPassword = (GetFieldId $template "Password")
        $newPass = $proxy.GeneratePassword($token, $secretFieldIdForPassword).GeneratedPassword
    }
	
    $genNote = "SA account for MS SQL Server for " + $application
    $secretName = "sa " + $env:COMPUTERNAME + ".CORP.SAAB.SE,$sqlPortNumber"
    $serverName = $env:COMPUTERNAME + ".CORP.SAAB.SE,$sqlPortNumber"
    $secretItemFields = ((GetFieldId $template "Server"), (GetFieldId $template "Username"), (GetFieldId $template "Password"), (GetFieldId $template "Notes"))
    $secretItemValues=($serverName,"sa",$newPass, $genNote)
    $folderId = 739;
    $addResult = $proxy.AddSecret($token, $template.Id, $secretName, $secretItemFields, $secretItemValues, $folderId)
    
	if($addResult.Errors.Count -gt 0) {
        Write-Host "Add Secret Error: ", $addResult.Errors[0] -ForegroundColor Red
		$logInfo = "Add Secret Error: " + $addResult.Errors[0]
		logFunction $logInfo
        Return
    }
	
    else {
        $logInfo = "Successfully added Secret: " + $addResult.Secret.Name + " (Secret Id:" + $addResult.Secret.Id + ")"
		Write-Host $logInfo -ForegroundColor Green
		logFunction $logInfo
        Return $newPass
    }
    Return $password = CreateNewSecret $applicationName
}

Add-WindowsFeature RSAT-AD-PowerShell
import-module activedirectory

function CreateAccount {
param(
[string]$module,
[ref][string] $pass)
	try {
		Get-aduser ICT-$module$applicationName -ErrorAction Stop
		$logInfo = "ICT-$module$applicationName already exists, trying to get it from secret"
		write-host $logInfo
		$sqlPassword = GetPasswordExistingSecret ICT-$module$applicationName
        	if ($sqlPassword -eq $null) {
			$logInfo = "Something went wrong with secretconnection or secret missing"
			Write-Host $logInfo
			exit
		}
		$pass.Value = $sqlPassword
	} 
	catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException] { 
		$sqlPassword = CreateNewSecret $applicationName
		if ($sqlPassword -eq $null) {
			echo "Connection to secret failed"
			Write-Host "Connection to secret failed (Serviceaccont-creation)"
			exit
		}
		else {
			$sName = "ICT-$module$applicationName"
			if ($sName.length > 19) {
				New-ADUser -Name $sName.substring(0,20) -GivenName "ICT-$module$applicationName" -DisplayName "ICT-$module$applicationName" -UserPrincipalName "ICT-$module$applicationName@corp.saab.se" -AccountPassword  (ConvertTo-SecureString $sqlPassword -AsPlainText -Force) -CannotChangePassword 1 -PasswordNeverExpires 1 -Description "$module Service Account for $applicationName" -Path "OU=MSSQL,OU=System Accounts,OU=SAAB-ICT,DC=corp,DC=saab,DC=se" -Enabled 1
			}
			else {
				New-ADUser -Name $sName -GivenName "ICT-$module$applicationName" -DisplayName "ICT-$module$applicationName" -UserPrincipalName "ICT-$module$applicationName@corp.saab.se" -AccountPassword  (ConvertTo-SecureString $sqlPassword -AsPlainText -Force) -CannotChangePassword 1 -PasswordNeverExpires 1 -Description "$module Service Account for $applicationName" -Path "OU=MSSQL,OU=System Accounts,OU=SAAB-ICT,DC=corp,DC=saab,DC=se" -Enabled 1
			}
			Start-Sleep -s 15
			$u = get-aduser ICT-$module$applicationName
			$g = New-Object System.Guid "00000000-0000-0000-0000-000000000000"
			$self = [System.Security.Principal.NTAccount] 'NT AUTHORITY\SELF'
			$ADSI = [ADSI]"LDAP://$($u.DistinguishedName)"
			$ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($self,"Self, WriteProperty, GenericRead","Allow",$g, "None")
			$ADSI.psbase.Options.SecurityMasks = [System.DirectoryServices.SecurityMasks]::Dacl
			$ADSI.psbase.ObjectSecurity.AddAccessRule($ACE)
			$ADSI.psbase.commitchanges() 
			Set-ADAccountControl ICT-$module$applicationName -TrustedForDelegation $true
		}
		$pass.Value = $sqlPassword
	}
}

$sqlpass = ""

CreateAccount "SQL" ([ref]$sqlpass)

if($ssas -eq 1){
	$ssaspass = ""
	CreateAccount "SSAS" ([ref]$ssaspass)
}

if($ssis -eq 1){
	$ssispass = ""
	CreateAccount "SSIS" ([ref]$ssispass)
}

if($ssrs -eq 1){
	$ssrspass = ""
	CreateAccount "SSRS" ([ref]$ssrspass)
}

$saPassword = CreateNewSA $applicationName

if ($saPassword -eq $null) {
	echo "Connection to secret failed"
	Write-Host "Connection to secret failed (SA-creation)"
	exit
}


$agPassword = $sqlpass
