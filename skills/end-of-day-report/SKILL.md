---
name: end-of-day-report
description: Use when the user wants a summary of what was accomplished today. Triggers on "end of day report", "daily report", "what did I do today", "standup notes", "daily standup". Primary source is git commits; enriches with docs/plans if available.
---

# End-of-Day Report

Generate a concise summary of today's work from git history, optionally enriched with docs and plans.

## Step 1: Gather git commits

```bash
# Today's commits by this author
git log --since="00:00:00" --format="%h %s" --no-merges
```

If that returns nothing (no commits today), also check for recent staged/unstaged work:

```bash
git status --short
git stash list | head -5
```

## Step 2: Check for optional enrichment sources

Look for context files modified today:

```bash
# Docs/plans modified today
find . \( -path ./node_modules -prune -o -path ./.git -prune \) \
  -o -name "*.md" -newer /tmp -mtime -1 -print 2>/dev/null \
  | grep -v node_modules | head -20

# Recent plan files
ls -lt docs/plans/ 2>/dev/null | head -5
ls -lt docs/research/ 2>/dev/null | head -5
```

Read any relevant files to add context to the report. **Only read files that are clearly related to today's work — don't read more than 3-4 files.**

## Step 3: Generate the report

Produce a report in this structure:

```markdown
## Daily Report — <date>

### Accomplished
- <group commits by theme, not just list them verbatim>
- <use past tense, describe what changed not what the commit message said>

### In Progress
- <uncommitted work, WIP branches, stashed changes>
- <leave blank if nothing>

### Notes
- <blockers, decisions made, interesting findings>
- <leave blank if nothing>
```

**Guidelines for "Accomplished":**
- Group related commits (e.g. 3 fix commits for the same feature → one bullet)
- Use plain language, not commit message syntax (`feat:`, `fix:` → omit prefixes)
- Mention the "why" when visible from commit messages or docs
- Cap at 8 bullets — group aggressively if there are many commits

## Step 4: Ask about format

Ask the user:
- **Standup format** — 3 short bullets (done / doing / blockers)
- **Full report** — the structured format above
- **Slack message** — brief paragraph, no headers
- **Keep as-is** — show whatever was generated

## What counts as "enrichment"

Use additional sources only when they add meaningful context the git log doesn't show:

| Source | Read when |
|--------|-----------|
| `docs/plans/*.md` | Commits reference a plan by name |
| `docs/research/*.md` | Research was published today |
| `CHANGELOG.md` | Entry was added today |
| Test output / eval results | Commits mention "eval" or "results" |
| PR description | A PR was opened or merged today |

**Don't** read source files, configs, or anything not directly about planning/decisions.
