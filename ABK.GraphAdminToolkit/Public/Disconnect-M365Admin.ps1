<#
.SYNOPSIS
    Disconnects all Microsoft Graph, Exchange Online, and Purview sessions.
.DESCRIPTION
    Dot-source this file, then call Disconnect-M365Admin. Safe to run when not connected.
.EXAMPLE
    Disconnect-M365Admin
    Disconnect-M365Admin
#>
function Disconnect-M365Admin {
    [CmdletBinding()]
    param()

    if (Get-Command Get-MgContext -ErrorAction SilentlyContinue) {
        if (Get-MgContext) { Disconnect-MgGraph | Out-Null; Write-Verbose 'Graph disconnected.' }
    }
    # Disconnect-ExchangeOnline closes both EXO and IPPS sessions.
    if (Get-Command Disconnect-ExchangeOnline -ErrorAction SilentlyContinue) {
        Disconnect-ExchangeOnline -Confirm:$false -ErrorAction SilentlyContinue
        Write-Verbose 'Exchange Online / Purview disconnected.'
    }
    Write-Information 'All M365 admin sessions closed.' -InformationAction Continue
}

