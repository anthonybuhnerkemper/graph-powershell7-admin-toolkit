#Requires -Version 7.4
<#
.SYNOPSIS
    Exports Defender for Office 365 / EOP anti-phishing policies and their key settings to CSV.
.DESCRIPTION
    Requires Connect-ExchangeOnline. Read-only. Joins each policy with its rule
    (scope and priority). Impersonation settings require Defender for Office 365 Plan 1+.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-AntiPhishPolicyReport.ps1
#>
[CmdletBinding()]
param(
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command Get-AntiPhishPolicy -ErrorAction SilentlyContinue)) {
    throw 'Get-AntiPhishPolicy not found. Run Connect-ExchangeOnline first.'
}
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$rules = @{}
Get-AntiPhishRule | ForEach-Object { $rules[$_.AntiPhishPolicy] = $_ }

$rows = Get-AntiPhishPolicy | ForEach-Object {
    $rule = $rules[$_.Name]
    [pscustomobject]@{
        Policy                       = $_.Name
        IsDefault                    = $_.IsDefault
        Enabled                      = $_.Enabled
        RulePriority                 = $rule.Priority
        RuleState                    = $rule.State
        SentToDomains                = $rule.RecipientDomainIs -join ';'
        PhishThresholdLevel          = $_.PhishThresholdLevel
        EnableSpoofIntelligence      = $_.EnableSpoofIntelligence
        AuthenticationFailAction     = $_.AuthenticationFailAction
        HonorDmarcPolicy             = $_.HonorDmarcPolicy
        EnableMailboxIntelligence    = $_.EnableMailboxIntelligence
        EnableMailboxIntelligenceProtection = $_.EnableMailboxIntelligenceProtection
        EnableTargetedUserProtection = $_.EnableTargetedUserProtection
        EnableOrganizationDomainsProtection = $_.EnableOrganizationDomainsProtection
        TargetedUserProtectionAction = $_.TargetedUserProtectionAction
        EnableFirstContactSafetyTips = $_.EnableFirstContactSafetyTips
        EnableUnauthenticatedSender  = $_.EnableUnauthenticatedSender
    }
}
$file = Join-Path $OutputFolder "AntiPhishPolicies-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv -Path $file -NoTypeInformation
Write-Information "Policies: $(@($rows).Count) -> $file" -InformationAction Continue
