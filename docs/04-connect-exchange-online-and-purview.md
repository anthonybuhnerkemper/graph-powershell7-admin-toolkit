# 04 - Connecting to Exchange Online and Purview (Security & Compliance)

Both use the **ExchangeOnlineManagement v3** module. It uses REST-backed cmdlets, needs no WinRM basic auth, and works on Windows, macOS, and Linux in PowerShell 7.

## Exchange Online

Interactive:
```powershell
Connect-ExchangeOnline -UserPrincipalName admin@contoso.onmicrosoft.com -ShowBanner:$false
```

Certificate (app-only). `-Organization` must be the **.onmicrosoft.com** domain:
```powershell
Connect-ExchangeOnline -AppId $env:M365_CLIENT_ID `
                       -CertificateThumbprint $env:M365_CERT_THUMBPRINT `
                       -Organization 'contoso.onmicrosoft.com' -ShowBanner:$false
```

Managed identity (Azure Automation):
```powershell
Connect-ExchangeOnline -ManagedIdentity -Organization 'contoso.onmicrosoft.com'
```

Verify:
```powershell
Get-ConnectionInformation | Select-Object Name, UserPrincipalName, TokenStatus, ConnectionUri
Get-EXOMailbox -ResultSize 5
```

> Prefer the `Get-EXO*` cmdlets (`Get-EXOMailbox`, `Get-EXOCASMailbox`, `Get-EXOMailboxStatistics`) for large tenants. They are faster and page automatically.

## Purview / Security & Compliance (`Connect-IPPSSession`)

Interactive:
```powershell
Connect-IPPSSession -UserPrincipalName admin@contoso.onmicrosoft.com
```

Certificate (app-only):
```powershell
Connect-IPPSSession -AppId $env:M365_CLIENT_ID `
                    -CertificateThumbprint $env:M365_CERT_THUMBPRINT `
                    -Organization 'contoso.onmicrosoft.com'
```

Verify:
```powershell
Get-Label | Select-Object -First 3 DisplayName, Priority
Get-DlpCompliancePolicy | Select-Object Name, Mode
```

The app's service principal needs a Purview-capable role (for example **Compliance Administrator**). Some cmdlets, such as eDiscovery, also need role-group membership in the Purview portal.

## Using both at once

EXO and IPPS sessions can run side by side. `Connect-M365Admin` in this repo does Graph, EXO, and IPPS in one call:
```powershell
. ./scripts/Connect/Connect-M365Admin.ps1
Connect-M365Admin -Service ExchangeOnline, Purview -Interactive
```

## Disconnect
```powershell
Disconnect-ExchangeOnline -Confirm:$false   # closes EXO and IPPS sessions
```
