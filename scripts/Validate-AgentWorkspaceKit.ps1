[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot)
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$failures = New-Object System.Collections.Generic.List[string]

function Add-Failure {
    param([string]$Message)
    $failures.Add($Message)
}

function Test-PathRequired {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        Add-Failure "Missing required path: $Path"
    }
}

function Test-PowerShellSyntax {
    param([string]$Path)
    $tokens = $null
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile($Path, [ref]$tokens, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        Add-Failure "PowerShell syntax error in $Path"
    }
}

function Test-JsonFile {
    param([string]$Path)
    try {
        Get-Content -LiteralPath $Path -Raw | ConvertFrom-Json | Out-Null
    }
    catch {
        Add-Failure "Invalid JSON: $Path"
    }
}

function Test-TomlFile {
    param([string]$Path)
    try {
        & python -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb'))" $Path *> $null
    }
    catch {
        Add-Failure "Invalid TOML: $Path"
    }
}

function Test-XmlFile {
    param([string]$Path)
    try {
        [xml](Get-Content -LiteralPath $Path -Raw) | Out-Null
    }
    catch {
        Add-Failure "Invalid XML/SVG: $Path"
    }
}

function Test-VersionConsistency {
    param(
        [string]$ManifestPath,
        [string]$ChangelogPath
    )

    try {
        $manifest = Get-Content -LiteralPath $ManifestPath -Raw | ConvertFrom-Json
        $manifestVersion = [string]$manifest.version
        if (-not $manifestVersion) {
            Add-Failure "Missing manifest version in $ManifestPath"
            return
        }

        $changelog = Get-Content -LiteralPath $ChangelogPath -Raw
        $match = [regex]::Match($changelog, '(?m)^##\s+([0-9]+\.[0-9]+\.[0-9]+(?:[-A-Za-z0-9\.]+)?)\s+-\s+\d{4}-\d{2}-\d{2}\s*$')
        if (-not $match.Success) {
            Add-Failure "Could not determine latest changelog version from $ChangelogPath"
            return
        }

        $changelogVersion = $match.Groups[1].Value
        if ($changelogVersion -ne $manifestVersion) {
            Add-Failure "Manifest version ($manifestVersion) does not match changelog version ($changelogVersion)."
        }
    }
    catch {
        Add-Failure "Version consistency check failed."
    }
}

function Test-FileContains {
    param(
        [string]$Path,
        [string]$Pattern,
        [string]$FailureMessage
    )

    try {
        $content = Get-Content -LiteralPath $Path -Raw
        if ($content -notmatch $Pattern) {
            Add-Failure $FailureMessage
        }
    }
    catch {
        Add-Failure "Unreadable file during content validation: $Path"
    }
}

$requiredPaths = @(
    "$RepoRoot\README.md",
    "$RepoRoot\LICENSE",
    "$RepoRoot\CHANGELOG.md",
    "$RepoRoot\.editorconfig",
    "$RepoRoot\.gitattributes",
    "$RepoRoot\.gitignore",
    "$RepoRoot\AGENTS.md",
    "$RepoRoot\CLAUDE.md",
    "$RepoRoot\VISION.md",
    "$RepoRoot\agent-atlas.manifest.json",
    "$RepoRoot\CODE_OF_CONDUCT.md",
    "$RepoRoot\CONTRIBUTING.md",
    "$RepoRoot\SECURITY.md",
    "$RepoRoot\SUPPORT.md",
    "$RepoRoot\docs\architecture.md",
    "$RepoRoot\docs\comparison.md",
    "$RepoRoot\docs\first-run-walkthrough.md",
    "$RepoRoot\docs\quickstart.md",
    "$RepoRoot\docs\faq.md",
    "$RepoRoot\docs\publishing-checklist.md",
    "$RepoRoot\docs\repo-tour.md",
    "$RepoRoot\docs\showcase.md",
    "$RepoRoot\docs\knowledge-pipeline.md",
    "$RepoRoot\docs\migration-guide.md",
    "$RepoRoot\docs\positioning.md",
    "$RepoRoot\docs\release-process.md",
    "$RepoRoot\docs\roadmap.md",
    "$RepoRoot\docs\why-agent-atlas.md",
    "$RepoRoot\assets\hero.svg",
    "$RepoRoot\assets\install-flow.svg",
    "$RepoRoot\assets\compare.svg",
    "$RepoRoot\assets\installed-layout.svg",
    "$RepoRoot\assets\social-preview.svg",
    "$RepoRoot\scripts\Install-AgentWorkspaceKit.ps1",
    "$RepoRoot\scripts\Invoke-KitScenarioSimulations.ps1",
    "$RepoRoot\scripts\Invoke-KitSmokeTests.ps1",
    "$RepoRoot\scripts\New-ReleaseBundle.ps1",
    "$RepoRoot\scripts\New-WorkspaceProject.ps1",
    "$RepoRoot\scripts\Validate-AgentWorkspaceKit.ps1",
    "$RepoRoot\scripts\Validate-MarkdownLinks.ps1",
    "$RepoRoot\templates\codex\AGENTS.md",
    "$RepoRoot\templates\codex\config.template.toml",
    "$RepoRoot\templates\claude\CLAUDE.md",
    "$RepoRoot\templates\claude\settings.template.json",
    "$RepoRoot\templates\workspace\README.md",
    "$RepoRoot\templates\workspace\AGENTS.md",
    "$RepoRoot\templates\workspace\CLAUDE.md",
    "$RepoRoot\templates\workspace\_SHARED\tools\Invoke-WorkspaceDoctor.ps1",
    "$RepoRoot\templates\workspace\_SHARED\tools\Search-Vault.ps1",
    "$RepoRoot\templates\workspace\_SHARED\tools\New-VaultInboxNote.ps1",
    "$RepoRoot\templates\workspace\_SHARED\tools\Promote-VaultDraft.ps1",
    "$RepoRoot\templates\workspace\_SHARED\tools\Compile-VaultKnowledge.ps1",
    "$RepoRoot\templates\workspace\_SHARED\templates\README.md",
    "$RepoRoot\templates\obsidian\README.md",
    "$RepoRoot\templates\obsidian\AGENTS.md",
    "$RepoRoot\templates\obsidian\CLAUDE.md",
    "$RepoRoot\templates\obsidian\00_System\README.md",
    "$RepoRoot\templates\obsidian\.obsidian\core-plugins.json",
    "$RepoRoot\templates\obsidian\.obsidian\templates.json",
    "$RepoRoot\templates\obsidian\.obsidian\daily-notes.json",
    "$RepoRoot\templates\obsidian\10_Inbox\Agent Drafts\AGENTS.override.md",
    "$RepoRoot\templates\obsidian\_Templates\Agent Draft Note.md",
    "$RepoRoot\templates\obsidian\_Templates\Decision Note.md",
    "$RepoRoot\templates\obsidian\_Templates\Knowledge Note.md",
    "$RepoRoot\templates\obsidian\_Templates\Project Note.md",
    "$RepoRoot\templates\obsidian\_Templates\Daily Note.md",
    "$RepoRoot\examples\sample-workspace\README.md",
    "$RepoRoot\examples\sample-vault\README.md",
    "$RepoRoot\examples\sample-vault\00_System\Project Index.md",
    "$RepoRoot\examples\sample-vault\10_Inbox\Agent Drafts\2026-04-13 - Evaluate context routing.md",
    "$RepoRoot\examples\sample-workspace\Project-Alpha\src\AGENTS.override.md",
    "$RepoRoot\.github\ISSUE_TEMPLATE\bug_report.yml",
    "$RepoRoot\.github\ISSUE_TEMPLATE\feature_request.yml",
    "$RepoRoot\.github\ISSUE_TEMPLATE\config.yml",
    "$RepoRoot\.github\CODEOWNERS",
    "$RepoRoot\.github\dependabot.yml",
    "$RepoRoot\.github\PULL_REQUEST_TEMPLATE.md",
    "$RepoRoot\.github\workflows\validate.yml"
)

$requiredPaths | ForEach-Object { Test-PathRequired -Path $_ }

Get-ChildItem -Path "$RepoRoot\scripts" -Filter '*.ps1' -File | ForEach-Object {
    Test-PowerShellSyntax -Path $_.FullName
}

Get-ChildItem -Path "$RepoRoot\templates\workspace\_SHARED\tools" -Filter '*.ps1' -File | ForEach-Object {
    Test-PowerShellSyntax -Path $_.FullName
}

Test-JsonFile -Path "$RepoRoot\templates\claude\settings.template.json"
Test-TomlFile -Path "$RepoRoot\templates\codex\config.template.toml"
Test-JsonFile -Path "$RepoRoot\agent-atlas.manifest.json"
Test-JsonFile -Path "$RepoRoot\templates\obsidian\.obsidian\templates.json"
Test-JsonFile -Path "$RepoRoot\templates\obsidian\.obsidian\daily-notes.json"
Test-VersionConsistency -ManifestPath "$RepoRoot\agent-atlas.manifest.json" -ChangelogPath "$RepoRoot\CHANGELOG.md"
Test-FileContains -Path "$RepoRoot\.github\workflows\validate.yml" -Pattern '(?m)^permissions:\s*\r?\n\s+contents:\s+read\s*$' -FailureMessage 'Workflow is missing least-privilege contents: read permissions.'
Test-FileContains -Path "$RepoRoot\.github\dependabot.yml" -Pattern 'package-ecosystem:\s*"github-actions"' -FailureMessage 'Dependabot config is missing GitHub Actions updates.'
try {
    & (Join-Path $RepoRoot 'scripts\Validate-MarkdownLinks.ps1') | Out-Null
}
catch {
    Add-Failure 'Markdown link validation failed.'
}

try {
    Get-Content -LiteralPath "$RepoRoot\templates\obsidian\.obsidian\core-plugins.json" -Raw | ConvertFrom-Json | Out-Null
}
catch {
    Add-Failure "Invalid JSON array: $RepoRoot\templates\obsidian\.obsidian\core-plugins.json"
}

Get-ChildItem -Path "$RepoRoot\assets" -Filter '*.svg' -File | ForEach-Object {
    Test-XmlFile -Path $_.FullName
}

$textFiles = Get-ChildItem -Path $RepoRoot -Recurse -File | Where-Object {
    $_.Extension -in '.md', '.txt', '.ps1', '.toml', '.json', '.yml', '.yaml'
}

$forbiddenPatterns = @(
    'C:\\Users\\[^\\\r\n]+',
    'C:/Users/[^/\r\n]+'
)

foreach ($file in $textFiles) {
    if ($file.FullName -eq (Join-Path $RepoRoot 'scripts\Validate-AgentWorkspaceKit.ps1')) {
        continue
    }
    try {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        foreach ($pattern in $forbiddenPatterns) {
            if ($content -match $pattern) {
                Add-Failure "Forbidden personal reference in $($file.FullName): $pattern"
            }
        }
    }
    catch {
        Add-Failure "Unreadable file during validation: $($file.FullName)"
    }
}

if ($failures.Count -gt 0) {
    Write-Host "Validation failed:" -ForegroundColor Red
    $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 1
}

Write-Host "Validation passed." -ForegroundColor Green
