#Requires -Version 7.4
#Requires -Modules Microsoft.Graph.Users
<#
.SYNOPSIS
    Finds guest users with no sign-in within a given number of days and exports them to CSV.
.DESCRIPTION
    Requires Connect-MgGraph with User.Read.All and AuditLog.Read.All (signInActivity
    needs Entra ID P1). Read-only: review the CSV before removing any account.
.PARAMETER DaysInactive
    Guests whose last sign-in (interactive or non-interactive) is older than this are stale. Default 90.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-StaleGuestUsers.ps1 -DaysInactive 120
#>
[CmdletBinding()]
param(
    [ValidateRange(1, 3650)][int]$DaysInactive = 90,
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-MgContext)) { throw 'Not connected. Run Connect-MgGraph first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$cutoff = (Get-Date).ToUniversalTime().AddDays(-$DaysInactive)
$guests = Get-MgUser -All -Filter "userType eq 'Guest'" `
    -Property Id, DisplayName, Mail, UserPrincipalName, CreatedDateTime, AccountEnabled, ExternalUserState, SignInActivity

$rows = foreach ($g in $guests) {
    $last = @($g.SignInActivity.LastSignInDateTime, $g.SignInActivity.LastNonInteractiveSignInDateTime) |
        Where-Object { $_ } | Sort-Object -Descending | Select-Object -First 1
    # Never signed in: judge by creation date so brand-new invites are not flagged.
    $reference = $last ?? $g.CreatedDateTime
    if ($reference -lt $cutoff) {
        [pscustomobject]@{
            DisplayName       = $g.DisplayName
            Mail              = $g.Mail
            UserPrincipalName = $g.UserPrincipalName
            Id                = $g.Id
            AccountEnabled    = $g.AccountEnabled
            InvitationState   = $g.ExternalUserState
            Created           = $g.CreatedDateTime
            LastSignIn        = $last
            DaysSinceActivity = [int]((Get-Date).ToUniversalTime() - $reference).TotalDays
        }
    }
}
$rows = $rows | Sort-Object DaysSinceActivity -Descending
$file = Join-Path $OutputFolder "StaleGuests-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv -Path $file -NoTypeInformation
Write-Information "Guests: $(@($guests).Count)  Stale (>$DaysInactive days): $(@($rows).Count) -> $file" -InformationAction Continue
