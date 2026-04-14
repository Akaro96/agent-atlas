[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$VaultRoot = '__VAULT_ROOT__',
    [string]$ReportDirectory
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $ReportDirectory) {
    $ReportDirectory = Join-Path $WorkspaceRoot 'active\reports'
}

New-Item -ItemType Directory -Force -Path $ReportDirectory | Out-Null

$results = New-Object System.Collections.Generic.List[object]

function Add-Result {
    param([string]$Category,[string]$Item,[string]$Status,[string]$Details)
    $results.Add([pscustomobject]@{
        Category = $Category
        Item = $Item
        Status = $Status
        Details = $Details
    })
}

function Test-RequiredPath {
    param([string]$Path,[string]$Category)
    if (Test-Path -LiteralPath $Path) {
        Add-Result $Category $Path 'PASS' 'Path exists.'
    }
    else {
        Add-Result $Category $Path 'FAIL' 'Missing required path.'
    }
}

Test-RequiredPath -Path (Join-Path $WorkspaceRoot 'README.md') -Category 'Workspace'
Test-RequiredPath -Path (Join-Path $WorkspaceRoot 'AGENTS.md') -Category 'Workspace'
Test-RequiredPath -Path (Join-Path $WorkspaceRoot 'CLAUDE.md') -Category 'Workspace'
Test-RequiredPath -Path (Join-Path $WorkspaceRoot '_INBOX') -Category 'Workspace'
Test-RequiredPath -Path (Join-Path $WorkspaceRoot '_SHARED') -Category 'Workspace'
Test-RequiredPath -Path (Join-Path $WorkspaceRoot '_ARCHIVE') -Category 'Workspace'
Test-RequiredPath -Path (Join-Path $WorkspaceRoot '_SHARED\tools\Search-Vault.ps1') -Category 'Tools'
Test-RequiredPath -Path (Join-Path $WorkspaceRoot '_SHARED\tools\New-VaultInboxNote.ps1') -Category 'Tools'
Test-RequiredPath -Path (Join-Path $WorkspaceRoot '_SHARED\tools\Sync-WorkspaceProjectDrafts.ps1') -Category 'Tools'
Test-RequiredPath -Path (Join-Path $VaultRoot 'README.md') -Category 'Vault'
Test-RequiredPath -Path (Join-Path $VaultRoot '00 Home.md') -Category 'Vault'
Test-RequiredPath -Path (Join-Path $VaultRoot '10_Inbox\Agent Drafts') -Category 'Vault'
Test-RequiredPath -Path (Join-Path $VaultRoot '_Templates') -Category 'Vault'

$topLevelProjects = Get-ChildItem -LiteralPath $WorkspaceRoot -Directory -Force | Where-Object {
    $_.Name -notlike '_*' -and $_.Name -ne '.claude' -and $_.Name -ne 'active'
}

foreach ($project in $topLevelProjects) {
    Test-RequiredPath -Path (Join-Path $project.FullName 'README.md') -Category 'Project'
    Test-RequiredPath -Path (Join-Path $project.FullName 'AGENTS.md') -Category 'Project'
    Test-RequiredPath -Path (Join-Path $project.FullName 'CLAUDE.md') -Category 'Project'
    $docsOverview = Join-Path $project.FullName 'docs\OVERVIEW.md'
    if (Test-Path -LiteralPath $docsOverview) {
        Add-Result 'Project' $docsOverview 'PASS' 'docs/OVERVIEW.md exists.'
    }
}

$syncScript = Join-Path $WorkspaceRoot '_SHARED\tools\Sync-WorkspaceProjectDrafts.ps1'
if ((Test-Path -LiteralPath $syncScript) -and (Test-Path -LiteralPath $VaultRoot)) {
    try {
        $syncJson = & $syncScript -WorkspaceRoot $WorkspaceRoot -VaultRoot $VaultRoot -AllProjects -PreviewOnly -AsJson -Quiet
        if ($syncJson) {
            $syncResult = $syncJson | ConvertFrom-Json
            foreach ($candidate in @($syncResult.Results | Where-Object { $_.Action -eq 'would-create' })) {
                Add-Result 'Knowledge' $candidate.ProjectTitle 'WARN' 'Serious project is missing vault coverage; review or create an inbox draft.'
            }
        }
    }
    catch {
        Add-Result 'Knowledge' $syncScript 'WARN' 'Project draft sync preview failed.'
    }
}

$failed = @($results | Where-Object Status -eq 'FAIL').Count
$passed = @($results | Where-Object Status -eq 'PASS').Count
$status = if ($failed -eq 0) { 'PASS' } else { 'FAIL' }
$timestamp = Get-Date -Format 'yyyyMMdd-HHmmss'
$reportPath = Join-Path $ReportDirectory "workspace-doctor-$timestamp.md"

$lines = @(
    '# Workspace Doctor Report',
    '',
    "- Generated: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')",
    "- Workspace root: $WorkspaceRoot",
    "- Vault root: $VaultRoot",
    "- Overall status: **$status**",
    "- Passed: **$passed**",
    "- Failed: **$failed**",
    '',
    '| Category | Item | Status | Details |',
    '| --- | --- | --- | --- |'
)

foreach ($row in $results) {
    $lines += "| $($row.Category) | $($row.Item) | $($row.Status) | $($row.Details) |"
}

Set-Content -LiteralPath $reportPath -Value ($lines -join [Environment]::NewLine)
Get-Content -LiteralPath $reportPath
