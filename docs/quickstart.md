# Quickstart

## What You Need

- Windows with PowerShell 7
- Python 3.11+ for TOML validation
- one or both of:
  - Codex
  - Claude Code
- optionally Obsidian

## Fastest Setup

1. Download or clone this repository.
2. Open PowerShell in the repository root.
3. Run:

```powershell
pwsh -File .\scripts\Install-AgentWorkspaceKit.ps1 `
  -DestinationRoot "D:\AgentWorkspace" `
  -OwnerName "Your Name" `
  -WorkspaceName "AI-Workspace" `
  -VaultName "Knowledge-Vault"
```

4. If you use Codex, copy or adapt:
   - `D:\AgentWorkspace\.codex\config.toml`
   - `D:\AgentWorkspace\.codex\AGENTS.md`
5. If you use Claude Code, copy or adapt:
   - `D:\AgentWorkspace\.claude\settings.json`
   - `D:\AgentWorkspace\.claude\CLAUDE.md`
6. Open `D:\AgentWorkspace\AI-Workspace` as your working root.
7. Open `D:\AgentWorkspace\Knowledge-Vault` in Obsidian if you want the optional knowledge layer.
8. Optionally run the generated workspace doctor:

```powershell
pwsh -File D:\AgentWorkspace\AI-Workspace\_SHARED\tools\Invoke-WorkspaceDoctor.ps1
```

9. When a project becomes serious enough to deserve cross-session recall, sync a candidate draft into the vault:

```powershell
pwsh -File D:\AgentWorkspace\AI-Workspace\_SHARED\tools\Sync-WorkspaceProjectDrafts.ps1 `
  -WorkspaceRoot "D:\AgentWorkspace\AI-Workspace" `
  -VaultRoot "D:\AgentWorkspace\Knowledge-Vault" `
  -AllProjects
```

## Important Note

The installer creates portable starter configs inside the generated destination root.
It does not automatically overwrite your live home-directory Codex or Claude Code configuration.
Review and merge the generated `.codex/` and `.claude/` files deliberately.

## First Good Habit

Do not do real implementation work in the umbrella root.
Move into the actual project folder first.
