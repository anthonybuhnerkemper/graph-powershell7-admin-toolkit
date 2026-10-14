#Requires -Version 7.4
#Requires -Modules Microsoft.Graph.Identity.SignIns
<#
.SYNOPSIS
    Reports whether Entra ID security defaults are enabled, alongside Conditional Access usage.
.DESCRIPTION
    Requires Connect-MgGraph with Policy.Read.All. Read-only. Security defaults and
    Conditional Access are mutually exclusive; this script shows which model the tenant uses.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-SecurityDefaultsStatus.ps1
#>
[CmdletBinding()]
param(
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-MgContext)) { throw 'Not connected. Run Connect-MgGraph first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$defaults = Get-MgPolicyIdentitySecurityDefaultEnforcementPolicy
$ca = @(Get-MgIdentityConditionalAccessPolicy -All)

$result = [pscustomobject]@{
    TenantId                 = (Get-MgContext).TenantId
    SecurityDefaultsEnabled  = $defaults.IsEnabled
    CAPoliciesTotal          = $ca.Count
    CAPoliciesEnabled        = @($ca | Where-Object State -eq 'enabled').Count
    CAPoliciesReportOnly     = @($ca | Where-Object State -eq 'enabledForReportingButNotEnforced').Count
    Recommendation           = if ($defaults.IsEnabled) { 'Security defaults on. Fine for small tenants; move to Conditional Access when you need granular control (Entra ID P1).' }
                               elseif (@($ca | Where-Object State -eq 'enabled').Count -eq 0) { 'WARNING: security defaults off and no enabled CA policies. MFA may not be enforced.' }
                               else { 'Conditional Access in use. Verify MFA and legacy-auth blocking policies cover all users.' }
    CheckedAt                = Get-Date
}
$result | Export-Csv -Path (Join-Path $OutputFolder "SecurityDefaults-$(Get-Date -Format 'yyyyMMdd-HHmm').csv") -NoTypeInformation
$result
