[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$Title,
    [string]$VaultRoot = '__VAULT_ROOT__',
    [string]$Project = '',
    [switch]$Preview
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$draftRoot = Join-Path $VaultRoot '10_Inbox\Agent Drafts'
$templatePath = Join-Path $VaultRoot '_Templates\Agent Draft Note.md'
$date = Get-Date -Format 'yyyy-MM-dd'
$safeTitle = ($Title -replace '[\\/:*?""<>|]', '-').Trim()
$fileName = "$date - $safeTitle.md"
$targetPath = Join-Path $draftRoot $fileName

New-Item -ItemType Directory -Force -Path $draftRoot | Out-Null

$content = if (Test-Path -LiteralPath $templatePath) {
    Get-Content -LiteralPath $templatePath -Raw
}
else {
@"
# __TITLE__

## Project

__PROJECT__

## Summary

Add the durable draft note here.
"@
}

$content = $content.Replace('__TITLE__', $Title)
$content = $content.Replace('__PROJECT__', $(if ($Project) { $Project } else { 'Unspecified' }))
$content = $content.Replace('__DATE__', $date)

if ($Preview) {
    Write-Output "Preview path: $targetPath"
    Write-Output $content
    exit 0
}

Set-Content -LiteralPath $targetPath -Value $content -NoNewline
Write-Output $targetPath
