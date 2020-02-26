# Define parameters
Param(
[string]$siteName,
[int]$targetBuild,
[string]$updateSource,
[string]$configurationFile,
[string]$sqlCollation,
[string]$applicationName,
[string]$changeNumber,
[bool]$ssis,
[bool]$ssas)

#########################################################################################################################################################################################################

### Variables ###

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

#Build/ISO configuration
if ($targetBuild -eq 4001) {
	$isoFile = "[iso] microsoft/MS SQL Server/SQL2016/SQL Server 2016 Standard Edition with SP1 - Per Core\SW_DVD9_NTRL_SQL_Svr_Standard_Edtn_2016w_SP1_64Bit_English_OEM_VL_X21-22231.ISO"
}
elseif ($targetBuild -eq 5000) {
	$isoFile = "[iso] microsoft/MS SQL Server/SQL2014/SQL Server 2014 Standard Edition with SP2 - Per Core\SW_DVD9_SQL_Svr_Standard_Edtn_2014w_SP2_64Bit_English_MLF_X21-04422.ISO"
}
elseif ($targetBuild -eq 1000) {
	$isoFile = "[iso] microsoft/MS SQL Server/SQL2017/SQL Server 2017 Standard Edition - Per Core\SW_DVD9_NTRL_SQL_Svr_Standard_Edtn_2017_64Bit_English_OEM_VL_X21-56945.ISO"
}
elseif ($targetBuild -eq 5026) {
	$isoFile = "[iso] microsoft/MS SQL Server/SQL2016/SQL Server 2016 Standard Edition with SP2 - Per Core/SW_DVD9_NTRL_SQL_Svr_Standard_Edtn_2016w_SP2_64Bit_English_OEM_VL_X21-59522.ISO"
}

#########################################################################################################################################################################################################

Import-Module ServerManager

$fileName = "CustomSqllog-$(Get-Date -f yyyyMMdd-hhmm).log"
function logFunction($string) {
    Write-Output $string | Out-File -FilePath $fileName -Append
}

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

#Query getting GPT formated disks
$gptQ = get-disk | select PartitionStyle | where {$_.PartitionStyle -EQ 'GPT'}

#Query getting blocksize for NTFS volumes with Label like SQL but not binary
$wmiQuery = "SELECT Name, Label, Blocksize FROM Win32_Volume WHERE FileSystem='NTFS' AND Label LIKE '%SQL%' AND Label <> 'SQL Binary'"
$blockResult = Get-WmiObject -Query $wmiQuery -ComputerName '.' | Sort-Object Name | Select-Object Name, Label, Blocksize
if ($env:COMPUTERNAME -like 'CORPAPPL*') {
    $noDisks = 5
}
elseif ($env:COMPUTERNAME -like 'CORPDB*') {
    $noDisks = 4
}
else {
    Write-Host "Wrong computername?"
    exit
}

#Evaluate if there are at least 4 disks with GPT
if ($gptQ.Count -ge 4) {
	logFunction "Disks format with GPT"
	Write-Host "Disks format with GPT" -ForegroundColor DarkGreen
}
else {
	logFunction "Check GPT formating"
	Write-Host "Check GPT formating" -ForegroundColor Red
}

#Evaluate if blocksize is 64k
if ($blockResult.Blocksize -lt "65536") {
    logFunction "Check Blocksize"
	Write-Host "Check Blocksize" -ForegroundColor Red
	exit
}
else {
    logFunction "Blocksize is 65536/64k"
	Write-Host "Blocksize is 65536/64k" -ForegroundColor DarkGreen
}

#Evaluate if Site is (correct) configured in AD Sites and Services
$site = nltest /dsgetsite 2>$null
if($LASTEXITCODE -eq 0 -and $site[0] -eq $siteName){
	Write-Host $site[0] -ForegroundColor DarkGreen
	$logInfo = "Correct siteconfiguration (" + $site[0] + ")"
	logFunction $logInfo
}
elseif ($site.count -lt 1) {
   logFunction "Siteconfiguration could not be found"
   Write-Host "Siteconfiguration could not be found"
   exit
}
else {
   $logInfo = "Site is wrong (" + $site[0] + ") + should be: ",$siteName
   logFunction $logInfo
   Write-Host "Site is wrong (",$site[0],"), should be: ",$siteName -ForegroundColor Red
   exit
}

#Checking version of ISO mounted
$cd = Get-WMIObject -Class Win32_CDROMDrive -ComputerName $env:COMPUTERNAME -ErrorAction Stop
$versionMajor
foreach ($i in $cd.Drive)
{
    $version = (Get-Command $i\setup.exe).Version 2> $null
    if ($version.Build -eq $targetBuild -and $version.Major -eq "13")
    {
		$versionMajor = $version.Major
        $version = "SQL 2016 SP1"
        break
    }
    elseif ($version.Build -eq $targetBuild -and $version.Major -eq "12")
    {
		$versionMajor = $version.Major
        $version = "SQL 2014 SP2"
        break
    }
    elseif ($version.Build -eq $targetBuild -and $version.Major -eq "13")
    {
		$versionMajor = $version.Major
        $version = "SQL 2016 SP2"
        break
    }
    elseif ($version.Build -eq $targetBuild -and $version.Major -eq "14")
    {
		$versionMajor = $version.Major
        $version = "SQL 2017 RTM"
        break
    }
    else
    {
      	Write-Host "Wrong ISO is mounted" -ForegroundColor Red
		$version = "unknown"
    }
}
if ($version -eq "unknown")
{
	Write-Host "trying to mount correct ISO" -ForegroundColor Blue
	logFunction "Wrong ISO is mounted, trying to mount"
	Invoke-Command -ScriptBlock {Add-PSSnapin VMware.VimAutomation.Core; Set-PowerCliConfiguration -InvalidCertificateAction Ignore -Confirm:$false; Connect-VIServer vcenter; get-cddrive -VM $($args[0]) | set-cddrive -IsoPath $($args[1]) -Connected $True -confirm:$false} -ComputerName $runServer -ArgumentList $env:COMPUTERNAME, $isoFile
}
logFunction $version

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

$updateSource = """$updateSource"""

#Starting Install including update

$installString1 = 'cmd /C Z:\setup.exe /ACTION=Install /UpdateSource='
$installString2 = ' /CONFIGURATIONFILE="'
$installString3 = '" /SAPWD="'
$installSTring4 = '" /SQLCOLLATION="'
$installSTring5 = '" /SQLSVCACCOUNT="'
$installSTring6 = '" /SQLSVCPASSWORD="'
$installSTring7 = '" /AGTSVCACCOUNT="'
$installSTring8 = '" /AGTSVCPASSWORD="'
$installSTring9 = '" /IACCEPTSQLSERVERLICENSETERMS '
$installSQL = $installString1 + $updateSource + $installString2 + $configurationFile + $installString3 + $saPassword + $installSTring4 + $sqlCollation + $installSTring5 + $sqlSVC + $installSTring6 + $sqlpass + $installSTring7 + $agSVC + $installSTring8 + $agPassword

if($ssis -eq 1){
	$installSTring10 = '" /ISSVCACCOUNT="'
	$installSTring11 = '" /ISSVCPASSWORD="'
	$installSQL = $installSQL + $installString10 + $isSVC + $installString11+ $ssispass 
}
if($ssas -eq 1){
	$installSTring12 = '" /ASSVCACCOUNT="'
	$installSTring13 = '" /ASSVCPASSWORD="'
	$installSQL = $installSQL + $installString12 + $asSVC + $installString13+ $ssaspass 
}

$installSQL = $installSQL + $installSTring9


Invoke-Expression -Command:$installSQL

#Copy Configfile

if ($versionMajor -eq 13) {
	cd 'C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\Log'
	cd ((gci 'C:\Program Files\Microsoft SQL Server\130\Setup Bootstrap\Log' | ? { $_.PSIsContainer } | sort CreationTime)[-1]).Name
	$confDestPath = '\\corp.saab.se\so\mgmt\L3_groups\L3_dbSQL\MSSQL Installation\ConfigurationFiles\' + $env:COMPUTERNAME + '-Standard 2016 - With no SSIS, SSAS, SSRS -ConfigurationFile.ini'
	copy .\ConfigurationFile.ini $confDestPath
	Write-Host "Copied 2016 conf file" -ForegroundColor Blue
}

elseif ($versionMajor -eq 12) {
	cd 'C:\Program Files\Microsoft SQL Server\120\Setup Bootstrap\Log'
	cd ((gci 'C:\Program Files\Microsoft SQL Server\120\Setup Bootstrap\Log' | ? { $_.PSIsContainer } | sort CreationTime)[-1]).Name
	$confDestPath = '\\corp.saab.se\so\mgmt\L3_groups\L3_dbSQL\MSSQL Installation\ConfigurationFiles\' + $env:COMPUTERNAME + '-Standard 2014 - With no SSIS, SSAS, SSRS -ConfigurationFile.ini'
	copy .\ConfigurationFile.ini $confDestPath
	Write-Host "Copied 2014 conf file" -ForegroundColor Blue
}

elseif ($versionMajor -eq 14) {
	cd 'C:\Program Files\Microsoft SQL Server\140\Setup Bootstrap\Log'
	cd ((gci 'C:\Program Files\Microsoft SQL Server\140\Setup Bootstrap\Log' | ? { $_.PSIsContainer } | sort CreationTime)[-1]).Name
	$confDestPath = '\\corp.saab.se\so\mgmt\L3_groups\L3_dbSQL\MSSQL Installation\ConfigurationFiles\' + $env:COMPUTERNAME + '-Standard 2017 - With no SSIS, SSAS, SSRS -ConfigurationFile.ini'
	copy .\ConfigurationFile.ini $confDestPath
	Write-Host "Copied 2017 conf file" -ForegroundColor Blue
}
else {
	Write-Host "No configuration file copied, do it manual" -ForegroundColor Red
	Write-Host $versionMajor
}


#Portconfig
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null

#Configuration of instance ports
$wmi = New-Object ("Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer")
$si = $wmi.ServerInstances["MSSQLSERVER"]
$tcp = $si.ServerProtocols["Tcp"]
Foreach ($1 in $tcp.IPAddresses)
{
    if ($1.Name -eq "IPALL") {
        $1.IPAddressProperties[1].Value="$sqlPortNumber"
        $Tcp.Alter()
    }
    else {
        $1.IPAddressProperties[4].Value="$sqlPortNumber"
        $Tcp.Alter()
    }

}
$logInfo = "Default port for SQL Instance changed to $sqlPortNumber"
logFunction $logInfo
Write-Host $logInfo

#Configure of 64bit Native client
$tcp_list = $wmi.ClientProtocols  | Where-Object {$_.displayname -eq "TCP/IP"}
$default_tcp = $tcp_list.ProtocolProperties | Where-Object {$_.Name -eq "Default Port"}
$default_tcp.value=$sqlPortNumber
$tcp_list.alter()
$logInfo = "Default port for 64bit SQL Native client changed to $sqlPortNumber"
logFunction $logInfo
Write-Host $logInfo

#Configure of 32bit Native client
$script ={param($p) [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | Out-Null
[reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.SqlWmiManagement") | Out-Null
$wmi = New-Object ("Microsoft.SqlServer.Management.Smo.Wmi.ManagedComputer")
$tcp_list = $wmi.ClientProtocols  | Where-Object {$_.displayname -eq "TCP/IP"}
$default_tcp = $tcp_list.ProtocolProperties | Where-Object {$_.Name -eq "Default Port"}
$default_tcp.value=$p
$tcp_list.alter()}
C:\windows\SysWOW64\WindowsPowerShell\v1.0\Powershell.exe -Command  $script -args $sqlPortNumber
$logInfo = "Default port for 32bit SQL Native client changed to $sqlPortNumber"
logFunction $logInfo
Write-Host $logInfo

#Restart of SQL Services
Stop-Service SQLSERVERAGENT
Stop-Service MSSQLSERVER
logFunction "Restart of SQL Service"
Write-Host "Restart of SQL Service"
Start-Service MSSQLSERVER
Start-Service SQLSERVERAGENT
logFunction "Restart of SQL Service finished"
Write-Host "Restart of SQL Service finished"

#Cleanup
Remove-WindowsFeature RSAT-AD-Powershell
