# 01 - Install PowerShell 7 and the Microsoft modules

## 1. Install PowerShell 7.4+

**Windows** (winget):
```powershell
winget install --id Microsoft.PowerShell --source winget
```
**macOS** (Homebrew): `brew install --cask powershell`
**Linux (Ubuntu)**: follow the Microsoft Learn guide "Installing PowerShell on Ubuntu", or use the snap: `sudo snap install powershell --classic`

Start it with `pwsh` and check the version:
```powershell
$PSVersionTable.PSVersion   # should be 7.4 or later
```

## 2. Trust the PowerShell Gallery (optional)
```powershell
Set-PSResourceRepository -Name PSGallery -Trusted   # PSResourceGet
# or, with PowerShellGet v2:
Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```

## 3. Install the modules
```powershell
# Microsoft Graph SDK v2 (installs all sub-modules)
Install-Module Microsoft.Graph -Scope CurrentUser

# Exchange Online + Security & Compliance (Purview) cmdlets
Install-Module ExchangeOnlineManagement -Scope CurrentUser

# Linting (optional, used by the CI workflow)
Install-Module PSScriptAnalyzer -Scope CurrentUser
```

> Tip: the full Microsoft.Graph module is large. To save time, install only what this toolkit needs:
> `Microsoft.Graph.Authentication`, `Microsoft.Graph.Users`, `Microsoft.Graph.Reports`,
> `Microsoft.Graph.Identity.SignIns`, `Microsoft.Graph.Identity.Governance`, `Microsoft.Graph.Security`.

## 4. Verify
```powershell
Get-Module Microsoft.Graph.Authentication, ExchangeOnlineManagement -ListAvailable |
    Select-Object Name, Version
```

## 5. Keep them current
```powershell
Update-Module Microsoft.Graph
Update-Module ExchangeOnlineManagement
```
Avoid having Microsoft.Graph v1 and v2 side by side. If you see assembly-load errors, uninstall old versions (see [06-troubleshooting](06-troubleshooting.md)).
