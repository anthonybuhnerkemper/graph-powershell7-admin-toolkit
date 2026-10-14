function Get-SensitivityLabelReport {
    <#
    .SYNOPSIS
        Exports Microsoft Purview sensitivity labels and label publishing policies to CSV.
    .DESCRIPTION
        Requires an active Connect-IPPSSession (see scripts/Connect/Connect-M365Admin).
        Read-only. Produces two CSV files: labels and label policies.
    .PARAMETER OutputFolder
        Folder for CSV output. Created if missing. Defaults to ./output.
    .EXAMPLE
        Get-SensitivityLabelReport -OutputFolder ./output
    .NOTES
        Role required: Compliance Data Administrator or Information Protection Reader.
    #>
    [CmdletBinding()]
    param(
        [string]$OutputFolder = (Join-Path (Get-Location) 'output')
    )
    $ErrorActionPreference = 'Stop'
    if (-not (Get-Command Get-Label -ErrorAction SilentlyContinue)) {
        throw 'Get-Label not found. Run Connect-IPPSSession first.'
    }
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmm'

    $labels = Get-Label | Sort-Object Priority | ForEach-Object {
        [pscustomobject]@{
            DisplayName  = $_.DisplayName
            Name         = $_.Name
            Guid         = $_.Guid
            Priority     = $_.Priority
            ParentId     = $_.ParentId
            ContentType  = $_.ContentType -join ';'
            Disabled     = $_.Disabled
            Tooltip      = $_.Tooltip
            WhenChanged  = $_.WhenChangedUTC
        }
    }
    $labelFile = Join-Path $OutputFolder "SensitivityLabels-$stamp.csv"
    $labels | Export-Csv -Path $labelFile -NoTypeInformation

    $policies = Get-LabelPolicy | ForEach-Object {
        [pscustomobject]@{
            Name             = $_.Name
            Enabled          = $_.Enabled
            Labels           = $_.Labels -join ';'
            ExchangeLocation = $_.ExchangeLocation.Name -join ';'
            Mode             = $_.Mode
            DistributionStatus = $_.DistributionStatus
            WhenChanged      = $_.WhenChangedUTC
        }
    }
    $policyFile = Join-Path $OutputFolder "SensitivityLabelPolicies-$stamp.csv"
    $policies | Export-Csv -Path $policyFile -NoTypeInformation

    Write-Information "Labels: $(@($labels).Count) -> $labelFile" -InformationAction Continue
    Write-Information "Policies: $(@($policies).Count) -> $policyFile" -InformationAction Continue
}

