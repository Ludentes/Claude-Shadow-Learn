#Requires -Version 5.1
# shadow-learn — shadow learning toolkit for Claude Code
# https://github.com/Ludentes/Claude-Shadow-Learn

param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'health', 'install-hooks', 'help')]
    [string]$Command = 'help',

    [switch]$y
)

$ErrorActionPreference = 'Stop'

# --- Constants ---
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsDir = Join-Path $RepoDir 'skills'
$ClaudeSkillsDir = Join-Path $HOME '.claude' 'skills'
$ProjectSlug = (Get-Location).Path -replace '[/\\]', '-'
$MemoryDir = Join-Path $HOME '.claude' 'projects' $ProjectSlug 'memory'

# --- Helpers ---
function Write-Ok   { param([string]$Msg) Write-Host "  ✔ $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "  ⚠ $Msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$Msg) Write-Host "  ✘ $Msg" -ForegroundColor Red }

# --- Bootstrap snippet ---
$Bootstrap = @"
## Shadow Learning

This project uses shadow learning. Learned patterns and entity context are stored in the auto memory directory.

Before work that involves judgment (reviews, architecture, writing):
- Read ``patterns/*.md`` files in the memory directory for domain-specific rules
- Read ``entities/*.md`` files for context about people, services, or systems
- Read ``docs/playbooks/*.md`` in the project repo for repeatable procedures

When the user corrects you, note the correction explicitly — it will be extracted later.
"@

# --- AGENTS.md snippet (cross-tool) ---
$AgentsSnippet = @"
# AGENTS.md

This project uses shadow learning for continuous improvement from user corrections.

## Knowledge Store

Before work that involves judgment (reviews, architecture, writing), check:
- ``docs/playbooks/*.md`` — repeatable procedures (deploy, setup, release)

When the user corrects your output, note the correction explicitly in your response.

## Conventions

- Hard rules (import order, commit format) belong in linters and hooks, not instructions
- Memory is for things requiring judgment — tone, structure, quality bar
- Keep instruction files concise — overly long files degrade agent performance
"@

# =============================================================================
# INIT
# =============================================================================
function Invoke-Init {
    Write-Host "Shadow Learning Init" -ForegroundColor White -NoNewline
    Write-Host ""
    Write-Host ""

    # 1. Memory directories
    Write-Host "Memory directory: $MemoryDir"
    New-Item -ItemType Directory -Path (Join-Path $MemoryDir 'patterns') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $MemoryDir 'entities') -Force | Out-Null
    Write-Ok 'patterns/'
    Write-Ok 'entities/'

    # 2. Playbooks directory
    New-Item -ItemType Directory -Path 'docs\playbooks' -Force | Out-Null
    Write-Ok 'docs/playbooks/'
    Write-Host ''

    # 3. Copy skills
    Write-Host "Installing skills to $ClaudeSkillsDir"
    New-Item -ItemType Directory -Path $ClaudeSkillsDir -Force | Out-Null

    $extractDir = Join-Path $SkillsDir 'session-knowledge-extract'
    if (-not (Test-Path $extractDir)) {
        Write-Fail "Skills not found at $SkillsDir"
        Write-Host '  Run this script from the claude-shadow-learn repo directory.'
        exit 1
    }

    foreach ($skill in @('session-knowledge-extract', 'memory-consolidate')) {
        $src = Join-Path $SkillsDir $skill
        if (Test-Path $src) {
            Copy-Item -Path $src -Destination $ClaudeSkillsDir -Recurse -Force
            Write-Ok $skill
        }
    }
    Write-Host ''

    # 4. Bootstrap CLAUDE.md
    $claudeMd = 'CLAUDE.md'
    if ((Test-Path $claudeMd) -and (Select-String -Path $claudeMd -Pattern 'shadow learning' -Quiet)) {
        Write-Ok "Bootstrap already present in $claudeMd"
    }
    else {
        $doAdd = $false
        if ($y) {
            $doAdd = $true
        }
        else {
            $answer = Read-Host '  Add shadow learning bootstrap to CLAUDE.md? [y/N]'
            if ($answer -match '^[Yy]$') { $doAdd = $true }
        }

        if ($doAdd) {
            if (Test-Path $claudeMd) {
                Add-Content -Path $claudeMd -Value "`n"
            }
            Add-Content -Path $claudeMd -Value $Bootstrap
            Write-Ok "Bootstrap added to $claudeMd"
        }
        else {
            Write-Warn 'Skipped. Add the bootstrap snippet manually later.'
            Write-Host '  See GETTING_STARTED.md for the snippet.'
        }
    }

    # 5. AGENTS.md (cross-tool compatibility)
    $agentsMd = 'AGENTS.md'
    if (Test-Path $agentsMd) {
        Write-Ok 'AGENTS.md already exists'
    }
    else {
        $doAgents = $false
        if ($y) {
            $doAgents = $true
        }
        else {
            $answer = Read-Host '  Create AGENTS.md for cross-tool compatibility? [y/N]'
            if ($answer -match '^[Yy]$') { $doAgents = $true }
        }

        if ($doAgents) {
            Set-Content -Path $agentsMd -Value $AgentsSnippet -Encoding UTF8
            Write-Ok "Created $agentsMd"
        }
        else {
            Write-Warn 'Skipped AGENTS.md. Create it manually if you use non-Claude agents.'
        }
    }

    Write-Host ''
    Write-Host 'Done.' -ForegroundColor White
    Write-Host '  Start working. Correct Claude when it gets things wrong.'
    Write-Host '  Run /session-knowledge-extract at end of day.'
}

# =============================================================================
# HEALTH
# =============================================================================
function Invoke-Health {
    Write-Host "Shadow Learning Health  $(Get-Location)" -ForegroundColor White
    Write-Host ''

    $okCount = 0; $warnCount = 0; $failCount = 0

    # 1. Memory directory
    if (Test-Path $MemoryDir) {
        Write-Ok 'Memory directory exists'
        $okCount++
    }
    else {
        Write-Fail "Memory directory missing: $MemoryDir"
        $failCount++
        Write-Host ''
        Write-Host '  Run: .\shadow-learn.ps1 init'
        return
    }

    # 2. Pattern files
    $patternsDir = Join-Path $MemoryDir 'patterns'
    $patternFiles = @()
    if (Test-Path $patternsDir) {
        $patternFiles = @(Get-ChildItem -Path $patternsDir -Filter '*.md' -ErrorAction SilentlyContinue)
    }
    if ($patternFiles.Count -gt 0) {
        $ruleCount = ($patternFiles | ForEach-Object { Get-Content $_.FullName } |
            Where-Object { $_ -match '^\s*- ' }).Count
        Write-Ok "Pattern files: $($patternFiles.Count) files, $ruleCount rules"
        $okCount++
    }
    else {
        Write-Warn 'No pattern files yet'
        $warnCount++
    }

    # 3. Entity files
    $entitiesDir = Join-Path $MemoryDir 'entities'
    $entityFiles = @()
    if (Test-Path $entitiesDir) {
        $entityFiles = @(Get-ChildItem -Path $entitiesDir -Filter '*.md' -ErrorAction SilentlyContinue)
    }
    if ($entityFiles.Count -gt 0) {
        Write-Ok "Entity files: $($entityFiles.Count) files"
        $okCount++
    }
    else {
        Write-Warn 'No entity files yet'
        $warnCount++
    }

    # 4. Playbook files
    $playbookDir = 'docs\playbooks'
    if (Test-Path $playbookDir) {
        $playbookFiles = @(Get-ChildItem -Path $playbookDir -Filter '*.md' -ErrorAction SilentlyContinue)
        if ($playbookFiles.Count -gt 0) {
            $draftCount = ($playbookFiles | Where-Object {
                (Get-Content $_.FullName -Raw) -match 'status:\s*draft'
            }).Count
            $reviewedCount = ($playbookFiles | Where-Object {
                (Get-Content $_.FullName -Raw) -match 'status:\s*reviewed'
            }).Count
            if ($draftCount -gt 0 -and $reviewedCount -eq 0) {
                Write-Warn "Playbooks: $($playbookFiles.Count) files (all draft - review them)"
                $warnCount++
            }
            else {
                Write-Ok "Playbooks: $($playbookFiles.Count) files ($reviewedCount reviewed, $draftCount draft)"
                $okCount++
            }
        }
        else {
            Write-Warn 'No playbooks yet'
            $warnCount++
        }
    }
    else {
        Write-Warn 'docs/playbooks/ directory missing'
        $warnCount++
    }

    # 5. Line budgets
    $budgetOk = $true
    $memoryMd = Join-Path $MemoryDir 'MEMORY.md'
    if (Test-Path $memoryMd) {
        $memLines = (Get-Content $memoryMd).Count
        if ($memLines -ge 200) {
            Write-Warn "MEMORY.md: $memLines/200 lines - run /memory-consolidate"
            $budgetOk = $false
            $warnCount++
        }
    }

    foreach ($f in $patternFiles) {
        $lines = (Get-Content $f.FullName).Count
        if ($lines -ge 150) {
            Write-Warn "$($f.Name): $lines/150 lines - split or compress"
            $budgetOk = $false
            $warnCount++
        }
    }

    if (Test-Path $playbookDir) {
        foreach ($f in @(Get-ChildItem -Path $playbookDir -Filter '*.md' -ErrorAction SilentlyContinue)) {
            $lines = (Get-Content $f.FullName).Count
            if ($lines -ge 80) {
                Write-Warn "$($f.Name): $lines/80 lines - split"
                $budgetOk = $false
                $warnCount++
            }
        }
    }

    if ($budgetOk) {
        Write-Ok 'Line budgets OK'
        $okCount++
    }

    # 6. Last extraction
    $extractedKnowledge = Join-Path $MemoryDir 'extracted-knowledge.md'
    if (Test-Path $extractedKnowledge) {
        $lastMod = (Get-Item $extractedKnowledge).LastWriteTime
        $daysAgo = [math]::Floor(((Get-Date) - $lastMod).TotalDays)
        $extDate = $lastMod.ToString('yyyy-MM-dd')
        if ($daysAgo -le 3) {
            Write-Ok "Last extraction: $extDate ($daysAgo days ago)"
            $okCount++
        }
        else {
            Write-Warn "Last extraction: $extDate ($daysAgo days ago)"
            $warnCount++
        }
    }
    else {
        Write-Warn 'No extractions yet - run /session-knowledge-extract'
        $warnCount++
    }

    # 7. Bootstrap
    if ((Test-Path 'CLAUDE.md') -and (Select-String -Path 'CLAUDE.md' -Pattern 'shadow learning' -Quiet)) {
        Write-Ok 'Bootstrap in CLAUDE.md'
        $okCount++
    }
    else {
        Write-Fail 'No bootstrap in CLAUDE.md - run: .\shadow-learn.ps1 init'
        $failCount++
    }

    # 8. AGENTS.md (cross-tool)
    if (Test-Path 'AGENTS.md') {
        Write-Ok 'AGENTS.md present (cross-tool compatibility)'
        $okCount++
    }
    else {
        Write-Warn 'No AGENTS.md - run: .\shadow-learn.ps1 init'
        $warnCount++
    }

    Write-Host ''
    Write-Host "  $okCount OK, $warnCount WARN, $failCount MISSING"
}

# =============================================================================
# INSTALL-HOOKS
# =============================================================================
function Invoke-InstallHooks {
    Write-Host 'Install Session-End Hook' -ForegroundColor White
    Write-Host ''

    $settingsPath = '.claude\settings.local.json'
    New-Item -ItemType Directory -Path '.claude' -Force | Out-Null

    # Check existing
    if ((Test-Path $settingsPath) -and (Select-String -Path $settingsPath -Pattern 'session-knowledge-extract' -Quiet)) {
        Write-Ok "Hook already installed in $settingsPath"
        return
    }

    # Read or create settings
    $data = @{}
    if (Test-Path $settingsPath) {
        $data = Get-Content $settingsPath -Raw | ConvertFrom-Json -AsHashtable -ErrorAction SilentlyContinue
        if (-not $data) { $data = @{} }
    }

    $hookEntry = @{
        matcher = ''
        hooks   = @(
            @{
                type          = 'command'
                command       = "claude -p 'Run /session-knowledge-extract on the session that just ended. Write results without asking - apply automatically to extracted-knowledge.md.'"
                timeout       = 300
                statusMessage = 'Extracting session knowledge…'
            }
        )
    }

    if (-not $data.ContainsKey('hooks')) { $data['hooks'] = @{} }
    if (-not $data['hooks'].ContainsKey('Stop')) { $data['hooks']['Stop'] = @() }

    $data['hooks']['Stop'] += $hookEntry

    $data | ConvertTo-Json -Depth 10 | Set-Content $settingsPath -Encoding UTF8
    Write-Ok "Hook installed: session-knowledge-extract on Stop"
    Write-Host "  File: $settingsPath"
    Write-Host ''
    Write-Host '  The hook runs /session-knowledge-extract when a Claude session ends.'
}

# =============================================================================
# USAGE
# =============================================================================
function Show-Usage {
    Write-Host 'shadow-learn - shadow learning toolkit for Claude Code'
    Write-Host ''
    Write-Host 'Usage: .\shadow-learn.ps1 <command> [options]'
    Write-Host ''
    Write-Host 'Commands:'
    Write-Host '  init [-y]        Set up shadow learning for the current project'
    Write-Host '  health           Check shadow learning status'
    Write-Host '  install-hooks    Auto-extract knowledge on session end'
    Write-Host ''
    Write-Host 'Or just copy the skills manually - see README.md'
}

# =============================================================================
# MAIN
# =============================================================================
switch ($Command) {
    'init'          { Invoke-Init }
    'health'        { Invoke-Health }
    'install-hooks' { Invoke-InstallHooks }
    default         { Show-Usage }
}
