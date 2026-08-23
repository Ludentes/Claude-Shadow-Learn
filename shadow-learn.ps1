#Requires -Version 5.1
# shadow-learn — shadow learning toolkit for Claude Code, Codex CLI, and Kimi Code
# https://github.com/Ludentes/Claude-Shadow-Learn

param(
    [Parameter(Position = 0)]
    [ValidateSet('init', 'health', 'migrate', 'install-hooks', 'help')]
    [string]$Command = 'help',

    [Parameter(Position = 1)]
    [string]$Target = '',

    [switch]$y,
    [switch]$Merge
)

$ErrorActionPreference = 'Stop'

# --- Constants ---
$RepoDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$SkillsDir = Join-Path $RepoDir 'skills'
$AgentsDir = Join-Path $RepoDir 'agents'
$BootstrapPatternsDir = Join-Path $RepoDir 'bootstrap-patterns'
$AgentsHome      = Join-Path $HOME '.agents'
$AgentsSkillsDir = Join-Path $AgentsHome 'skills'
$AgentsBinDir    = Join-Path $AgentsHome 'bin'
$MemoryDir       = Join-Path (Get-Location) '.agents\memory'

# --- Helpers ---
function Write-Ok   { param([string]$Msg) Write-Host "  ✔ $Msg" -ForegroundColor Green }
function Write-Warn { param([string]$Msg) Write-Host "  ⚠ $Msg" -ForegroundColor Yellow }
function Write-Fail { param([string]$Msg) Write-Host "  ✘ $Msg" -ForegroundColor Red }

# --- Tool detection ---
# Tools that need skills copied into their own directory.
# Kimi reads ~/.agents/skills natively and is handled separately.
function Get-DetectedTools {
    $found = @()
    if (Test-Path (Join-Path $HOME '.claude')) {
        $found += [pscustomobject]@{ Name = 'claude'; Dir = (Join-Path $HOME '.claude' 'skills') }
    }
    if (Test-Path (Join-Path $HOME '.codex')) {
        $found += [pscustomobject]@{ Name = 'codex'; Dir = (Join-Path $HOME '.codex' 'skills') }
    }
    return $found
}

function Test-KimiInstalled {
    return (Test-Path (Join-Path $HOME '.kimi-code')) -or (Test-Path (Join-Path $HOME '.kimi'))
}

# =============================================================================
# INIT
# =============================================================================
function Invoke-Init {
    Write-Host "Shadow Learning Init" -ForegroundColor White -NoNewline
    Write-Host ""
    Write-Host ""

    # Project store
    Write-Host "Knowledge store: $MemoryDir"
    New-Item -ItemType Directory -Path (Join-Path $MemoryDir 'patterns') -Force | Out-Null
    New-Item -ItemType Directory -Path (Join-Path $MemoryDir 'entities') -Force | Out-Null
    New-Item -ItemType Directory -Path 'docs\playbooks' -Force | Out-Null
    Write-Ok 'patterns/'
    Write-Ok 'entities/'
    Write-Ok 'docs/playbooks/'
    Write-Host ''

    # User-global skills and normalizer
    Write-Host "Installing to $AgentsHome"
    New-Item -ItemType Directory -Path $AgentsSkillsDir -Force | Out-Null
    New-Item -ItemType Directory -Path $AgentsBinDir -Force | Out-Null

    $extractDir = Join-Path $SkillsDir 'session-knowledge-extract'
    if (-not (Test-Path $extractDir)) {
        Write-Fail "Skills not found at $SkillsDir"
        Write-Host '  Run this script from the claude-shadow-learn repo directory.'
        exit 1
    }

    foreach ($skill in @('session-knowledge-extract', 'memory-consolidate', 'start-research-thread')) {
        $src = Join-Path $SkillsDir $skill
        if (Test-Path $src) {
            $dest = Join-Path $AgentsSkillsDir $skill
            if (Test-Path $dest) { Remove-Item -Path $dest -Recurse -Force }
            Copy-Item -Path $src -Destination $AgentsSkillsDir -Recurse -Force
            Write-Ok "skills/$skill"
        }
    }
    Copy-Item -Path (Join-Path $RepoDir 'bin\session-turns') -Destination (Join-Path $AgentsBinDir 'session-turns') -Force
    Write-Ok 'bin/session-turns'
    Write-Host ''

    # Copy into each installed tool.
    # Windows gets copies, not symlinks: creating a symlink needs elevation or
    # developer mode, and a failed link is worse than a copy the user refreshes.
    Write-Host 'Copying skills into installed tools'
    foreach ($tool in (Get-DetectedTools)) {
        New-Item -ItemType Directory -Path $tool.Dir -Force | Out-Null
        foreach ($skillPath in (Get-ChildItem -Path $AgentsSkillsDir -Directory -ErrorAction SilentlyContinue)) {
            $dest = Join-Path $tool.Dir $skillPath.Name
            if (Test-Path $dest) { Remove-Item -Path $dest -Recurse -Force }
            Copy-Item -Path $skillPath.FullName -Destination $tool.Dir -Recurse -Force
        }
        Write-Ok "$($tool.Name) -> $($tool.Dir)"
    }
    if (Test-KimiInstalled) {
        Write-Ok 'kimi -> reads ~/.agents/skills natively (no copy needed)'
    }
    Write-Warn 'Windows: skills are copied, not linked. Re-run init after editing a skill.'
    Write-Host ''

    # Seed bootstrap pattern files
    if (Test-Path $BootstrapPatternsDir) {
        Write-Host "Seeding bootstrap patterns into $MemoryDir\patterns\"
        foreach ($patternFile in (Get-ChildItem -Path $BootstrapPatternsDir -Filter '*.md' -ErrorAction SilentlyContinue)) {
            $dest = Join-Path $MemoryDir 'patterns' $patternFile.Name
            if (Test-Path $dest) {
                Write-Ok "$($patternFile.Name) already present (kept local edits)"
            } else {
                Copy-Item -Path $patternFile.FullName -Destination $dest -Force
                Write-Ok "$($patternFile.Name) (copied)"
            }
        }
        Write-Host ''
    }

    # Project subagents (Claude-only feature)
    if ((Test-Path (Join-Path $HOME '.claude')) -and (Test-Path $AgentsDir) -and (Get-ChildItem -Path $AgentsDir -Filter '*.md' -ErrorAction SilentlyContinue)) {
        Write-Host 'Installing project subagents to .claude/agents/'
        New-Item -ItemType Directory -Path '.claude/agents' -Force | Out-Null
        foreach ($agentFile in (Get-ChildItem -Path $AgentsDir -Filter '*.md')) {
            $dest = Join-Path '.claude/agents' $agentFile.Name
            if (Test-Path $dest) {
                Write-Ok "$($agentFile.Name) already present (kept local edits)"
            } else {
                Copy-Item -Path $agentFile.FullName -Destination $dest -Force
                Write-Ok $agentFile.Name
            }
        }
        Write-Host ''
    }

    # AGENTS.md
    if (Test-Path 'AGENTS.md') {
        Write-Ok 'AGENTS.md already exists (kept local edits)'
    }
    else {
        Copy-Item -Path (Join-Path $RepoDir 'AGENTS.md.template') -Destination 'AGENTS.md' -Force
        Write-Ok 'Created AGENTS.md'
    }

    # CLAUDE.md pointer
    if ((Test-Path 'CLAUDE.md') -and (Select-String -Path 'CLAUDE.md' -Pattern 'AGENTS.md' -Quiet)) {
        Write-Ok 'CLAUDE.md already points at AGENTS.md'
    }
    elseif (Test-Path (Join-Path $HOME '.claude')) {
        if (Test-Path 'CLAUDE.md') { Add-Content -Path 'CLAUDE.md' -Value '' }
        Add-Content -Path 'CLAUDE.md' -Value 'See [AGENTS.md](AGENTS.md) for shadow learning instructions.'
        Write-Ok 'CLAUDE.md points at AGENTS.md'
    }

    # Privacy choice
    $ignored = (Test-Path '.gitignore') -and (Select-String -Path '.gitignore' -Pattern '^\.agents/memory/' -Quiet)
    if (-not $ignored) {
        $share = $false
        if ($y) {
            $share = $true
        }
        else {
            Write-Host ''
            Write-Host '  .agents/memory/ holds learned patterns and entity notes.'
            Write-Host '  Committing it shares learning with your team; it may contain names'
            Write-Host '  or client details.'
            $answer = Read-Host '  Commit .agents/memory/ to git? [Y/n]'
            if ($answer -notmatch '^[Nn]$') { $share = $true }
        }
        if ($share) {
            Write-Ok '.agents/memory/ will be committed (shared with the team)'
        }
        else {
            Add-Content -Path '.gitignore' -Value '.agents/memory/'
            Write-Ok '.agents/memory/ added to .gitignore (private)'
        }
    }

    Write-Host ''
    Write-Host 'Done.' -ForegroundColor White
    Write-Host '  Start working. Correct the agent when it gets things wrong.'
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

    # 7. Instruction file
    if ((Test-Path 'AGENTS.md') -and (Select-String -Path 'AGENTS.md' -Pattern '\.agents/memory' -Quiet)) {
        Write-Ok 'AGENTS.md points at the knowledge store'
        $okCount++
    }
    else {
        Write-Fail 'AGENTS.md missing or not pointing at .agents/memory - run: .\shadow-learn.ps1 init'
        $failCount++
    }

    # 8. Per-tool reachability
    $anyTool = $false
    foreach ($tool in (Get-DetectedTools)) {
        $anyTool = $true
        if (Test-Path (Join-Path $tool.Dir 'session-knowledge-extract')) {
            Write-Ok "$($tool.Name): skills installed"
            $okCount++
        }
        else {
            Write-Warn "$($tool.Name): skills not installed - run: .\shadow-learn.ps1 init"
            $warnCount++
        }
    }
    if (Test-KimiInstalled) {
        $anyTool = $true
        if (Test-Path (Join-Path $AgentsSkillsDir 'session-knowledge-extract')) {
            Write-Ok 'kimi: skills present in ~/.agents/skills (native)'
            $okCount++
        }
        else {
            Write-Warn 'kimi: ~/.agents/skills missing - run: .\shadow-learn.ps1 init'
            $warnCount++
        }
    }
    if (-not $anyTool) { Write-Warn 'No supported agent tool detected' }

    # 9. Transcript reader
    $turnsPath = Join-Path $AgentsBinDir 'session-turns'
    if (Test-Path $turnsPath) {
        $py = if (Get-Command python3 -ErrorAction SilentlyContinue) { 'python3' } else { 'python' }
        $report = (& $py $turnsPath --since 7d 2>&1 1>$null) -join ' '
        Write-Ok "session-turns: $report"
        $okCount++
    }
    else {
        Write-Warn 'session-turns not installed - run: .\shadow-learn.ps1 init'
        $warnCount++
    }

    Write-Host ''
    Write-Host "  $okCount OK, $warnCount WARN, $failCount MISSING"
}

# =============================================================================
# MIGRATE
# =============================================================================
function Invoke-Migrate {
    $slug = (Get-Location).Path -replace '[/\\]', '-'
    $legacy = Join-Path $HOME '.claude' 'projects' $slug 'memory'

    Write-Host 'Migrate legacy Claude store' -ForegroundColor White
    Write-Host ''

    if (-not (Test-Path $legacy)) {
        Write-Fail "No legacy store at $legacy"
        exit 1
    }

    $hasContent = (Test-Path $MemoryDir) -and (Get-ChildItem -Path $MemoryDir -Recurse -File -ErrorAction SilentlyContinue)
    if ($hasContent -and (-not $Merge)) {
        Write-Fail "$MemoryDir already has content"
        Write-Host '  Re-run with -Merge to add missing files without overwriting.'
        exit 1
    }

    New-Item -ItemType Directory -Path $MemoryDir -Force | Out-Null
    $copied = 0
    $kept = 0
    foreach ($src in (Get-ChildItem -Path $legacy -Recurse -File -Filter '*.md')) {
        $rel = $src.FullName.Substring($legacy.Length).TrimStart('\', '/')
        $dest = Join-Path $MemoryDir $rel
        if (Test-Path $dest) {
            Write-Ok "$rel already present (kept)"
            $kept++
        }
        else {
            New-Item -ItemType Directory -Path (Split-Path -Parent $dest) -Force | Out-Null
            Copy-Item -Path $src.FullName -Destination $dest -Force
            Write-Ok $rel
            $copied++
        }
    }

    Write-Host ''
    Write-Host "  $copied copied, $kept kept"
    Write-Host "  Original left intact at $legacy"
    Write-Warn 'Review .agents/memory/ for names or client details before committing.'
}

# =============================================================================
# INSTALL-HOOKS
# =============================================================================
function Invoke-InstallHooks {
    param([string]$Tool = 'claude')
    switch ($Tool) {
        'claude' { Install-HooksClaude }
        'kimi'   { Install-HooksKimi }
        'codex'  {
            Write-Warn 'Codex hook installation is not automated.'
            Write-Host "  Codex's hook schema is not verified against a live install."
            Write-Host '  See GETTING_STARTED.md for the config.toml block to add by hand.'
        }
        default  { Write-Fail "Unknown tool: $Tool (expected claude, kimi, or codex)"; exit 1 }
    }
}

function Install-HooksKimi {
    $config = Join-Path $HOME '.kimi-code' 'config.toml'
    if (-not (Test-Path $config)) { $config = Join-Path $HOME '.kimi' 'config.toml' }
    if (-not (Test-Path $config)) {
        Write-Fail 'No Kimi config found at ~/.kimi-code/config.toml'
        exit 1
    }
    if (Select-String -Path $config -Pattern 'session-knowledge-extract' -Quiet) {
        Write-Ok "Hook already installed in $config"
        return
    }

    # Kimi ships `hooks = []` in the root table. Appending [[hooks]] alongside it
    # is a duplicate key and makes the TOML invalid, so drop the empty array first.
    # A non-empty inline array is left alone - merging it is the user's call.
    $lines = Get-Content $config
    if ($lines | Where-Object { $_ -match '^\s*hooks\s*=\s*\[\s*\S' }) {
        Write-Fail "$config already defines a non-empty inline 'hooks' array"
        Write-Host '  Add this to it by hand, or convert it to [[hooks]] tables first:'
        Write-Host '    { event = "SessionEnd", command = "kimi -p ..." }'
        exit 1
    }
    $kept = $lines | Where-Object { $_ -notmatch '^\s*hooks\s*=\s*\[\s*\]\s*$' }
    $block = @(
        '',
        '[[hooks]]',
        'event = "SessionEnd"',
        'command = "kimi -p ''Run the session-knowledge-extract skill on the session that just ended. Write results without asking.''"'
    )
    Set-Content -Path $config -Value ($kept + $block) -Encoding UTF8
    Write-Ok 'Hook installed: session-knowledge-extract on SessionEnd'
    Write-Host "  File: $config"
}

function Install-HooksClaude {
    Write-Host 'Install Session-End Hook (Claude Code)' -ForegroundColor White
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
    Write-Host 'shadow-learn - shadow learning toolkit for Claude Code, Codex CLI, and Kimi Code'
    Write-Host ''
    Write-Host 'Usage: .\shadow-learn.ps1 <command> [options]'
    Write-Host ''
    Write-Host 'Commands:'
    Write-Host '  init [-y]                Set up shadow learning for the current project'
    Write-Host '  health                   Check status across all installed tools'
    Write-Host '  migrate [-Merge]         Move a legacy ~/.claude memory store into .agents/memory/'
    Write-Host '  install-hooks [TOOL]     Auto-extract on session end (claude|kimi|codex)'
    Write-Host ''
    Write-Host 'Supported tools: Claude Code, Codex CLI, Kimi Code'
    Write-Host ''
    Write-Host 'Or just copy the skills manually - see README.md'
}

# =============================================================================
# MAIN
# =============================================================================
switch ($Command) {
    'init'          { Invoke-Init }
    'health'        { Invoke-Health }
    'migrate'       { Invoke-Migrate }
    'install-hooks' { if ($Target) { Invoke-InstallHooks -Tool $Target } else { Invoke-InstallHooks } }
    default         { Show-Usage }
}
