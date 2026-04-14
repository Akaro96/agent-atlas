[CmdletBinding()]
param(
    [string]$WorkspaceRoot = (Split-Path -Parent (Split-Path -Parent $PSScriptRoot)),
    [string]$VaultRoot = '__VAULT_ROOT__',
    [string]$ProjectRoot,
    [string]$ClaudeMemoryRoot = '',
    [int]$MinScore = 5,
    [switch]$AllProjects,
    [switch]$Force,
    [switch]$PreviewOnly,
    [switch]$Quiet,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')
    if (-not $slug) {
        return 'project'
    }

    return $slug
}

function ConvertTo-UnderscoreSlug {
    param([string]$Value)

    return (ConvertTo-Slug -Value $Value) -replace '-', '_'
}

function Get-WorkspaceProjects {
    param(
        [string]$WorkspaceRoot,
        [string]$ProjectRoot,
        [switch]$AllProjects
    )

    if ($ProjectRoot) {
        if (-not (Test-Path -LiteralPath $ProjectRoot -PathType Container)) {
            throw "Project root not found: $ProjectRoot"
        }

        return @(Get-Item -LiteralPath $ProjectRoot)
    }

    if (-not $AllProjects) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $WorkspaceRoot -Directory -Force | Where-Object {
        $_.Name -notlike '_*' -and
        $_.Name -ne '.claude' -and
        $_.Name -ne 'active' -and
        $_.Name -ne 'dist'
    })
}

function Get-ProjectTitle {
    param([string]$ProjectPath)

    $readmePath = Join-Path $ProjectPath 'README.md'
    if (Test-Path -LiteralPath $readmePath) {
        foreach ($line in (Get-Content -LiteralPath $readmePath)) {
            if ($line -match '^#\s+(.+?)\s*$') {
                return $Matches[1].Trim()
            }
        }
    }

    return [System.IO.Path]::GetFileName($ProjectPath)
}

function Get-ReadmeBlurb {
    param([string]$ProjectPath)

    $readmePath = Join-Path $ProjectPath 'README.md'
    if (-not (Test-Path -LiteralPath $readmePath)) {
        return $null
    }

    $content = Get-Content -LiteralPath $readmePath -Raw
    $content = [regex]::Replace($content, '(?m)^---[\s\S]*?^---\s*', '')
    $content = [regex]::Replace($content, '(?m)^# .+\r?\n?', '')
    $paragraphs = $content -split '(?:\r?\n){2,}'
    foreach ($paragraph in $paragraphs) {
        $clean = ($paragraph -replace '\s+', ' ').Trim()
        if ($clean -and $clean -notmatch '^```' -and $clean.Length -ge 32) {
            return $clean
        }
    }

    return $null
}

function Get-ClaudeMemoryFile {
    param(
        [string]$ClaudeMemoryRoot,
        [string]$ProjectTitle,
        [string]$ProjectSlug,
        [string]$ProjectPath
    )

    if (-not $ClaudeMemoryRoot -or -not (Test-Path -LiteralPath $ClaudeMemoryRoot)) {
        return $null
    }

    $preferred = Join-Path $ClaudeMemoryRoot ('project_' + (ConvertTo-UnderscoreSlug -Value $ProjectTitle) + '.md')
    if (Test-Path -LiteralPath $preferred) {
        return (Get-Item -LiteralPath $preferred).FullName
    }

    $fallback = Get-ChildItem -LiteralPath $ClaudeMemoryRoot -File -Filter '*.md' -ErrorAction SilentlyContinue | Where-Object {
        $_.BaseName -match [regex]::Escape((ConvertTo-UnderscoreSlug -Value $ProjectSlug))
    } | Select-Object -First 1
    if ($fallback) {
        return $fallback.FullName
    }

    $pathNeedle = ($ProjectPath -replace '\\', '/').ToLowerInvariant()
    $titleNeedle = $ProjectTitle.ToLowerInvariant()
    foreach ($file in (Get-ChildItem -LiteralPath $ClaudeMemoryRoot -File -Filter '*.md' -ErrorAction SilentlyContinue)) {
        try {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            $haystack = ($content -replace '\\', '/').ToLowerInvariant()
            if ($haystack.Contains($pathNeedle) -or $haystack.Contains($titleNeedle)) {
                return $file.FullName
            }
        }
        catch {
            continue
        }
    }

    return $null
}

function Get-ClaudeMemorySummary {
    param([string]$Path)

    if (-not $Path -or -not (Test-Path -LiteralPath $Path)) {
        return $null
    }

    $lines = Get-Content -LiteralPath $Path
    foreach ($line in $lines) {
        if ($line -match '^description:\s*(.+?)\s*$') {
            return $Matches[1].Trim().Trim("'")
        }
    }

    foreach ($line in $lines) {
        $clean = ($line -replace '\*\*', '').Trim()
        if ($clean -and $clean -notmatch '^(---|name:|description:|type:|originSessionId:|# )') {
            return $clean
        }
    }

    return $null
}

function Get-ReportFiles {
    param(
        [string]$WorkspaceRoot,
        [string]$ProjectSlug,
        [string]$ProjectName
    )

    $reportRoot = Join-Path $WorkspaceRoot 'active\reports'
    if (-not (Test-Path -LiteralPath $reportRoot)) {
        return @()
    }

    return @(Get-ChildItem -LiteralPath $reportRoot -File -ErrorAction SilentlyContinue | Where-Object {
        $name = $_.Name.ToLowerInvariant()
        $name.Contains($ProjectSlug.ToLowerInvariant()) -or $name.Contains($ProjectName.ToLowerInvariant())
    })
}

function Get-ProjectSignals {
    param(
        [System.IO.DirectoryInfo]$Project,
        [string]$ProjectTitle,
        [string]$ProjectSlug,
        [string]$WorkspaceRoot,
        [string]$ClaudeMemoryRoot,
        [int]$MinScore
    )

    $reasons = New-Object System.Collections.Generic.List[string]
    $score = 0

    $readmePath = Join-Path $Project.FullName 'README.md'
    if (Test-Path -LiteralPath $readmePath) {
        $score += 1
        $reasons.Add('README present')
    }

    $manifestCandidates = @(
        'package.json',
        'Cargo.toml',
        'pyproject.toml',
        'go.mod',
        'tauri.conf.json',
        'src-tauri\tauri.conf.json',
        '*.sln'
    )
    $hasManifest = $false
    foreach ($candidate in $manifestCandidates) {
        if ($candidate.Contains('*')) {
            if (Get-ChildItem -LiteralPath $Project.FullName -Filter $candidate -File -ErrorAction SilentlyContinue | Select-Object -First 1) {
                $hasManifest = $true
                break
            }
        }
        elseif (Test-Path -LiteralPath (Join-Path $Project.FullName $candidate)) {
            $hasManifest = $true
            break
        }
    }
    if ($hasManifest) {
        $score += 1
        $reasons.Add('build manifest present')
    }

    $implementationRoots = @('src', 'src-tauri', 'app', 'lib', 'components', 'public')
    if ($implementationRoots | Where-Object { Test-Path -LiteralPath (Join-Path $Project.FullName $_) } | Select-Object -First 1) {
        $score += 1
        $reasons.Add('implementation directories present')
    }

    if (
        (Test-Path -LiteralPath (Join-Path $Project.FullName '.git')) -or
        (Test-Path -LiteralPath (Join-Path $Project.FullName 'AGENTS.md')) -or
        (Test-Path -LiteralPath (Join-Path $Project.FullName 'CLAUDE.md')) -or
        (Test-Path -LiteralPath (Join-Path $Project.FullName 'docs'))
    ) {
        $score += 1
        $reasons.Add('project-local instructions or docs present')
    }

    $reportFiles = Get-ReportFiles -WorkspaceRoot $WorkspaceRoot -ProjectSlug $ProjectSlug -ProjectName $Project.Name
    if (@($reportFiles).Count -gt 0) {
        $score += 2
        $reasons.Add("$(@($reportFiles).Count) matching report artifact(s)")
    }

    $memoryFile = Get-ClaudeMemoryFile -ClaudeMemoryRoot $ClaudeMemoryRoot -ProjectTitle $ProjectTitle -ProjectSlug $ProjectSlug -ProjectPath $Project.FullName
    if ($memoryFile) {
        $score += 2
        $reasons.Add('Claude project memory present')
    }

    $summary = Get-ClaudeMemorySummary -Path $memoryFile
    if (-not $summary) {
        $summary = Get-ReadmeBlurb -ProjectPath $Project.FullName
    }

    return [pscustomobject]@{
        Score         = $score
        Reasons       = @($reasons)
        ShouldCapture = ($score -ge $MinScore)
        ReportFiles   = @($reportFiles | ForEach-Object { $_.FullName })
        MemoryFile    = $memoryFile
        Summary       = $summary
    }
}

function Get-VaultCoverage {
    param(
        [string]$VaultRoot,
        [string]$ProjectTitle,
        [string]$ProjectName,
        [string]$ProjectSlug
    )

    $projectRoot = Join-Path $VaultRoot '20_Projects'
    $draftRoot = Join-Path $VaultRoot '10_Inbox\Agent Drafts'
    $markerPattern = "project-sync-slug:\s*$([regex]::Escape($ProjectSlug))"
    $tagPattern = "project/$([regex]::Escape($ProjectSlug))"

    foreach ($candidate in @($ProjectTitle, $ProjectName)) {
        if (-not $candidate) {
            continue
        }

        $curatedPath = Join-Path $projectRoot ($candidate + '.md')
        if (Test-Path -LiteralPath $curatedPath) {
            return [pscustomobject]@{
                Status = 'curated'
                Path   = $curatedPath
            }
        }
    }

    foreach ($file in (Get-ChildItem -LiteralPath $projectRoot -File -Filter '*.md' -ErrorAction SilentlyContinue)) {
        try {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            if ($content -match $markerPattern -or $content -match $tagPattern) {
                return [pscustomobject]@{
                    Status = 'curated'
                    Path   = $file.FullName
                }
            }
        }
        catch {
            continue
        }
    }

    foreach ($file in (Get-ChildItem -LiteralPath $draftRoot -File -Filter '*.md' -ErrorAction SilentlyContinue)) {
        try {
            $content = Get-Content -LiteralPath $file.FullName -Raw
            if ($content -match $markerPattern -or $content -match $tagPattern) {
                return [pscustomobject]@{
                    Status = 'draft'
                    Path   = $file.FullName
                }
            }
        }
        catch {
            continue
        }
    }

    return [pscustomobject]@{
        Status = 'missing'
        Path   = $null
    }
}

function Build-DraftBody {
    param(
        [string]$ProjectTitle,
        [string]$ProjectRoot,
        [string]$ProjectSlug,
        [pscustomobject]$Signals
    )

    $lines = @(
        '## Why this was captured',
        '',
        "- serious-project threshold reached (`score = $($Signals.Score)`)",
        '- no existing project note or synced draft was found in the vault',
        ''
    )

    if ($Signals.Reasons.Count -gt 0) {
        $lines += '## Signals'
        $lines += ''
        $lines += ($Signals.Reasons | ForEach-Object { '- ' + $_ })
        $lines += ''
    }

    $lines += '## Summary'
    $lines += ''
    if ($Signals.Summary) {
        $lines += $Signals.Summary
    }
    else {
        $lines += '- Review this project and capture the durable context worth keeping.'
    }
    $lines += ''
    $lines += '## Source hints'
    $lines += ''
    $lines += ('- Project root: `{0}`' -f $ProjectRoot)

    if ($Signals.MemoryFile) {
        $lines += ('- Claude memory: `{0}`' -f $Signals.MemoryFile)
    }

    if (@($Signals.ReportFiles).Count -gt 0) {
        $lines += '- Matching reports:'
        $lines += ($Signals.ReportFiles | Select-Object -First 6 | ForEach-Object { '  - `' + $_ + '`' })
    }

    $lines += ''
    $lines += '## Metadata'
    $lines += ''
    $lines += ('- project-sync-slug: {0}' -f $ProjectSlug)
    $lines += '- created by: Sync-WorkspaceProjectDrafts.ps1'
    $lines += ''
    $lines += '## Next action'
    $lines += ''
    $lines += '- decide whether this belongs in 20_Projects, 30_Knowledge, 40_Decisions, or should stay a draft'

    return ($lines -join "`r`n")
}

$noteWriter = Join-Path $WorkspaceRoot '_SHARED\tools\New-VaultInboxNote.ps1'
if (-not (Test-Path -LiteralPath $noteWriter)) {
    throw "Missing note writer script: $noteWriter"
}

$projects = Get-WorkspaceProjects -WorkspaceRoot $WorkspaceRoot -ProjectRoot $ProjectRoot -AllProjects:$AllProjects
$results = @()

foreach ($project in $projects) {
    $projectTitle = Get-ProjectTitle -ProjectPath $project.FullName
    $projectSlug = ConvertTo-Slug -Value $project.Name
    $signals = Get-ProjectSignals -Project $project -ProjectTitle $projectTitle -ProjectSlug $projectSlug -WorkspaceRoot $WorkspaceRoot -ClaudeMemoryRoot $ClaudeMemoryRoot -MinScore $MinScore
    $coverage = Get-VaultCoverage -VaultRoot $VaultRoot -ProjectTitle $projectTitle -ProjectName $project.Name -ProjectSlug $projectSlug

    $action = 'skip'
    $reason = 'below-threshold'
    $draftPath = $null

    if (-not $signals.ShouldCapture) {
        $reason = 'below-threshold'
    }
    elseif ($coverage.Status -ne 'missing' -and -not $Force) {
        $reason = 'already-covered'
    }
    else {
        $body = Build-DraftBody -ProjectTitle $projectTitle -ProjectRoot $project.FullName -ProjectSlug $projectSlug -Signals $signals
        if ($PreviewOnly) {
            $action = 'would-create'
            $reason = 'serious-project-missing-coverage'
        }
        else {
            $draftResult = (& $noteWriter `
                -VaultRoot $VaultRoot `
                -Title ("Project Snapshot - {0}" -f $projectTitle) `
                -Project $projectTitle `
                -Source 'agent-atlas/project-sync' `
                -Tags @('agent-draft', 'auto-capture', 'project-sync', ("project/{0}" -f $projectSlug)) `
                -Body $body) | Select-Object -Last 1
            if ($draftResult -is [string]) {
                $draftPath = $draftResult
            }
            elseif ($null -ne $draftResult.PSObject.Properties['Path']) {
                $draftPath = [string]$draftResult.Path
            }
            $action = 'created'
            $reason = 'created-draft'
        }
    }

    $results += [pscustomobject]@{
        ProjectName     = $project.Name
        ProjectTitle    = $projectTitle
        ProjectRoot     = $project.FullName
        ProjectSlug     = $projectSlug
        Score           = $signals.Score
        Signals         = @($signals.Reasons)
        ShouldCapture   = [bool]$signals.ShouldCapture
        CoverageStatus  = $coverage.Status
        CoveragePath    = $coverage.Path
        Action          = $action
        Reason          = $reason
        DraftPath       = $draftPath
        MemoryFile      = $signals.MemoryFile
        ReportCount     = @($signals.ReportFiles).Count
    }
}

$summary = [pscustomobject]@{
    WorkspaceRoot    = $WorkspaceRoot
    VaultRoot        = $VaultRoot
    MinScore         = $MinScore
    CreatedCount     = @($results | Where-Object { $_.Action -eq 'created' }).Count
    WouldCreateCount = @($results | Where-Object { $_.Action -eq 'would-create' }).Count
    CoveredCount     = @($results | Where-Object { $_.Reason -eq 'already-covered' }).Count
    Results          = @($results)
}

if ($AsJson) {
    $summary | ConvertTo-Json -Depth 6
    return
}

if (-not $Quiet) {
    foreach ($result in $results) {
        switch ($result.Action) {
            'created' {
                Write-Host "Created project draft for $($result.ProjectTitle): $($result.DraftPath)" -ForegroundColor Green
            }
            'would-create' {
                Write-Host "Would create project draft for $($result.ProjectTitle)." -ForegroundColor Yellow
            }
            default {
                if ($result.Reason -eq 'already-covered') {
                    Write-Host "Project already covered in vault: $($result.ProjectTitle)" -ForegroundColor DarkGray
                }
            }
        }
    }
}

$summary
