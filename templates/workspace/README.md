# __WORKSPACE_NAME__

This folder is the shared workspace root.

Use it to choose a project, manage templates, and keep support areas tidy.
Do not treat it like a single implementation repo.

## Layout

- `AGENTS.md`: Codex workspace rules
- `CLAUDE.md`: Claude workspace rules
- `_INBOX`: rough intake
- `_SHARED`: reusable helpers and docs
- `_ARCHIVE`: inactive work

## Durable Knowledge

Long-lived knowledge belongs in:

- `__VAULT_ROOT__`

Serious projects should also earn at least one inbox draft once they become worth remembering.

- use `_SHARED/tools/Sync-WorkspaceProjectDrafts.ps1` to create draft candidates
- keep curated folders curated
- do not mirror every throwaway project into the vault
