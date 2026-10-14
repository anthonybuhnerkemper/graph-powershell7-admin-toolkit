function Get-PrivilegedRoleAssignments {
    <#
    .SYNOPSIS
        Exports active (and optionally PIM-eligible) Entra ID directory role assignments to CSV.
    .DESCRIPTION
        Requires Connect-MgGraph with RoleManagement.Read.Directory. -IncludeEligible also
        needs RoleEligibilitySchedule.Read.Directory and Entra ID P2. Read-only.
    .PARAMETER PrivilegedOnly
        Only include roles flagged isPrivileged by Microsoft.
    .PARAMETER IncludeEligible
        Include PIM eligible assignments.
    .PARAMETER OutputFolder
        Folder for CSV output. Defaults to ./output.
    .EXAMPLE
        Get-PrivilegedRoleAssignments -PrivilegedOnly -IncludeEligible
    #>
    [CmdletBinding()]
    param(
        [switch]$PrivilegedOnly,
        [switch]$IncludeEligible,
        [string]$OutputFolder = (Join-Path (Get-Location) 'output')
    )
    $ErrorActionPreference = 'Stop'
    if (-not (Get-MgContext)) { throw 'Not connected. Run Connect-MgGraph first.' }
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null

    $roles = @{}
    Get-MgRoleManagementDirectoryRoleDefinition -All | ForEach-Object { $roles[$_.Id] = $_ }

    function ConvertTo-Row {
        param($Assignment, [string]$Type, [bool]$OnlyPrivileged)
        $role = $roles[$Assignment.RoleDefinitionId]
        if ($OnlyPrivileged -and -not $role.AdditionalProperties['isPrivileged']) { return }
        $p = $Assignment.Principal.AdditionalProperties
        [pscustomobject]@{
            Role          = $role.DisplayName
            IsPrivileged  = $role.AdditionalProperties['isPrivileged']
            AssignmentType = $Type
            PrincipalName = $p['displayName']
            PrincipalUPN  = $p['userPrincipalName']
            PrincipalType = ($p['@odata.type'] -replace '#microsoft.graph.', '')
            PrincipalId   = $Assignment.PrincipalId
            Scope         = $Assignment.DirectoryScopeId
        }
    }

    $rows = @(Get-MgRoleManagementDirectoryRoleAssignment -All -ExpandProperty Principal |
        ForEach-Object { ConvertTo-Row -Assignment $_ -Type 'Active' -OnlyPrivileged $PrivilegedOnly.IsPresent })
    if ($IncludeEligible) {
        $rows += Get-MgRoleManagementDirectoryRoleEligibilitySchedule -All -ExpandProperty Principal |
            ForEach-Object { ConvertTo-Row -Assignment $_ -Type 'Eligible' -OnlyPrivileged $PrivilegedOnly.IsPresent }
    }
    $rows = $rows | Sort-Object Role, PrincipalName
    $file = Join-Path $OutputFolder "PrivilegedRoles-$(Get-Date -Format 'yyyyMMdd-HHmm').csv"
    $rows | Export-Csv -Path $file -NoTypeInformation
    $ga = @($rows | Where-Object { $_.Role -eq 'Global Administrator' -and $_.AssignmentType -eq 'Active' }).Count
    Write-Information "Assignments: $(@($rows).Count)  Active Global Admins: $ga -> $file" -InformationAction Continue
}

