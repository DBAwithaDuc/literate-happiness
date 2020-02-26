# ========================================================================================================
 Function GetDBUserInfo($Dbase)
 {
  if ($dbase.status -eq "Normal")  # ensures the DB is online before checking
   {$users = $Dbase.users | where {$_.login -eq $SQLLogin.name}   # Ignore the account running this as it is assumed to be an admin account on all servers
     foreach ($u in $users)
     {
       if ($u)
         {
           $DBRoles = $u.enumroles()
           foreach ($role in $DBRoles) {
           if ($role -eq "db_owner") {
           write-host $role "on"$Dbase.name -foregroundcolor "red"  #if db_owner set text color to red
           }
           else {
           write-host $role "on"$Dbase.name
           }
           }
         #Get any explicitily granted permissions
         foreach($perm in $Dbase.EnumObjectPermissions($u.Name)){
         write-host  $perm.permissionstate $perm.permissiontype "on" $perm.objectname "in" $DBase.name }
      }
    } # Next user in database
   }
   #else
   #Skip to next database.
 }
 #Main portion of script start
 [reflection.assembly]::LoadWithPartialName("Microsoft.SqlServer.Smo") | out-null  #ensure we have SQL SMO available
 foreach ($SQLsvr in get-content "C:\temp\Instances.txt")  # read the instance source file to get instance names
 {
   $svr = new-object ("Microsoft.SqlServer.Management.Smo.Server") $SQLsvr
   write-host "================================================================================="
   write-host "SQL Instance: " $svr.name
   write-host "SQL Version:" $svr.VersionString
   write-host "Edition:" $svr.Edition
   write-host "Login Mode:" $svr.LoginMode
   write-host "================================================================================="
   $SQLLogins = $svr.logins
   foreach ($SQLLogin in $SQLLogins)
   {
     write-host    "Login          : " $SQLLogin.name
     write-host    "Login Type     : " $SQLLogin.LoginType
     write-host    "Created        : " $SQLLogin.CreateDate
     write-host    "Default DB     : " $SQLLogin.DefaultDatabase
     Write-Host    "Disabled       : " $SQLLogin.IsDisabled
     $SQLRoles = $SQLLogin.ListMembers()
     if ($SQLRoles) {
     if ($SQLRoles -eq "SysAdmin"){ write-host    "Server Role    : " $SQLRoles -foregroundcolor "red"}
     else { write-host    "Server Role    : " $SQLRoles
     } } else {"Server Role    :  Public"}
      If ( $SQLLogin.LoginType -eq "WindowsGroup" ) {   #get individuals in any Windows domain groups
            write-host "Group Members:"
         try {
                $ADGRoupMembers = get-adgroupmember  $SQLLogin.name.Split("\")[1] -Recursive
                foreach($member in $ADGRoupMembers){
                write-host "   Account: " $member.name "("$member.SamAccountName")"
                                                    }
            }
            catch
            {
            #Sometimes there are 'ghost' groups left behind that are no longer in the domain, this highlights those still in SQL
                write-host "Unable to locate group "  $SQLLogin.name.Split("\")[1] " in the AD Domain" -foregroundcolor Red
            }
            }
        #Check the permissions in the DBs the Login is linked to.
     if ($SQLLogin.EnumDatabaseMappings())
       {write-host "Permissions:"
       foreach ( $DB in $svr.Databases)
         {
         GetDBUserInfo($DB)
         } # Next Database
       }
     Else
       {write-host "None."
       }
     write-host "   ----------------------------------------------------------------------------"
   } # Next Login
 } # Next Server