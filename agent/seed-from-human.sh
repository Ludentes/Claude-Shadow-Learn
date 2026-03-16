#!/usr/bin/env bash
set -euo pipefail

# seed-from-human — copy patterns from a real developer's memory to an agent
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

usage() {
  echo "seed-from-human — copy patterns from a real developer's memory to an agent"
  echo ""
  echo "Usage: ./seed-from-human.sh <source-memory-dir> <agent-memory-dir> [options]"
  echo ""
  echo "Arguments:"
  echo "  source-memory-dir   Path to human's memory directory"
  echo "                      (e.g., ~/.claude/projects/-home-dev-w-app/memory)"
  echo "  agent-memory-dir    Path to agent's memory directory"
  echo "                      (e.g., data/agents/beki/memory)"
  echo ""
  echo "Options:"
  echo "  --patterns-only     Only copy patterns, skip entities"
  echo "  --merge             Merge with existing agent patterns (default: overwrite)"
  echo "  --filter DOMAIN     Only copy patterns matching domain (e.g., 'coding', 'review')"
  echo ""
  echo "Examples:"
  echo "  ./seed-from-human.sh ~/.claude/projects/-home-kirill-w-app/memory data/agents/beki/memory"
  echo "  ./seed-from-human.sh ~/memory data/agents/beki/memory --patterns-only --filter coding"
}

if [ $# -lt 2 ]; then
  usage
  exit 1
fi

SOURCE_DIR="$1"
TARGET_DIR="$2"
shift 2

PATTERNS_ONLY=false
MERGE=false
FILTER=""

while [ $# -gt 0 ]; do
  case "$1" in
    --patterns-only) PATTERNS_ONLY=true; shift ;;
    --merge)         MERGE=true; shift ;;
    --filter)        FILTER="$2"; shift 2 ;;
    *)               fail "Unknown option: $1"; usage; exit 1 ;;
  esac
done

# Validate source
if [ ! -d "$SOURCE_DIR" ]; then
  fail "Source directory not found: $SOURCE_DIR"
  exit 1
fi

if [ ! -d "$SOURCE_DIR/patterns" ]; then
  fail "No patterns/ directory in source: $SOURCE_DIR"
  exit 1
fi

echo -e "${BOLD}Seed Agent from Human Memory${RESET}"
echo "  Source: $SOURCE_DIR"
echo "  Target: $TARGET_DIR"
echo ""

# Create target directories
mkdir -p "$TARGET_DIR/patterns" "$TARGET_DIR/entities"

# Copy patterns
copied=0
skipped=0
for f in "$SOURCE_DIR/patterns/"*.md; do
  [ -f "$f" ] || continue
  name=$(basename "$f")

  # Apply filter
  if [ -n "$FILTER" ]; then
    if ! echo "$name" | grep -qi "$FILTER"; then
      skipped=$((skipped + 1))
      continue
    fi
  fi

  # Check merge mode
  if [ -f "$TARGET_DIR/patterns/$name" ] && ! $MERGE; then
    # Overwrite
    cp "$f" "$TARGET_DIR/patterns/$name"
    ok "Overwritten: $name"
    copied=$((copied + 1))
  elif [ -f "$TARGET_DIR/patterns/$name" ] && $MERGE; then
    # Merge: append human patterns that aren't already present
    # Simple line-level dedup
    while IFS= read -r line; do
      if [ -n "$line" ] && ! grep -qF "$line" "$TARGET_DIR/patterns/$name" 2>/dev/null; then
        echo "$line" >> "$TARGET_DIR/patterns/$name"
      fi
    done < "$f"
    ok "Merged: $name"
    copied=$((copied + 1))
  else
    cp "$f" "$TARGET_DIR/patterns/$name"
    ok "Copied: $name"
    copied=$((copied + 1))
  fi
done

# Copy entities (unless patterns-only)
entity_copied=0
if ! $PATTERNS_ONLY && [ -d "$SOURCE_DIR/entities" ]; then
  for f in "$SOURCE_DIR/entities/"*.md; do
    [ -f "$f" ] || continue
    name=$(basename "$f")
    cp "$f" "$TARGET_DIR/entities/$name"
    ok "Entity: $name"
    entity_copied=$((entity_copied + 1))
  done
fi

echo ""
echo -e "${BOLD}Done.${RESET}"
echo "  Patterns: $copied copied, $skipped filtered out"
if ! $PATTERNS_ONLY; then
  echo "  Entities: $entity_copied copied"
fi
echo ""
echo "  Run init-agent.sh to regenerate MEMORY.md index if needed."
