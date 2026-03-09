---
name: end-of-week-report
description: Use when the user wants a summary of the week's work. Triggers on "end of week report", "weekly report", "weekly summary", "what did I do this week", "week in review". Primary source is git commits since Monday; enriches with docs/plans if available.
---

# End-of-Week Report

Generate a structured summary of the week's work from git history, optionally enriched with docs and plans.

## Step 1: Gather git commits for the week

```bash
# Commits since last Monday (handles running any day of the week)
MONDAY=$(date -d "last monday" +%Y-%m-%d 2>/dev/null || date -v-monday +%Y-%m-%d 2>/dev/null)
git log --since="$MONDAY 00:00:00" --format="%ad %h %s" --date=short --no-merges
```

Also get a sense of scope:

```bash
# Files changed this week
git diff --stat $(git log --since="$MONDAY 00:00:00" --format="%H" | tail -1) HEAD 2>/dev/null | tail -5

# PRs merged (if using gh CLI)
gh pr list --state merged --search "merged:>=$MONDAY" 2>/dev/null | head -10
```

## Step 2: Check for optional enrichment sources

Scan for docs and plans created or modified this week:

```bash
find . \( -path ./node_modules -prune -o -path ./.git -prune \) \
  -o -name "*.md" -newer /tmp -mtime -7 -print 2>/dev/null \
  | grep -E "(docs/|plans/|research/|CHANGELOG)" \
  | grep -v node_modules | head -15
```

Read at most 4-5 key files (plans, research docs, CHANGELOG entries). Prioritize by date — most recent first.

## Step 3: Generate the report

```markdown
## Week in Review — Week of <Monday date>

### Key Accomplishments
- <major features, milestones, or shipped work — 3-6 bullets>
- <group by theme, not by day>

### Technical Work
- <significant implementation details worth recording>
- <architecture decisions made>
- <bugs fixed that were noteworthy>

### Research & Planning
- <docs written, designs created, evals run>
- <leave blank if none>

### In Progress / Carrying Forward
- <work started but not finished>
- <what's next week's priority>

### Metrics (if available)
- Tests: <count or pass rate>
- PRs merged: <count>
- Sessions: <count>
```

**Guidelines:**
- Lead with impact, not activity — "Shipped X" not "Worked on X"
- Group commits by theme across days (don't break down by day)
- Call out any significant decisions or pivots
- "Research & Planning" section only appears if docs were actually written
- Cap the whole report at ~20 bullets total

## Step 4: Ask about format

| Format | Use for |
|--------|---------|
| **Full report** (default) | Personal record, team wiki |
| **Executive summary** | 3-4 sentence paragraph, no headers |
| **Bullet list** | Quick Slack/email update |
| **Standup carry-forward** | Just the "in progress" section |

## What counts as "enrichment"

| Source | Read when |
|--------|-----------|
| `docs/plans/*.md` | New plans created this week |
| `docs/research/*.md` | Research published this week |
| `CHANGELOG.md` | Entries added this week |
| Eval results / metrics | Performance data from experiments |
| PR descriptions | Merged PRs with meaningful descriptions |
| Meeting notes | If referenced in commits |

**Don't** read source code files, test files, or configs — those details belong in the technical section only if clearly significant.

## Handling multi-project weeks

If commits span multiple repos, ask the user which projects to include:

```bash
# Show all recent project dirs with activity
ls ~/.claude/projects/ | while read d; do
  count=$(find ~/.claude/projects/$d -name "*.jsonl" -mtime -7 2>/dev/null | wc -l)
  [ "$count" -gt 0 ] && echo "$count sessions: $d"
done | sort -rn | head -10
```
