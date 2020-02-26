<#<# testing.ps1
 .DESCRIPTION 
    * 
   Created by: Mattias Gunnmo @DBAwithaDuc
   Modified: 2018-11-19  

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

param(
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Targetserver,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $database,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $application,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $Groupowner,
    [Parameter(Mandatory = $True, valueFromPipeline = $true)][String] $BU

    
)

<# Load the dbatoosl module #>
if (-not (Get-Module -Name dbatools)) {Import-module dbatools}

<# Sets name of the job to be runned when completed #>
$job = 'ITDrift - SQL Inventory to SQL Drift'

<# Convert server to instance #>
$sqlinstance = $Targetserver + ',11433'

#>


'Creating AD-groups' | Write-Output
& $scriptpath\CreateADGroups.ps1 -applicationName $application -role $role1 -owner $Groupowner -BU $BU -serverName $sqlinstance -dbName $database | write-output
& $scriptpath\CreateADGroups.ps1 -applicationName $application -role $role2 -owner $Groupowner -BU $BU -serverName $sqlinstance -dbName $database | write-output
& $scriptpath\CreateADGroups.ps1  -applicationName $application -role $role3 -owner $Groupowner -BU $BU -serverName $sqlinstance -dbName $database | write-output
