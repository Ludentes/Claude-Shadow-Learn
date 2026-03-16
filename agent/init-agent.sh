#!/usr/bin/env bash
set -euo pipefail

# init-agent — initialize shadow learning for a simulated agent
# Part of the claude-shadow-learn agent runtime

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$SCRIPT_DIR")"
BOOTSTRAP_DIR="$SCRIPT_DIR/bootstrap"
TEMPLATES_DIR="$SCRIPT_DIR/templates"

# --- Color detection ---
if [ -t 1 ] && [ "${TERM:-dumb}" != "dumb" ]; then
  GREEN='\033[0;32m'; YELLOW='\033[0;33m'; RED='\033[0;31m'; BOLD='\033[1m'; RESET='\033[0m'
else
  GREEN=''; YELLOW=''; RED=''; BOLD=''; RESET=''
fi

ok()   { echo -e "  ${GREEN}✔${RESET} $1"; }
warn() { echo -e "  ${YELLOW}⚠${RESET} $1"; }
fail() { echo -e "  ${RED}✘${RESET} $1"; }

usage() {
  echo "init-agent — initialize shadow learning for a simulated agent"
  echo ""
  echo "Usage: ./init-agent.sh <agent-id> <role> <agent-dir> [options]"
  echo ""
  echo "Arguments:"
  echo "  agent-id       Unique identifier (e.g., beki, besa)"
  echo "  role           Agent role: developer | pm"
  echo "  agent-dir      Directory where agent memory will live"
  echo ""
  echo "Options:"
  echo "  --name NAME         Human-readable name (default: agent-id)"
  echo "  --domain DOMAIN     Agent domain (e.g., 'Expo / React Native')"
  echo "  --seed-from PATH    Seed patterns from a human's memory directory"
  echo "  --workspace PATH    Project workspace the agent operates in"
  echo ""
  echo "Examples:"
  echo "  ./init-agent.sh beki developer data/agents/beki"
  echo "  ./init-agent.sh besa pm data/agents/besa --name Besa --domain 'Product management'"
  echo "  ./init-agent.sh beki developer data/agents/beki --seed-from ~/.claude/projects/-home-kirill-w-app/memory"
}

# --- Parse arguments ---
if [ $# -lt 3 ]; then
  usage
  exit 1
fi

AGENT_ID="$1"
ROLE="$2"
AGENT_DIR="$3"
shift 3

AGENT_NAME="$AGENT_ID"
DOMAIN=""
SEED_FROM=""
WORKSPACE=""

while [ $# -gt 0 ]; do
  case "$1" in
    --name)       AGENT_NAME="$2"; shift 2 ;;
    --domain)     DOMAIN="$2"; shift 2 ;;
    --seed-from)  SEED_FROM="$2"; shift 2 ;;
    --workspace)  WORKSPACE="$2"; shift 2 ;;
    *)            fail "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Validate role
if [[ "$ROLE" != "developer" && "$ROLE" != "pm" ]]; then
  fail "Invalid role: $ROLE (must be 'developer' or 'pm')"
  exit 1
fi

# Set defaults based on role
if [ -z "$DOMAIN" ]; then
  case "$ROLE" in
    developer) DOMAIN="Software development" ;;
    pm)        DOMAIN="Product management, research, task coordination" ;;
  esac
fi

echo -e "${BOLD}Agent Init: $AGENT_NAME ($ROLE)${RESET}"
echo ""

# =============================================================================
# 1. Create directory structure
# =============================================================================
echo "Agent directory: $AGENT_DIR"
mkdir -p "$AGENT_DIR/memory/patterns" "$AGENT_DIR/memory/entities"
ok "memory/patterns/"
ok "memory/entities/"

# =============================================================================
# 2. Bootstrap patterns (cold start)
# =============================================================================
if [ -n "$SEED_FROM" ]; then
  # Seed from a real developer's patterns
  echo ""
  echo "Seeding from: $SEED_FROM"
  if [ -d "$SEED_FROM/patterns" ]; then
    cp -r "$SEED_FROM/patterns/"*.md "$AGENT_DIR/memory/patterns/" 2>/dev/null || true
    local_count=$(find "$AGENT_DIR/memory/patterns" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
    ok "Copied $local_count pattern files from human memory"
  else
    warn "No patterns/ found in $SEED_FROM — using cold start instead"
    SEED_FROM=""  # Fall through to cold start
  fi
  if [ -d "$SEED_FROM/entities" ]; then
    cp -r "$SEED_FROM/entities/"*.md "$AGENT_DIR/memory/entities/" 2>/dev/null || true
    ok "Copied entity files from human memory"
  fi
fi

if [ -z "$SEED_FROM" ]; then
  # Cold start — copy role-specific bootstrap patterns
  local_bootstrap="$BOOTSTRAP_DIR/$ROLE"
  if [ -d "$local_bootstrap/patterns" ]; then
    cp "$local_bootstrap/patterns/"*.md "$AGENT_DIR/memory/patterns/" 2>/dev/null || true
    ok "Cold start patterns for $ROLE"
  else
    warn "No bootstrap patterns found for $ROLE"
  fi
fi

# =============================================================================
# 3. Generate MEMORY.md index
# =============================================================================
pattern_count=$(find "$AGENT_DIR/memory/patterns" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')
entity_count=$(find "$AGENT_DIR/memory/entities" -name "*.md" 2>/dev/null | wc -l | tr -d ' ')

cat > "$AGENT_DIR/memory/MEMORY.md" << EOF
# $AGENT_NAME — Knowledge Store

Agent: $AGENT_NAME ($AGENT_ID)
Role: $ROLE
Domain: $DOMAIN
Initialized: $(date +%Y-%m-%d)

## Patterns ($pattern_count files)
EOF

for f in "$AGENT_DIR/memory/patterns/"*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md)
  echo "- [$name.md](patterns/$name.md)" >> "$AGENT_DIR/memory/MEMORY.md"
done

cat >> "$AGENT_DIR/memory/MEMORY.md" << EOF

## Entities ($entity_count files)
EOF

for f in "$AGENT_DIR/memory/entities/"*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f" .md)
  echo "- [$name.md](entities/$name.md)" >> "$AGENT_DIR/memory/MEMORY.md"
done

cat >> "$AGENT_DIR/memory/MEMORY.md" << EOF

## Staging
- [extracted-knowledge.md](extracted-knowledge.md) — pending entries from work sessions
EOF

ok "MEMORY.md generated"

# =============================================================================
# 4. Generate CLAUDE.md for agent
# =============================================================================
WORKSPACE_NOTE=""
if [ -n "$WORKSPACE" ]; then
  WORKSPACE_NOTE="
Workspace: $WORKSPACE"
fi

cat > "$AGENT_DIR/CLAUDE.md" << EOF
## Agent Identity

Name: $AGENT_NAME
Role: $ROLE
Domain: $DOMAIN$WORKSPACE_NOTE

## Shadow Learning

This agent uses shadow learning. Learned patterns and entity context are stored in the memory directory.

Before work that involves judgment (reviews, architecture, writing):
- Read \`memory/patterns/*.md\` for domain-specific rules
- Read \`memory/entities/*.md\` for context about people, services, or systems

After completing a task:
- Note what worked and what didn't
- If you discovered a reusable pattern, note it explicitly
- If you made a mistake and corrected it, note the correction

## Conventions

- Follow patterns from memory — they were learned from real developers
- When patterns conflict with the task, follow the task (patterns are guidance, not law)
- Hard rules (import order, commit format) come from linters and CI, not memory
- Keep responses focused on the task — don't over-explain
EOF

ok "CLAUDE.md generated"

# =============================================================================
# 5. Generate AGENTS.md (cross-tool)
# =============================================================================
cat > "$AGENT_DIR/AGENTS.md" << EOF
# AGENTS.md

Agent: $AGENT_NAME — $ROLE
Domain: $DOMAIN

## Knowledge Store

Before work that involves judgment, check:
- \`memory/patterns/*.md\` — domain rules learned from experience
- \`memory/entities/*.md\` — context about people, services, systems

After completing work, note reusable patterns and corrections explicitly.

## Conventions

- Follow learned patterns as guidance, not absolute rules
- Hard rules belong in linters and CI
- Keep instruction files concise
EOF

ok "AGENTS.md generated"

# =============================================================================
# 6. Copy agent-specific skills
# =============================================================================
local_skills="$SCRIPT_DIR/skills"
if [ -d "$local_skills/work-to-knowledge" ]; then
  mkdir -p "$AGENT_DIR/skills"
  cp -r "$local_skills/work-to-knowledge" "$AGENT_DIR/skills/"
  ok "work-to-knowledge skill"
fi

# =============================================================================
# Summary
# =============================================================================
echo ""
echo -e "${BOLD}Done.${RESET} Agent $AGENT_NAME initialized at $AGENT_DIR"
echo ""
echo "  Memory:    $AGENT_DIR/memory/"
echo "  Patterns:  $pattern_count files"
echo "  CLAUDE.md: $AGENT_DIR/CLAUDE.md"
echo "  AGENTS.md: $AGENT_DIR/AGENTS.md"
echo ""
if [ -n "$SEED_FROM" ]; then
  echo "  Seeded from: $SEED_FROM"
else
  echo "  Cold start: $ROLE bootstrap patterns"
fi
echo ""
echo "  Next: integrate with Galatea's coding adapter to reference"
echo "  this agent's memory when launching Claude Code sessions."
