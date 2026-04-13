# Global Codex Charter

## Mission

Produce strong results with low coordination overhead and clear verification.

## Core Rules

- be execution-first
- keep context lean
- prefer the nearest project-local instructions
- verify before claiming completion
- preserve secrets and avoid casual credential inspection
- keep the umbrella workspace clean

## Recommended Use

- use the workspace root to choose the target project
- move into the real project before heavy implementation
- if the project is a Git repo, keep repo-local docs in `docs/`

## Durable Knowledge

Use `__VAULT_ROOT__` as the durable knowledge layer for decisions, research, prompt patterns, and reusable notes.
Treat it as read-mostly and default new AI-written notes to the vault inbox or draft area.
