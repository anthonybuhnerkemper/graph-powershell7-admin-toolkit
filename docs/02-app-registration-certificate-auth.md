# 02 - App registration with certificate authentication

App-only (unattended) auth uses an Entra ID app registration plus a certificate. Certificates are preferred over client secrets: the private key never leaves your machine or key vault.

## 1. Create a self-signed certificate (Windows)

```powershell
$cert = New-SelfSignedCertificate `
    -Subject 'CN=M365AdminToolkit' `
    -CertStoreLocation 'Cert:\CurrentUser\My' `
    -KeyExportPolicy Exportable `
    -KeySpec Signature `
    -KeyLength 2048 `
    -KeyAlgorithm RSA `
    -HashAlgorithm SHA256 `
    -NotAfter (Get-Date).AddYears(1)

# Public key (.cer) to upload to Entra ID
New-Item -ItemType Directory -Path ./certs -Force | Out-Null
Export-Certificate -Cert $cert -FilePath ./certs/M365AdminToolkit.cer

$cert.Thumbprint   # save this; you'll use it in M365_CERT_THUMBPRINT
```

Optional: export a password-protected PFX for another machine or Azure Automation. Never commit it (`*.pfx` and `certs/` are in `.gitignore`):
```powershell
$pfxPassword = Read-Host -AsSecureString -Prompt 'PFX password'
Export-PfxCertificate -Cert $cert -FilePath ./certs/M365AdminToolkit.pfx -Password $pfxPassword
```

On macOS/Linux, create the certificate with OpenSSL and load the PFX with `-CertificatePath`. Put its password in the `M365_CERT_PASSWORD` environment variable.

> Production: store the certificate in Azure Key Vault, or use a **managed identity** from Azure Automation / Azure Functions (`Connect-MgGraph -Identity`, `Connect-ExchangeOnline -ManagedIdentity -Organization contoso.onmicrosoft.com`).

## 2. Register the application

1. Go to the **Microsoft Entra admin center**, then **Identity > Applications > App registrations > New registration**.
2. Name: `M365 Admin Toolkit`. Supported account types: **this organizational directory only**. No redirect URI.
3. Click **Register**. Copy the **Application (client) ID** and **Directory (tenant) ID**.

## 3. Upload the certificate

**Certificates & secrets > Certificates > Upload certificate**, then select `M365AdminToolkit.cer`. Confirm the thumbprint matches.

## 4. Add API permissions

**API permissions > Add a permission**:

- **Microsoft Graph > Application permissions:** `AuditLog.Read.All`, `Policy.Read.All`, `SecurityEvents.Read.All`, `RoleManagement.Read.Directory`, `User.Read.All` (and `RoleEligibilitySchedule.Read.Directory` if you use PIM)
- **APIs my organization uses > Office 365 Exchange Online > Application permissions:** `Exchange.ManageAsApp`

## 5. Grant admin consent

Click **Grant admin consent for Contoso** and confirm that every permission shows a green check.

## 6. Assign an Entra role for Exchange / Purview

`Exchange.ManageAsApp` alone is not enough. The app's service principal also needs a directory role:

1. **Roles & admins**, then pick a role (for example **Exchange Administrator** for changes, **Global Reader** for read-only, **Compliance Administrator** for Purview).
2. **Add assignments**, then search for the app name and assign it.

## 7. Test

```powershell
$env:M365_TENANT_ID       = '00000000-0000-0000-0000-000000000000'
$env:M365_CLIENT_ID       = '00000000-0000-0000-0000-000000000000'
$env:M365_CERT_THUMBPRINT = '<thumbprint>'
$env:M365_ORGANIZATION    = 'contoso.onmicrosoft.com'

. ./scripts/Connect/Connect-M365Admin.ps1
Connect-M365Admin -Verbose
Get-MgContext | Select-Object AuthType, AppName, Scopes
```

## Certificate rotation
Create the new certificate before the old one expires, upload it alongside the old one, switch `M365_CERT_THUMBPRINT`, then remove the old certificate from the app.
