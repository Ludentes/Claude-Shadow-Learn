#!/usr/bin/env bash
set -euo pipefail

# health-agent — check shadow learning status for a simulated agent
# Part of the claude-shadow-learn agent runtime

# --- Color detection ---
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
  GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BOLD=''; RESET=''
fi

ok()   { echo -e "  ${GREEN}✔${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET} $1"; }
fail() { echo -e "  ${RED}✘${RESET} $1"; }

# --- OS detection ---
if [[ "$(uname)" == "Darwin" ]]; then
  mtime_date() { date -r "$(stat -f %m "$1")" "+%Y-%m-%d" 2>/dev/null; }
  days_since() { echo $(( ( $(date +%s) - $(stat -f %m "$1") ) / 86400 )); }
else
  mtime_date() { date -d "@$(stat -c %Y "$1")" "+%Y-%m-%d" 2>/dev/null; }
  days_since() { echo $(( ( $(date +%s) - $(stat -c %Y "$1") ) / 86400 )); }
fi

usage() {
  echo "health-agent — check shadow learning status for a simulated agent"
  echo ""
  echo "Usage: ./health-agent.sh <agent-dir>"
  echo ""
  echo "Example: ./health-agent.sh data/agents/beki"
}

if [ $# -lt 1 ]; then
  usage
  exit 1
fi

AGENT_DIR="$1"

if [ ! -d "$AGENT_DIR" ]; then
  fail "Agent directory not found: $AGENT_DIR"
  exit 1
fi

MEMORY_DIR="$AGENT_DIR/memory"

# Read agent identity from CLAUDE.md if available
AGENT_NAME="$AGENT_DIR"
if [ -f "$AGENT_DIR/CLAUDE.md" ]; then
  name_line=$(grep '^Name:' "$AGENT_DIR/CLAUDE.md" 2>/dev/null | head -1)
  if [ -n "$name_line" ]; then
    AGENT_NAME=$(echo "$name_line" | sed 's/^Name: //')
  fi
fi

echo -e "${BOLD}Agent Health: $AGENT_NAME${RESET}"
echo "  Directory: $AGENT_DIR"
echo ""

local_ok=0 local_warn=0 local_fail=0

# 1. Memory directory
if [ -d "$MEMORY_DIR" ]; then
  ok "Memory directory exists"
  local_ok=$((local_ok + 1))
else
  fail "Memory directory missing"
  local_fail=$((local_fail + 1))
  echo ""
  echo "  Run: ./init-agent.sh to initialize"
  exit 1
fi

# 2. CLAUDE.md
if [ -f "$AGENT_DIR/CLAUDE.md" ]; then
  ok "CLAUDE.md present"
  local_ok=$((local_ok + 1))
else
  fail "CLAUDE.md missing"
  local_fail=$((local_fail + 1))
fi

# 3. Pattern files
pattern_count=0 rule_count=0
if [ -d "$MEMORY_DIR/patterns" ]; then
  pattern_count=$(find "$MEMORY_DIR/patterns" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi
if [ "$pattern_count" -gt 0 ]; then
  rule_count=$(grep -r -c '^[[:space:]]*- ' "$MEMORY_DIR/patterns/" 2>/dev/null | awk -F: '{s+=$NF} END {print s+0}')
  ok "Patterns: $pattern_count files, $rule_count rules"
  local_ok=$((local_ok + 1))
else
  warn "No patterns — agent running on cold start only"
  local_warn=$((local_warn + 1))
fi

# 4. Entity files
entity_count=0
if [ -d "$MEMORY_DIR/entities" ]; then
  entity_count=$(find "$MEMORY_DIR/entities" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
fi
if [ "$entity_count" -gt 0 ]; then
  ok "Entities: $entity_count files"
  local_ok=$((local_ok + 1))
else
  warn "No entity files"
  local_warn=$((local_warn + 1))
fi

# 5. Line budgets
budget_ok=true
if [ -f "$MEMORY_DIR/MEMORY.md" ]; then
  mem_lines=$(wc -l < "$MEMORY_DIR/MEMORY.md" | tr -d ' ')
  if [ "$mem_lines" -ge 200 ]; then
    warn "MEMORY.md: $mem_lines/200 lines — needs consolidation"
    budget_ok=false
    local_warn=$((local_warn + 1))
  fi
fi

if [ -d "$MEMORY_DIR/patterns" ] && [ "$pattern_count" -gt 0 ]; then
  while IFS= read -r f; do
    lines=$(wc -l < "$f" | tr -d ' ')
    if [ "$lines" -ge 150 ]; then
      warn "$(basename "$f"): $lines/150 lines — split or compress"
      budget_ok=false
      local_warn=$((local_warn + 1))
    fi
  done < <(find "$MEMORY_DIR/patterns" -name "*.md" 2>/dev/null)
fi

if $budget_ok; then
  ok "Line budgets OK"
  local_ok=$((local_ok + 1))
fi

# 6. Extracted knowledge (staging area)
if [ -f "$MEMORY_DIR/extracted-knowledge.md" ]; then
  ext_date=$(mtime_date "$MEMORY_DIR/extracted-knowledge.md")
  days=$(days_since "$MEMORY_DIR/extracted-knowledge.md")

  # Count pending entries
  pending=$(grep -c '^### →' "$MEMORY_DIR/extracted-knowledge.md" 2>/dev/null || echo "0")

  if [ "$days" -le 3 ]; then
    ok "Last extraction: $ext_date ($days days ago, $pending pending)"
    local_ok=$((local_ok + 1))
  else
    warn "Last extraction: $ext_date ($days days ago) — consolidation may be needed"
    local_warn=$((local_warn + 1))
  fi
else
  warn "No extractions yet — agent hasn't completed tasks with work-to-knowledge"
  local_warn=$((local_warn + 1))
fi

# 7. AGENTS.md
if [ -f "$AGENT_DIR/AGENTS.md" ]; then
  ok "AGENTS.md present"
  local_ok=$((local_ok + 1))
else
  warn "No AGENTS.md"
  local_warn=$((local_warn + 1))
fi

# 8. Skills
if [ -d "$AGENT_DIR/skills/work-to-knowledge" ]; then
  ok "work-to-knowledge skill installed"
  local_ok=$((local_ok + 1))
else
  warn "work-to-knowledge skill missing"
  local_warn=$((local_warn + 1))
fi

echo ""
echo "  $local_ok OK, $local_warn WARN, $local_fail MISSING"

# Overall assessment
echo ""
if [ "$local_fail" -gt 0 ]; then
  echo -e "  ${RED}Agent not ready — fix MISSING items${RESET}"
elif [ "$pattern_count" -eq 0 ] && [ "$entity_count" -eq 0 ]; then
  echo -e "  ${YELLOW}Cold start — agent will work but has no learned experience${RESET}"
elif [ "$local_warn" -gt 0 ]; then
  echo -e "  ${YELLOW}Agent ready with warnings${RESET}"
else
  echo -e "  ${GREEN}Agent healthy${RESET}"
fi
