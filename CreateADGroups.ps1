# .\CreateADGroups -applicationName "AndreasApp" -role "DataReader" -owner "u025753" -BU "CO" -serverName "CORPDB4044.CORP.SAAB.SE,11433" -dbName "AndreasDB" -environment "PROD"

#function CreateADGroup {
    param([string]$applicationName,
    [string]$role,
    [string]$owner,
    [string]$BU,
    [string]$dbName,
    [string]$serverName,
    [string]$environment = "none")

    ##################### Configuration ##############################

    $environmentOrg = $environment
    $gaName    = "AP-" + $BU + "-" + $applicationName + "-GA"
    $path = "OU=AP,OU=Groups,OU=Global,DC=corp,DC=saab,DC=se"
    $sqlRole = "db_" + $role.ToLower()
    $role = "SQLdb" + $role
    if ($environment -eq "none") {
        $name = "AP-" + $BU + "-" + $applicationName + "-" + $role
        $environment = ""
    }
    else {
        $environment = "-" + $environment
        $name = "AP-" + $BU + "-" + $applicationName + $environment + "-" + $role
    }

    ################ Automatic configuration #########################

    if ($role -ne "SQLdbbulkadmin") {
        $query = "use " + $dbName + "; select count(*) from sysusers where name = 'CORP\" + $name + "'" #'CORP\AP-CO-" + $applicationName + "-" + $role + "'"
        $QueryResult = Invoke-Sqlcmd -ServerInstance $serverName -Query $query
        $e = $QueryResult.Column1
        $e = $e -as [int]
        if ($e -gt 0) {
            $userExist = 1
            Write-Host CORP\$name exist in database -ForegroundColor Green #CORP\AP-CO-$applicationName-$role exist in database -ForegroundColor Green
        }
        else {
            $userExist = 0
            Write-Host CORP\$name missing in database -ForegroundColor Yellow #CORP\AP-CO-$applicationName-$role missing in database -ForegroundColor Yellow
        }
    }
    else {
        $role = "SQLbulkadmin"
        $userExist = 1
        
        if ($environmentOrg -eq "none") {
            $name = "AP-" + $BU + "-" + $applicationName + "-" + $role
            $environment = ""
        }
        else {
            $name = "AP-" + $BU + "-" + $applicationName + $environment + "-" + $role
            #$environment = "-" + $environment
        }
    }

    $query = "select count(*) from sys.syslogins where name = 'CORP\" + $name + "'" #AP-CO-" + $applicationName + "-" + $role + "'"
    $QueryResult = Invoke-Sqlcmd -ServerInstance $serverName -Query $query
    $d = $QueryResult.Column1
    $d = $d -as [int]
    
    if ($d -gt 0) {
        $loginExist = 1
        Write-Host CORP\$name exist on server -ForegroundColor Green #CORP\AP-CO-$applicationName-$role exist on server -ForegroundColor Green
    }
    else {
        $loginExist = 0
        Write-Host CORP\$name missing on server -ForegroundColor Yellow  #CORP\AP-CO-$applicationName-$role missing on server -ForegroundColor Yellow
    }
    #Write-Host $role
  
    ######################### CALLS ##################################

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

    #Write-Host $environment
    #pause
    
    
    try{
        $result = Get-ADGroup -Identity $name
        Write-Host "Ingen Grupp skapas"
    }
    catch
    {
        $desc = $applicationName + " - MSSQL - " + $sqlRole
        #$managedBy = "AP-" + $BU + "-" + $applicationName + "-GA"
        New-ADGroup -Path $path -Name $name -GroupScope DomainLocal -GroupCategory Security -Description $desc -ManagedBy $gaName
        Write-Host "Grupp skapad"
        Start-sleep -s 60
    }
    if ($loginExist -eq 0) {
        Write-Host "Creating AD-group $name (login) on the server"
        sqlcmd -S $serverName -v dbName = $dbName -v applicationName = $applicationName$environment -v BU = $BU -v role = $role -i AddADGroupLogin.sql -m 1
    }
    if ($userExist -eq 0) {
        Write-Host "Creating AD-group $name (user) in database"
        sqlcmd -S $serverName -v dbName = $dbName -v applicationName = $applicationName$environment -v BU = $BU -v role = $role -v sqlRole = $sqlRole -i AddADGroupUser.sql -m 1
    }
    if ($role -eq "SQLbulkadmin") {
        Write-Host "Assign Bulkadmin permssion"
        sqlcmd -S $serverName -v applicationName = $applicationName$environment -v BU = $BU -v role = $role -i AddBulkAdmin.sql -m 1
    }
#}