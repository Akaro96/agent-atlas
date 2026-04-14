[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [string]$Body,
    [string]$Source = 'agent-atlas',
    [string]$Project,
    [string[]]$Tags = @('agent-draft'),
    [string]$VaultRoot = '__VAULT_ROOT__',
    [switch]$Preview,
    [switch]$PreviewOnly,
    [switch]$AsJson
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

function ConvertTo-Slug {
    param([string]$Value)

    $slug = $Value.ToLowerInvariant()
    $slug = $slug -replace '[^a-z0-9]+', '-'
    $slug = $slug.Trim('-')
    if (-not $slug) {
        return 'note'
    }

    return $slug
}

function ConvertTo-YamlSingleQuoted {
    param([string]$Value)

    return "'" + ($Value -replace "'", "''") + "'"
}

function Resolve-ProjectNoteTitle {
    param(
        [string]$ProjectName,
        [string]$VaultRoot
    )

    if (-not $ProjectName) {
        return $null
    }

    $projectFolder = Join-Path $VaultRoot '20_Projects'
    if (-not (Test-Path -LiteralPath $projectFolder)) {
        return $null
    }

    $candidates = @(
        $ProjectName,
        ($ProjectName + ' Workspace')
    )

    foreach ($candidate in $candidates) {
        $candidatePath = Join-Path $projectFolder ($candidate + '.md')
        if (Test-Path -LiteralPath $candidatePath) {
            return $candidate
        }
    }

    return $null
}

function Normalize-Tags {
    param([string[]]$Values)

    $normalized = New-Object System.Collections.Generic.List[string]
    foreach ($value in @($Values)) {
        if (-not $value) {
            continue
        }

        $parts = if ($value.Contains(',')) { $value -split ',' } else { @($value) }
        foreach ($part in $parts) {
            $clean = $part.Trim().Trim("'`"")
            if ($clean) {
                $normalized.Add($clean)
            }
        }
    }

    return @($normalized)
}

$targetFolder = Join-Path $VaultRoot '10_Inbox\Agent Drafts'
New-Item -ItemType Directory -Path $targetFolder -Force | Out-Null

$datePrefix = Get-Date -Format 'yyyy-MM-dd'
$safeTitle = $Title -replace '[<>:"/\\|?*]', '-'
$safeTitle = ($safeTitle -replace '\s+', ' ').Trim()
if (-not $safeTitle) {
    $safeTitle = 'Untitled note'
}

$baseName = "$datePrefix - $safeTitle"
$filePath = Join-Path $targetFolder ($baseName + '.md')
$counter = 2
while (Test-Path -LiteralPath $filePath) {
    $filePath = Join-Path $targetFolder ("$baseName-$counter.md")
    $counter += 1
}

$relativePath = $filePath.Substring([System.IO.Path]::GetFullPath($VaultRoot).Length).TrimStart('\')
$created = Get-Date -Format 'yyyy-MM-ddTHH:mm:ss'

$allTags = New-Object System.Collections.Generic.List[string]
foreach ($tag in (Normalize-Tags -Values $Tags)) {
    if ($tag -and -not $allTags.Contains($tag)) {
        $allTags.Add($tag)
    }
}

if ($Project) {
    $projectTag = 'project/' + (ConvertTo-Slug -Value $Project)
    if (-not $allTags.Contains($projectTag)) {
        $allTags.Add($projectTag)
    }
}

$frontmatter = New-Object System.Collections.Generic.List[string]
$frontmatter.Add('---')
$frontmatter.Add("title: $(ConvertTo-YamlSingleQuoted -Value $Title)")
$frontmatter.Add('type: agent-draft')
$frontmatter.Add('status: inbox')
$frontmatter.Add("created: $created")
$frontmatter.Add("source: $(ConvertTo-YamlSingleQuoted -Value $Source)")

if ($Project) {
    $frontmatter.Add("project: $(ConvertTo-YamlSingleQuoted -Value $Project)")
}

$frontmatter.Add('tags:')
foreach ($tag in $allTags) {
    $frontmatter.Add("  - $(ConvertTo-YamlSingleQuoted -Value $tag)")
}
$frontmatter.Add('---')

$contentBody = if ($Body) {
    $Body.Trim()
}
else {
    "## Summary`r`n`r`n-`r`n`r`n## Next Action`r`n`r`n- decide whether this stays a draft or moves into Projects, Knowledge, Decisions, or Prompts"
}

$relatedNotes = New-Object System.Collections.Generic.List[string]
$relatedNotes.Add('[[00 Home]]')
$relatedNotes.Add('[[Projects]]')

$projectNoteTitle = Resolve-ProjectNoteTitle -ProjectName $Project -VaultRoot $VaultRoot
if ($projectNoteTitle) {
    $relatedNotes.Add("[[$projectNoteTitle]]")
}

$relatedBlock = @(
    '## Related Notes',
    ''
) + ($relatedNotes | ForEach-Object { '- ' + $_ })

$frontmatterText = ($frontmatter -join "`r`n")
$content = @(
    $frontmatterText,
    '',
    ('# ' + $Title),
    '',
    ($relatedBlock -join "`r`n"),
    '',
    $contentBody
) -join "`r`n"

$result = [pscustomobject]@{
    Path         = $filePath
    RelativePath = $relativePath
    PreviewOnly  = [bool]($Preview -or $PreviewOnly)
    Title        = $Title
}

if ($Preview -or $PreviewOnly) {
    if ($AsJson) {
        $result | ConvertTo-Json -Depth 5
    }
    else {
        Write-Output "Preview path: $filePath"
        Write-Output $content
    }
    return
}

if ($PSCmdlet.ShouldProcess($filePath, 'Create vault inbox note')) {
    Set-Content -LiteralPath $filePath -Value $content -Encoding UTF8
}

if ($AsJson) {
    $result | ConvertTo-Json -Depth 5
}
else {
    Write-Output $filePath
}
