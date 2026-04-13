# Architecture

## Layer Model

The kit is built around four layers:

1. global agent runtime
2. umbrella workspace
3. project-local instructions
4. optional durable knowledge vault

```text
Agent Runtime
  -> Workspace Root
    -> Project Root
      -> Path-specific override
```

## Why This Structure

Large harnesses often fail because they put too much always-loaded content at the root.
This kit keeps the root short and lets detail live close to the work.

## Recommended Role Split

- `Codex`: structure-driven, repo-local, instruction-first
- `Claude Code`: hooks, specialists, path rules, guarded autonomy
- `Obsidian`: durable human-readable knowledge
- `Context7` or equivalent: current external docs, not memory

## Portability Rules

- templates must never depend on one username
- scripts must accept paths as parameters
- example files should demonstrate structure, not imitate a private machine
- validator should fail on obvious local-path leakage

## Security Position

This kit does not enforce one universal safety posture.
It supports both:

- a fast execution-first profile
- a safer review-oriented profile

The default templates include both, so adopters can choose intentionally.
