# GitHub Launch Plan

## Goal

Publish `Agent Atlas` as a clean public repository with strong first impression, healthy repository metadata, and a repeatable release path.

## Authentication Status

Local GitHub CLI authentication is already present for the maintainer account.
That means the repository can be created and pushed without asking for an additional token.

## Recommended Public Identity

- Repository name: `agent-atlas`
- Visibility: `public`
- Default branch: `main`
- Tag for first release: `v0.1.0`

## Why This Name

- matches the product name in the docs
- cleaner and more memorable than the old internal working title
- better for badges, release URLs, screenshots, and word-of-mouth sharing

## Preflight Before Publish

Run these locally:

```powershell
pwsh -File .\scripts\Validate-AgentWorkspaceKit.ps1
pwsh -File .\scripts\Invoke-KitSmokeTests.ps1
pwsh -File .\scripts\Invoke-KitScenarioSimulations.ps1
pwsh -File .\scripts\New-ReleaseBundle.ps1
```

## Local Repository Preparation

1. Initialize Git in the repository root.
2. Create a clean initial commit on `main`.
3. Make sure no generated `dist/` or temp artifacts are staged.

## Remote Repository Creation

Use GitHub CLI to create a new public repository from the local directory.

Guideline:

- do not ask GitHub to generate a README, license, or gitignore remotely
- push the existing local repository as-is
- set the description and homepage/social preview immediately after create

## Immediate Post-Create Hardening

After the remote exists:

1. Verify the repository community profile.
2. Enable branch protection on `main`.
3. Require pull requests for future changes.
4. Require status checks for the validation workflow.
5. Confirm Dependabot is active.
6. Confirm `CODEOWNERS` is detected.

## Metadata To Set

- Description:
  `Portable dual-agent workspace harness for Codex, Claude Code, and an optional Obsidian knowledge layer.`
- Topics:
  - `codex`
  - `claude-code`
  - `obsidian`
  - `developer-tools`
  - `agentic`
  - `workflow`
  - `windows`
  - `knowledge-management`
  - `automation`
- Social preview:
  prefer `assets/social-preview.png`

## First Release

1. Create a tag `v0.1.0`.
2. Create a GitHub release from that tag.
3. Attach the generated ZIP and SHA256 from `dist/`.
4. Use a release summary based on `CHANGELOG.md`.

## Recommended Launch Order

1. Publish the repository.
2. Verify README rendering and image loading.
3. Verify the Actions workflow ran successfully on GitHub.
4. Create the `v0.1.0` release.
5. Double-check community profile warnings.
6. Only then share the repository publicly.

## What Can Be Fully Automated

- local git initialization
- initial commit
- GitHub repository creation via `gh`
- push to `main`
- repository description
- topics
- release tag
- GitHub release creation

## What Still Needs Final Human Judgment

- exact public repo name if you want something other than `agent-atlas`
- whether Discussions should be enabled on day one
- whether social preview should use `hero.jpg` directly or a separate export
- branch protection details if you want stricter rules than the safe default
