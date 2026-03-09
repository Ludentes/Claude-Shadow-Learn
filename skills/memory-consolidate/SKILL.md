---
name: memory-consolidate
description: "Use when the shadow learning knowledge store needs maintenance. Triggers on 'consolidate memory', 'clean up memory', 'prune memory', 'memory maintenance'. Also use when MEMORY.md exceeds 150 lines, after /session-knowledge-extract, or after a major project milestone."
---

# Memory Consolidate

Weekly maintenance pass over the shadow learning knowledge store. Routes staged entries to their destinations, merges duplicates, prunes stale patterns, enforces file size budgets, and rebalances MEMORY.md as the index.

## Step 1: Read all memory files

```bash
MEMORY_DIR="$HOME/.claude/projects/$(echo $(pwd) | tr '/' '-')/memory"
ls -laR "$MEMORY_DIR" 2>/dev/null
```

Read everything: `MEMORY.md`, `patterns/*.md`, `entities/*.md`, `extracted-knowledge.md`. Also read project CLAUDE.md for overlap detection.

## Step 2: Route staged entries

If `extracted-knowledge.md` exists and has destination-tagged entries (from `/session-knowledge-extract`):

For each entry tagged `→ patterns/[file].md`:
- Create the patterns/ directory and file if needed
- Append to the appropriate section in the target pattern file
- If no appropriate section exists, create one

For each entry tagged `→ entities/[file].md`:
- Create the entities/ directory and file if needed
- Append or update the entity entry

For each entry tagged `→ skip`:
- Remove it — already filtered as general knowledge

For each entry tagged `→ unsorted`:
- Present to user: "Where should this go?" Suggest a destination.

After routing, clear `extracted-knowledge.md` of promoted entries. Keep any entries that weren't routed.

## Step 3: Identify consolidation actions across ALL files

Analyze all memory content (patterns/, entities/, MEMORY.md) and classify each entry:

| Action | Criteria | Example |
|---|---|---|
| **Keep** | Still relevant, no duplicates | "PostgreSQL runs on port 15432" |
| **Merge** | Two entries say the same thing differently | "Use pnpm" + "Never use npm" → single entry |
| **Update** | Entry is partially outdated | "Uses AI SDK v5" when v6 is now in use |
| **Remove (stale)** | Decision was reversed or fact changed | "Chose SQLite for storage" when project moved to PostgreSQL |
| **Remove (duplicate)** | Already in CLAUDE.md or another memory file | Memory says "Use Biome" and CLAUDE.md says "Use Biome 2.3" |
| **Remove (general knowledge)** | Model already knows this | "Use meaningful variable names" |
| **Move** | In wrong file or in MEMORY.md but belongs in patterns/entities | Detailed rule in MEMORY.md → move to patterns/ |

**General knowledge filter:** Apply the "different senior dev" test. Would a senior dev at a different company do this differently? If no → remove it.

## Step 4: Chain of Density pass

For entries being kept, apply compression:

- **Merge related items** into single, denser entries. "Use pnpm" + "Never use npm" + "Install with pnpm add" → "Package manager: pnpm (never npm)"
- **Preserve specifics** — don't lose port numbers, version numbers, or exact tool names
- **Keep reasoning** for decisions — "Chose JWT over sessions because microservices" > "Use JWT"

## Step 5: Enforce file size budgets

| File | Max | Action if over |
|---|---|---|
| MEMORY.md | 200 lines | Move detail to pattern/entity files, keep index entries |
| Each pattern file | 150 lines | Compress, merge, or split into two domain files |
| Entity files | No hard limit | But prune inactive entities (no interaction in 30+ days) |

**MEMORY.md should be an index**, not a store. Format:

```markdown
# Project Memory

## Patterns (N files)
- [frontend.md](patterns/frontend.md) — FSD, shadcn, imports (12 rules, 3 sessions)
- [review-patterns.md](patterns/review-patterns.md) — thesis review (22 rules, 5 sessions)

## Entities (N tracked)
- [people.md](entities/people.md) — Anna, Denis, Mikhail, Sophiya

## Staging
- [extracted-knowledge.md](extracted-knowledge.md) — N entries pending
```

## Step 6: Present diff and confirm

Show the user a clear summary:

```
## Consolidation Summary

### Routing (from extracted-knowledge.md)
- Promoted to patterns/: [N entries, list destinations]
- Promoted to entities/: [N entries]
- Skipped (general knowledge): [N entries]
- Unsorted (needs input): [N entries]

### Consolidation
- Merged: [list of merged entries]
- Removed (stale): [list]
- Removed (duplicate): [list]
- Removed (general knowledge): [list]

### File sizes
- MEMORY.md: [X] → [Y] lines (budget: 200)
- patterns/frontend.md: [X] lines (budget: 150)
- ...

### Changes to files
[List each file that changed]
```

Then show the full proposed content of each changed file.

Ask:
- **Apply all** — write all changes
- **Apply selectively** — let user pick which changes to accept
- **Show only** — no changes

Do NOT write without explicit user confirmation.
