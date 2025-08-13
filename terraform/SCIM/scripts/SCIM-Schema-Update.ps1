# This function does simple replacement of attribute names in SCIM schema
# based on provided hash table mapping
# requires SP object id and hash table to be sent as environment variables
function Update-AttributeNames {
    param (
        [array]$mappings,
        [hashtable]$dictionary
    )
    $resultMappings = @()
    for($i = 0; $i -lt $mappings.Count; $i++) {
        foreach ($key in $dictionary.Keys) {
            if ($mappings[$i].source.expression.Contains($key,'InvariantCultureIgnoreCase')) {
                $mappings[$i].source.expression = $mappings[$i].source.expression -replace $key, $dictionary[$key]
            }
            if ($mappings[$i].source.name.Contains($key,'InvariantCultureIgnoreCase')) {
                $mappings[$i].source.name = $mappings[$i].source.name -replace $key, $dictionary[$key]
            }
        }
        $resultMappings += $mappings[$i]
    }
    
}

$servicePrincipalObjectID = $Env:spoid
$IAGDictionary = $Env:json_attrs
$IAGDictionary = $IAGDictionary | ConvertFrom-Json -AsHashtable

Connect-MgGraph -AccessToken (ConvertTo-SecureString $Env:MSGRAPH_TOKEN -AsPlainText -Force) -NoWelcome

$job = Get-MgServicePrincipalSynchronizationJob -ServicePrincipalId $servicePrincipalObjectID

$url = "https://graph.microsoft.com/beta/servicePrincipals/$servicePrincipalObjectID/synchronization/jobs/$($job.id)/schema"


$schema = Invoke-MgGraphRequest -Uri $url -Method GET -OutputType Json

$schema = $schema | ConvertFrom-Json -Depth 100

$userRuleIndex = [array]::indexof($schema.synchronizationRules.objectMappings.sourceObjectName,'User')


Update-AttributeNames -mappings $schema.synchronizationRules.objectMappings[$userRuleIndex].attributeMappings -dictionary $IAGDictionary

# Setting/Updating the schema with users filter
# By default scope structure is empty, so we need to create it if filter was never defined before

$users_filter = $Env:users_filter
$users_filter = $users_filter | ConvertFrom-Json -Depth 100
if ($users_filter){
    $userRuleIndex = [array]::indexof($schema.synchronizationRules.objectMappings.sourceObjectName,'User')
    if ($schema.synchronizationRules.objectMappings[$userRuleIndex].scope) {
        $schema.synchronizationRules.objectMappings[$userRuleIndex].scope.groups = @()
        foreach ($group in $users_filter) {
            $schema.synchronizationRules.objectMappings[$userRuleIndex].scope.groups +=, $group
        }
    } else {
        $scope = @{
            categoryFilterGroups = @()
            inputFilterGroups = @()
            groups = @()
        }
        foreach ($group in $users_filter) {
            $scope.groups +=, $group
        }
        $schema.synchronizationRules.objectMappings[$userRuleIndex].scope = $scope
    }
}

$schema = $schema | ConvertTo-Json -Depth 100

Invoke-MgGraphRequest -Uri $url -Method PUT -Body $schema -ContentType "application/json"








