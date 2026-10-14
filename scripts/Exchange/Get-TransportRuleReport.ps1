#Requires -Version 7.4
<#
.SYNOPSIS
    Exports Exchange Online mail flow (transport) rules to CSV.
.DESCRIPTION
    Requires Connect-ExchangeOnline. Read-only. Highlights rules that redirect, BCC,
    or bypass spam filtering (SetSCL -1), which are common persistence or risk indicators.
.PARAMETER OutputFolder
    Folder for CSV output. Defaults to ./output.
.EXAMPLE
    ./Get-TransportRuleReport.ps1
#>
[CmdletBinding()]
param(
    [string]$OutputFolder = (Join-Path (Get-Location) 'output')
)
$ErrorActionPreference = 'Stop'
if (-not (Get-Command Get-TransportRule -ErrorAction SilentlyContinue)) {
    throw 'Get-TransportRule not found. Run Connect-ExchangeOnline first.'
}
New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

$rows = Get-TransportRule | Sort-Object Priority | ForEach-Object {
    [pscustomobject]@{
        Name               = $_.Name
        Priority           = $_.Priority
        State              = $_.State
        Mode               = $_.Mode
        Description        = ($_.Description -replace '\s+', ' ').Trim()
        RedirectTo         = $_.RedirectMessageTo -join ';'
        BlindCopyTo        = $_.BlindCopyTo -join ';'
        SetSCL             = $_.SetSCL
        BypassesSpamFilter = ($_.SetSCL -eq -1)
        WhenChanged        = $_.WhenChanged
    }
}
$file = Join-Path $OutputFolder "TransportRules-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
$rows | Export-Csv -Path $file -NoTypeInformation
Write-Information "Rules: $(@($rows).Count) -> $file" -InformationAction Continue
