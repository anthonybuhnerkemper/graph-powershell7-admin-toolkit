function Get-DLPPolicyReport {
    <#
    .SYNOPSIS
        Exports Microsoft Purview DLP compliance policies and their rules to CSV.
    .DESCRIPTION
        Requires an active Connect-IPPSSession. Read-only. One row per rule, joined with
        its parent policy, so you can review mode, locations, and actions in one sheet.
    .PARAMETER OutputFolder
        Folder for CSV output. Defaults to ./output.
    .EXAMPLE
        Get-DLPPolicyReport
    .NOTES
        Role required: Compliance Administrator or DLP Compliance Management (view).
    #>
    [CmdletBinding()]
    param(
        [string]$OutputFolder = (Join-Path (Get-Location) 'output')
    )
    $ErrorActionPreference = 'Stop'
    if (-not (Get-Command Get-DlpCompliancePolicy -ErrorAction SilentlyContinue)) {
        throw 'Get-DlpCompliancePolicy not found. Run Connect-IPPSSession first.'
    }
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

    $rows = foreach ($policy in Get-DlpCompliancePolicy) {
        $rules = @(Get-DlpComplianceRule -Policy $policy.Name)
        if ($rules.Count -eq 0) { $rules = @($null) }
        foreach ($rule in $rules) {
            [pscustomobject]@{
                Policy            = $policy.Name
                Mode              = $policy.Mode
                Enabled           = $policy.Enabled
                Workload          = $policy.Workload
                ExchangeLocation  = $policy.ExchangeLocation.Name -join ';'
                SharePointLocation = $policy.SharePointLocation.Name -join ';'
                OneDriveLocation  = $policy.OneDriveLocation.Name -join ';'
                TeamsLocation     = $policy.TeamsLocation.Name -join ';'
                Rule              = $rule.Name
                RuleDisabled      = $rule.Disabled
                SensitiveInfoTypes = ($rule.ContentContainsSensitiveInformation | ForEach-Object { $_.name }) -join ';'
                BlockAccess       = $rule.BlockAccess
                NotifyUser        = $rule.NotifyUser -join ';'
                GenerateIncidentReport = $rule.GenerateIncidentReport -join ';'
            }
        }
    }
    $file = Join-Path $OutputFolder "DLPPolicies-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
    $rows | Export-Csv -Path $file -NoTypeInformation
    Write-Information "DLP rows: $(@($rows).Count) -> $file" -InformationAction Continue
}

