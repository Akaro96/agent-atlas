# Agent Workspace Kit Repo Rules

This repository is the portable open-source distribution of a dual-agent workspace harness.

## Scope

- Keep this repo portable.
- Do not add machine-specific paths, usernames, auth files, or personal workspace history.
- Treat templates as the product, not as a dump of one local machine.

## Quality Bar

- Prefer templates, install scripts, and validation over one-off docs.
- If a new module increases complexity, justify it in docs and keep it optional.
- Preserve the split between operational workspace, durable knowledge layer, and live docs layer.

## Verification

- Run `pwsh -File .\scripts\Validate-AgentWorkspaceKit.ps1` after meaningful changes.
- Keep JSON and TOML templates parseable.
- Keep PowerShell scripts syntax-clean.

## Portability

- Use tokens like `__WORKSPACE_ROOT__`, `__VAULT_ROOT__`, and `__OWNER_NAME__` in templates.
- Do not hardcode real usernames or absolute personal paths.
- Keep Windows-first choices explicit when a file is platform-specific.
