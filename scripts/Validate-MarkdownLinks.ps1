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

function Resolve-MarkdownTarget {
    param(
        [string]$SourceFile,
        [string]$Target
    )

    if ($Target -match '^(https?:|mailto:|tel:)') {
        return $null
    }

    if ($Target.StartsWith('#')) {
        return $null
    }

    $cleanTarget = ($Target -split '#', 2)[0]
    if (-not $cleanTarget) {
        return $null
    }

    if ($cleanTarget.StartsWith('/')) {
        $relativeFromRoot = $cleanTarget.TrimStart('/').Replace('/', '\')
        return Join-Path $RepoRoot $relativeFromRoot
    }

    $sourceDirectory = Split-Path -Parent $SourceFile
    return Join-Path $sourceDirectory ($cleanTarget.Replace('/', '\'))
}

$markdownFiles = Get-ChildItem -Path $RepoRoot -Recurse -Filter '*.md' -File
$pattern = '!?\\[[^\\]]*\\]\\(([^)]+)\\)'

foreach ($file in $markdownFiles) {
    $content = Get-Content -LiteralPath $file.FullName -Raw
    $matches = [regex]::Matches($content, $pattern)
    foreach ($match in $matches) {
        $target = $match.Groups[1].Value.Trim()
        $resolved = Resolve-MarkdownTarget -SourceFile $file.FullName -Target $target
        if (-not $resolved) {
            continue
        }

        if (-not (Test-Path -LiteralPath $resolved)) {
            Add-Failure "Broken markdown link in $($file.FullName): $target"
        }
    }
}

if ($failures.Count -gt 0) {
    Write-Host 'Markdown link validation failed:' -ForegroundColor Red
    $failures | ForEach-Object { Write-Host " - $_" -ForegroundColor Red }
    exit 1
}

Write-Host 'Markdown links passed.' -ForegroundColor Green
