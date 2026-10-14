function Get-RetentionPolicyReport {
    <#
    .SYNOPSIS
        Exports Microsoft Purview retention policies, rules, and retention labels to CSV.
    .DESCRIPTION
        Requires an active Connect-IPPSSession. Read-only.
    .PARAMETER OutputFolder
        Folder for CSV output. Defaults to ./output.
    .EXAMPLE
        Get-RetentionPolicyReport
    .NOTES
        Role required: Compliance Administrator or Records Management (view).
    #>
    [CmdletBinding()]
    param(
        [string]$OutputFolder = (Join-Path (Get-Location) 'output')
    )
    $ErrorActionPreference = 'Stop'
    if (-not (Get-Command Get-RetentionCompliancePolicy -ErrorAction SilentlyContinue)) {
        throw 'Get-RetentionCompliancePolicy not found. Run Connect-IPPSSession first.'
    }
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmm'

    $policies = foreach ($policy in Get-RetentionCompliancePolicy -DistributionDetail) {
        $rule = Get-RetentionComplianceRule -Policy $policy.Name | Select-Object -First 1
        [pscustomobject]@{
            Policy              = $policy.Name
            Enabled             = $policy.Enabled
            Mode                = $policy.Mode
            DistributionStatus  = $policy.DistributionStatus
            ExchangeLocation    = $policy.ExchangeLocation.Name -join ';'
            SharePointLocation  = $policy.SharePointLocation.Name -join ';'
            OneDriveLocation    = $policy.OneDriveLocation.Name -join ';'
            ModernGroupLocation = $policy.ModernGroupLocation.Name -join ';'
            TeamsChatLocation   = $policy.TeamsChatLocation.Name -join ';'
            RetentionDuration   = $rule.RetentionDuration
            RetentionAction     = $rule.RetentionComplianceAction
            ExpirationDateOption = $rule.ExpirationDateOption
        }
    }
    $policyFile = Join-Path $OutputFolder "RetentionPolicies-$stamp.csv"
    $policies | Export-Csv -Path $policyFile -NoTypeInformation

    $labels = Get-ComplianceTag | Select-Object Name, RetentionAction, RetentionDuration, RetentionType, IsRecordLabel, Regulatory, WhenChangedUTC
    $labelFile = Join-Path $OutputFolder "RetentionLabels-$stamp.csv"
    $labels | Export-Csv -Path $labelFile -NoTypeInformation

    Write-Information "Policies: $(@($policies).Count) -> $policyFile" -InformationAction Continue
    Write-Information "Labels: $(@($labels).Count) -> $labelFile" -InformationAction Continue
}

