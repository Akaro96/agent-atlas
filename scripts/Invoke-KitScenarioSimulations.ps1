[CmdletBinding()]
param(
    [string]$RepoRoot = (Split-Path -Parent $PSScriptRoot),
    [string]$TempRoot = (Join-Path $env:TEMP 'agent-atlas-simulations'),
    [switch]$KeepArtifacts
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function Assert-Path {
    param([string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) {
        throw "Missing expected path: $Path"
    }
}

function Assert-True {
    param([bool]$Condition,[string]$Message)
    if (-not $Condition) {
        throw $Message
    }
}

function Assert-Throws {
    param(
        [scriptblock]$ScriptBlock,
        [string]$FailureMessage
    )

    $threw = $false
    try {
        & $ScriptBlock
    }
    catch {
        $threw = $true
    }

    if (-not $threw) {
        throw $FailureMessage
    }
}

function New-SimulationInstall {
    param(
        [string]$DestinationRoot,
        [string]$WorkspaceName,
        [string]$VaultName,
        [string]$OwnerName
    )

    & (Join-Path $RepoRoot 'scripts\Install-AgentWorkspaceKit.ps1') `
        -DestinationRoot $DestinationRoot `
        -OwnerName $OwnerName `
        -WorkspaceName $WorkspaceName `
        -VaultName $VaultName
}

function Invoke-SpacesAndKnowledgeScenario {
    param([string]$ScenarioRoot)

    $destinationRoot = Join-Path $ScenarioRoot 'Release Candidate With Spaces'
    $workspaceName = 'Studio Workspace Deluxe'
    $vaultName = 'Studio Vault Deluxe'
    $workspaceRoot = Join-Path $destinationRoot $workspaceName
    $vaultRoot = Join-Path $destinationRoot $vaultName

    New-SimulationInstall -DestinationRoot $destinationRoot -WorkspaceName $workspaceName -VaultName $vaultName -OwnerName 'Scenario Test User'

    $startHere = Join-Path $destinationRoot 'START HERE.md'
    $doctor = Join-Path $workspaceRoot '_SHARED\tools\Invoke-WorkspaceDoctor.ps1'
    $capture = Join-Path $workspaceRoot '_SHARED\tools\New-VaultInboxNote.ps1'
    $search = Join-Path $workspaceRoot '_SHARED\tools\Search-Vault.ps1'
    $promote = Join-Path $workspaceRoot '_SHARED\tools\Promote-VaultDraft.ps1'
    $compile = Join-Path $workspaceRoot '_SHARED\tools\Compile-VaultKnowledge.ps1'

    Assert-Path $startHere
    Assert-Path (Join-Path $destinationRoot '.codex\config.toml')
    Assert-Path (Join-Path $destinationRoot '.claude\settings.json')
    Assert-Path $doctor
    Assert-Path $capture
    Assert-Path $search
    Assert-Path $promote
    Assert-Path $compile

    $startText = Get-Content -LiteralPath $startHere -Raw
    Assert-True ($startText.Contains($workspaceRoot)) 'START HERE is missing the generated workspace path.'
    Assert-True ($startText.Contains($vaultRoot)) 'START HERE is missing the generated vault path.'

    & python -c "import tomllib,sys; tomllib.load(open(sys.argv[1],'rb'))" (Join-Path $destinationRoot '.codex\config.toml') | Out-Null
    Get-Content -LiteralPath (Join-Path $destinationRoot '.claude\settings.json') -Raw | ConvertFrom-Json | Out-Null

    & (Join-Path $RepoRoot 'scripts\New-WorkspaceProject.ps1') -WorkspaceRoot $workspaceRoot -ProjectName 'Project Software' -ProjectType software
    & (Join-Path $RepoRoot 'scripts\New-WorkspaceProject.ps1') -WorkspaceRoot $workspaceRoot -ProjectName 'Project Pipeline' -ProjectType ai-pipeline
    & (Join-Path $RepoRoot 'scripts\New-WorkspaceProject.ps1') -WorkspaceRoot $workspaceRoot -ProjectName 'Project Research' -ProjectType research

    Assert-Path (Join-Path $workspaceRoot 'Project Software\src\AGENTS.override.md')
    Assert-Path (Join-Path $workspaceRoot 'Project Pipeline\04_BUILD')
    Assert-Path (Join-Path $workspaceRoot 'Project Research\notes')
    Assert-Path (Join-Path $workspaceRoot 'Project Research\outputs')

    $doctorReport = ((& $doctor -WorkspaceRoot $workspaceRoot -VaultRoot $vaultRoot) -join [Environment]::NewLine)
    Assert-True ($doctorReport -match 'Overall status: \*\*PASS\*\*') 'Workspace doctor did not report PASS in the spaces scenario.'

    $draftOne = (& $capture -VaultRoot $vaultRoot -Title 'Alpha Draft' -Project 'Project Software') | Select-Object -Last 1
    $draftTwo = (& $capture -VaultRoot $vaultRoot -Title 'Beta Draft' -Project 'Project Research') | Select-Object -Last 1
    Assert-Path $draftOne
    Assert-Path $draftTwo

    $draftSearch = ((& $search -VaultRoot $vaultRoot -Query 'Draft' -Scope drafts) -join [Environment]::NewLine)
    Assert-True ($draftSearch -match 'Alpha Draft') 'Draft scope search missed Alpha Draft.'
    Assert-True ($draftSearch -match 'Beta Draft') 'Draft scope search missed Beta Draft.'

    $promotedCopy = (& $promote -VaultRoot $vaultRoot -DraftPath $draftOne -Kind knowledge -KeepOriginal) | Select-Object -Last 1
    $promotedMove = (& $promote -VaultRoot $vaultRoot -DraftPath $draftTwo -Kind decision) | Select-Object -Last 1

    Assert-Path $promotedCopy
    Assert-Path $promotedMove
    Assert-True (Test-Path -LiteralPath $draftOne) 'KeepOriginal promotion removed the original draft.'
    Assert-True (-not (Test-Path -LiteralPath $draftTwo)) 'Move promotion left the original draft in place.'

    & $compile -VaultRoot $vaultRoot | Out-Null
    & $compile -VaultRoot $vaultRoot | Out-Null

    $homeText = Get-Content -LiteralPath (Join-Path $vaultRoot '00 Home.md') -Raw
    $startCount = ([regex]::Matches($homeText, '<!-- ROOTED_AGENTS_COMPILED_VIEWS_START -->')).Count
    $endCount = ([regex]::Matches($homeText, '<!-- ROOTED_AGENTS_COMPILED_VIEWS_END -->')).Count
    Assert-True ($startCount -eq 1) 'Compiled views start marker duplicated after repeated compile.'
    Assert-True ($endCount -eq 1) 'Compiled views end marker duplicated after repeated compile.'

    $knowledgeIndex = Get-Content -LiteralPath (Join-Path $vaultRoot '00_System\Knowledge Index.md') -Raw
    $decisionIndex = Get-Content -LiteralPath (Join-Path $vaultRoot '00_System\Decision Index.md') -Raw
    $draftDigest = Get-Content -LiteralPath (Join-Path $vaultRoot '00_System\Draft Digest.md') -Raw
    Assert-True ($knowledgeIndex -match 'Alpha Draft') 'Knowledge Index missed promoted draft.'
    Assert-True ($decisionIndex -match 'Beta Draft') 'Decision Index missed promoted draft.'
    Assert-True ($draftDigest -match 'Alpha Draft') 'Draft Digest missed retained draft.'
    Assert-True ($draftDigest -notmatch 'Beta Draft') 'Draft Digest still contains a moved draft.'

    $curatedSearch = ((& $search -VaultRoot $vaultRoot -Query 'Draft' -Scope curated) -join [Environment]::NewLine)
    Assert-True ($curatedSearch -match 'Alpha Draft') 'Curated search missed Alpha Draft.'
    Assert-True ($curatedSearch -match 'Beta Draft') 'Curated search missed Beta Draft.'
}

function Invoke-WorkspaceOnlyScenario {
    param([string]$ScenarioRoot)

    $destinationRoot = Join-Path $ScenarioRoot 'Workspace-Only'
    $workspaceRoot = Join-Path $destinationRoot 'Solo-Workspace'
    $vaultRoot = Join-Path $destinationRoot 'Solo-Vault'

    New-SimulationInstall -DestinationRoot $destinationRoot -WorkspaceName 'Solo-Workspace' -VaultName 'Solo-Vault' -OwnerName 'Workspace Only User'

    & (Join-Path $RepoRoot 'scripts\New-WorkspaceProject.ps1') -WorkspaceRoot $workspaceRoot -ProjectName 'Minimal Project' -ProjectType software

    Assert-Path (Join-Path $workspaceRoot 'Minimal Project\README.md')
    Assert-Path (Join-Path $workspaceRoot 'Minimal Project\docs\OVERVIEW.md')
    Assert-Path (Join-Path $workspaceRoot 'Minimal Project\src\AGENTS.override.md')

    $doctorOutput = ((& (Join-Path $workspaceRoot '_SHARED\tools\Invoke-WorkspaceDoctor.ps1') -WorkspaceRoot $workspaceRoot -VaultRoot $vaultRoot) -join [Environment]::NewLine)
    Assert-True ($doctorOutput -match 'Overall status: \*\*PASS\*\*') 'Workspace-only doctor run did not pass.'
}

function Invoke-ReleaseConsumerScenario {
    param([string]$ScenarioRoot)

    $distRoot = Join-Path $ScenarioRoot 'dist'
    $extractRoot = Join-Path $ScenarioRoot 'extract'

    & (Join-Path $RepoRoot 'scripts\New-ReleaseBundle.ps1') -DistRoot $distRoot -SkipChecks | Out-Null

    $zipPath = Join-Path $distRoot 'AgentAtlas-0.1.0.zip'
    $hashPath = Join-Path $distRoot 'AgentAtlas-0.1.0.sha256.txt'
    Assert-Path $zipPath
    Assert-Path $hashPath

    Expand-Archive -LiteralPath $zipPath -DestinationPath $extractRoot -Force
    $bundleRoot = Join-Path $extractRoot 'AgentAtlas-0.1.0'
    Assert-Path $bundleRoot

    & (Join-Path $bundleRoot 'scripts\Validate-AgentWorkspaceKit.ps1') | Out-Null
    $bundleReadme = Get-Content -LiteralPath (Join-Path $bundleRoot 'README.md') -Raw
    Assert-True ($bundleReadme -match 'portable starter configs') 'Release bundle README lost the config-merge clarification.'
}

function Invoke-NegativeScenario {
    param([string]$ScenarioRoot)

    $destinationRoot = Join-Path $ScenarioRoot 'Negative-Install'
    $workspaceRoot = Join-Path $destinationRoot 'Negative-Workspace'
    $vaultRoot = Join-Path $destinationRoot 'Negative-Vault'
    $stagingRoot = Join-Path $env:TEMP 'agent-atlas-release-9.9.9-test'

    New-SimulationInstall -DestinationRoot $destinationRoot -WorkspaceName 'Negative-Workspace' -VaultName 'Negative-Vault' -OwnerName 'Negative User'

    $promote = Join-Path $workspaceRoot '_SHARED\tools\Promote-VaultDraft.ps1'
    $compile = Join-Path $workspaceRoot '_SHARED\tools\Compile-VaultKnowledge.ps1'
    $badPath = Join-Path $vaultRoot '30_Knowledge\Already Curated.md'
    Set-Content -LiteralPath $badPath -Value '# Already Curated' -NoNewline

    Assert-Throws -ScriptBlock { & $promote -VaultRoot $vaultRoot -DraftPath $badPath -Kind knowledge | Out-Null } -FailureMessage 'Promotion guard did not reject non-draft input.'

    & $compile -VaultRoot $vaultRoot | Out-Null
    & $compile -VaultRoot $vaultRoot | Out-Null

    & (Join-Path $RepoRoot 'scripts\New-ReleaseBundle.ps1') -Version '9.9.9-test' -DistRoot (Join-Path $ScenarioRoot 'dist') -SkipChecks | Out-Null
    Assert-True (-not (Test-Path -LiteralPath $stagingRoot)) 'Release staging root was not cleaned up.'
}

if (Test-Path -LiteralPath $TempRoot) {
    Remove-Item -LiteralPath $TempRoot -Recurse -Force
}

try {
    & (Join-Path $RepoRoot 'scripts\Validate-AgentWorkspaceKit.ps1')

    Invoke-SpacesAndKnowledgeScenario -ScenarioRoot (Join-Path $TempRoot 'spaces-and-knowledge')
    Invoke-WorkspaceOnlyScenario -ScenarioRoot (Join-Path $TempRoot 'workspace-only')
    Invoke-ReleaseConsumerScenario -ScenarioRoot (Join-Path $TempRoot 'release-consumer')
    Invoke-NegativeScenario -ScenarioRoot (Join-Path $TempRoot 'negative')

    Write-Host 'Scenario simulations passed.' -ForegroundColor Green
}
finally {
    if (-not $KeepArtifacts -and (Test-Path -LiteralPath $TempRoot)) {
        Remove-Item -LiteralPath $TempRoot -Recurse -Force
    }
}
