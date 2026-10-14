#Requires -Version 7.4
<#
.SYNOPSIS
    Audits mailboxes for forwarding, inbox forwarding rules, auditing, and SMTP AUTH.
.DESCRIPTION
    Requires Connect-ExchangeOnline. Read-only. For each mailbox reports:
      * Mailbox-level forwarding (ForwardingSmtpAddress / ForwardingAddress)
      * Inbox rules that forward, redirect, or forward-as-attachment, flagging external targets
      * Whether mailbox auditing is enabled
      * Whether SMTP client authentication is enabled (per mailbox and tenant default)
.PARAMETER AcceptedDomain
    Domains treated as internal. Defaults to the tenant's accepted domains.
.PARAMETER ResultSize
    Number of mailboxes to scan. Default Unlimited.
.PARAMETER SkipInboxRules
    Skip the (slow) per-mailbox inbox rule scan.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-MailboxSecurityAudit.ps1 -ResultSize 100
.NOTES
    Role required: View-Only Organization Management or Exchange Administrator.
#>
[CmdletBinding()]
param(
    [string[]]$AcceptedDomain,
    [string]$ResultSize = 'Unlimited',
    [switch]$SkipInboxRules,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command Get-EXOMailbox -ErrorAction SilentlyContinue)) {
    throw 'Get-EXOMailbox not found. Run Connect-ExchangeOnline first.'
}
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

if (-not $AcceptedDomain) { $AcceptedDomain = (Get-AcceptedDomain).DomainName }
$tenantSmtpAuthDisabled = (Get-TransportConfig).SmtpClientAuthenticationDisabled

function Test-IsExternal {
    param([string]$Address)
    if (-not $Address) { return $false }
    # Rule targets look like "Name" [SMTP:user@contoso.com]; pull out the address.
    $addr = if ($Address -match '([\w.+-]+@[\w.-]+)') { $Matches[1] } else { $Address }
    $domain = ($addr -split '@')[-1].TrimEnd(']')
    return $domain -notin $AcceptedDomain
}

$mailboxes = Get-EXOMailbox -ResultSize $ResultSize -RecipientTypeDetails UserMailbox, SharedMailbox `
    -Properties ForwardingSmtpAddress, ForwardingAddress, DeliverToMailboxAndForward, AuditEnabled
$casLookup = @{}
Get-EXOCASMailbox -ResultSize $ResultSize -Properties SmtpClientAuthenticationDisabled |
    ForEach-Object { $casLookup[$_.PrimarySmtpAddress] = $_.SmtpClientAuthenticationDisabled }

$i = 0
$rows = foreach ($mbx in $mailboxes) {
    $i++
    Write-Progress -Activity 'Auditing mailboxes' -Status $mbx.PrimarySmtpAddress -PercentComplete ($i / @($mailboxes).Count * 100)

    $fwdRules = @()
    if (-not $SkipInboxRules) {
        $fwdRules = @(Get-InboxRule -Mailbox $mbx.PrimarySmtpAddress -ErrorAction SilentlyContinue |
            Where-Object { $_.Enabled -and ($_.ForwardTo -or $_.RedirectTo -or $_.ForwardAsAttachmentTo) })
    }
    $ruleTargets = $fwdRules | ForEach-Object { $_.ForwardTo; $_.RedirectTo; $_.ForwardAsAttachmentTo } | Where-Object { $_ }
    $mbxFwd = ($mbx.ForwardingSmtpAddress -replace '^smtp:', '')

    # $null on the CAS mailbox means "inherit tenant setting".
    $casValue = $casLookup[$mbx.PrimarySmtpAddress]
    $smtpAuthEnabled = if ($null -eq $casValue) { -not $tenantSmtpAuthDisabled } else { -not $casValue }

    [pscustomobject]@{
        Mailbox                 = $mbx.PrimarySmtpAddress
        Type                    = $mbx.RecipientTypeDetails
        ForwardingSmtpAddress   = $mbxFwd
        ForwardingAddress       = $mbx.ForwardingAddress
        DeliverAndForward       = $mbx.DeliverToMailboxAndForward
        ExternalMailboxForward  = Test-IsExternal $mbxFwd
        ForwardingRuleCount     = $fwdRules.Count
        ForwardingRuleNames     = $fwdRules.Name -join ';'
        ExternalRuleForward     = [bool]($ruleTargets | Where-Object { Test-IsExternal $_ })
        AuditEnabled            = $mbx.AuditEnabled
        SmtpAuthEnabled         = $smtpAuthEnabled
    }
}
Write-Progress -Activity 'Auditing mailboxes' -Completed

$file = Join-Path $OutputFolder "MailboxSecurityAudit-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv -Path $file -NoTypeInformation
$flagged = @($rows | Where-Object { $_.ExternalMailboxForward -or $_.ExternalRuleForward -or -not $_.AuditEnabled -or $_.SmtpAuthEnabled })
Write-Information "Mailboxes: $(@($rows).Count)  Flagged: $($flagged.Count)  Tenant SMTP AUTH disabled: $tenantSmtpAuthDisabled -> $file" -InformationAction Continue
