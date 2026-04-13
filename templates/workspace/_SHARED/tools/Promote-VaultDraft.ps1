[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DraftPath,
    [Parameter(Mandatory = $true)]
    [ValidateSet('knowledge', 'decision', 'project', 'prompt', 'reference')]
    [string]$Kind,
    [string]$VaultRoot = '__VAULT_ROOT__',
    [switch]$KeepOriginal
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

if (-not (Test-Path -LiteralPath $DraftPath)) {
    throw "Draft not found: $DraftPath"
}

if (-not (Test-Path -LiteralPath $VaultRoot)) {
    throw "Vault root not found: $VaultRoot"
}

$resolvedDraftPath = (Resolve-Path -LiteralPath $DraftPath).Path
$resolvedDraftRoot = (Resolve-Path -LiteralPath (Join-Path $VaultRoot '10_Inbox\Agent Drafts')).Path
$draftRelativePath = [System.IO.Path]::GetRelativePath($resolvedDraftRoot, $resolvedDraftPath)

if (
    [System.IO.Path]::IsPathRooted($draftRelativePath) -or
    $draftRelativePath.Equals('..', [System.StringComparison]::Ordinal) -or
    $draftRelativePath.StartsWith("..\", [System.StringComparison]::Ordinal) -or
    $draftRelativePath.StartsWith("../", [System.StringComparison]::Ordinal)
) {
    throw "Draft path must live under: $resolvedDraftRoot"
}

$targetFolder = switch ($Kind) {
    'knowledge' { Join-Path $VaultRoot '30_Knowledge' }
    'decision' { Join-Path $VaultRoot '40_Decisions' }
    'project' { Join-Path $VaultRoot '20_Projects' }
    'prompt' { Join-Path $VaultRoot '50_Prompts' }
    'reference' { Join-Path $VaultRoot '60_References' }
}

New-Item -ItemType Directory -Force -Path $targetFolder | Out-Null

$targetPath = Join-Path $targetFolder ([System.IO.Path]::GetFileName($DraftPath))
$resolvedTargetPath = [System.IO.Path]::GetFullPath($targetPath)

if ($resolvedDraftPath.Equals($resolvedTargetPath, [System.StringComparison]::OrdinalIgnoreCase)) {
    throw 'Draft is already in the requested target location.'
}

if ($KeepOriginal) {
    Copy-Item -LiteralPath $DraftPath -Destination $targetPath -Force
}
else {
    Move-Item -LiteralPath $DraftPath -Destination $targetPath -Force
}

Write-Output $targetPath
