[CmdletBinding()]
param (
    [Parameter(Mandatory)][string]$servicePrincipalObjectID
)


Connect-MgGraph -AccessToken (ConvertTo-SecureString $Env:MSGRAPH_TOKEN -AsPlainText -Force) -NoWelcome

$template = Get-MgServicePrincipalSynchronizationTemplate -ServicePrincipalId $servicePrincipalObjectID

$templateID = ($template | Where-Object {$_.Default}).Id

$outputResult = ConvertTo-Json @{id=$templateID} -Compress

$outputResult


