#!/usr/bin/env bash
set -euo pipefail

# shadow-learn — shadow learning toolkit for Claude Code
# https://github.com/Ludentes/Claude-Shadow-Learn

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_DIR="$REPO_DIR/skills"
CLAUDE_SKILLS_DIR="$HOME/.claude/skills"
PROJECT_SLUG=$(echo "$PWD" | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_SLUG/memory"

# --- Color detection ---
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
  GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BOLD=''; RESET=''
fi

ok()   { echo -e "  ${GREEN}✔${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET} $1"; }
fail() { echo -e "  ${RED}✘${RESET} $1"; }

# --- OS detection for stat/date ---
if [[ "$(uname)" == "Darwin" ]]; then
  file_mtime() { stat -f %m "$1" 2>/dev/null; }
  mtime_date() { date -r "$(stat -f %m "$1")" "+%Y-%m-%d" 2>/dev/null; }
  days_since() { echo $(( ( $(date +%s) - $(stat -f %m "$1") ) / 86400 )); }
else
  file_mtime() { stat -c %Y "$1" 2>/dev/null; }
  mtime_date() { date -d "@$(stat -c %Y "$1")" "+%Y-%m-%d" 2>/dev/null; }
  days_since() { echo $(( ( $(date +%s) - $(stat -c %Y "$1") ) / 86400 )); }
fi

# --- Bootstrap snippet ---
BOOTSTRAP='## Shadow Learning

This project uses shadow learning. Learned patterns and entity context are stored in the auto memory directory.

Before work that involves judgment (reviews, architecture, writing):
- Read `patterns/*.md` files in the memory directory for domain-specific rules
- Read `entities/*.md` files for context about people, services, or systems
- Read `docs/playbooks/*.md` in the project repo for repeatable procedures

When the user corrects you, note the correction explicitly — it will be extracted later.'

# --- AGENTS.md snippet (cross-tool) ---
AGENTS_SNIPPET='# AGENTS.md

This project uses shadow learning for continuous improvement from user corrections.

## Knowledge Store

Before work that involves judgment (reviews, architecture, writing), check:
- `docs/playbooks/*.md` — repeatable procedures (deploy, setup, release)

When the user corrects your output, note the correction explicitly in your response.

## Conventions

- Hard rules (import order, commit format) belong in linters and hooks, not instructions
- Memory is for things requiring judgment — tone, structure, quality bar
- Keep instruction files concise — overly long files degrade agent performance'

# =============================================================================
# INIT
# =============================================================================
cmd_init() {
  local auto_yes=false
  [[ "${1:-}" == "-y" ]] && auto_yes=true

  echo -e "${BOLD}Shadow Learning Init${RESET}"
  echo ""

  # 1. Memory directories
  echo "Memory directory: $MEMORY_DIR"
  mkdir -p "$MEMORY_DIR/patterns" "$MEMORY_DIR/entities"
  ok "patterns/"
  ok "entities/"

  # 2. Playbooks directory (in project repo)
  mkdir -p "docs/playbooks"
  ok "docs/playbooks/"
  echo ""

  # 3. Copy skills
  echo "Installing skills to $CLAUDE_SKILLS_DIR"
  mkdir -p "$CLAUDE_SKILLS_DIR"

  if [ ! -d "$SKILLS_DIR/session-knowledge-extract" ]; then
    fail "Skills not found at $SKILLS_DIR"
    echo "  Run this script from the claude-shadow-learn repo directory."
    exit 1
  fi

  for skill in session-knowledge-extract memory-consolidate; do
    if [ -d "$SKILLS_DIR/$skill" ]; then
      cp -r "$SKILLS_DIR/$skill" "$CLAUDE_SKILLS_DIR/"
      ok "$skill"
    fi
  done
  echo ""

  # 4. Bootstrap CLAUDE.md
  local claude_md="CLAUDE.md"
  if [ -f "$claude_md" ] && grep -qi "shadow learning" "$claude_md" 2>/dev/null; then
    ok "Bootstrap already present in $claude_md"
  else
    local do_add=false
    if $auto_yes; then
      do_add=true
    else
      read -r -p "  Add shadow learning bootstrap to $claude_md? [y/N] " answer
      [[ "$answer" =~ ^[Yy]$ ]] && do_add=true
    fi

    if $do_add; then
      if [ -f "$claude_md" ]; then
        # Add blank line before snippet if file doesn't end with one
        [[ -s "$claude_md" && "$(tail -c 1 "$claude_md")" != "" ]] && echo "" >> "$claude_md"
        echo "" >> "$claude_md"
      fi
      echo "$BOOTSTRAP" >> "$claude_md"
      ok "Bootstrap added to $claude_md"
    else
      warn "Skipped. Add the bootstrap snippet manually later."
      echo "  See GETTING_STARTED.md for the snippet."
    fi
  fi

  # 5. AGENTS.md (cross-tool compatibility)
  local agents_md="AGENTS.md"
  if [ -f "$agents_md" ]; then
    ok "AGENTS.md already exists"
  else
    local do_agents=false
    if $auto_yes; then
      do_agents=true
    else
      read -r -p "  Create AGENTS.md for cross-tool compatibility? [y/N] " answer
      [[ "$answer" =~ ^[Yy]$ ]] && do_agents=true
    fi

    if $do_agents; then
      echo "$AGENTS_SNIPPET" > "$agents_md"
      ok "Created $agents_md"
    else
      warn "Skipped AGENTS.md. Create it manually if you use non-Claude agents."
    fi
  fi

  echo ""
  echo -e "${BOLD}Done.${RESET} Start working. Correct Claude when it gets things wrong."
  echo "  Run /session-knowledge-extract at end of day."
}

# =============================================================================
# HEALTH
# =============================================================================
cmd_health() {
  echo -e "${BOLD}Shadow Learning Health${RESET}  $(pwd)"
  echo ""

  local ok_count=0 warn_count=0 fail_count=0

  # 1. Memory directory
  if [ -d "$MEMORY_DIR" ]; then
    ok "Memory directory exists"
    ok_count=$((ok_count + 1))
  else
    fail "Memory directory missing: $MEMORY_DIR"
    fail_count=$((fail_count + 1))
    echo ""
    echo "  Run: ./shadow-learn.sh init"
    return
  fi

  # 2. Pattern files
  local pattern_count=0 rule_count=0
  if [ -d "$MEMORY_DIR/patterns" ]; then
    pattern_count=$(find "$MEMORY_DIR/patterns" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ "$pattern_count" -gt 0 ]; then
    rule_count=$(grep -r -c '^[[:space:]]*- ' "$MEMORY_DIR/patterns/" 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')
    ok "Pattern files: $pattern_count files, $rule_count rules"
    ok_count=$((ok_count + 1))
  else
    warn "No pattern files yet"
    warn_count=$((warn_count + 1))
  fi

  # 3. Entity files
  local entity_count=0
  if [ -d "$MEMORY_DIR/entities" ]; then
    entity_count=$(find "$MEMORY_DIR/entities" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
  fi
  if [ "$entity_count" -gt 0 ]; then
    ok "Entity files: $entity_count files"
    ok_count=$((ok_count + 1))
  else
    warn "No entity files yet"
    warn_count=$((warn_count + 1))
  fi

  # 4. Playbook files
  local playbook_count=0 draft_count=0 reviewed_count=0
  if [ -d "docs/playbooks" ]; then
    playbook_count=$(find "docs/playbooks" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    if [ "$playbook_count" -gt 0 ]; then
      draft_count=$(grep -rl 'status: draft' docs/playbooks/*.md 2>/dev/null | wc -l | tr -d ' ')
      reviewed_count=$(grep -rl 'status: reviewed' docs/playbooks/*.md 2>/dev/null | wc -l | tr -d ' ')
      if [ "$draft_count" -gt 0 ] && [ "$reviewed_count" -eq 0 ]; then
        warn "Playbooks: $playbook_count files (all draft — review them)"
        warn_count=$((warn_count + 1))
      else
        ok "Playbooks: $playbook_count files ($reviewed_count reviewed, $draft_count draft)"
        ok_count=$((ok_count + 1))
      fi
    else
      warn "No playbooks yet"
      warn_count=$((warn_count + 1))
    fi
  else
    warn "docs/playbooks/ directory missing"
    warn_count=$((warn_count + 1))
  fi

  # 5. Line budgets
  local budget_ok=true
  if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
    local mem_lines
    mem_lines=$(wc -l < "$MEMORY_DIR/MEMORY.md" | tr -d ' ')
    if [ "$mem_lines" -ge 200 ]; then
      warn "MEMORY.md: $mem_lines/200 lines — run /memory-consolidate"
      budget_ok=false
      warn_count=$((warn_count + 1))
    fi
  fi

  if [ -d "$MEMORY_DIR/patterns" ] && [ "$pattern_count" -gt 0 ]; then
    while IFS= read -r f; do
      local lines
      lines=$(wc -l < "$f" | tr -d ' ')
      if [ "$lines" -ge 150 ]; then
        warn "$(basename "$f"): $lines/150 lines — split or compress"
        budget_ok=false
        warn_count=$((warn_count + 1))
      fi
    done < <(find "$MEMORY_DIR/patterns" -name "*.md" 2>/dev/null)
  fi

  if [ -d "docs/playbooks" ] && [ "$playbook_count" -gt 0 ]; then
    while IFS= read -r f; do
      local lines
      lines=$(wc -l < "$f" | tr -d ' ')
      if [ "$lines" -ge 80 ]; then
        warn "$(basename "$f"): $lines/80 lines — split"
        budget_ok=false
        warn_count=$((warn_count + 1))
      fi
    done < <(find "docs/playbooks" -name "*.md" 2>/dev/null)
  fi

  if $budget_ok; then
    ok "Line budgets OK"
    ok_count=$((ok_count + 1))
  fi

  # 6. Last extraction
  if [ -f "$MEMORY_DIR/extracted-knowledge.md" ]; then
    local ext_date days
    ext_date=$(mtime_date "$MEMORY_DIR/extracted-knowledge.md")
    days=$(days_since "$MEMORY_DIR/extracted-knowledge.md")
    if [ "$days" -le 3 ]; then
      ok "Last extraction: $ext_date ($days days ago)"
      ok_count=$((ok_count + 1))
    else
      warn "Last extraction: $ext_date ($days days ago)"
      warn_count=$((warn_count + 1))
    fi
  else
    warn "No extractions yet — run /session-knowledge-extract"
    warn_count=$((warn_count + 1))
  fi

  # 7. Bootstrap
  if [ -f "CLAUDE.md" ] && grep -qi "shadow learning" "CLAUDE.md" 2>/dev/null; then
    ok "Bootstrap in CLAUDE.md"
    ok_count=$((ok_count + 1))
  else
    fail "No bootstrap in CLAUDE.md — run: ./shadow-learn.sh init"
    fail_count=$((fail_count + 1))
  fi

  # 8. AGENTS.md (cross-tool)
  if [ -f "AGENTS.md" ]; then
    ok "AGENTS.md present (cross-tool compatibility)"
    ok_count=$((ok_count + 1))
  else
    warn "No AGENTS.md — run: ./shadow-learn.sh init"
    warn_count=$((warn_count + 1))
  fi

  echo ""
  echo "  $ok_count OK, $warn_count WARN, $fail_count MISSING"
}

# =============================================================================
# INSTALL-HOOKS
# =============================================================================
cmd_install_hooks() {
  echo -e "${BOLD}Install Session-End Hook${RESET}"
  echo ""

  local settings=".claude/settings.local.json"
  mkdir -p .claude

  # Check if hook already exists
  if [ -f "$settings" ] && grep -q "session-knowledge-extract" "$settings" 2>/dev/null; then
    ok "Hook already installed in $settings"
    return
  fi

  python3 -c "
import json, sys, os

path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except (FileNotFoundError, json.JSONDecodeError):
    data = {}

hook_entry = {
    'matcher': '',
    'hooks': [{
        'type': 'command',
        'command': \"claude -p 'Run /session-knowledge-extract on the session that just ended. Write results without asking — apply automatically to extracted-knowledge.md.'\",
        'timeout': 300,
        'statusMessage': 'Extracting session knowledge\u2026'
    }]
}

hooks = data.setdefault('hooks', {})
stop_hooks = hooks.setdefault('Stop', [])

# Don't duplicate
for existing in stop_hooks:
    for h in existing.get('hooks', []):
        if 'session-knowledge-extract' in h.get('command', ''):
            print('Already installed')
            sys.exit(0)

stop_hooks.append(hook_entry)

with open(path, 'w') as f:
    json.dump(data, f, indent=2)
    f.write('\n')

print('Installed')
" "$settings"

  ok "Hook installed: session-knowledge-extract on Stop"
  echo "  File: $settings"
  echo ""
  echo "  The hook runs /session-knowledge-extract when a Claude session ends."
}

# =============================================================================
# USAGE
# =============================================================================
usage() {
  echo "shadow-learn — shadow learning toolkit for Claude Code"
  echo ""
  echo "Usage: ./shadow-learn.sh <command> [options]"
  echo ""
  echo "Commands:"
  echo "  init [-y]        Set up shadow learning for the current project"
  echo "  health           Check shadow learning status"
  echo "  install-hooks    Auto-extract knowledge on session end"
  echo ""
  echo "Or just copy the skills manually — see README.md"
}

# =============================================================================
# MAIN
# =============================================================================
case "${1:-}" in
  init)           shift; cmd_init "${1:-}" ;;
  health)         cmd_health ;;
  install-hooks)  cmd_install_hooks ;;
  -h|--help|help) usage ;;
  *)              usage ;;
esac
