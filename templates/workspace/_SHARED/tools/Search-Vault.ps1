[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Query,
    [string]$VaultRoot = '__VAULT_ROOT__',
    [int]$Limit = 10,
    [ValidateSet('all', 'drafts', 'curated', 'compiled')]
    [string]$Scope = 'all'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$noteFiles = Get-ChildItem -LiteralPath $VaultRoot -Recurse -Filter '*.md' -File

switch ($Scope) {
    'drafts' {
        $noteFiles = $noteFiles | Where-Object { $_.FullName -match '\\10_Inbox\\Agent Drafts\\' }
    }
    'curated' {
        $noteFiles = $noteFiles | Where-Object { $_.FullName -match '\\(20_Projects|30_Knowledge|40_Decisions|50_Prompts|60_References)\\' }
    }
    'compiled' {
        $noteFiles = $noteFiles | Where-Object { $_.FullName -match '\\00_System\\' }
    }
}

$results = $noteFiles |
    Select-String -Pattern $Query -SimpleMatch |
    Select-Object -First $Limit

if (-not $results) {
    Write-Host "No results for '$Query'."
    exit 0
}

foreach ($result in $results) {
    "{0}:{1}: {2}" -f $result.Path, $result.LineNumber, $result.Line.Trim()
}
