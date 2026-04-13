# Knowledge Pipeline

## Why This Exists

Many “agent memory” setups either:

- keep everything in chat history
- dump everything into one vault
- or confuse raw notes with curated knowledge

This kit uses a simpler but stronger model:

```text
capture -> curate -> compile -> use
```

## Stages

### Capture

Raw notes start in:

- `10_Inbox/Agent Drafts`
- `10_Inbox/Human Notes`

### Curate

Only notes worth keeping move into:

- `20_Projects`
- `30_Knowledge`
- `40_Decisions`
- `50_Prompts`
- `60_References`

### Compile

Generated navigation and digest pages live in:

- `00_System`

These are created by:

- `Compile-VaultKnowledge.ps1`

### Use

Agents and humans can:

- search drafts only
- search curated notes only
- search compiled views only
- navigate from `00 Home.md`

## Why This Is Stronger Than Raw Memory Dumps

- drafts stay cheap
- curated notes stay meaningful
- generated indices improve discoverability
- project truth still stays near the project itself
