# Microsoft Graph PowerShell 7 Admin Toolkit

A practical toolkit and step-by-step guide for connecting to **Microsoft Graph with PowerShell 7** and managing **Microsoft Purview**, **Exchange Online**, and **Entra ID security** settings, using current Microsoft modules:

- **Microsoft.Graph** PowerShell SDK v2
- **ExchangeOnlineManagement** v3 (`Connect-ExchangeOnline` and `Connect-IPPSSession` for Purview)

Every script is commented, has comment-based help (`Get-Help ./script.ps1 -Full`), exports reports to CSV, and every change script supports `-WhatIf` / `-Confirm`. Authentication uses **certificates** (app-only) or **interactive** delegated sign-in. Tenant, app, and certificate values come from parameters or environment variables. No secrets are stored in the repo.

> ⚠️ **Disclaimer:** Test everything in a non-production / developer tenant first. Examples use `contoso.com`, `contoso.onmicrosoft.com`, and placeholder GUIDs (`00000000-0000-0000-0000-000000000000`). Review each script before running it in your environment.

## Prerequisites

| Requirement | Version / notes |
|---|---|
| PowerShell | 7.4 or later (`pwsh`) |
| Microsoft.Graph | 2.x |
| ExchangeOnlineManagement | 3.x |
| Entra ID licensing | P1 for sign-in activity and CA reports, P2 for PIM-eligible roles |
| Roles | Use a least-privilege role per task (see [docs/05](docs/05-least-privilege-permissions.md)) |

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser -Repository PSGallery
Install-Module ExchangeOnlineManagement -Scope CurrentUser -Repository PSGallery
```

## Quick start

```powershell
git clone https://github.com/anthonybuhnerkemper/graph-powershell7-admin-toolkit.git
cd graph-powershell7-admin-toolkit

# Option A: interactive (delegated)
. ./scripts/Connect/Connect-M365Admin.ps1
Connect-M365Admin -Interactive -UserPrincipalName admin@contoso.onmicrosoft.com

# Option B: certificate (app-only); values come from environment variables
$env:M365_TENANT_ID       = '00000000-0000-0000-0000-000000000000'
$env:M365_CLIENT_ID       = '00000000-0000-0000-0000-000000000000'
$env:M365_CERT_THUMBPRINT = '<thumbprint of your cert>'
$env:M365_ORGANIZATION    = 'contoso.onmicrosoft.com'
Connect-M365Admin

# Run reports (CSV files land in ./output)
./scripts/Security/Get-MFARegistrationReport.ps1
./scripts/Exchange/Get-MailboxSecurityAudit.ps1
./scripts/Purview/Get-DLPPolicyReport.ps1

# Preview a change before applying it
./scripts/Exchange/Set-ModernAuthBaseline.ps1 -WhatIf

. ./scripts/Connect/Disconnect-M365Admin.ps1
Disconnect-M365Admin
```

## Repo map

```text
docs/
  01-install-powershell7-and-modules.md
  02-app-registration-certificate-auth.md
  03-connect-graph-interactive-delegated-vs-app-only.md
  04-connect-exchange-online-and-purview.md
  05-least-privilege-permissions.md
  06-troubleshooting.md
scripts/
  Connect/   Connect-M365Admin.ps1, Disconnect-M365Admin.ps1
  Purview/   Get-SensitivityLabelReport, Get-DLPPolicyReport, Get-RetentionPolicyReport, Start-ContentSearchExport
  Exchange/  Get-MailboxSecurityAudit, Set-ModernAuthBaseline, Get-TransportRuleReport, Get-AntiPhishPolicyReport
  Security/  Get-MFARegistrationReport, Get-ConditionalAccessReport, Get-SecureScoreSummary,
             Get-SecurityDefaultsStatus, Get-PrivilegedRoleAssignments, Get-StaleGuestUsers
```

## Required Microsoft Graph permissions

All Graph scripts are read-only. Grant the **Application** permission for app-only (certificate) use or the **Delegated** one for interactive use.

| Script | Graph permission(s) | Notes |
|---|---|---|
| Get-MFARegistrationReport | `AuditLog.Read.All` | Entra ID P1. Delegated also needs Reports Reader |
| Get-ConditionalAccessReport | `Policy.Read.All` | |
| Get-SecureScoreSummary | `SecurityEvents.Read.All` | |
| Get-SecurityDefaultsStatus | `Policy.Read.All` | |
| Get-PrivilegedRoleAssignments | `RoleManagement.Read.Directory` (+ `RoleEligibilitySchedule.Read.Directory` for `-IncludeEligible`) | P2 for PIM |
| Get-StaleGuestUsers | `User.Read.All`, `AuditLog.Read.All` | signInActivity needs P1 |

Exchange and Purview scripts don't use Graph scopes. They need the `Exchange.ManageAsApp` API permission (Office 365 Exchange Online) for app-only use, plus an Entra role such as **Exchange Administrator**, **Compliance Administrator**, or a read-only equivalent. See [docs/05](docs/05-least-privilege-permissions.md).

## License

[MIT](LICENSE) © 2026 Anthony Buhnerkemper
