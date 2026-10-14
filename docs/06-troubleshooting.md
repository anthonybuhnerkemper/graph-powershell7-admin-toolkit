# 06 - Troubleshooting

| Symptom | Likely cause | Fix |
|---|---|---|
| `Could not load file or assembly 'Microsoft.Identity.Client'` | Graph and EXO modules loading conflicting MSAL versions | Start a fresh `pwsh`, update both modules, and connect to Graph **before** EXO (or vice versa) consistently |
| `Insufficient privileges to complete the operation` (Graph 403) | Missing scope / app role, or consent not granted | `(Get-MgContext).Scopes`; add the permission and grant admin consent; reconnect |
| `Authentication_RequestFromNonPremiumTenantOrB2CTenant` | signInActivity or reports require Entra ID P1 | License the tenant or skip that property |
| `The role assigned to application ... isn't supported` (EXO) | Service principal lacks an Entra role | Assign Exchange Administrator / Global Reader to the app (docs/02 step 6) |
| `AADSTS700027: Client assertion contains an invalid signature` | Certificate on the machine doesn't match the uploaded .cer | Compare thumbprints; re-upload the public key |
| `AADSTS7000215` / `AADSTS700016` | Wrong client ID or tenant ID | Check `M365_CLIENT_ID` / `M365_TENANT_ID` |
| `Connect-ExchangeOnline: -Organization` errors | Used a custom domain | Use `contoso.onmicrosoft.com` |
| Purview cmdlets not found after connecting | Connected to EXO only | Run `Connect-IPPSSession` |
| `New-ComplianceSearchAction -Export` fails | Tenant moved to the modern eDiscovery export flow | Export from the Purview portal (eDiscovery > Searches) |
| Certificate not found on macOS/Linux | No CurrentUser\My store for thumbprint lookup | Use `-CertificatePath` with a PFX and `M365_CERT_PASSWORD` |
| Script blocked: "not digitally signed" | Execution policy on Windows | `Unblock-File ./scripts -Recurse` or `Set-ExecutionPolicy -Scope CurrentUser RemoteSigned` |

## Useful diagnostics

```powershell
# Graph
Get-MgContext | Format-List
Invoke-MgGraphRequest -Method GET -Uri 'v1.0/organization' | Select-Object -ExpandProperty value | Select-Object id, displayName

# Exchange / Purview
Get-ConnectionInformation | Format-Table Name, State, TokenStatus, IsEopSession

# Module versions
Get-Module Microsoft.Graph*, ExchangeOnlineManagement -ListAvailable | Sort-Object Name | Format-Table Name, Version

# Verbose / debug output for any SDK call
Get-MgUser -Top 1 -Debug
```

## Throttling
Graph returns HTTP 429 with a `Retry-After` header. The SDK retries automatically. For very large tenants, use `-All` sparingly and filter on the server side (`-Filter`, `-Property`).
