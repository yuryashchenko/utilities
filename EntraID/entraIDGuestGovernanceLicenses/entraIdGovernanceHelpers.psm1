# EntraIdGovernanceHelpers PowerShell Module
# Contains helper functions for Entra ID governance analysis scripts





# Functions for Entra ID governance analysis

function Initialize-MicrosoftGraphModules {
    <#
    .SYNOPSIS
    Detects, installs, and imports Microsoft Graph PowerShell SDK modules
    .DESCRIPTION
    Uses an all-or-nothing approach: either ALL standard modules OR ALL Beta modules to avoid conflicts.
    Prefers standard modules when all are available, falls back to Beta when needed.
    .OUTPUTS
    Hashtable with UseStandardModules, UserCmdlet, AuditLogCmdlet, and HasIssues properties
    #>
    param()
    
    Write-Host "Checking Microsoft Graph PowerShell SDK modules..." -ForegroundColor Cyan

    # Define the modules we need, preferring standard over Beta versions
    $RequiredModules = @{
        "Microsoft.Graph.Authentication" = @{
            Name = "Microsoft.Graph.Authentication"
            BetaName = "Microsoft.Graph.Authentication"  # Authentication module is the same for both
            Description = "Microsoft Graph Authentication"
            PreferStandard = $true
        }
        "Microsoft.Graph.Users" = @{
            Name = "Microsoft.Graph.Users"
            BetaName = "Microsoft.Graph.Beta.Users"
            Description = "Microsoft Graph Users"
            PreferStandard = $true
        }
        "Microsoft.Graph.Reports" = @{
            Name = "Microsoft.Graph.Reports"
            BetaName = "Microsoft.Graph.Beta.Reports"
            Description = "Microsoft Graph Reports/Audit Logs"
            PreferStandard = $true
        }
    }

    $ModuleIssues = @()
    $ModulesInstalled = @()

    # Check what modules are already installed
    $StandardModulesAvailable = @{}
    $BetaModulesAvailable = @{}

    Write-Host "`nChecking module availability..." -ForegroundColor Yellow

    foreach ($ModuleKey in $RequiredModules.Keys) {
        $Module = $RequiredModules[$ModuleKey]
        $StandardModuleName = $Module.Name
        $BetaModuleName = $Module.BetaName
        
        $StandardModule = Get-Module -ListAvailable -Name $StandardModuleName -ErrorAction SilentlyContinue
        $BetaModule = Get-Module -ListAvailable -Name $BetaModuleName -ErrorAction SilentlyContinue
        
        $StandardModulesAvailable[$ModuleKey] = ($null -ne $StandardModule)
        $BetaModulesAvailable[$ModuleKey] = ($null -ne $BetaModule)
        
        Write-Host "  $($Module.Description):" -ForegroundColor White
            Write-Host "    Standard ($StandardModuleName): $(if ($StandardModule) { "Available" } else { "Not found" })" -ForegroundColor $(if ($StandardModule) { "Green" } else { "Red" })
    Write-Host "    Beta ($BetaModuleName): $(if ($BetaModule) { "Available" } else { "Not found" })" -ForegroundColor $(if ($BetaModule) { "Green" } else { "Red" })
    }

    # Decide whether to use standard or beta modules (we use all of one type to avoid conflicts)
    $AllStandardAvailable = $StandardModulesAvailable.Values -notcontains $false
    $AllBetaAvailable = $BetaModulesAvailable.Values -notcontains $false

    $UseStandardModules = $false
    if ($AllStandardAvailable) {
        $UseStandardModules = $true
            Write-Host "`nDecision: Using all standard modules (all available)" -ForegroundColor Green
} elseif ($AllBetaAvailable) {
    $UseStandardModules = $false
    Write-Host "`nDecision: Using all Beta modules (all available)" -ForegroundColor Green
} else {
    # Missing some modules, so we'll install the standard ones
    $UseStandardModules = $true
    Write-Host "`nDecision: Using all standard modules (will install missing ones)" -ForegroundColor Yellow
    }

    # Install and import the modules we decided to use
    foreach ($ModuleKey in $RequiredModules.Keys) {
        $Module = $RequiredModules[$ModuleKey]
        $ModuleNameToUse = if ($UseStandardModules) { $Module.Name } else { $Module.BetaName }
        $ModuleType = if ($UseStandardModules) { "standard" } else { "Beta" }
        
        Write-Host "`nProcessing $ModuleType module: $ModuleNameToUse" -ForegroundColor Yellow
        
        $InstalledModule = Get-Module -ListAvailable -Name $ModuleNameToUse -ErrorAction SilentlyContinue
        
        if ($InstalledModule) {
                    Write-Host "$ModuleNameToUse is already installed (Version: $($InstalledModule[0].Version))" -ForegroundColor Green
        try {
            Import-Module $ModuleNameToUse -Force -ErrorAction Stop
            Write-Host "Successfully imported $ModuleNameToUse" -ForegroundColor Green
            $ModulesInstalled += $ModuleNameToUse
        } catch {
            $ErrorMsg = "Failed to import $ModuleNameToUse : $_"
            Write-Host $ErrorMsg -ForegroundColor Red
                $ModuleIssues += $ErrorMsg
            }
        } else {
            try {
                Write-Host "  Installing $ModuleNameToUse..." -ForegroundColor Cyan
                Install-Module $ModuleNameToUse -Force -AllowClobber -Scope CurrentUser -ErrorAction Stop
                            Write-Host "Successfully installed $ModuleNameToUse" -ForegroundColor Green
            
            Import-Module $ModuleNameToUse -Force -ErrorAction Stop
            Write-Host "Successfully imported $ModuleNameToUse" -ForegroundColor Green
            $ModulesInstalled += $ModuleNameToUse
        } catch {
            $ErrorMsg = "Failed to install/import $ModuleNameToUse : $_"
            Write-Host $ErrorMsg -ForegroundColor Red
                $ModuleIssues += $ErrorMsg
            }
        }
    }

    Write-Host "`n" + "="*60 -ForegroundColor Cyan
    Write-Host "MODULE INSTALLATION SUMMARY" -ForegroundColor Cyan
    Write-Host "="*60 -ForegroundColor Cyan

    if ($ModulesInstalled.Count -gt 0) {
            Write-Host "`nSuccessfully loaded modules:" -ForegroundColor Green
    foreach ($Module in $ModulesInstalled) {
        Write-Host "  - $Module" -ForegroundColor Green
    }
}

    # Figure out which cmdlets to use based on the modules we have
$UserCmdlet = if ($UseStandardModules) { "Get-MgUser" } else { "Get-MgBetaUser" }
$AuditLogCmdlet = if ($UseStandardModules) { "Get-MgAuditLogDirectoryAudit" } else { "Get-MgBetaAuditLogDirectoryAudit" }



    $HasIssues = $ModuleIssues.Count -gt 0
    
    if ($HasIssues) {
        Write-Host "`nModule issues detected:" -ForegroundColor Red
        foreach ($Issue in $ModuleIssues) {
            Write-Host "  - $Issue" -ForegroundColor Red
        }
        
        $Response = Read-Host "`nDo you want to continue despite module issues? (y/N)"
        if ($Response -ne 'y' -and $Response -ne 'Y') {
            Write-Host "Script execution aborted by user." -ForegroundColor Red
            exit 1
        }
    }

    Write-Host "`nModule check completed. Proceeding with script execution..." -ForegroundColor Green

    # Return configuration object
    return @{
        UseStandardModules = $UseStandardModules
        UserCmdlet = $UserCmdlet
        AuditLogCmdlet = $AuditLogCmdlet
        HasIssues = $HasIssues
        ModulesInstalled = $ModulesInstalled
        ModuleIssues = $ModuleIssues
    }
}

function Get-GovernanceAuditLogs {
    <#
    .SYNOPSIS
    Retrieves governance-related audit logs
    .PARAMETER Filter
    OData filter string for the audit log query
    .PARAMETER FeatureName
    Name of the governance feature being analyzed (for logging)
    .PARAMETER PageSize
    Number of records to retrieve per page (default: 200)
    .PARAMETER AuditLogCmdlet
    The audit log cmdlet to use (Get-MgAuditLogDirectoryAudit or Get-MgBetaAuditLogDirectoryAudit)
    .OUTPUTS
    Array of audit log entries matching the filter criteria
    #>
    param(
        [Parameter(Mandatory=$true)]
        [string]$Filter,
        
        [Parameter(Mandatory=$true)]
        [string]$FeatureName,
        
        [Parameter(Mandatory=$false)]
        [int]$PageSize = 200,
        
        [Parameter(Mandatory=$false)]
        [string]$AuditLogCmdlet = "Get-MgBetaAuditLogDirectoryAudit"
    )
    
    Write-Host "Retrieving $FeatureName audit logs..." -ForegroundColor Cyan
    
    try {
        $logs = & $AuditLogCmdlet -Filter $Filter -PageSize $PageSize -All -ErrorAction Stop
        
        if ($null -eq $logs) {
            $logs = @()
        } elseif ($logs -isnot [array]) {
            $logs = @($logs)
        }
        
        $logCount = $logs.Count
        Write-Host "$FeatureName audit logs retrieved: $logCount entries" -ForegroundColor Cyan
        
        return $logs
    } catch {
        Write-Error "Failed to retrieve $FeatureName audit logs: $($_.Exception.Message)"
        return @()
    }
}

function Find-BillableGuestUsers {
    <#
    .SYNOPSIS
    Processes audit logs to find billable guest users with GovernanceLicenseFeatureUsed = True
    .DESCRIPTION
    Analyzes audit log entries to identify unique guest users who have triggered billable governance features.
    Checks for both GovernanceLicenseFeatureUsed = "True" AND TargetUserType = "Guest" conditions.
    .PARAMETER AuditLogs
    Array of audit log entries to process
    .PARAMETER ServiceName
    Name of the governance service (for logging purposes)
    .OUTPUTS
    Hashtable containing unique guest user IDs as keys with $true values
    .EXAMPLE
    $billableGuests = Find-BillableGuestUsers -AuditLogs $entitlementLogs -ServiceName "Entitlement Management"
    #>
    param(
        [Parameter(Mandatory=$true)]
        [AllowEmptyCollection()]
        [array]$AuditLogs,
        
        [Parameter(Mandatory=$true)]
        [string]$ServiceName
    )
    
    # Make sure we have a valid array to work with
    if ($null -eq $AuditLogs) {
        $AuditLogs = @()
    }
    
    $uniqueGuests = @{}
    
    foreach ($log in $AuditLogs) {
        $hasGovernanceLicense = $false
        $isGuestUser = $false
        $targetUserId = $null
        
        # Look for the properties we need in AdditionalDetails
        if ($log.AdditionalDetails) {
            foreach ($detail in $log.AdditionalDetails) {
                if ($detail.Key -eq "GovernanceLicenseFeatureUsed") {
                    $hasGovernanceLicense = ($detail.Value -eq "True")
                }
                if ($detail.Key -eq "TargetUserType") {
                    $isGuestUser = ($detail.Value -eq "Guest")
                }
                if ($detail.Key -eq "TargetId" -and $detail.Value) {
                    $targetUserId = $detail.Value
                }
            }
        }
        
        # If we didn't find TargetUserType above, check modifiedProperties too
        if (-not $isGuestUser -and $log.TargetResources) {
            foreach ($resource in $log.TargetResources) {
                if ($resource.ModifiedProperties) {
                    foreach ($prop in $resource.ModifiedProperties) {
                        if ($prop.DisplayName -eq "TargetUserType" -and $prop.NewValue -eq '"Guest"') {
                            $isGuestUser = $true
                        }
                    }
                }
            }
        }
        
        # Only count this user if they meet all our criteria
        if ($hasGovernanceLicense -and ($isGuestUser -or $targetUserId)) {
            $uniqueGuests[$targetUserId] = $true
        }
    }
    
    return $uniqueGuests
}







# Export functions to make them available when module is imported
Export-ModuleMember -Function @(
    'Initialize-MicrosoftGraphModules',
    'Get-GovernanceAuditLogs',
    'Find-BillableGuestUsers'
) 
