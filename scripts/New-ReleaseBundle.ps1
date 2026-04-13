[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$Version,
    [string]$DistRoot,
    [switch]$SkipChecks
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not $DistRoot) {
    $DistRoot = Join-Path $RepoRoot 'dist'
}

$manifestPath = Join-Path $RepoRoot 'agent-atlas.manifest.json'
if (-not $Version) {
    $manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json
    $Version = [string]$manifest.version
}

if (-not $Version) {
    throw 'Unable to determine release version.'
}

$bundleName = "AgentAtlas-$Version"
$stagingRoot = Join-Path $env:TEMP "agent-atlas-release-$Version"
$bundleRoot = Join-Path $stagingRoot $bundleName
$zipPath = Join-Path $DistRoot "$bundleName.zip"
$hashPath = Join-Path $DistRoot "$bundleName.sha256.txt"

if (Test-Path -LiteralPath $stagingRoot) {
    Remove-Item -LiteralPath $stagingRoot -Recurse -Force
}

if (Test-Path -LiteralPath $zipPath) {
    Remove-Item -LiteralPath $zipPath -Force
}

if (Test-Path -LiteralPath $hashPath) {
    Remove-Item -LiteralPath $hashPath -Force
}

try {
    New-Item -ItemType Directory -Force -Path $DistRoot,$bundleRoot | Out-Null

    if (-not $SkipChecks) {
        & (Join-Path $RepoRoot 'scripts\Validate-AgentWorkspaceKit.ps1')
        & (Join-Path $RepoRoot 'scripts\Invoke-KitSmokeTests.ps1')
    }

    $excludedNames = @('.git', 'dist')

    Get-ChildItem -LiteralPath $RepoRoot -Force | Where-Object { $excludedNames -notcontains $_.Name } | ForEach-Object {
        Copy-Item -LiteralPath $_.FullName -Destination $bundleRoot -Recurse -Force
    }

    Compress-Archive -Path $bundleRoot -DestinationPath $zipPath -Force
    $hash = Get-FileHash -Algorithm SHA256 -LiteralPath $zipPath
    Set-Content -LiteralPath $hashPath -Value "$($hash.Hash)  $([System.IO.Path]::GetFileName($zipPath))" -NoNewline

    Write-Host "Created release bundle: $zipPath"
    Write-Host "Created SHA256: $hashPath"
}
finally {
    if (Test-Path -LiteralPath $stagingRoot) {
        Remove-Item -LiteralPath $stagingRoot -Recurse -Force
    }
}
