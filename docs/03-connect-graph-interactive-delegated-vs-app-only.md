# 03 - Connecting to Graph: delegated (interactive) vs app-only

| | Delegated (interactive) | App-only (certificate / managed identity) |
|---|---|---|
| Who is acting | A signed-in user | The application itself |
| Effective rights | Overlap of the granted scopes **and** the user's role | Granted application permissions (tenant-wide) |
| MFA / Conditional Access | Applies to the user | Applies to workload identities (CA for workload identities) |
| Best for | Ad hoc admin work, exploration | Scheduled reports, automation |

## Delegated (interactive)

```powershell
Connect-MgGraph -Scopes 'User.Read.All','Policy.Read.All','AuditLog.Read.All' -NoWelcome
Get-MgContext | Select-Object Account, AuthType, Scopes
```

- The first time, you (or an admin) will be asked to consent to the scopes.
- Headless / SSH session: add `-UseDeviceCode`. (Device code flow may be blocked by Conditional Access in hardened tenants.)
- Ask for the **minimum** scopes for the task. You can reconnect with more later.

## App-only with a certificate

```powershell
Connect-MgGraph -TenantId $env:M365_TENANT_ID `
                -ClientId $env:M365_CLIENT_ID `
                -CertificateThumbprint $env:M365_CERT_THUMBPRINT `
                -NoWelcome
Get-MgContext | Select-Object AppName, AuthType, Scopes   # AuthType = AppOnly
```

Cross-platform, from a PFX:
```powershell
$cert = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new('./certs/M365AdminToolkit.pfx', $env:M365_CERT_PASSWORD)
Connect-MgGraph -TenantId $env:M365_TENANT_ID -ClientId $env:M365_CLIENT_ID -Certificate $cert -NoWelcome
```

## App-only with a managed identity (Azure Automation / Functions / VM)

```powershell
Connect-MgGraph -Identity -NoWelcome                   # system-assigned
Connect-MgGraph -Identity -ClientId '<uami-client-id>' # user-assigned
```
Assign Graph app roles to the managed identity with `New-MgServicePrincipalAppRoleAssignment` (managed identities have no portal "API permissions" blade).

## Finding the right permission

```powershell
Find-MgGraphCommand -Command Get-MgIdentityConditionalAccessPolicy | Select-Object -First 1 -ExpandProperty Permissions
Find-MgGraphPermission conditionalaccess -PermissionType Application
```

## Making raw requests

Anything the SDK doesn't wrap can be called directly:
```powershell
Invoke-MgGraphRequest -Method GET -Uri 'v1.0/reports/authenticationMethods/userRegistrationDetails?$top=5'
```

## Disconnect
```powershell
Disconnect-MgGraph
```
