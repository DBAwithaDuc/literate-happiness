# ! Install-Module -Name AnyBox -RequiredVersion 0.3.0 -Scope CurrentUser -Force
# ! Install-Module -Name dbatools -Scope CurrentUser -Force
# ! Install-Module -Name SqlServer -Force
<# $Dest = $env:PSModulePath -split ';'
Copy-Item \\corp.saab.se\so\mgmt\L3_groups\L3_dbSQL\Applications\PowershellModules\* -Recurse -Destination $Dest[0] -Force
Import-Module dbatools -Force
Import-Module Anybox -Force #>

#Clear-Variable  -name Inputparams 
#Clear-Variable *
#Terminalerver to run CA checks and if needed mount CD from
$runServer = 'CORPTS6975'

#Other configuration
$sqlPortNumber = 11433
$sqlSVC = "CORP\ICT-SQL$applicationName"
$agSVC = "CORP\ICT-SQL$applicationName"
$isSVC = "CORP\ICT-SSIS$applicationName"
$asSVC = "CORP\ICT-SSAS$applicationName"
$Documents = [Environment]::GetFolderPath("MyDocuments")

#Ca server for CA querys
$CaServer = 'CORPDB9216.CORP.SAAB.SE,11433'

#Configuration for Secret API
$secretAccount = 'SVC-MSSQL-SECRET'
$secretBaseURL = 'https://secret.corp.saab.se/Secret/'
$secretURL = '/webservices/SSWebService.asmx'
$domainName = 'corp.saab.se'

$StdFeatures = "SQLENGINE"
$INSTALLSHAREDDIR = "D:\Microsoft SQL Server"
$INSTALLSHAREDWOWDIR = "D:\Microsoft SQL Server (x86)"
$INSTANCEDIR = "D:\Microsoft SQL Server"
$SQLTempDbLogFileGrowth = "512"
$ServerName = $env:COMPUTERNAME


$PromptChangeNr = New-AnyBoxPrompt  -Name 'ChangeNr' -Message 'Change Number'  -ShowSeparator 
$ChangeInput = Show-AnyBox @font  -MinWidth 500 -WindowStyle 'SingleBorderWindow' -Prompt $PromptChangeNr -Buttons  'Cancel', 'Ok'
if ($ChangeInput.Cancel -eq $True)
{
    Break
}
else
{
    $Change = $ChangeInput.ChangeNr
    $DescriptionQuery = @"
select description from dbo.chg where chg_ref_num = '$Change'
"@

    $Description = Invoke-Sqlcmd -ServerInstance $CaServer -Database mdb -Query $DescriptionQuery
    $Desc = $Description.Description -replace " - " , " :"  
    $Desc | Out-File $Documents\Desc.csv
    $Header = 'Desc', 'Value', 'Slask'
    $Desc2 = Import-Csv -path $Documents\Desc.csv -Delimiter  : -Header $Header
    $Collation = $Desc2 | Where-Object { $_.Desc -like "*Collation" } | Get-Unique 
    $Collation.Value
    $Application = $Desc2 | Where-Object { $_.Desc -eq "For Application" } 
    $Application.Value = $Application.Value -replace '\s+', ''
    # * $Version = $Desc2 | Where-Object { $_.Desc -like "*MS*SQL*" } 
    # * $SqlVerEdt = $Version.Value -split ' '
    $SqlVerEdt = $Desc2.Value -split ' ' -replace '\s+', ''
    $SqlVer = $SqlVerEdt | Select-String -Pattern '20*' 
    $SqlVer = $SqlVer[0] -replace '\s+', ''
    if ($SqlVerEdt | Select-String -Pattern 'Standard')
    {
        $SqlEdt = "Standard"
    }
    if ($SqlVerEdt | Select-String -Pattern 'Enterprise')
    {
        $SqlEdt = "Enterprise"
    }
    if ($SqlVerEdt | Select-String -Pattern 'Developer')
    {
        $SqlEdt = "Developer"
    }
    
    if ($SqlVer -eq "2017")
    {
        $SqlPath = "MSSQL14.MSSQLSERVER"
    }

    if ($SqlVer -eq "2016")
    {
        $SqlPath = "MSSQL13.MSSQLSERVER"
    }

    if ($SqlVer -eq "2019")
    {
        $SqlPath = "MSSQL15.MSSQLSERVER"
    } 



    $PromptServer = New-AnyBoxPrompt  -Name 'Server' -Message 'Server to install' -DefaultValue $ServerName -ShowSeparator
    $PromptInstance = New-AnyBoxPrompt  -Name 'Instance' -Message 'Instancename other than default'  -DefaultValue "MSSQLSERVER"  -ShowSeparator
    $PromptApplication = New-AnyBoxPrompt  -Name 'Application' -Message 'Application that will run on server'   -DefaultValue $Application.Value -ShowSeparator
    $PromptSiteName = New-AnyBoxPrompt  -Name 'SiteName' -Message 'Site Name' -DefaultValue "SE-LKP"  -ShowSeparator
    $PromptSecretPwd = New-AnyBoxPrompt  -Name 'SecretPwd' -Message 'Password Secret user' -InputType 'Password'  -ShowSeparator 
    $Initialinput = Show-AnyBox @font  -MinWidth 500 -WindowStyle 'SingleBorderWindow' -Prompt $PromptServer, $PromptInstance, $PromptSiteName, $PromptApplication, $PromptSecretPwd -Buttons  'Cancel', 'Ok'

    $changeNumber = $Initialinput.ChangeNr
    $applicationName = $Initialinput.Application
    $secretPassword = $Initialinput.SecretPwd 
    $sitename = $Initialinput.SiteName

    if ($Initialinput.Cancel -eq $True)
    {
        Break
    }

    else
    {
        [hashtable]$font = @{ FontFamily = 'Consola'; FontSize = 12 }
        $Getcollation = @"
SELECT distinct [collation]
  FROM [tbldatabases]
  where collation <> ''
  order by collation asc
"@
        $Collationlist = Invoke-Sqlcmd -ServerInstance 'corpdb4804.corp.saab.se,11433' -Database SQLDrift -Query $Getcollation
        $Promptcollation = New-AnyBoxPrompt -Tab '1.Main' -Name 'Collation' -Message 'Choose collation' -ValidateSet $($Collationlist.collation) -DefaultValue $Collation.Value -ShowSeparator
        $PromptInstance = New-AnyBoxPrompt -Tab '1.Main' -Name 'InstanceName' -Message 'Set instancename ' -DefaultValue 'MSSQLSERVER' -ShowSeparator
        $PromptVersion = New-AnyBoxPrompt -Tab '1.Main' -Name 'Version' -Message 'Choose Version' -ValidateSet @('2019', '2017', '2016') -DefaultValue $SqlVer
        $PromptEdition = New-AnyBoxPrompt -Tab '1.Main' -Name 'Edition' -Message 'Choose edition' -ValidateSet @('Standard', 'Enterprise', 'Developer') -DefaultValue $SqlEdt -ShowSeparator
        $PromptSecurity = New-AnyBoxPrompt -Tab '1.Main' -Name 'Security' -Message 'Set Mixed (SQL) or Windows authentication' -ValidateSet @('SQL', 'WIN')  -DefaultValue 'SQL'
        $PromptPort = New-AnyBoxPrompt -Tab '1.Main' -Name 'Port' -Message 'Set portnumber'  -DefaultValue '11433' -ShowSeparator
        $PromptSSAS = New-AnyBoxPrompt -Tab '2.Features' -Name 'SSASFeatures' -Inputtype 'Checkbox' -Message 'SSAS' 
        $PromptSSIS = New-AnyBoxPrompt -Tab '2.Features'  -Name 'SSISFeatures' -Inputtype 'Checkbox' -Message 'SSIS' 
        $PromptSSRS = New-AnyBoxPrompt -Tab '2.Features'  -Name 'SSRSFeatures' -Inputtype 'Checkbox' -Message 'SSRS' 
        $PromptFT = New-AnyBoxPrompt -Tab '2.Features'  -Name 'FTFeatures' -Inputtype 'Checkbox' -Message 'Fulltext Search' 
        $PromptInstant = New-AnyBoxPrompt -Tab '2.Features'  -Name 'Instant' -Inputtype 'Checkbox' -Message 'Grant Perform Volume Maintenance' 
        $PromptTempdbDataPath = New-AnyBoxPrompt -Tab '3. Paths' -Name 'TempDbData' -Message 'Tempdb default datafile path' -DefaultValue "G:\Microsoft SQL Server\$($SqlPath)\MSSQL\Data"
        $PromptTempdbLogPath = New-AnyBoxPrompt -Tab '3. Paths' -Name 'TempDbLog' -Message 'Tempdb default logfile path' -DefaultValue "G:\Microsoft SQL Server\$($SqlPath)\MSSQL\Log"
        $PromptDbDataPath = New-AnyBoxPrompt -Tab '3. Paths' -Name 'DbData' -Message 'Default datafile path' -DefaultValue "E:\Microsoft SQL Server\$($SqlPath)\MSSQL\Data"
        $PromptDbLogPath = New-AnyBoxPrompt -Tab '3. Paths' -Name 'DbLog' -Message 'Default logfile path' -DefaultValue "F:\Microsoft SQL Server\$($SqlPath)\MSSQL\\Log"
        $PromptDbBckPath = New-AnyBoxPrompt -Tab '3. Paths' -Name 'DbBck' -Message 'Default backup path' -DefaultValue "E:\Microsoft SQL Server\$($SqlPath)\MSSQL\Backup"
        $PromptQs = New-AnyBoxPrompt -Tab '1.Main' -Name 'QS' -Message 'Quiet Simple' -Inputtype 'Checkbox' 
        $PromptQ = New-AnyBoxPrompt -Tab '1.Main' -Name 'Q' -Message 'Quiet' -Inputtype 'Checkbox' 

        $Inputparams = Show-AnyBox @font  -MinWidth 500 -WindowStyle 'SingleBorderWindow' -Prompt $Promptcollation, $PromptInstance, $PromptVersion, $PromptSecurity, $PromptEdition, $PromptPort, $PromptSSAS, $PromptSSIS, $PromptSSRS, $PromptTempdbDataPath, $PromptTempdbLogPath, $PromptDbDataPath, $PromptDbLogPath, $PromptDbBckPath, $PromptQs, $PromptQ, $PromptFT, $PromptInstant  -Buttons 'Cancel', 'Ok' 
    }
    if ($Inputparams.Cancel -eq $True)
    {
        Break 
    } 
    if ($Inputparams.QS -eq $True)
    {
        $Quiet = "Qs"
    }
    if ($Inputparams.Q -eq $True)
    {
        $Quiet = "Q"
    }

    if ($Inputparams.Version -eq '2017' )
    {
        $Updatesource = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2017"
        $SqlPath = "MSSQL14.MSSQLSERVER"
        if ($Inputparams.Edition -eq 'Standard')
        {
            $ImagePath = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2017\SQL Server 2017 Standard Edition - Per Core\SW_DVD9_NTRL_SQL_Svr_Standard_Edtn_2017_64Bit_English_OEM_VL_X21-56945.ISO"
        }
        if ($Inputparams.Edition -eq 'Enterprise')
        {
            $ImagePath = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2017\SQL Server 2017 Enterprise Edition - Per Core\SW_DVD9_NTRL_SQL_Svr_Ent_Core_2017_64Bit_English_OEM_VL_X21-56995.ISO"
        }
        if ($Inputparams.Edition -eq 'Developer')
        {
            $ImagePath = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2017\SQL Server 2017 Developer Edition\SQLServer2017-x64-ENU-Dev.iso"
        }
    }
    elseif ( $Inputparams.Version -eq '2016')
    {
        $Updatesource = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2016"
        $SqlPath = "MSSQL13.MSSQLSERVER"
        if ($Inputparams.Edition -eq 'Standard')
        {
            $ImagePath = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2016\SQL Server 2016 Standard Edition - Per Core\SW_DVD9_NTRL_SQL_Svr_Standard_Edtn_2016_64Bit_English_OEM_VL_X20-97264.ISO"
        }
        if ($Inputparams.Edition -eq 'Enterprise')
        {
            $ImagePath = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2016\SQL Server 2016 Enterprise Edition - Per Core\SW_DVD9_NTRL_SQL_Svr_Ent_Core_2016_64Bit_English_OEM_VL_X20-97253.ISO"
        }
        if ($Inputparams.Edition -eq 'Developer')
        {
            $ImagePath = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2016\SQL Server 2016 Developer with Service Pack 1 (x64) - DVD (English)\en_sql_server_2016_developer_with_service_pack_1_x64_dvd_9548071.iso"
        }
    }
    elseif ( $Inputparams.Version -eq '2019')
    {
        $Updatesource = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2019"
        $SqlPath = "MSSQL15.MSSQLSERVER"
        if ($Inputparams.Edition -eq 'Standard')
        {
            $ImagePath = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2017\SQL Server 2017 Standard Edition - Per Core\SW_DVD9_NTRL_SQL_Svr_Standard_Edtn_2017_64Bit_English_OEM_VL_X21-56945.ISO"
        }
        if ($Inputparams.Edition -eq 'Enterprise')
        {
            $ImagePath = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2017\SQL Server 2017 Enterprise Edition - Per Core\SW_DVD9_NTRL_SQL_Svr_Ent_Core_2017_64Bit_English_OEM_VL_X21-56995.ISO"
        }
        if ($Inputparams.Edition -eq 'Developer')
        {
            $ImagePath = "\\corp.saab.se\so\iso\microsoft\lkp\MS SQL Server\SQL2017\SQL Server 2017 Developer Edition\SQLServer2017-x64-ENU-Dev.iso"
        }
    }

    # * Mount correct ISO for installation
    Mount-DiskImage $ImagePath
    $Setuppath = (Get-DiskImage $ImagePath | Get-Volume).DriveLetter + ":\setup.exe" 

    if ($Inputparams.Instant -eq $True)
    {
        $Instant = "True" 
    }

    if ($Inputparams.Security -eq 'WIN')
    {
        $Security = $null
    }
    else
    {
        $Security = 'SQL'
    }

    if ($Inputparams.SSRSFeatures -eq $True -or $Inputparams.SSISFeatures -eq $True -or $Inputparams.SSASFeatures -eq $True -or $Inputparams.FTFeatures -eq $True )
    {
        if ($Inputparams.SSRSFeatures -eq $True)
        {
            $SSRS = "RS"
        }
        elseif ($Inputparams.SSISFeatures -eq $True)
        {
            $SSIS = "IS"
        }
        elseif ($Inputparams.SSASFeatures -eq $True)
        {
            $SSAS = "AS"
        }
        elseif ($Inputparams.FTFeatures -eq $True)
        {
            $Fulltext = "FullText"
        }
        $Features = $StdFeatures + ',' + $SSRS + ',' + $SSAS + ',' + $SSIS + ',' + $Fulltext
    }
    else
    {
        $Features = $StdFeatures
    }

    # * Set tempdb files and Size

    $CPUresults = Get-WmiObject -ComputerName $Initialinput.Server  -class Win32_processor | Select-Object NumberOfCores
    $NumberOfCores = $CPUresults.NumberOfCores	
    $Drive = $Inputparams.TempDbData.Split('\')[0]
    $wql = "select Driveletter,Capacity from win32_volume where Driveletter = '$Drive'" #'C:'"
    $Size = Get-WmiObject -ComputerName $Initialinput.Server  -Query $wql | Select-Object Capacity
    $TempDbTotFiles = $NumberOfCores + 1
    $Filesize = [math]::FLOOR($Size.capacity / 1Mb / $($TempDbTotFiles) - 200)
    $SQLTempDbFileCount = $NumberOfCores      
    $SQLTempDbFileSize = $Filesize
    $SQLTempDbLogFileSize = $Filesize


    Import-Module ServerManager

    function CheckHeadTypeinCA
    {
        Param([string]$changeNumber)
        $number = $null
        $sqlQuery = 'use mdb; select count(*) from dbo.chg where chg_ref_num = ''' + $changeNumber + ''' and summary like ''%application server%'';'
        $scriptString = "{Invoke-Sqlcmd -Query """ + $sqlQuery + """ -ServerInstance """ + $caServer + """ | select -expand Column1}"
        $script = [ScriptBlock]::Create($scriptstring)
        $number = Invoke-Command -ScriptBlock { Invoke-Sqlcmd -Query $($args[0]) -ServerInstance $($args[1]) | select -expand Column1 } -ComputerName $runServer -ArgumentList $sqlQuery, $caServer
        Return $number
    }

    function CheckTypeinCA
    {
        Param([string]$changeNumber)
        $result = $null
        $sqlQuery = 'use mdb; DECLARE @st1 nvarchar(max), @st2 nvarchar(max), @len int; SET @st1 =  (select description from chg where chg_ref_num = ''' + $changeNumber + '''); SET @st2 = (SELECT SUBSTRING(@st1, CHARINDEX(''SQL Type:'', @st1)  + 10, LEN(@st1))); SELECT SUBSTRING(@st2,0, CHARINDEX('' '', @st2)  -3);'
        $scriptString = "{Invoke-Sqlcmd -Query """ + $sqlQuery + """ -ServerInstance """ + $caServer + """ | select -expand Column1}"
        $script = [ScriptBlock]::Create($scriptstring)
        $result = Invoke-Command -ScriptBlock { Invoke-Sqlcmd -Query $($args[0]) -ServerInstance $($args[1]) | select -expand Column1 } -ComputerName $runServer -ArgumentList $sqlQuery, $caServer
        Return $result
    }

    function CheckCIinCA
    {
        Param([string]$changeNumber)
        $result = $null
        $sqlQuery = 'use mdb; select has_CI from dbo.chg where chg_ref_num = ''' + $changeNumber + ''';'
        $scriptString = "{Invoke-Sqlcmd -Query """ + $sqlQuery + """ -ServerInstance """ + $caServer + """ | select -expand Column1}"
        $script = [ScriptBlock]::Create($scriptstring)
        $result = Invoke-Command -ScriptBlock { Invoke-Sqlcmd -Query $($args[0]) -ServerInstance $($args[1]) | select -expand has_CI } -ComputerName $runServer -ArgumentList $sqlQuery, $caServer
        Return $result
    }
    <#
#Start with manual checks
Write-Host "Current name: " $env:COMPUTERNAME -ForegroundColor Yellow
$logInfo = "Current name: " + $env:COMPUTERNAME

$applicationServerValue = CheckHeadTypeinCA $changeNumber
if ($applicationServerValue -eq 1)
{
    $logInfo = "Seems like the server is ordered as Applicationserver, the server name is: " + $env:COMPUTERNAME + " seems correct?"
    Write-Host $logInfo
}
$sqlType = CheckTypeinCA $changeNumber
$sqlType = "SQLType: " + $sqlType
Write-Host $sqlType
Write-Host "Check how you should install the server after “SQL Type:”. If that information is missing, return the change order to the person\group who has prepared the change order, and cancel this script" -ForegroundColor Yellow
pause
$hasCI = 1 #CheckCIinCA $changeNumber
if ($hasCI -eq 0)
{
    Write-Host "CI is missing, correct it before continue."
	
}
else
{
    Write-Host "CI is present."
	
}
#>
    #Query getting GPT formated disks
    $gptQ = get-disk | select PartitionStyle | where { $_.PartitionStyle -EQ 'GPT' }

    #Query getting blocksize for NTFS volumes with Label like SQL but not binary
    <#
$wmiQuery = "SELECT Name, Label, Blocksize FROM Win32_Volume WHERE FileSystem='NTFS' AND Label LIKE '%SQL%' AND Label <> 'SQL Binary'"
$blockResult = Get-WmiObject -Query $wmiQuery -ComputerName '.' | Sort-Object Name | Select-Object Name, Label, Blocksize
if ($env:COMPUTERNAME -like 'CORPAPPL*')
{
    $noDisks = 5
}
elseif ($env:COMPUTERNAME -like 'CORPDB*')
{
    $noDisks = 4
}
else
{
    Write-Host "Wrong computername?"
    exit
}

#Evaluate if there are at least 4 disks with GPT
if ($gptQ.Count -ge 4)
{
    logFunction "Disks format with GPT"
    Write-Host "Disks format with GPT" -ForegroundColor DarkGreen
}
else
{
    logFunction "Check GPT formating"
    Write-Host "Check GPT formating" -ForegroundColor Red
}

#Evaluate if blocksize is 64k
if ($blockResult.Blocksize -lt "65536")
{
    logFunction "Check Blocksize"
    Write-Host "Check Blocksize" -ForegroundColor Red
    exit
}
else
{
    logFunction "Blocksize is 65536/64k"
    Write-Host "Blocksize is 65536/64k" -ForegroundColor DarkGreen
}
#>
    #Evaluate if Site is (correct) configured in AD Sites and Services
    $site = nltest /dsgetsite 2>$null
    if ($LASTEXITCODE -eq 0 -and $site[0] -eq $siteName)
    {
        Write-Host $site[0] -ForegroundColor DarkGreen
	
    }
    elseif ($site.count -lt 1)
    {
        Write-Host "Siteconfiguration could not be found"
        Break # exit
    }
    else
    {
        Write-Host "Site is wrong (", $site[0], "), should be: ", $siteName -ForegroundColor Red
        Break # exit
    }

    #Checking version of ISO mounted
    #Helper Function
    function GetFieldId($template, [string]$name)
    {
        Return ($template.Fields | Where { $_.DisplayName -eq $name }).Id
    }

    function CreateNewSecret
    {
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
    
        if ($tokenResult.Errors.Count -gt 0)
        {
            $msg = "Authentication Error: " + $tokenResult.Errors[0]
            Return
        }
	
        $token = $tokenResult.Token
        $templateName = "RPC - Active Directory Account"
        $template = $proxy.GetSecretTemplates($token).SecretTemplates | Where { $_.Name -eq $templateName }
    
        if ($template.id -eq $null)
        {
            $msg = "Error: Unable to find Secret Template " + $templateName
            Return
        }
	
        #enter the domain for the AD account you are creating
        if ( $accountUserName -eq $null)
        {
            $accountUserName = "New User"
        }
    
        #Password is set to null so will generate a new one based on settings on template
        $newPass = $null
        if ($newPass -eq $null)
        {
            $secretFieldIdForPassword = (GetFieldId $template "Password")
            #$newPass = $proxy.GeneratePassword($token, $secretFieldIdForPassword).GeneratedPassword
            $randomObj = New-Object System.Random
            $NewPass = ""
            1..3 | ForEach { $NewPass = $NewPass + [char]$randomObj.next(65, 90) + [char]$randomObj.next(48, 57) + [char]$randomObj.next(97, 122) }
            1..3 | ForEach { $NewPass = $NewPass + [char]$randomObj.next(65, 90) + [char]$randomObj.next(60, 64) + [char]$randomObj.next(42, 43) + [char]$randomObj.next(48, 57) + [char]$randomObj.next(97, 122) }
            $NewPass
        }
        if ($module -eq "SQL")
        {
            $genNote = "MS" + $module + " Service Account for " + $accountUserName
        }
        else
        {
            $genNote = $module + " Service Account for " + $accountUserName
        }
        $secretName = "CORP\ICT-" + $module + $accountUserName
        $secretItemFields = ((GetFieldId $template "Domain"), (GetFieldId $template "Username"), (GetFieldId $template "Password"), (GetFieldId $template "Notes"))
        $secretItemValues = ($domain, "CORP\ICT-$module$accountUserName", $newPass, $genNote)
        $folderId = 121;
        
        $addResult = $proxy.AddSecret($token, $template.Id, $secretName, $secretItemFields, $secretItemValues, $folderId)
    
        if ($addResult.Errors.Count -gt 0)
        {
            Write-Host "Add Secret Error: " +  $addResult.Errors[0] -ForegroundColor Red
            $logInfo = "Add Secret Error: " + $addResult.Errors[0]
            Return
        }
	
        else
        {
            $logInfo = "Successfully added Secret: " + $addResult.Secret.Name + " (Secret Id:" + $addResult.Secret.Id + ")"
            Write-Host $logInfo -ForegroundColor Green
            Return $newPass
        }
    }

    function GetPasswordExistingSecret
    {
        param($searchterm)

        $domain = $domainName
        $baseUrl = $secretBaseURL
        $url = $baseUrl + $secretURL
        $username = $secretAccount
        $secretPassword = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($secretPassword)
        $secretPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($secretPassword)
        $password = $secretPassword
    
        $proxy = New-WebServiceProxy -uri $url -UseDefaultCredential
        Write-Output "Searching"
        # get a token for further use by authenticating using username/password
        $result1 = $proxy.Authenticate($username, $password, '', $domain)
    
        if ($result1.Errors.length -gt 0)
        {
            $result1.Errors[0]
            Return
        } 
    
        else
        {
            $token = $result1.Token
        }

        # search secrets with our searchterm (authenticate by passing in our token)
        $result2 = $proxy.SearchSecrets($token, $searchterm, $null, $null)
    
        if ($result2.Errors.length -gt 0)
        {
            $result2.Errors[0]
            Return
        }
        else
        {
            $secretObject = $proxy.GetSecret($token, $result2.SecretSummaries[0].SecretId, $false, $null)
            $secretObject.Secret.Items | foreach-object { if ($_.FieldName -eq "Password") { $pwd = $_.Value } }
            Return $pwd
        }
    }
   
    function CreateNewSA
    {
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
    
        if ($tokenResult.Errors.Count -gt 0)
        {
            $msg = "Authentication Error: " + $tokenResult.Errors[0]
            Return
        }
	
        $token = $tokenResult.Token
        $templateName = "RPC - DIR-C-060 SQL Server SA Account"
        $template = $proxy.GetSecretTemplates($token).SecretTemplates | Where { $_.Name -eq $templateName }
    
        if ($template.id -eq $null)
        {
            $msg = "Error: Unable to find Secret Template " + $templateName
            Return
        }
    
        if ( $accountUserName -eq $null)
        {
            $accountUserName = "New User"
        }
    
        #Password is set to null so will generate a new one based on settings on template
        $newPass = $null
    
        if ($newPass -eq $null)
        {
            $secretFieldIdForPassword = (GetFieldId $template "Password")
            #$newPass = $proxy.GeneratePassword($token, $secretFieldIdForPassword).GeneratedPassword
            $randomObj = New-Object System.Random
            $NewPass = ""
            1..12 | ForEach { $NewPassword = $NewPassword + [char]$randomObj.next(48, 57) + [char]$randomObj.next(65, 90) + [char]$randomObj.next(97, 122) }
        }
	
        $genNote = "SA account for MS SQL Server for " + $application
        $secretName = "sa " + $env:COMPUTERNAME + ".CORP.SAAB.SE,$sqlPortNumber"
        $serverName = $env:COMPUTERNAME + ".CORP.SAAB.SE,$sqlPortNumber"
        $secretItemFields = ((GetFieldId $template "Server"), (GetFieldId $template "Username"), (GetFieldId $template "Password"), (GetFieldId $template "Notes"))
        $secretItemValues = ($serverName, "sa", $newPass, $genNote)
        $folderId = 739;
        $addResult = $proxy.AddSecret($token, $template.Id, $secretName, $secretItemFields, $secretItemValues, $folderId)
    
        if ($addResult.Errors.Count -gt 0)
        {
            Write-Host "Add Secret Error: ", $addResult.Errors[0] -ForegroundColor Red
            $logInfo = "Add Secret Error: " + $addResult.Errors[0]
            #logFunction $logInfo
            Return
        }
	
        else
        {
            $logInfo = "Successfully added Secret: " + $addResult.Secret.Name + " (Secret Id:" + $addResult.Secret.Id + ")"
            Write-Host $logInfo -ForegroundColor Green
            logFunction $logInfo
            Return $newPass
        }
        Return $password = CreateNewSecret $applicationName
    }

    Add-WindowsFeature RSAT-AD-PowerShell
    import-module activedirectory

    function CreateAccount
    {
        param(
            [string]$module,
            [ref][string] $pass)
        try
        {
            Get-aduser ICT-$module$applicationName -ErrorAction Stop
            $logInfo = "ICT-$module$applicationName already exists, trying to get it from secret"
            write-host $logInfo
            $sqlPassword = GetPasswordExistingSecret ICT-$module$applicationName
            if ($sqlPassword -eq $null)
            {
                $logInfo = "Something went wrong with secretconnection or secret missing"
                Write-Host $logInfo
                exit
            }
            $pass.Value = $sqlPassword
        } 
        catch [Microsoft.ActiveDirectory.Management.ADIdentityNotFoundException]
        { 
            $sqlPassword = CreateNewSecret $applicationName
            if ($sqlPassword -eq $null)
            {
                echo "Connection to secret failed"
                Write-Host "Connection to secret failed (Serviceaccont-creation)"
                exit
            }
            else
            {
                $sName = "ICT-$module$applicationName"
                if ($sName.length > 19)
                {
                    New-ADUser -Name $sName.substring(0, 20) -GivenName "ICT-$module$applicationName" -DisplayName "ICT-$module$applicationName" -UserPrincipalName "ICT-$module$applicationName@corp.saab.se" -AccountPassword  (ConvertTo-SecureString $sqlPassword -AsPlainText -Force) -CannotChangePassword 1 -PasswordNeverExpires 1 -Description "$module Service Account for $applicationName" -Path "OU=MSSQL,OU=System Accounts,OU=SAAB-ICT,DC=corp,DC=saab,DC=se" -Enabled 1
                }
                else
                {
                    New-ADUser -Name $sName -GivenName "ICT-$module$applicationName" -DisplayName "ICT-$module$applicationName" -UserPrincipalName "ICT-$module$applicationName@corp.saab.se" -AccountPassword  (ConvertTo-SecureString $sqlPassword -AsPlainText -Force) -CannotChangePassword 1 -PasswordNeverExpires 1 -Description "$module Service Account for $applicationName" -Path "OU=MSSQL,OU=System Accounts,OU=SAAB-ICT,DC=corp,DC=saab,DC=se" -Enabled 1
                }
                Start-Sleep -s 15
                $u = get-aduser ICT-$module$applicationName
                $g = New-Object System.Guid "00000000-0000-0000-0000-000000000000"
                $self = [System.Security.Principal.NTAccount] 'NT AUTHORITY\SELF'
                $ADSI = [ADSI]"LDAP://$($u.DistinguishedName)"
                $ACE = New-Object System.DirectoryServices.ActiveDirectoryAccessRule($self, "Self, WriteProperty, GenericRead", "Allow", $g, "None")
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
    $agPassword = $sqlpass
    $saPassword = CreateNewSA $applicationName

    if ($saPassword -eq $null)
    {
        echo "Connection to secret failed"
        Write-Host "Connection to secret failed (SA-creation)"
        exit
    }

    $FileBody = '

; Other parameters
ACTION="Install"
SQLSVCINSTANTFILEINIT="' + $Instant + '"
USEMICROSOFTUPDATE="False"
SUPPRESSPRIVACYSTATEMENTNOTICE="False"
IACCEPTROPENLICENSETERMS="True"
IACCEPTSQLSERVERLICENSETERMS="True"
SQMREPORTING="False"
ERRORREPORTING="False"

SQLCOLLATION="' + $Inputparams.Collation + '"

TCPENABLED="1"
NPENABLED="0"
UPDATEENABLED="True"
UPDATESOURCE="' + $Updatesource + '"
ENU="True"
FEATURES="' + $Features + '"

; CM brick TCP communication port 
COMMFABRICPORT="0"
; How matrix will use private networks 
COMMFABRICNETWORKLEVEL="0"
; How inter brick communication will be protected 
COMMFABRICENCRYPTION="0"
; TCP port used by the CM brick 
MATRIXCMBRICKCOMMPORT="0"

; ------------------------------------------------------------------------------------------------------
; Directories and paths

; Default directory for the Database Engine backup files. 
SQLBACKUPDIR="' + $Inputparams.DbBck + '"

; Default directory for the Database Engine user databases. 
SQLUSERDBDIR="' + $Inputparams.DbData + '"

; Default directory for the Database Engine user database logs. 
SQLUSERDBLOGDIR="' + $Inputparams.DbLog + '"

; Directories for Database Engine TempDB files. 

SQLTEMPDBDIR="' + $Inputparams.TempDbData + '"
SQLTEMPDBLOGDIR="' + $Inputparams.TempDbLog + '"

INSTALLSHAREDDIR="' + $INSTALLSHAREDDIR + '"
INSTALLSHAREDWOWDIR="' + $INSTALLSHAREDWOWDIR + '"
INSTANCEDIR= "' + $INSTANCEDIR + '"

; ------------------------------------------------------------------------------------------------------
; Instance information

INSTANCENAME="' + $Initialinput.Instance + '"
INSTANCEID="' + $Initialinput.Instance + '"

; ------------------------------------------------------------------------------------------------------
; Tempdb files

SQLTEMPDBFILECOUNT="' + $SQLTempDbFileCount + '"
SQLTEMPDBFILESIZE="' + $SQLTempDbFileSize + '"
SQLTEMPDBFILEGROWTH="' + $SQLTempDbLogFileGrowth + '"
SQLTEMPDBLOGFILESIZE="' + $SQLTempDbLogFileSize + '"
SQLTEMPDBLOGFILEGROWTH="' + $SQLTempDbLogFileGrowth + '"

; ------------------------------------------------------------------------------------------------------
; Accounts

AGTSVCACCOUNT="' + $agSVC + '"
SQLSVCACCOUNT="' + $sqlSVC + '"
ADDCURRENTUSERASSQLADMIN="False"
SQLTELSVCACCT="NT Service\SQLTELEMETRY"
SQLSYSADMINACCOUNTS="CORP\SAAB-ICT-Admin-MSSQL"


; ------------------------------------------------------------------------------------------------------
; ServicesStartupConfigDescription 

SQLTELSVCSTARTUPTYPE="Automatic"
BROWSERSVCSTARTUPTYPE="Disabled"
SQLSVCSTARTUPTYPE="Automatic"
AGTSVCSTARTUPTYPE="Automatic"


; ------------------------------------------------------------------------------------------------------
; Security 

SECURITYMODE="' + $Security + '"



'

    if ($Inputparams.Ok -eq $True)
    {
        [System.Reflection.Assembly]::LoadWithPartialName("System.windows.forms") | Out-Null
 
        $OpenFileDialog = New-Object System.Windows.Forms.SaveFileDialog
        $OpenFileDialog.initialDirectory = "C:\Temp"
        $OpenFileDialog.filter = "All files (*.ini)| *.ini"
        $OpenFileDialog.FileName = "$($Initialinput.server)"
        $OpenFileDialog.DefaultExt = "ini"
        $OpenFileDialog.ShowDialog() | Out-Null
 
        $FileBody | Out-File $OpenFileDialog.filename

        $cmd = $Setuppath + " /ConfigurationFile=$($OpenFileDialog.filename) /SQLSVCPASSWORD= " + "$sqlpass" + " /AGTSVCPASSWORD= $agPassword /SAPWD= $saPassword  /$Quiet"
        Invoke-Expression $cmd | Write-Verbose
        Write-Output $cmd
  
    }
    $Connectionstring = $Initialinput.Server + '.' + $Domain + ',11433'
    Set-DbaTcpPort -SqlInstance $Connectionstring -Port $Initialinput.Port
}
<# UnInstall-Module -Name AnyBox -Force
UnInstall-Module -Name SqlServer -Force
Uninstall-Module -Name Dbatools -Force #>