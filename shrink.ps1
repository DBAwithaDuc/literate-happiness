# shrink.ps1
$databases = "UAT16_UsageAndHealth,UAT16_SaabNet_PortalContent,SISP_UAT16_MySiteContent,SISP_UAT16_TeamSites,UAT16Uniform_UsageAndHealth,SISP_UAT16_PortalContent_temp,SISP_UAT16_ACABContent"


Invoke-DbaDbShrink -SqlInstance 'CORPDB16398.CORP.SAAB.SE,11433' -Database $databases -FileType Log -PercentFreeSpace 20 -ShrinkMethod TruncateOnly -StepSize 250MB

Invoke-DbaDbShrink -SqlInstance 'CORPDB16398.CORP.SAAB.SE,11433' -Database UAT16_UsageAndHealth,UAT16_SaabNet_PortalContent,SISP_UAT16_MySiteContent,SISP_UAT16_TeamSites,UAT16Uniform_UsageAndHealth,SISP_UAT16_PortalContent_temp,SISP_UAT16_ACABContent -FileType Log -PercentFreeSpace 20 -ShrinkMethod TruncateOnly -StepSize 250MB
