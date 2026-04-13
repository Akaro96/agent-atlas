[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$TempRoot = (Join-Path $env:TEMP 'agent-atlas-smoke'),
    [switch]$KeepArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Path {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing expected path: $Path"
    }
}

if (Test-Path -LiteralPath $TempRoot) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}

$destinationRoot = Join-Path $TempRoot 'install'
$workspaceRoot = Join-Path $destinationRoot 'Studio-Workspace'
$vaultRoot = Join-Path $destinationRoot 'Studio-Vault'

try {
    & (Join-Path $RepoRoot 'scripts\Validate-AgentWorkspaceKit.ps1')
    & (Join-Path $RepoRoot 'scripts\Install-AgentWorkspaceKit.ps1') `
        -DestinationRoot $destinationRoot `
        -OwnerName 'Smoke Test User' `
        -WorkspaceName 'Studio-Workspace' `
        -VaultName 'Studio-Vault'

    Assert-Path (Join-Path $destinationRoot '.codex\config.toml')
    Assert-Path (Join-Path $destinationRoot '.claude\settings.json')
    Assert-Path (Join-Path $destinationRoot 'START HERE.md')
    Assert-Path (Join-Path $workspaceRoot '_SHARED\tools\Invoke-WorkspaceDoctor.ps1')
    Assert-Path (Join-Path $workspaceRoot '_SHARED\tools\Search-Vault.ps1')
    Assert-Path (Join-Path $workspaceRoot '_SHARED\tools\New-VaultInboxNote.ps1')
    Assert-Path (Join-Path $workspaceRoot '_SHARED\tools\Promote-VaultDraft.ps1')
    Assert-Path (Join-Path $workspaceRoot '_SHARED\tools\Compile-VaultKnowledge.ps1')

    & python -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb')); print('config ok')" (Join-Path $destinationRoot '.codex\config.toml')
    Get-Content -LiteralPath (Join-Path $destinationRoot '.claude\settings.json') -Raw | ConvertFrom-Json | Out-Null

    & (Join-Path $RepoRoot 'scripts\New-WorkspaceProject.ps1') -WorkspaceRoot $workspaceRoot -ProjectName 'Project-Beta' -ProjectType software
    & (Join-Path $RepoRoot 'scripts\New-WorkspaceProject.ps1') -WorkspaceRoot $workspaceRoot -ProjectName 'Project-Gamma' -ProjectType ai-pipeline

    Assert-Path (Join-Path $workspaceRoot 'Project-Beta\src\AGENTS.override.md')
    Assert-Path (Join-Path $workspaceRoot 'Project-Gamma\04_BUILD')
    Assert-Path (Join-Path $vaultRoot '00_System\Knowledge Index.md')

    $doctorOutput = ((& (Join-Path $workspaceRoot '_SHARED\tools\Invoke-WorkspaceDoctor.ps1') -WorkspaceRoot $workspaceRoot -VaultRoot $vaultRoot) -join [Environment]::NewLine)
    if ($doctorOutput -notmatch 'Overall status') {
        throw 'Workspace doctor did not produce a recognizable report.'
    }

    $previewOutput = ((& (Join-Path $workspaceRoot '_SHARED\tools\New-VaultInboxNote.ps1') -VaultRoot $vaultRoot -Title 'Smoke Draft' -Project 'Project-Beta' -Preview) -join [Environment]::NewLine)
    if ($previewOutput -notmatch 'Agent Drafts') {
        throw 'Vault draft preview did not reference Agent Drafts.'
    }

    $draftPath = (& (Join-Path $workspaceRoot '_SHARED\tools\New-VaultInboxNote.ps1') -VaultRoot $vaultRoot -Title 'Smoke Draft' -Project 'Project-Beta') | Select-Object -Last 1
    Assert-Path $draftPath

    $searchOutput = ((& (Join-Path $workspaceRoot '_SHARED\tools\Search-Vault.ps1') -VaultRoot $vaultRoot -Query 'Smoke Draft') -join [Environment]::NewLine)
    if ($searchOutput -notmatch 'Smoke Draft') {
        throw 'Vault search did not return the created draft note.'
    }

    $promotedPath = (& (Join-Path $workspaceRoot '_SHARED\tools\Promote-VaultDraft.ps1') -VaultRoot $vaultRoot -DraftPath $draftPath -Kind knowledge) -join [Environment]::NewLine
    if ($promotedPath -notmatch '30_Knowledge') {
        throw 'Draft promotion did not target 30_Knowledge.'
    }

    & (Join-Path $workspaceRoot '_SHARED\tools\Compile-VaultKnowledge.ps1') -VaultRoot $vaultRoot | Out-Null
    Assert-Path (Join-Path $vaultRoot '00_System\Knowledge Index.md')
    $compiledOutput = ((Get-Content -LiteralPath (Join-Path $vaultRoot '00_System\Knowledge Index.md')) -join [Environment]::NewLine)
    if ($compiledOutput -notmatch 'Smoke Draft') {
        throw 'Knowledge compiler did not include the promoted note.'
    }

    $releaseDist = Join-Path $TempRoot 'dist'
    & (Join-Path $RepoRoot 'scripts\New-ReleaseBundle.ps1') -Version '0.1.0-test' -DistRoot $releaseDist -SkipChecks | Out-Null
    $releaseZip = Join-Path $releaseDist 'AgentAtlas-0.1.0-test.zip'
    Assert-Path $releaseZip
    Assert-Path (Join-Path $releaseDist 'AgentAtlas-0.1.0-test.sha256.txt')

    $releaseExtract = Join-Path $TempRoot 'release-extract'
    Expand-Archive -LiteralPath $releaseZip -DestinationPath $releaseExtract -Force
    Assert-Path (Join-Path $releaseExtract 'AgentAtlas-0.1.0-test')

    Write-Host 'Smoke tests passed.' -ForegroundColor Green
}
finally {
    if (-not $KeepArtifacts -and (Test-Path -LiteralPath $TempRoot)) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}
