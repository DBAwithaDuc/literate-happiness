<# Module Cleanup.ps1 #>
$currentVersion = Get-Module dbatools -ListAvailable | Select-Object -ExpandProperty Version
$newVersion = Find-Module dbatools | Select-Object -ExpandProperty Version

Write-Output "The currently installed version of dbatools is $currentVersion"
Write-Output "The latest version of dbatools in the PSGallery is $newVersion"

<#
    # check what latest version is in PSGallery, full results
    Find-Module dbatools
#>
<#
    # check what latest version is in PSGallery
    Find-Module dbatools | Select-Object Version, PublishedDate
#>

if ( $currentVersion -lt $newVersion ) {
    Write-Output "New version of dbatools detected...`nWARNING: Finding and killing all other instances of powershell.exe and powershell_ise.exe to prevent uninstall issues later due to being in-use. (This could impact Agent Jobs if run on a server)"

    Get-Process PowerShell* | Where-Object Id -NE $PID | ForEach-Object { Stop-Process -Confirm $_ }
    Write-Output "Now updating to $newVersion..."
    Get-Module dbatools | Remove-Module
    Update-Module dbatools

    Write-Output "Uninstalling old version $currentVersion"
    Uninstall-Module dbatools -RequiredVersion $currentVersion

    Write-Output "Update completed!"
    Write-Output "Recommended to exit this powershell.exe or powershell_ise.exe"
} else {
    Write-Output "No update needed."
}