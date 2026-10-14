#Requires -Version 7.4
<#
.SYNOPSIS
    Applies a modern-authentication baseline to Exchange Online.
.DESCRIPTION
    Requires Connect-ExchangeOnline with Exchange Administrator. Supports -WhatIf / -Confirm.
    Baseline:
      1. Organization OAuth2ClientProfileEnabled = $true (modern auth for clients)
      2. Tenant SMTP client authentication disabled (TransportConfig)
      3. Mailbox auditing on by default (AuditDisabled = $false)
      4. Optional: block automatic external forwarding in the default outbound spam policy
      5. Optional: an authentication policy that blocks basic auth for legacy protocols, set as org default
.PARAMETER BlockExternalForwarding
    Set AutoForwardingMode = Off on the default outbound spam filter policy.
.PARAMETER CreateBlockBasicAuthPolicy
    Create (if missing) and set as default an auth policy named by -AuthPolicyName.
.PARAMETER AuthPolicyName
    Name for the authentication policy. Default 'Block Basic Auth'.
.EXAMPLE
    ./Set-ModernAuthBaseline.ps1 -WhatIf
.EXAMPLE
    ./Set-ModernAuthBaseline.ps1 -BlockExternalForwarding -Confirm:$false
#>
[CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
param(
    [switch]$BlockExternalForwarding,
    [switch]$CreateBlockBasicAuthPolicy,
    [string]$AuthPolicyName = 'Block Basic Auth'
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command Set-OrganizationConfig -ErrorAction SilentlyContinue)) {
    throw 'Set-OrganizationConfig not found. Run Connect-ExchangeOnline first.'
}

$org = Get-OrganizationConfig
if (-not $org.OAuth2ClientProfileEnabled) {
    if ($PSCmdlet.ShouldProcess('OrganizationConfig', 'Enable OAuth2ClientProfile (modern auth)')) {
        Set-OrganizationConfig -OAuth2ClientProfileEnabled $true
    }
}
else { Write-Verbose 'Modern auth already enabled.' }

if ($org.AuditDisabled) {
    if ($PSCmdlet.ShouldProcess('OrganizationConfig', 'Enable mailbox auditing by default')) {
        Set-OrganizationConfig -AuditDisabled $false
    }
}
else { Write-Verbose 'Mailbox auditing already on by default.' }

if (-not (Get-TransportConfig).SmtpClientAuthenticationDisabled) {
    if ($PSCmdlet.ShouldProcess('TransportConfig', 'Disable SMTP client authentication tenant-wide')) {
        Set-TransportConfig -SmtpClientAuthenticationDisabled $true
    }
}
else { Write-Verbose 'SMTP AUTH already disabled tenant-wide.' }

if ($BlockExternalForwarding) {
    $policy = Get-HostedOutboundSpamFilterPolicy -Identity Default
    if ($policy.AutoForwardingMode -ne 'Off' -and
        $PSCmdlet.ShouldProcess('HostedOutboundSpamFilterPolicy Default', 'Set AutoForwardingMode Off')) {
        Set-HostedOutboundSpamFilterPolicy -Identity Default -AutoForwardingMode Off
    }
}

if ($CreateBlockBasicAuthPolicy) {
    if (-not (Get-AuthenticationPolicy -Identity $AuthPolicyName -ErrorAction SilentlyContinue)) {
        if ($PSCmdlet.ShouldProcess($AuthPolicyName, 'Create authentication policy (all basic auth blocked)')) {
            # New-AuthenticationPolicy blocks every protocol by default when no Allow* switches are passed.
            New-AuthenticationPolicy -Name $AuthPolicyName | Out-Null
        }
    }
    if ($PSCmdlet.ShouldProcess('OrganizationConfig', "Set default authentication policy to '$AuthPolicyName'")) {
        Set-OrganizationConfig -DefaultAuthenticationPolicy $AuthPolicyName
    }
}

Get-OrganizationConfig | Select-Object OAuth2ClientProfileEnabled, AuditDisabled, DefaultAuthenticationPolicy
