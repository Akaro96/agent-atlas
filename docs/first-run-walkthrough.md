# First Run Walkthrough

## Goal

This walkthrough is for someone who just downloaded the repository and wants a clean first experience.

## Step 1

Open PowerShell in the repo root and run:

```powershell
pwsh -File .\scripts\Install-AgentWorkspaceKit.ps1 `
  -DestinationRoot "D:\AgentWorkspace" `
  -OwnerName "Your Name" `
  -WorkspaceName "AI-Workspace" `
  -VaultName "Knowledge-Vault"
```

## Step 2

Open:

- `D:\AgentWorkspace\START HERE.md`

Read it once.
That file tells you exactly where the generated workspace, vault, and configs live.
Those generated `.codex/` and `.claude/` files are starter configs for you to review and merge.
The installer does not silently replace your existing home-directory agent setup.

## Step 3

Create a real project:

```powershell
pwsh -File .\scripts\New-WorkspaceProject.ps1 `
  -WorkspaceRoot "D:\AgentWorkspace\AI-Workspace" `
  -ProjectName "My-Project" `
  -ProjectType software
```

## Step 4

Run the workspace doctor:

```powershell
pwsh -File "D:\AgentWorkspace\AI-Workspace\_SHARED\tools\Invoke-WorkspaceDoctor.ps1"
```

## Step 5

Create a draft note:

```powershell
pwsh -File "D:\AgentWorkspace\AI-Workspace\_SHARED\tools\New-VaultInboxNote.ps1" `
  -VaultRoot "D:\AgentWorkspace\Knowledge-Vault" `
  -Title "First durable note" `
  -Project "My-Project"
```

## Step 6

Compile the vault:

```powershell
pwsh -File "D:\AgentWorkspace\AI-Workspace\_SHARED\tools\Compile-VaultKnowledge.ps1" `
  -VaultRoot "D:\AgentWorkspace\Knowledge-Vault"
```

Now the generated index pages in `00_System/` reflect your curated knowledge model.

## Step 7

Once a project becomes serious enough to deserve durable recall, create a candidate draft before manually curating it:

```powershell
pwsh -File "D:\AgentWorkspace\AI-Workspace\_SHARED\tools\Sync-WorkspaceProjectDrafts.ps1" `
  -WorkspaceRoot "D:\AgentWorkspace\AI-Workspace" `
  -VaultRoot "D:\AgentWorkspace\Knowledge-Vault" `
  -AllProjects
```
