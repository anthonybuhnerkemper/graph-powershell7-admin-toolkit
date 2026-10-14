function Get-ConditionalAccessReport {
    <#
    .SYNOPSIS
        Exports Entra ID Conditional Access policies to CSV (and optionally raw JSON).
    .DESCRIPTION
        Requires Connect-MgGraph with Policy.Read.All. Read-only. Flattens the most useful
        conditions and controls into one row per policy. Use -IncludeJson to also save the full
        policy objects for backup or diffing.
    .PARAMETER IncludeJson
        Also write a JSON file with full policy definitions.
    .PARAMETER OutputFolder
        Folder for output. Defaults to ./output.
    .EXAMPLE
        Get-ConditionalAccessReport -IncludeJson
    #>
    [CmdletBinding()]
    param(
        [switch]$IncludeJson,
        [string]$OutputFolder = (Join-Path (Get-Location) 'output')
    )
    $ErrorActionPreference = 'Stop'
    if (-not (Get-MgContext)) { throw 'Not connected. Run Connect-MgGraph first.' }
    New-Item -ItemType Directory -Path $OutputFolder -Force | Out-Null
    $stamp = Get-Date -Format 'yyyyMMdd-HHmm'

    $policies = Get-MgIdentityConditionalAccessPolicy -All
    $rows = $policies | ForEach-Object {
        $c = $_.Conditions
        [pscustomobject]@{
            DisplayName        = $_.DisplayName
            Id                 = $_.Id
            State              = $_.State
            IncludeUsers       = $c.Users.IncludeUsers -join ';'
            ExcludeUsers       = $c.Users.ExcludeUsers -join ';'
            IncludeGroups      = $c.Users.IncludeGroups -join ';'
            ExcludeGroups      = $c.Users.ExcludeGroups -join ';'
            IncludeRoles       = $c.Users.IncludeRoles -join ';'
            IncludeApps        = $c.Applications.IncludeApplications -join ';'
            ExcludeApps        = $c.Applications.ExcludeApplications -join ';'
            ClientAppTypes     = $c.ClientAppTypes -join ';'
            Platforms          = $c.Platforms.IncludePlatforms -join ';'
            IncludeLocations   = $c.Locations.IncludeLocations -join ';'
            SignInRiskLevels   = $c.SignInRiskLevels -join ';'
            UserRiskLevels     = $c.UserRiskLevels -join ';'
            GrantOperator      = $_.GrantControls.Operator
            GrantControls      = $_.GrantControls.BuiltInControls -join ';'
            AuthStrength       = $_.GrantControls.AuthenticationStrength.DisplayName
            SessionSignInFreq  = $_.SessionControls.SignInFrequency.Value
            Modified           = $_.ModifiedDateTime
        }
    }
    $file = Join-Path $OutputFolder "ConditionalAccess-$stamp.csv"
    $rows | Export-Csv -Path $file -NoTypeInformation
    if ($IncludeJson) {
        $policies | ConvertTo-Json -Depth 10 | Set-Content -Path (Join-Path $OutputFolder "ConditionalAccess-$stamp.json")
    }
    $byState = $rows | Group-Object State | ForEach-Object { "$($_.Name)=$($_.Count)" }
    Write-Information "Policies: $(@($rows).Count) ($($byState -join ', ')) -> $file" -InformationAction Continue
}

