# Microsoft Entra ID Governance - Guest User Licensing Analysis

This repository contains PowerShell scripts to help organizations analyze their guest user population and identify potential **Microsoft Entra ID Governance licensing costs** based on governance feature usage.

## 📋 Overview

Microsoft Entra ID Governance uses a **Monthly Active User (MAU) billing model** for guest users
Guest users are only billed when they actively use governance features exclusive to Entra ID Governance. This tool helps you:

- **Identify billable activities**: Analyze audit logs to find guest users engaging with governance features
- **Estimate licensing costs**: Understand which guests would incur charges under the MAU model
- **Monitor governance engagement**: Track monthly active governance usage patterns
- **Plan license requirements**: Make informed decisions about Entra ID Governance adoption

## 🎯 Key Features

### Guest User Analysis
- Total guest user count and tenant statistics
- Monthly active guest tracking (current month)
- Sign-in activity analysis
- Never-signed-in guest identification

### Billable Governance Feature Detection
Analyzes audit logs for activities that trigger Entra ID Governance billing:

#### **Entitlement Management**
- Access package assignments and requests
- Auto-assignment policy executions
- Direct user assignments to access packages
- Guest lifecycle management activities
- Sponsor policy applications

#### **Lifecycle Workflows**
- Workflow executions targeting guest users

#### **Access Reviews** *(Available after 8/1/2025)*
- Machine learning assisted access reviews
- Inactive user reviews

## 📊 Understanding the Billing Model

### When Guest Users Are Billed
Guest users with `userType` = "Guest" are billed when they have **billable governance activities** in a calendar month. Key principles:

- ✅ **One charge per month**: Each guest is billed once per month regardless of activity volume
- ✅ **Activity-based**: Only billed when using exclusive governance features
- ❌ **No free tier**: Unlike regular Entra licensing, all governance usage is billable
- ❌ **P2 features excluded**: Basic features included with Entra P2 don't trigger billing

### Billable Activity Identification
The scripts look for audit log entries with these properties:
- `TargetUserType`: Guest
- `GovernanceLicenseFeatureUsed`: True
- Specific activity types listed in the [Microsoft documentation](https://learn.microsoft.com/en-us/entra/id-governance/microsoft-entra-id-governance-licensing-for-guest-users)

## 🚀 Getting Started

### Prerequisites

1. **PowerShell 5.1 or PowerShell 7+**
2. **Microsoft Graph PowerShell SDK modules** (auto-installed by script - uses either ALL standard OR ALL Beta modules)
3. **Appropriate permissions**:
   - **Service Principal**: `User.Read.All`, `AuditLog.Read.All` (Application permissions)
   - **Delegated**: Global Reader or Security Reader role

### Installation

1. **Clone the repository**:
   ```powershell
   git clone <repository-url>
   cd utilities
   ```

2. **The script will automatically install required modules**:
   - Uses **either ALL standard OR ALL Beta modules** (no mixing to avoid conflicts)
   - Microsoft.Graph.Authentication (same for both standard and Beta)
   - Microsoft.Graph.Users + Microsoft.Graph.Reports (preferred)
   - OR Microsoft.Graph.Beta.Users + Microsoft.Graph.Beta.Reports (if standard not available)

### Authentication Setup

#### Option 1: Delegated Authentication (Recommended for testing)
```powershell
.\guestUsersGovernanceActivities.ps1 -AuthenticationMethod Delegated -TenantId "your-tenant-id"
```

#### Option 2: Service Principal Authentication (Recommended for automation)
```powershell
.\guestUsersGovernanceActivities.ps1 -AuthenticationMethod ServicePrincipal -TenantId "your-tenant-id" -ClientId "your-client-id" -ClientSecret "your-client-secret"
```

## 📋 Usage Examples

### Basic Analysis (Interactive Sign-in)
```powershell
# Analyze governance usage with delegated authentication
.\guestUsersGovernanceActivities.ps1 -AuthenticationMethod Delegated -TenantId "34234-42343432-34234123-545401"
```

### Automated Analysis (Service Principal)
```powershell
# Run analysis using service principal for automation
.\guestUsersGovernanceActivities.ps1 `
    -AuthenticationMethod ServicePrincipal `
    -TenantId "your-tenant-id" `
    -ClientId "your-app-id" `
    -ClientSecret "your-secret"
```

## 📈 Sample Output

```
=== GUEST USERS GOVERNANCE ANALYSIS REPORT ===

TOTAL GUEST USERS: 1,247
Total users in tenant: 5,832
Member users: 4,585
Guest percentage: 21.38%

GUEST USER SIGN-IN ACTIVITY:
  Guests with sign-in data: 892
  Guests never signed in: 355
  Guests signed in this month: 234

BILLABLE GOVERNANCE FEATURES USAGE BY GUEST USERS (Current Month):
  Entitlement Management billable activities: 45 guest users
  Lifecycle Workflows billable activities: 12 guest users

BILLABLE GOVERNANCE ENGAGEMENT SUMMARY (Current Month):
  Unique guest users with billable governance activities: 52
  Billable governance engagement rate: 4.17%
  Analysis period: 2024-01-01 to 2024-01-25
```

## 🔍 Script Components

### Main Script: `guestUsersGovernanceActivities.ps1`
- **Purpose**: Primary analysis script for guest user governance activities
- **Functions**: 
  - Parameter validation and authentication setup
  - Microsoft Graph module initialization
  - Guest user enumeration and statistics
  - Sign-in activity analysis
  - Audit log analysis for billable activities
  - Comprehensive reporting

### Helper Module: `entraIdGovernanceHelpers.psm1`
- **Purpose**: Reusable functions for governance analysis
- **Functions**:
  - `Initialize-MicrosoftGraphModules`: Detects, installs, and imports Microsoft Graph modules (all-or-nothing approach)
  - `Get-GovernanceAuditLogs`: Retrieves audit logs from Microsoft Graph (supports both standard and Beta cmdlets)
  - `Find-BillableGuestUsers`: Processes audit logs to identify billable guest users with GovernanceLicenseFeatureUsed = True and TargetUserType = Guest

## ⚠️ Important Considerations

### Analysis Accuracy and Limitations

**⚠️ IMPORTANT: This tool provides an approximation, not exact billing calculations**

Microsoft's official guidance recommends checking each individual API call with specific properties (`TargetUserType: Guest` and `GovernanceLicenseFeatureUsed: True`) to determine precise billing. However, implementing this level of granular analysis is too complex.


Instead, these scripts use a **simplified approach** based on audit log analysis:
- ✅ **Provides useful insights**: Identifies guest users engaged in governance activities
- ✅ **Worst-case scenario**: Tends to overestimate rather than underestimate potential costs
- ❌ **Not billing-accurate**: May not reflect exact MAU charges from Microsoft

**Use this analysis for**:
- Planning and budgeting (worst-case estimates)
- Identifying governance adoption patterns
- Understanding which guests are actively using governance features
- Initial cost impact assessment

**Do NOT use this analysis for**:
- Exact billing calculations
- Disputing Microsoft charges
- Precise license procurement decisions


### Licensing Requirements
- You need at least **one Microsoft Entra ID Governance or Microsoft Entra Suite license** for an administrator in the tenant
- Guest users don't need individual licenses - they're billed via the MAU model

### Scope and Limitations
- **Current month analysis**: Script focuses on current calendar month activities
- **Audit log retention**: Analysis limited by your tenant's audit log retention period (but should be enough for MAU in most cases)
- **API throttling**: Microsoft Graph PowerShell cmdlets include built-in throttling and retry logic
- **Permissions required**: Ensure service principal has sufficient permissions for audit log access (User.Read.All, AuditLog.Read.All)


## 📚 Related Resources

- [Microsoft Entra ID Governance licensing for guest users](https://learn.microsoft.com/en-us/entra/id-governance/microsoft-entra-id-governance-licensing-for-guest-users)
- [Microsoft Entra ID Governance licensing fundamentals](https://learn.microsoft.com/en-us/entra/id-governance/licensing-fundamentals)
- [Azure pricing for Entra ID Governance](https://azure.microsoft.com/pricing/details/active-directory/)

## 🤝 Contributing

Contributions are welcome! Please ensure any changes maintain compatibility with the Microsoft Graph PowerShell SDK and follow PowerShell best practices.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## ⚡ Quick Start Checklist

- [ ] Clone repository
- [ ] Have tenant ID ready
- [ ] Ensure appropriate permissions (Global Reader or Security Reader for Delegated auth)
- [ ] Run script with delegated authentication for initial test
- [ ] Review output and understand billable activities

## ⚡ Additional information

You can view a sample audit log event schema in [sampleAuditLogEvent.json](sampleAuditLogEvent.json).