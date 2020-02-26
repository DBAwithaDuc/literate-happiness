# * Add new smtp server
$NewMailServer = "smtp.saabgroup.com"
# * Add old mailserver you want to replace
$OldMailServer = "oldsmtp.corp.saab.se"
# * Domain for servers that's going to change
$Domain = "corp.saab.se"

# * Query to get servers from SQLdrift which have DBMail and using old Mailserver
$GetServer = @"
        SELECT [tblmail_server].[servername] a,[tblSQLServer].[ServerName]
        FROM [SQLDrift].[dbo].[tblmail_server] 
        join [SQLDrift].[dbo].[tblSQLServer]
        on [tblmail_server].serverid = [tblSQLServer].serverid
        where [tblSQLServer].Discontinued = '0' and [tblmail_server].servername = '$OldMailServer'
"@

# * Runs the query to get mail servers
# $Servers = Invoke-Sqlcmd -ServerInstance 'corpdb4804.corp.saab.se,11433' -Query $GetServer -Database SQLDrift  
# * If you want to provide own list of servers
$Servers = "corpdb4044"

# * Loops through the servers
foreach ($Server in $Servers)
{
    # * Sets the connection string
    $Connectionstring = $Server + '.' + $Domain + ',11433'
    # * Gets the name of Mailaccounts
    $Mailaccounts = Get-DbaDbMailAccount -SqlInstance $Connectionstring
    # * Gets the mailconfig on the server
    $Mailconf = Get-DbaDbMailServer -sqlinstance $Connectionstring
    # * Loops throught the servers that has a mailconfig and using the oldmailserver
    # * Changes the mailserver
    foreach ($Mailaccount in $Mailaccounts.name)
    {
        # * the query that actually changes the mailserver
        $ChangeMail = @"
        EXECUTE msdb.dbo.sysmail_update_account_sp
        @account_name = [$Mailaccount]
        ,@mailserver_name = [$NewMailServer]
        ,@mailserver_type = 'SMTP'
"@ 

        if ($Mailconf.name -eq $OldMailServer)
        {
            Invoke-Sqlcmd -ServerInstance $Connectionstring -Query $ChangeMail
        }
        
    }
}

