#Requires -Version 7.4
#Requires -Modules Microsoft.Graph.Security
<#
.SYNOPSIS
    Summarizes Microsoft Secure Score and exports per-control scores to CSV.
.DESCRIPTION
    Requires Connect-MgGraph with SecurityEvents.Read.All. Read-only. Pulls the latest
    secure score snapshot, joins each control with its profile (title, max score, category),
    and sorts by points still available.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-SecureScoreSummary.ps1
#>
[CmdletBinding()]
param(
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-MgContext)) { throw 'Not connected. Run Connect-MgGraph first.' }
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$score = Get-MgSecuritySecureScore -Top 1
if (-not $score) { throw 'No secure score data returned.' }

$profiles = @{}
Get-MgSecuritySecureScoreControlProfile -All | ForEach-Object { $profiles[$_.Id] = $_ }

$rows = $score.ControlScores | ForEach-Object {
    $p = $profiles[$_.ControlName]
    $max = [double]($p.MaxScore ?? 0)
    [pscustomobject]@{
        Control     = $_.ControlName
        Title       = $p.Title
        Category    = $_.ControlCategory
        Score       = [double]$_.Score
        MaxScore    = $max
        Remaining   = [math]::Max(0, $max - [double]$_.Score)
        Service     = $p.Service
        UserImpact  = $p.UserImpact
        Deprecated  = $p.Deprecated
    }
} | Sort-Object Remaining -Descending

$file = Join-Path $OutputFolder "SecureScore-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv -Path $file -NoTypeInformation

$pct = if ($score.MaxScore) { [math]::Round($score.CurrentScore / $score.MaxScore * 100, 1) } else { 0 }
[pscustomobject]@{
    Date         = $score.CreatedDateTime
    CurrentScore = $score.CurrentScore
    MaxScore     = $score.MaxScore
    Percent      = $pct
    TopGaps      = ($rows | Select-Object -First 5 -ExpandProperty Title) -join '; '
    CsvPath      = $file
}
