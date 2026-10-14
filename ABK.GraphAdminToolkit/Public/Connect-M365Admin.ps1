<#
.SYNOPSIS
    Connects to Microsoft Graph, Exchange Online, and Security & Compliance (Purview) PowerShell.

.DESCRIPTION
    Dot-source this file, then call Connect-M365Admin. Supports two modes:
      * Certificate (app-only): pass -ClientId, -TenantId, -Organization and either
        -CertificateThumbprint (cert in the CurrentUser\My store on Windows) or
        -CertificatePath (PFX file; password read from the M365_CERT_PASSWORD env var).
      * Interactive (delegated): pass -Interactive and optionally -UserPrincipalName.
    Values can also come from environment variables: M365_TENANT_ID, M365_CLIENT_ID,
    M365_CERT_THUMBPRINT, M365_ORGANIZATION. No secrets are stored in this repo.

.PARAMETER Service
    Which services to connect. Defaults to Graph, ExchangeOnline and Purview.

.PARAMETER GraphScopes
    Delegated scopes requested in interactive mode.

.EXAMPLE
    Connect-M365Admin
    Connect-M365Admin -Interactive -UserPrincipalName admin@contoso.onmicrosoft.com

.EXAMPLE
    $env:M365_TENANT_ID = '00000000-0000-0000-0000-000000000000'
    $env:M365_CLIENT_ID = '00000000-0000-0000-0000-000000000000'
    $env:M365_CERT_THUMBPRINT = '0000000000000000000000000000000000000000'
    $env:M365_ORGANIZATION = 'contoso.onmicrosoft.com'
    Connect-M365Admin

.NOTES
    Requires Microsoft.Graph.Authentication (SDK v2) and ExchangeOnlineManagement v3.
#>

function Connect-M365Admin {
    [CmdletBinding(DefaultParameterSetName = 'Certificate')]
    param(
        [ValidateSet('Graph', 'ExchangeOnline', 'Purview')]
        [string[]]$Service = @('Graph', 'ExchangeOnline', 'Purview'),

        [Parameter(ParameterSetName = 'Certificate')]
        [string]$TenantId = $env:M365_TENANT_ID,

        [Parameter(ParameterSetName = 'Certificate')]
        [string]$ClientId = $env:M365_CLIENT_ID,

        [Parameter(ParameterSetName = 'Certificate')]
        [string]$CertificateThumbprint = $env:M365_CERT_THUMBPRINT,

        [Parameter(ParameterSetName = 'Certificate')]
        [string]$CertificatePath,

        [Parameter(ParameterSetName = 'Certificate')]
        [string]$Organization = $env:M365_ORGANIZATION,

        [Parameter(Mandatory, ParameterSetName = 'Interactive')]
        [switch]$Interactive,

        [Parameter(ParameterSetName = 'Interactive')]
        [string]$UserPrincipalName,

        [Parameter(ParameterSetName = 'Interactive')]
        [string[]]$GraphScopes = @(
            'User.Read.All', 'Directory.Read.All', 'Policy.Read.All',
            'AuditLog.Read.All', 'Reports.Read.All', 'RoleManagement.Read.Directory',
            'SecurityEvents.Read.All', 'UserAuthenticationMethod.Read.All'
        )
    )

    $ErrorActionPreference = 'Stop'

    # Build the certificate object once when a PFX file is used.
    $certificate = $null
    if ($PSCmdlet.ParameterSetName -eq 'Certificate') {
        foreach ($name in 'TenantId', 'ClientId', 'Organization') {
            if (-not (Get-Variable -Name $name -ValueOnly)) {
                throw "Missing $name. Pass it as a parameter or set the matching M365_* environment variable."
            }
        }
        if ($CertificatePath) {
            $pfxPassword = $env:M365_CERT_PASSWORD
            $certificate = [System.Security.Cryptography.X509Certificates.X509Certificate2]::new(
                (Resolve-Path $CertificatePath).Path, $pfxPassword)
        }
        elseif (-not $CertificateThumbprint) {
            throw 'Provide -CertificateThumbprint or -CertificatePath for app-only auth.'
        }
    }

    if ('Graph' -in $Service) {
        Write-Verbose 'Connecting to Microsoft Graph...'
        if ($Interactive) {
            Connect-MgGraph -Scopes $GraphScopes -NoWelcome
        }
        elseif ($certificate) {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -Certificate $certificate -NoWelcome
        }
        else {
            Connect-MgGraph -TenantId $TenantId -ClientId $ClientId -CertificateThumbprint $CertificateThumbprint -NoWelcome
        }
        $ctx = Get-MgContext
        Write-Information "Graph: $($ctx.AuthType) as $($ctx.Account ?? $ctx.AppName) in tenant $($ctx.TenantId)" -InformationAction Continue
    }

    # Common splat for EXO and IPPS (same auth model, different endpoint).
    $exoParams = @{ ShowBanner = $false }
    if ($Interactive) {
        if ($UserPrincipalName) { $exoParams.UserPrincipalName = $UserPrincipalName }
    }
    else {
        $exoParams.AppId = $ClientId
        $exoParams.Organization = $Organization
        if ($certificate) { $exoParams.Certificate = $certificate }
        else { $exoParams.CertificateThumbprint = $CertificateThumbprint }
    }

    if ('ExchangeOnline' -in $Service) {
        Write-Verbose 'Connecting to Exchange Online...'
        Connect-ExchangeOnline @exoParams
        Write-Information 'Exchange Online: connected' -InformationAction Continue
    }

    if ('Purview' -in $Service) {
        Write-Verbose 'Connecting to Security & Compliance (Purview)...'
        $ippsParams = $exoParams.Clone()
        $ippsParams.Remove('ShowBanner')
        Connect-IPPSSession @ippsParams
        Write-Information 'Purview (IPPS): connected' -InformationAction Continue
    }
}

