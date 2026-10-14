#Requires -Version 7.4
#Requires -Modules Microsoft.Graph.Reports
<#
.SYNOPSIS
    Exports MFA / authentication method registration status for all users to CSV.
.DESCRIPTION
    Uses the Graph report reports/authenticationMethods/userRegistrationDetails via
    Get-MgReportAuthenticationMethodUserRegistrationDetail (Microsoft.Graph SDK v2).
    Requires Connect-MgGraph with AuditLog.Read.All (delegated or application) and an
    Entra ID P1/P2 licensed tenant. Delegated callers also need Reports Reader or higher.
.PARAMETER IncludeGuests
    Include guest users (excluded by default).
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-MFARegistrationReport.ps1
#>
[CmdletBinding()]
param(
    [switch]$IncludeGuests,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-MgContext)) { throw 'Not connected. Run Connect-MgGraph first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$details = Get-MgReportAuthenticationMethodUserRegistrationDetail -All
if (-not $IncludeGuests) { $details = $details | Where-Object UserType -ne 'guest' }

$rows = $details | ForEach-Object {
    [pscustomobject]@{
        UserPrincipalName      = $_.UserPrincipalName
        DisplayName            = $_.UserDisplayName
        UserType               = $_.UserType
        IsAdmin                = $_.IsAdmin
        IsMfaRegistered        = $_.IsMfaRegistered
        IsMfaCapable           = $_.IsMfaCapable
        IsPasswordlessCapable  = $_.IsPasswordlessCapable
        IsSsprRegistered       = $_.IsSsprRegistered
        DefaultMfaMethod       = $_.DefaultMfaMethod
        MethodsRegistered      = $_.MethodsRegistered -join ';'
        LastUpdated            = $_.LastUpdatedDateTime
    }
}
$file = Join-Path $OutputFolder "MFARegistration-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv -Path $file -NoTypeInformation

$total = @($rows).Count
$capable = @($rows | Where-Object IsMfaCapable).Count
$adminsNoMfa = @($rows | Where-Object { $_.IsAdmin -and -not $_.IsMfaCapable }).Count
$pct = if ($total) { [math]::Round($capable / $total * 100, 1) } else { 0 }
Write-Information "Users: $total  MFA capable: $capable ($pct%)  Admins without MFA: $adminsNoMfa -> $file" -InformationAction Continue
