# This script does not have input parameters. All the required information is stored in environment variables.

$spid = $env:spid
$delete_credential = [System.Convert]::ToBoolean($env:delete_credential)
Connect-MgGraph -AccessToken (ConvertTo-SecureString $Env:MSGRAPH_TOKEN -AsPlainText -Force) -NoWelcome



if ($delete_credential) {
    $SyncNotificationSettings = @{
        Enabled                             = "false"
        HumanResourcesLookaheadQueryEnabled = "false"
        DeleteThresholdEnabled              = "false"
        DeleteThresholdValue                = ""
        Recipients                          = ""
    }
    $SyncNotificationSettings = $SyncNotificationSettings | ConvertTo-Json -Depth 10
} else {
    $SyncNotificationSettings = $env:scim_settings
}


$Settings = @{
    value = @(
        @{
            key = "BaseAddress"
            value = ""
        },
        @{
            key = "SecretToken"
            value = ""
        },
        @{
            key = "AuthenticationType"
            value = ""
        },
        @{
            key = "SyncNotificationSettings"
            value = $SyncNotificationSettings 
        },
        @{
            key = "SyncAll"
            value = ""
        }
    )
}

if (!$delete_credential) {
    $Settings.value[[array]::indexof($Settings.value.key,'BaseAddress')].value = $env:scim_url
    $Settings.value[[array]::indexof($Settings.value.key,'SecretToken')].value = $env:scim_password
    $Settings.value[[array]::indexof($Settings.value.key,'AuthenticationType')].value = "TokenBasedBearerToken"
    $Settings.value[[array]::indexof($Settings.value.key,'SyncAll')].value = "false"
    $Settings.value[[array]::indexof($Settings.value.key,'SyncNotificationSettings')].value = $env:scim_settings
}

$Settings = $Settings | ConvertTo-Json -Depth 100

Write-Host $Settings

$URL = "https://graph.microsoft.com/v1.0/servicePrincipals/$spid/synchronization/secrets"
Invoke-MgGraphRequest -Uri $URL -Method PUT -Body $Settings -ContentType "application/json"