# Agent Workspace Kit

This repo is a portable harness distribution, not a live personal workspace.

## Rules

- Preserve portability over convenience.
- Avoid leaking personal local paths into templates or docs.
- Keep root docs concise and push specifics into `docs/`, `templates/`, and `scripts/`.
- Validate after changes with `pwsh -File .\scripts\Validate-AgentWorkspaceKit.ps1`.
