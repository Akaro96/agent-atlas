# Release Process

## Goal

Create a clean distributable ZIP that has already passed validation and smoke tests.

## Command

```powershell
pwsh -File .\scripts\New-ReleaseBundle.ps1
```

## Output

The script creates:

- `dist/AgentAtlas-<version>.zip`
- `dist/AgentAtlas-<version>.sha256.txt`

By default, the release version comes from `agent-atlas.manifest.json`.
Use `-Version` only when you intentionally want an override such as a preview build.

## Recommended Confidence Sequence

Before cutting a public release, run:

```powershell
pwsh -File .\scripts\Validate-AgentWorkspaceKit.ps1
pwsh -File .\scripts\Invoke-KitSmokeTests.ps1
pwsh -File .\scripts\Invoke-KitScenarioSimulations.ps1
pwsh -File .\scripts\New-ReleaseBundle.ps1
```

## Why This Matters

This gives maintainers a cleaner release flow than “download the repo as zip and hope for the best”.
The generated `dist/` folder is intentionally ignored by Git.
