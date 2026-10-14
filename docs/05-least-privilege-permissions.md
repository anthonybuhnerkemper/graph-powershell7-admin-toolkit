# 05 - Least-privilege permissions

Grant only what each task needs, prefer read-only roles for reporting, and keep change rights separate.

## Graph permissions by script

| Script | Least-privileged permission | Type |
|---|---|---|
| Get-MFARegistrationReport | `AuditLog.Read.All` | Delegated / Application |
| Get-ConditionalAccessReport | `Policy.Read.All` | Delegated / Application |
| Get-SecurityDefaultsStatus | `Policy.Read.All` | Delegated / Application |
| Get-SecureScoreSummary | `SecurityEvents.Read.All` | Delegated / Application |
| Get-PrivilegedRoleAssignments | `RoleManagement.Read.Directory`, `RoleEligibilitySchedule.Read.Directory` | Delegated / Application |
| Get-StaleGuestUsers | `User.Read.All` + `AuditLog.Read.All` | Delegated / Application |

With delegated auth, the signed-in user also needs a matching Entra role. **Global Reader** covers every report above.

## Exchange Online and Purview roles

| Script | Suggested role (read) | Suggested role (change) |
|---|---|---|
| Get-MailboxSecurityAudit, Get-TransportRuleReport, Get-AntiPhishPolicyReport | Global Reader, or View-Only Organization Management | n/a |
| Set-ModernAuthBaseline | n/a | Exchange Administrator |
| Get-SensitivityLabelReport | Information Protection Reader / Global Reader | n/a |
| Get-DLPPolicyReport, Get-RetentionPolicyReport | Compliance Data Administrator (or Global Reader) | n/a |
| Start-ContentSearchExport | n/a | eDiscovery Manager role group |

## Recommended app split

| App registration | Permissions | Use |
|---|---|---|
| `M365 Toolkit - Reports` | Read-only Graph app roles + `Exchange.ManageAsApp` + **Global Reader** | Scheduled reporting |
| `M365 Toolkit - Changes` | `Exchange.ManageAsApp` + **Exchange Administrator** | Baseline changes, run on demand |

## Hardening tips

- Use **certificates or managed identities**, never client secrets in scripts.
- Restrict who can use the certificate (key in Key Vault or a hardware-backed store).
- Use **PIM** for human admins. Activate roles just in time.
- Apply **Conditional Access for workload identities** (Entra Workload ID) to restrict app sign-ins by location.
- Review app permissions quarterly: Entra admin center > Enterprise applications > the app > Permissions.
- Run change scripts with `-WhatIf` first. They all implement `SupportsShouldProcess`.
