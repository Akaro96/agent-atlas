[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$DestinationRoot,
    [string]$OwnerName = 'Your Name',
    [string]$WorkspaceName = 'AI-Workspace',
    [string]$VaultName = 'Knowledge-Vault'
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$templateRoot = Join-Path $repoRoot 'templates'
$workspaceTarget = Join-Path $DestinationRoot $WorkspaceName
$vaultTarget = Join-Path $DestinationRoot $VaultName

function New-CleanDirectory {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        New-Item -ItemType Directory -Path $Path -Force | Out-Null
    }
}

function Copy-TemplateTree {
    param(
        [string]$SourceRoot,
        [string]$TargetRoot,
        [hashtable]$Tokens
    )

    New-CleanDirectory -Path $TargetRoot

    Get-ChildItem -Path $SourceRoot -Recurse -Force | ForEach-Object {
        $relative = $_.FullName.Substring($SourceRoot.Length).TrimStart('\')
        $targetPath = Join-Path $TargetRoot $relative

        if ($_.PSIsContainer) {
            New-CleanDirectory -Path $targetPath
            return
        }

        $content = Get-Content -LiteralPath $_.FullName -Raw
        foreach ($key in $Tokens.Keys) {
            $content = $content.Replace($key, [string]$Tokens[$key])
        }

        $parent = Split-Path -Parent $targetPath
        New-CleanDirectory -Path $parent
        Set-Content -LiteralPath $targetPath -Value $content -NoNewline
    }
}

New-CleanDirectory -Path $DestinationRoot

$tokens = @{
    '__OWNER_NAME__'     = $OwnerName
    '__WORKSPACE_NAME__' = $WorkspaceName
    '__VAULT_NAME__'     = $VaultName
    '__WORKSPACE_ROOT__' = $workspaceTarget
    '__VAULT_ROOT__'     = $vaultTarget
}

Copy-TemplateTree -SourceRoot (Join-Path $templateRoot 'workspace') -TargetRoot $workspaceTarget -Tokens $tokens
Copy-TemplateTree -SourceRoot (Join-Path $templateRoot 'obsidian') -TargetRoot $vaultTarget -Tokens $tokens

$codexTarget = Join-Path $DestinationRoot '.codex'
$claudeTarget = Join-Path $DestinationRoot '.claude'
New-CleanDirectory -Path $codexTarget
New-CleanDirectory -Path $claudeTarget

Copy-TemplateTree -SourceRoot (Join-Path $templateRoot 'codex') -TargetRoot $codexTarget -Tokens $tokens
Copy-TemplateTree -SourceRoot (Join-Path $templateRoot 'claude') -TargetRoot $claudeTarget -Tokens $tokens

@(
    (Join-Path $workspaceTarget '.claude'),
    (Join-Path $workspaceTarget '.claude\rules'),
    (Join-Path $workspaceTarget '_INBOX'),
    (Join-Path $workspaceTarget '_SHARED'),
    (Join-Path $workspaceTarget '_SHARED\templates'),
    (Join-Path $workspaceTarget '_ARCHIVE'),
    (Join-Path $workspaceTarget 'active'),
    (Join-Path $workspaceTarget 'active\reports'),
    (Join-Path $workspaceTarget 'active\tmp'),
    (Join-Path $vaultTarget '10_Inbox'),
    (Join-Path $vaultTarget '20_Projects'),
    (Join-Path $vaultTarget '30_Knowledge'),
    (Join-Path $vaultTarget '40_Decisions'),
    (Join-Path $vaultTarget '50_Prompts'),
    (Join-Path $vaultTarget '60_References'),
    (Join-Path $vaultTarget '80_Daily'),
    (Join-Path $vaultTarget '_Templates')
) | ForEach-Object { New-CleanDirectory -Path $_ }

$codexTemplate = Join-Path $codexTarget 'config.template.toml'
$codexConfig = Join-Path $codexTarget 'config.toml'
if (Test-Path -LiteralPath $codexTemplate) {
    Move-Item -LiteralPath $codexTemplate -Destination $codexConfig -Force
}

$claudeTemplate = Join-Path $claudeTarget 'settings.template.json'
$claudeSettings = Join-Path $claudeTarget 'settings.json'
if (Test-Path -LiteralPath $claudeTemplate) {
    Move-Item -LiteralPath $claudeTemplate -Destination $claudeSettings -Force
}

$compileScript = Join-Path $workspaceTarget '_SHARED\tools\Compile-VaultKnowledge.ps1'
if (Test-Path -LiteralPath $compileScript) {
    & $compileScript -VaultRoot $vaultTarget -Quiet
}

$startHerePath = Join-Path $DestinationRoot 'START HERE.md'
$startHereLines = @(
    '# Start Here',
    '',
    'Your Agent Atlas workspace has been installed.',
    '',
    '## Generated Paths',
    '',
    ('- Workspace: `{0}`' -f $workspaceTarget),
    ('- Vault: `{0}`' -f $vaultTarget),
    ('- Codex config: `{0}`' -f (Join-Path $codexTarget 'config.toml')),
    ('- Claude config: `{0}`' -f (Join-Path $claudeTarget 'settings.json')),
    '',
    '## Recommended First Steps',
    '',
    '1. Open the workspace root and read `README.md`.',
    '2. If you use Obsidian, open the vault and inspect `00 Home.md`.',
    '3. Create your first real project with:',
    '',
    '```powershell',
    ('pwsh -File "{0}" -WorkspaceRoot "{1}" -ProjectName "My-Project" -ProjectType software' -f (Join-Path $repoRoot 'scripts\New-WorkspaceProject.ps1'), $workspaceTarget),
    '```',
    '',
    '4. Run the installed workspace doctor if you want a quick health check:',
    '',
    '```powershell',
    ('pwsh -File "{0}"' -f (Join-Path $workspaceTarget '_SHARED\tools\Invoke-WorkspaceDoctor.ps1')),
    '```'
)

Set-Content -LiteralPath $startHerePath -Value ($startHereLines -join [Environment]::NewLine) -NoNewline

Write-Host "Installed workspace at: $workspaceTarget"
Write-Host "Installed vault at: $vaultTarget"
Write-Host "Installed Codex config at: $codexTarget"
Write-Host "Installed Claude config at: $claudeTarget"
Write-Host "Wrote starter guide at: $startHerePath"
