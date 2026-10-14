function Start-ContentSearchExport {
    <#
    .SYNOPSIS
        Creates and runs a Purview compliance (content) search, then optionally starts an export.
    .DESCRIPTION
        Example eDiscovery workflow. Requires Connect-IPPSSession with an account in the
        eDiscovery Manager role group. Every change is guarded by ShouldProcess, so run with
        -WhatIf first to preview. Note: as of 2025 Microsoft is moving export to the modern
        Purview eDiscovery experience; the 'Export' action may require the portal in some tenants.
    .PARAMETER SearchName
        Unique name for the compliance search.
    .PARAMETER ExchangeLocation
        Mailboxes to search (UPNs), or 'All'.
    .PARAMETER ContentMatchQuery
        KQL query, for example: subject:"Project Falcon" AND sent>=2026-01-01
    .PARAMETER Export
        Start an export action after the search completes.
    .PARAMETER TimeoutMinutes
        How long to wait for the search to finish.
    .EXAMPLE
        Start-ContentSearchExport -SearchName 'Case-0001' -ExchangeLocation user1@contoso.com -ContentMatchQuery 'subject:"Invoice"' -WhatIf
    .EXAMPLE
        Start-ContentSearchExport -SearchName 'Case-0001' -ExchangeLocation All -ContentMatchQuery 'from:vendor@contoso.com' -Export -Confirm
    #>
    [CmdletBinding(SupportsShouldProcess, ConfirmImpact = 'High')]
    param(
        [Parameter(Mandatory)][string]$SearchName,
        [Parameter(Mandatory)][string[]]$ExchangeLocation,
        [Parameter(Mandatory)][string]$ContentMatchQuery,
        [switch]$Export,
        [ValidateRange(1, 240)][int]$TimeoutMinutes = 30
    )
    $ErrorActionPreference = 'Stop'
    if (-not (Get-Command New-ComplianceSearch -ErrorAction SilentlyContinue)) {
        throw 'New-ComplianceSearch not found. Run Connect-IPPSSession first.'
    }

    if ($PSCmdlet.ShouldProcess($SearchName, "Create compliance search ($ContentMatchQuery)")) {
        New-ComplianceSearch -Name $SearchName -ExchangeLocation $ExchangeLocation -ContentMatchQuery $ContentMatchQuery | Out-Null
    }
    if ($PSCmdlet.ShouldProcess($SearchName, 'Start compliance search')) {
        Start-ComplianceSearch -Identity $SearchName
        $deadline = (Get-Date).AddMinutes($TimeoutMinutes)
        do {
            Start-Sleep -Seconds 20
            $search = Get-ComplianceSearch -Identity $SearchName
            Write-Verbose "Status: $($search.Status)"
        } while ($search.Status -ne 'Completed' -and (Get-Date) -lt $deadline)

        if ($search.Status -ne 'Completed') { throw "Search did not complete within $TimeoutMinutes minutes." }
        Write-Information "Items: $($search.Items)  Size: $($search.Size) bytes" -InformationAction Continue
    }
    if ($Export -and $PSCmdlet.ShouldProcess($SearchName, 'Start export action')) {
        New-ComplianceSearchAction -SearchName $SearchName -Export -Format FxStream -ExchangeArchiveFormat PerUserPst -Confirm:$false
        Write-Information 'Export started. Download it from the Purview portal (eDiscovery > Exports).' -InformationAction Continue
    }
}

