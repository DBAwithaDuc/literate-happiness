$titel = 'Testar Titel'
$message = 'message'




#$anybox = Show-AnyBox -Title $titel -Message 'Message' -prompt 'Query:' -CancelButton  -Buttons 'ok'

function CheckforDB
{
    param ($sqlinstance2, $Newdbname
    )
    

    Write-Host 'Checking if the database allready exist and the permissions should be recreated after the database coping'
    $present = Get-DbaDatabase -SqlInstance $sqlinstance2 -Database $Newdbname | Select-Object name
    $present

    if ($present) {$Exists = $true}

    if ($Exists -eq $true) { Write-host  "The database exist on the target"}
    Return.$Exists
}