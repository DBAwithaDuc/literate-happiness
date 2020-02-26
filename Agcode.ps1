#Agcode.ps1


Function Wait-AvailabilityDatabaseSynchronization
{
    Param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()][array]$DatabaseCollection,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()][Microsoft.SqlServer.Management.Smo.SqlSmoObject]$SourceSqlSmoObject,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()][Microsoft.SqlServer.Management.Smo.SqlSmoObject]$TargetSqlSmoObject,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()][string]$SourceAvailabilityGroupName,
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()][string]$TargetAvailabilityGroupName,
        [parameter(Mandatory = $false)]
        [ValidateRange(1, 60)]
        [ValidateNotNullOrEmpty()][int]$StatusCheckFrequency = 1, # 1 second by default
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()][int]$StatusCheckTimeout = 60 # 600 seconds by default, per database
        
    )

    #get the AG object
    $sAvailabilityGroup = Get-AvailabilityGroups -SqlSmoObject $SourceSqlSmoObject | Where-Object {$_.Name -eq $SourceAvailabilityGroupName}
    $tAvailabilityGroup = Get-AvailabilityGroups -SqlSmoObject $TargetSqlSmoObject | Where-Object {$_.Name -eq $TargetAvailabilityGroupName}

    foreach ($db in $DatabaseCollection)
    {
        #while loop starts here
        $secondaryInSync = $false
        $passedTime = 0
    
        while ($secondaryInSync -eq $false)
        {
            
            #update the replica states for the current database for each of the replicas
            ($sAvailabilityGroup.DatabaseReplicaStates | Where-Object {$_.AvailabilityDatabaseName -eq $db.Name}).Refresh()
            ($tAvailabilityGroup.DatabaseReplicaStates | Where-Object {$_.AvailabilityDatabaseName -eq $db.Name}).Refresh()

            #get the primary and secondary availability database LastCommitLSN
            $pLastCommitLSN = ($sAvailabilityGroup.DatabaseReplicaStates | Where-Object {$_.AvailabilityDatabaseName -eq $db.Name -and $_.ReplicaRole -eq 'Primary'}).LastCommitLSN
            $sLastCommitLSN = ($tAvailabilityGroup.DatabaseReplicaStates | Where-Object {$_.AvailabilityDatabaseName -eq $db.Name -and $_.ReplicaRole -eq 'Secondary'}).LastCommitLSN

            if ($pLastCommitLSN -ne $sLastCommitLSN)
            {
                Write-Verbose -Message "$(Get-Date): Primary $($db.Name) LSN is $pLastCommitLSN" -Verbose
                Write-Warning -Message "$(Get-Date): Secondary $($db.Name) LSN is $sLastCommitLSN" -Verbose
                Start-Sleep -Seconds $StatusCheckFrequency
            }
            else
            {
                Write-Verbose -Message "$(Get-Date): Secondary $($db.Name) LSN is up to date with $sLastCommitLSN" -Verbose
                $secondaryInSync = $true
            }

            $passedTime ++
            if ($passedTime -gt $StatusCheckTimeout)
            {
                Write-Warning -Message "$(Get-Date): Timeout exceeded for $($db.Name) replication catchup" -Verbose
                $secondaryInSync = $true
            }
            

        }
        
    }
}


function Get-AvailabilityDatabaseHealth
{
    Param
    (
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()][Microsoft.SqlServer.Management.Smo.AvailabilityDatabase[]]$AvailabilityDatabaseCollection,
        [parameter(Mandatory = $false)]
        [ValidateSet('Synchronized', 'Synchronizing')]
        [ValidateNotNullOrEmpty()][string]$ValidateSynchronizationState = 'Synchronized',
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()][bool]$WaitOnSynchronizationState = $true,
        [parameter(Mandatory = $false)]
        [ValidateRange(1, 60)]
        [ValidateNotNullOrEmpty()][int]$StatusCheckFrequency = 5, # 5 seconds by default
        [parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()][int]$StatusCheckTimeout = 600 # 600 seconds by default, per database
    )

    $TimeoutDBs = @()
    foreach ($avDB in $AvailabilityDatabaseCollection)
    {
        $targetSyncState = $false
        $passedTime = 0

        while ($targetSyncState -eq $false)
        {
            $avDB.Refresh()
            if ($avDB.SynchronizationState -ne $ValidateSynchronizationState)
            {
                Write-Warning -Message "$(Get-Date): Database $($avDB.Name) is not $ValidateSynchronizationState" -Verbose
                #for now we identify the problem, but we should try to remediate this somehow
                Start-Sleep -Seconds $StatusCheckFrequency
            }
            else
            {
                Write-Verbose -Message "$(Get-Date): Database $($avDB.Name) is in $ValidateSynchronizationState state" -Verbose
                $targetSyncState = $true
            }
            $passedTime ++
            if ($passedTime -gt $StatusCheckTimeout)
            {
                Write-Warning -Message "$(Get-Date): Timeout exceeded for $($avDB.Name) replication catchup" -Verbose
                $TimeoutDBs += $avDB
                $targetSyncState = $true
            }
        }
    }
    if ($TimeoutDBs -ne '')
    {
        return $TimeoutDBs
    }
    else
    {
        return $null   
    }
}

