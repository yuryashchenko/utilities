<#
.SYNOPSIS
    Analyzes governance feature usage for guest users in Entra ID tenant.
    https://learn.microsoft.com/en-us/entra/id-governance/microsoft-entra-id-governance-licensing-for-guest-users

.DESCRIPTION
    This script provides comprehensive analysis of guest users including:
    - Total guest user count and statistics
    - Monthly active guests
    - Billable governance feature usage from audit logs (TargetUserType=Guest):
      * Entitlement Management (access package assignments, auto-assignments, direct assignments)
      * Lifecycle Workflows (workflow executions for guests)
      * Access Reviews (Basic)

.PARAMETER AuthenticationMethod
    Specifies the authentication method to use: 'ServicePrincipal' or 'Delegated'
    Default: ServicePrincipal

.PARAMETER TenantId
    The tenant ID for Microsoft Graph connection

.PARAMETER ClientId
    Client ID of the registered application (required for Service Principal authentication)

.PARAMETER ClientSecret
    Client secret of the registered application (required for Service Principal authentication)


.EXAMPLE
    # Run with delegated authentication (interactive sign-in)
    .\count-guest-users.ps1 -AuthenticationMethod Delegated

.EXAMPLE
    # Run with service principal authentication with custom parameters
    .\count-guest-users.ps1 -AuthenticationMethod ServicePrincipal -TenantId "your-tenant-id" -ClientId "your-client-id" -ClientSecret "your-client-secret"

.EXAMPLE
    # Run with delegated authentication for specific tenant
    .\count-guest-users.ps1 -AuthenticationMethod Delegated -TenantId "your-tenant-id"

.NOTES
    Required Microsoft Graph Permissions:
    - Service Principal: User.Read.All, AuditLog.Read.All (Application permissions)
    - Delegated: global reader or security reader should be sufficient


#>

param(
    [Parameter(HelpMessage="Authentication method: 'ServicePrincipal' or 'Delegated'")]
    [ValidateSet("ServicePrincipal", "Delegated")]
    [string]$AuthenticationMethod = "Delegated",

    [Parameter(HelpMessage="Tenant ID for Microsoft Graph connection")]
    [string]$TenantId,
    
    [Parameter(HelpMessage="Client ID (required for Service Principal auth)")]
    [string]$ClientId,
    
    [Parameter(HelpMessage="Client Secret (required for Service Principal auth)")]
    [string]$ClientSecret
)

# Handle Microsoft Graph PowerShell modules

# Import helper module
$ModulePath = Join-Path $PSScriptRoot "EntraIdGovernanceHelpers.psm1"
if (Test-Path $ModulePath) {
    Import-Module $ModulePath -Force
} else {
    Write-Error "Required module not found: $ModulePath"
    exit 1
}

# Initialize Microsoft Graph modules
$ModuleConfig = Initialize-MicrosoftGraphModules
$UserCmdlet = $ModuleConfig.UserCmdlet
$AuditLogCmdlet = $ModuleConfig.AuditLogCmdlet

$startTime = Get-Date
Write-Host "=== Starting Guest Users Count Script ===" -ForegroundColor Cyan
Write-Host "Script started at: $startTime" -ForegroundColor White
Write-Host "Authentication method: $AuthenticationMethod" -ForegroundColor White
Write-Host "Tenant ID: $TenantId" -ForegroundColor White

# Connect to Microsoft Graph using specified authentication method
try {
    switch ($AuthenticationMethod) {
        "ServicePrincipal" {
            Write-Host "`nConnecting to Microsoft Graph using service principal authentication..." -ForegroundColor Yellow
            
            # Validate required parameters for service principal auth
            if ([string]::IsNullOrEmpty($ClientId) -or [string]::IsNullOrEmpty($ClientSecret)) {
                throw "ClientId and ClientSecret are required for Service Principal authentication"
            }
            
            $SecureClientSecret = ConvertTo-SecureString $ClientSecret -AsPlainText -Force
            $Credential = New-Object -TypeName System.Management.Automation.PSCredential -ArgumentList $ClientId, $SecureClientSecret
            
            Connect-MgGraph -TenantId $TenantId -ClientSecretCredential $Credential -NoWelcome
            Write-Host "Connected successfully using Service Principal authentication" -ForegroundColor Green
        }
        
        "Delegated" {
            Write-Host "`nConnecting to Microsoft Graph using delegated authentication..." -ForegroundColor Yellow
            
            # Required permissions
            $RequiredScopes = @(
                "User.Read.All",
                "AuditLog.Read.All"
            )
            
            Write-Host "Required permissions: $($RequiredScopes -join ', ')" -ForegroundColor White
            Write-Host "You will be prompted to sign in and consent to those permissions..." -ForegroundColor White
            
            # Connect with required scopes for delegated authentication
            if ([string]::IsNullOrEmpty($TenantId)) {
                Write-Error "Tenant ID is required for delegated authentication"
                exit 1
            } else {
                Connect-MgGraph -TenantId $TenantId -Scopes $RequiredScopes -NoWelcome
            }
            Write-Host "Connected successfully using Delegated authentication" -ForegroundColor Green
        }
    }
    
    Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green
} catch {
    Write-Error "Failed to connect to Microsoft Graph: $_"
    Write-Warning "Ensure the service principal has the required application permissions in Entra ID"
    exit 1
}

# General statistics on users in the tenant
try {
    Write-Host "Counting users in Entra ID tenant..." -ForegroundColor Yellow
    
    Write-Host "Getting total user count..." -ForegroundColor White
    & $UserCmdlet -All -CountVariable totalUserCount -ConsistencyLevel eventual | Out-Null
    Write-Host "Total users in tenant: $totalUserCount" -ForegroundColor White
    
    Write-Host "Counting guest users..." -ForegroundColor White
    & $UserCmdlet -All -Filter "userType eq 'Guest'" -CountVariable guestCount -ConsistencyLevel eventual | Out-Null
    Write-Host "Guest users count: $guestCount" -ForegroundColor White
    
    $memberCount = $totalUserCount - $guestCount
    Write-Host "Member users: $memberCount" -ForegroundColor White
    
    # Get guest user details for the analysis
    Write-Host "Retrieving guest user details for governance analysis..." -ForegroundColor White
    $guestUsers = & $UserCmdlet -Filter "userType eq 'Guest'" -All -Property "Id,UserType,Mail,UserPrincipalName,SignInActivity" -ConsistencyLevel eventual
    
    Write-Host "Successfully retrieved $($guestUsers.Count) guest user objects for analysis" -ForegroundColor Green
    
} catch {
    Write-Error "Failed to retrieve users from tenant: $_"
    exit 1
}


Write-Host "Analyzing guest user sign-in activity..." -ForegroundColor Yellow

# Check sign-in activity for this month since MAU billing is monthly
$currentMonthStart = Get-Date -Day 1 -Hour 0 -Minute 0 -Second 0 -Millisecond 0

# Check each guest user's sign-in activity
$guestsWithSignInData = @()
$guestsSignedInThisMonth = @()
$guestsSignedInBefore = @()
$guestsNeverSignedIn = @()

foreach ($guest in $guestUsers) {
    $hasSignInData = $false
    $lastSignIn = $null
    
    # Check multiple possible sign-in date fields
    if ($guest.SignInActivity) {
        if ($guest.SignInActivity.LastSignInDateTime) {
            $hasSignInData = $true
            $lastSignIn = $guest.SignInActivity.LastSignInDateTime
        } elseif ($guest.SignInActivity.LastNonInteractiveSignInDateTime) {
            $hasSignInData = $true
            $lastSignIn = $guest.SignInActivity.LastNonInteractiveSignInDateTime
        }
    }
    
    if ($hasSignInData) {
        $guestsWithSignInData += $guest
        try {
            $signInDate = Get-Date $lastSignIn
            if ($signInDate -gt $currentMonthStart) {
                $guestsSignedInThisMonth += $guest
            } else {
                $guestsSignedInBefore += $guest
            }
        } catch {
            Write-Warning "Could not parse sign-in date for guest $($guest.UserPrincipalName): $lastSignIn"
        }
    } else {
        $guestsNeverSignedIn += $guest
    }
}

Write-Host "Analyzing billable governance feature usage for guest users from Entra ID logs..." -ForegroundColor Yellow
Write-Host "Searching for entries with GovernanceLicenseFeatureUsed = True and UserType = Guest" -ForegroundColor Cyan

$governanceAnalysisErrors = @()

$startDate = $currentMonthStart.ToString("yyyy-MM-ddTHH:mm:ssZ")
$endDate = (Get-Date).ToString("yyyy-MM-ddTHH:mm:ssZ")
$filterDate = $currentMonthStart.ToString("yyyy-MM-dd")

$billableGuestsByService = @{
    'EntitlementManagement' = @{}
    'LifecycleWorkflows' = @{}
    'AccessReviews' = @{}
}

# Check Entitlement Management billable activities
try {
    Write-Host "Checking Entitlement Management..." -ForegroundColor Yellow
    
    $entitlementMgmtFilters = @(
        "(category eq 'EntitlementManagement' and activityDisplayName eq 'User requests access package assignment')",
        "(category eq 'EntitlementManagement' and activityDisplayName eq 'Create access package assignment user update request')",
        "(category eq 'EntitlementManagement' and activityDisplayName eq 'Entitlement Management creates access package assignment request for user')",
        "(category eq 'EntitlementManagement' and activityDisplayName eq 'Administrator directly assigns user to access package')",
        "(category eq 'EntitlementManagement' and activityDisplayName eq 'Update access package user lifecycle')"
    )
    
    $entitlementFilter = "activityDateTime ge $filterDate and (" + ($entitlementMgmtFilters -join " or ") + ")"
    
    $entitlementLogs = Get-GovernanceAuditLogs -Filter $entitlementFilter -FeatureName "Entitlement Management" -AuditLogCmdlet $AuditLogCmdlet
    
    # Find billable guest users in these logs
    if ($null -eq $entitlementLogs) { $entitlementLogs = @() }
    $uniqueGuests = Find-BillableGuestUsers -AuditLogs $entitlementLogs -ServiceName "Entitlement Management"
    $billableGuestsByService['EntitlementManagement'] = $uniqueGuests
} catch {
    Write-Warning "Could not check Entitlement Management: $_"
    $governanceAnalysisErrors += "Entitlement Management: $_"
}

# Check Lifecycle Workflows billable activities
try {
    Write-Host "Checking Lifecycle Workflows..." -ForegroundColor Yellow
    
    $lifecycleFilters = @(
        "(category eq 'WorkflowManagement' and activityDisplayName eq 'Workflow execution started for user')"
    )
    
    $lifecycleFilter = "activityDateTime ge $filterDate and (" + ($lifecycleFilters -join " or ") + ")"
    
    $lifecycleLogs = Get-GovernanceAuditLogs -Filter $lifecycleFilter -FeatureName "Lifecycle Workflows" -AuditLogCmdlet $AuditLogCmdlet
    
    # Find billable guest users in these logs
    if ($null -eq $lifecycleLogs) { $lifecycleLogs = @() }
    $uniqueGuests = Find-BillableGuestUsers -AuditLogs $lifecycleLogs -ServiceName "Lifecycle Workflows"
    $billableGuestsByService['LifecycleWorkflows'] = $uniqueGuests
} catch {
    Write-Warning "Could not check Lifecycle Workflows: $_"
    $governanceAnalysisErrors += "Lifecycle Workflows: $_"
}

# Check Access Reviews billable activities
try {
    Write-Host "Checking Access Reviews..." -ForegroundColor Yellow
    
    $accessReviewFilters = @(
        "(category eq 'AccessReviews')"
    )

    $accessReviewFilter = "activityDateTime ge $filterDate and (" + ($accessReviewFilters -join " or ") + ")"
    
    $accessReviewLogs = Get-GovernanceAuditLogs -Filter $accessReviewFilter -FeatureName "Access Reviews" -AuditLogCmdlet $AuditLogCmdlet
    
    # Find billable guest users in these logs
    if ($null -eq $accessReviewLogs) { $accessReviewLogs = @() }
    $uniqueGuests = Find-BillableGuestUsers -AuditLogs $accessReviewLogs -ServiceName "Access Reviews"
    $billableGuestsByService['AccessReviews'] = $uniqueGuests
} catch {
    Write-Warning "Could not check Access Reviews: $_"
    $governanceAnalysisErrors += "Access Reviews: $_"
}



# Generate final report
Write-Host "`n=== GUEST USERS GOVERNANCE ANALYSIS REPORT ===" -ForegroundColor White
    Write-Host "`nTOTAL GUEST USERS: $guestCount" -ForegroundColor Green
    Write-Host "Total users in tenant: $totalUserCount" -ForegroundColor White
    Write-Host "Member users: $memberCount" -ForegroundColor White
    Write-Host "Guest percentage: $('{0:P2}' -f ($guestCount / $totalUserCount))" -ForegroundColor White


Write-Host "`nGUEST USER SIGN-IN ACTIVITY:" -ForegroundColor White
    Write-Host "Guests with sign-in data: $($guestsWithSignInData.Count)" -ForegroundColor White
    Write-Host "Guests signed in this month: $($guestsSignedInThisMonth.Count)" -ForegroundColor White
    Write-Host "Guests signed in before (not this month): $($guestsSignedInBefore.Count)" -ForegroundColor White
    Write-Host "Guests never signed in: $($guestsNeverSignedIn.Count)" -ForegroundColor White

Write-Host "`nBILLABLE GOVERNANCE FEATURES USAGE BY GUEST USERS (GovernanceLicenseFeatureUsed = True):" -ForegroundColor White
    Write-Host "Entitlement Management: $($billableGuestsByService['EntitlementManagement'].Count) unique guest users" -ForegroundColor Green
    Write-Host "Lifecycle Workflows: $($billableGuestsByService['LifecycleWorkflows'].Count) unique guest users" -ForegroundColor Green
    Write-Host "Access Reviews: $($billableGuestsByService['AccessReviews'].Count) unique guest users" -ForegroundColor Green

# Calculate what percentage of guests are using billable features
$allBillableGovernanceUsers = @{}

# Get all unique billable users across all services
foreach ($serviceKey in $billableGuestsByService.Keys) {
    foreach ($guestId in $billableGuestsByService[$serviceKey].Keys) {
        $allBillableGovernanceUsers[$guestId] = $true
    }
}

$totalUniqueBillableGovernanceUsers = $allBillableGovernanceUsers.Count
$billableGovernancePercentage = if ($guestCount -gt 0) { ($totalUniqueBillableGovernanceUsers / $guestCount) * 100 } else { 0 }

Write-Host "`nBILLABLE GOVERNANCE ENGAGEMENT SUMMARY (GovernanceLicenseFeatureUsed = True):" -ForegroundColor White
Write-Host "Total unique guest users with billable activities: $totalUniqueBillableGovernanceUsers" -ForegroundColor Cyan
Write-Host "Billable governance engagement rate: $('{0:F2}' -f $billableGovernancePercentage)%" -ForegroundColor Cyan

Write-Host "  Analysis period: $(Get-Date $startDate -Format 'yyyy-MM-dd') to $(Get-Date $endDate -Format 'yyyy-MM-dd')" -ForegroundColor White


if ($governanceAnalysisErrors.Count -gt 0) {
    Write-Warning "`nGOVERNANCE ANALYSIS WARNINGS:"
    foreach ($analysisError in $governanceAnalysisErrors) {
        Write-Warning "  - $analysisError"
    }
}

if ($guestsNeverSignedIn.Count -gt 0) {
    Write-Warning "`nNote: $($guestsNeverSignedIn.Count) guest users have never signed in"
}

$endTime = Get-Date
Write-Host "`n=== FINAL SUMMARY ===" -ForegroundColor White
Write-Host "Script execution completed at: $endTime" -ForegroundColor White
Write-Host "Tenant analyzed: $TenantId" -ForegroundColor White
Write-Host "`nTOTAL GUEST USERS: $guestCount" -ForegroundColor Green
Write-Host "Percentage of total users: $('{0:P2}' -f ($guestCount / $totalUserCount))" -ForegroundColor White
Write-Host "Active guests (signed in this month): $($guestsSignedInThisMonth.Count)" -ForegroundColor White
$inactiveGuestsCount = $guestsSignedInBefore.Count + $guestsNeverSignedIn.Count
Write-Host "Inactive guests (did not sign in this month): $inactiveGuestsCount" -ForegroundColor White
Write-Host "  - Signed in before: $($guestsSignedInBefore.Count)" -ForegroundColor White
Write-Host "  - Never signed in: $($guestsNeverSignedIn.Count)" -ForegroundColor White
Write-Host "`nBILLABLE GOVERNANCE FEATURES SUMMARY (GovernanceLicenseFeatureUsed = True Analysis):" -ForegroundColor Green
Write-Host "  Entitlement Management: $($billableGuestsByService['EntitlementManagement'].Count) unique guest users" -ForegroundColor Green
Write-Host "  Lifecycle Workflows: $($billableGuestsByService['LifecycleWorkflows'].Count) unique guest users" -ForegroundColor Green
Write-Host "  Access Reviews: $($billableGuestsByService['AccessReviews'].Count) unique guest users" -ForegroundColor Green
Write-Host "  TOTAL UNIQUE BILLABLE GUESTS: $totalUniqueBillableGovernanceUsers" -ForegroundColor Cyan
Write-Host "`nGuest user governance billing analysis completed!" -ForegroundColor Green
Write-Host "Note: Results show only activities with GovernanceLicenseFeatureUsed = True for Guest users" -ForegroundColor Yellow
Write-Host "Note: There might be some activities missing from results due to the Microsoft Description" -ForegroundColor Yellow
Disconnect-MgGraph


