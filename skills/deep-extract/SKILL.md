---
name: deep-extract
description: Use when the user wants high-recall knowledge extraction using the cloud LLM pipeline. Triggers on "deep extract", "full extract", "cloud extract", "run the pipeline". Requires OPENROUTER_API_KEY. Writes to auto memory directory.
---

# Deep Extract (Cloud LLM Pipeline)

Run the full shadow learning pipeline on today's sessions with cloud LLM extraction for ~95% recall. Writes to Claude Code's auto memory directory as `extracted-knowledge.md`.

**Requires:** `claude-shadow-learn` repo cloned locally, `OPENROUTER_API_KEY` in env.

Use `/session-knowledge-extract` instead if you want the free (no API key) version with ~55% recall.

## Steps

### 0. Pre-flight check

```bash
SHADOW_LEARN_DIR="${SHADOW_LEARN_DIR:-$HOME/tools/claude-shadow-learn}"
test -f "$SHADOW_LEARN_DIR/pipeline/scripts/run-pipeline-on-list.ts" || { echo "ERROR: claude-shadow-learn not found at $SHADOW_LEARN_DIR"; exit 1; }
test -n "$OPENROUTER_API_KEY" || { echo "ERROR: OPENROUTER_API_KEY not set"; exit 1; }
echo "OK"
```

Stop and tell the user if either check fails.

### 1. Locate today's sessions

```bash
CWD=$(pwd)
PROJECT_SLUG=$(echo "$CWD" | tr '/' '-')
SESSION_DIR="$HOME/.claude/projects/$PROJECT_SLUG"

echo "Looking in: $SESSION_DIR"
find "$SESSION_DIR" -name "*.jsonl" -not -name "history.jsonl" -mtime -1 \
  | sort > /tmp/todays-sessions.txt

echo "Sessions found: $(wc -l < /tmp/todays-sessions.txt)"
```

If zero sessions: run `ls ~/.claude/projects/ | grep <project-keyword>` to find the right dir.

### 2. Read existing memory context

```bash
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_SLUG/memory"
cat "$MEMORY_DIR/MEMORY.md" 2>/dev/null
cat "$MEMORY_DIR/extracted-knowledge.md" 2>/dev/null
```

Note what's already extracted to avoid duplicates in Step 5.

### 3. Run extraction pipeline

```bash
STORE="$HOME/.claude/memory${CWD}/entries.jsonl"

pnpm --dir "$SHADOW_LEARN_DIR/pipeline" tsx scripts/run-pipeline-on-list.ts \
  --sessions /tmp/todays-sessions.txt \
  --store "$STORE"
```

Already-extracted sessions are skipped automatically. Add `--force` to re-extract all.

### 4. Check store before continuing

```bash
ENTRY_COUNT=$(wc -l < "$STORE" 2>/dev/null || echo 0)
echo "Entries in store: $ENTRY_COUNT"
```

If count is 0: the sessions had no extractable signal. Tell the user and stop.

### 5. Render to auto memory

Read the store entries and format as cognitive model sections:

```bash
python3 -c "
import json, sys
entries = [json.loads(l) for l in open('$STORE') if l.strip()]
by_type = {}
for e in entries:
    t = e.get('type', 'fact')
    by_type.setdefault(t, []).append(e)
for t, items in sorted(by_type.items()):
    print(f'## {t.title()} ({len(items)} entries)')
    for i in items:
        print(f'- {i[\"content\"][:120]}')
    print()
"
```

Convert pipeline output into `extracted-knowledge.md` sections:

| Entry type | Section |
|---|---|
| fact (about: project) | `## Project` |
| fact (about: user) | `## User: [name]` |
| preference | `## User: [name]` |
| rule, correction | `## Conventions` |
| decision | `## Decisions` |
| procedure | `## Procedures` |

**Merge with existing `extracted-knowledge.md`** — don't overwrite. Add new entries to existing sections, skip duplicates.

Write to: `$MEMORY_DIR/extracted-knowledge.md`

If MEMORY.md doesn't reference the topic file, add:
```
- See extracted-knowledge.md for session-extracted preferences and decisions
```

### 6. Preview and confirm

Show the user the new entries being added. Ask:
- **Apply** — write the merged `extracted-knowledge.md`
- **Show only** — display without writing

Do NOT write without explicit user confirmation.

## Quick Diagnostics

| Problem | Fix |
|---------|-----|
| No sessions found | Check project slug: `ls ~/.claude/projects/ \| grep <keyword>` |
| `OPENROUTER_API_KEY` missing | Set it in `.env` in claude-shadow-learn dir or export in shell |
| Store empty after pipeline run | Sessions may have no extractable signal |
| All sessions "already extracted" | Add `--force` flag to re-extract |
| Entries fewer than expected | Confidence threshold 0.9 filters uncertain entries |
