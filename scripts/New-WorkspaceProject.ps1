[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$WorkspaceRoot,
    [Parameter(Mandatory = $true)]
    [string]$ProjectName,
    [ValidateSet('software', 'ai-pipeline', 'research')]
    [string]$ProjectType = 'software'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$projectRoot = Join-Path $WorkspaceRoot $ProjectName

if (Test-Path -LiteralPath $projectRoot) {
    throw "Project already exists: $projectRoot"
}

New-Item -ItemType Directory -Force -Path `
    $projectRoot, `
    (Join-Path $projectRoot '.claude'), `
    (Join-Path $projectRoot '.claude\rules') | Out-Null

switch ($ProjectType) {
    'software' {
        New-Item -ItemType Directory -Force -Path `
            (Join-Path $projectRoot 'docs'), `
            (Join-Path $projectRoot 'src') | Out-Null
    }
    'ai-pipeline' {
        New-Item -ItemType Directory -Force -Path `
            (Join-Path $projectRoot '00_MASTER_SYSTEM'), `
            (Join-Path $projectRoot '01_REFERENCES'), `
            (Join-Path $projectRoot '02_PROMPTS'), `
            (Join-Path $projectRoot '03_GENERATION'), `
            (Join-Path $projectRoot '04_BUILD'), `
            (Join-Path $projectRoot '05_FINAL'), `
            (Join-Path $projectRoot 'docs') | Out-Null
    }
    'research' {
        New-Item -ItemType Directory -Force -Path `
            (Join-Path $projectRoot 'docs'), `
            (Join-Path $projectRoot 'notes'), `
            (Join-Path $projectRoot 'references'), `
            (Join-Path $projectRoot 'outputs') | Out-Null
    }
}

$readme = @"
# $ProjectName

Describe the project, intended outcomes, and operating boundaries here.
"@

$agents = @"
# $ProjectName

This is a real project root.

## Rules

- Keep operational truth close to the code.
- Use `docs/` for architecture, workflow, and decisions that matter to the project.
- Add deeper `AGENTS.override.md` files only when a subtree genuinely needs different rules.
"@

$claude = @"
@AGENTS.md

## Claude Additions

- Keep this file short.
- Move path-specific rules into `.claude/rules/`.
"@

$overview = @"
# Overview

Document architecture, boundaries, and important commands here.
"@

$changelog = @"
# Changelog

Track meaningful changes, decisions, and milestones here.
"@

$deliveryRule = @"
# Local Delivery Rules

- keep this project root clean
- move enduring project truth into `docs/`
- only add deeper override files when a subtree truly needs different behavior
"@

$sourceOverride = @"
# Source Folder Override

- treat `src/` as the implementation subtree
- keep architecture and workflow truth in `../docs/`
- prefer verification close to the changed code
"@

Set-Content -LiteralPath (Join-Path $projectRoot 'README.md') -Value $readme -NoNewline
Set-Content -LiteralPath (Join-Path $projectRoot 'AGENTS.md') -Value $agents -NoNewline
Set-Content -LiteralPath (Join-Path $projectRoot 'CLAUDE.md') -Value $claude -NoNewline
Set-Content -LiteralPath (Join-Path $projectRoot 'docs\OVERVIEW.md') -Value $overview -NoNewline
Set-Content -LiteralPath (Join-Path $projectRoot 'docs\CHANGELOG.md') -Value $changelog -NoNewline
Set-Content -LiteralPath (Join-Path $projectRoot '.claude\rules\delivery.md') -Value $deliveryRule -NoNewline

if ($ProjectType -eq 'software') {
    Set-Content -LiteralPath (Join-Path $projectRoot 'src\AGENTS.override.md') -Value $sourceOverride -NoNewline
}

Write-Host "Created $ProjectType project: $projectRoot"
