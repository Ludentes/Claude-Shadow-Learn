---
name: start-research-thread
description: Open a new long-horizon research thread with the three-layer doc model. Creates topic file, first dated doc, and MEMORY.md pointer with correct frontmatter. Refuses if the thread is already falsified. Use when starting an investigation expected to run longer than a single session.
---

# Start Research Thread

Scaffolds a new research thread following the three-layer document model (dated evidence → topic index → MEMORY.md). The skill does **only** the scaffolding — it does not run the investigation. The user runs the experiments; this skill makes sure the memory layer exists before they start.

## When to use

- Opening an investigation expected to span multiple sessions
- Starting an ML experiment campaign, vendor evaluation, performance hunt, or any "we're not sure what we'll find" work
- Reopening a previously-shipped thread for follow-up work (will detect the prior runbook)

## When NOT to use

- One-session debugging or implementation work
- Documentation cleanup tasks
- The thread is already a `🛑 FALSIFIED` entry in MEMORY.md (skill refuses)

## Arguments

- `thread_name` — kebab-case slug, e.g. `embedding-strategy`, `reranker-tuning`
- `hypothesis` — one-sentence question or claim the thread will investigate
- `area` (optional) — domain tag, e.g. `retrieval`, `kiosk`, `infra`. If omitted, ask the user.

## Step 0: Load context

```bash
CWD=$(pwd)
PROJECT_SLUG=$(echo "$CWD" | tr '/' '-')
MEMORY_DIR="$HOME/.claude/projects/$PROJECT_SLUG/memory"
```

Read in order:
1. `$MEMORY_DIR/MEMORY.md` — current index
2. `$MEMORY_DIR/patterns/research-discipline.md` — the discipline (load it if it exists; if it doesn't, suggest the user copy it from shadow-learn's `bootstrap-patterns/`)
3. `docs/research/_topics/` listing if present — existing topic files

## Step 1: Refuse if already falsified or shipped

Scan MEMORY.md for entries containing the thread name:

- If `🛑 FALSIFIED` entry exists → **refuse**. Print the entry and the falsification doc reference. Ask: "This was falsified on [date] — reason: [from doc]. Open as a *new* thread name with a different angle, or reopen explicitly?"
- If `🚢 SHIPPED` entry exists → warn but allow. The user is opening a follow-up. Reference the prior runbook.
- If `🧭 ACTIVE THREAD` entry exists → refuse. Already open. Show the entry.

Do not proceed without explicit user confirmation in the warn/shipped case.

## Step 2: Create the topic index

Path: `docs/research/_topics/<thread_name>.md`

```markdown
---
title: <thread_name>
status: open
last_verified: <today>
area: <area>
---

# <thread_name>

**Hypothesis**: <hypothesis>

**Current belief**: (open — investigation just started)

## Dated docs on this thread

- <today>-<thread_name>-initial.md — opening writeup

## Status

`🧭 ACTIVE THREAD` since <today>
```

## Step 3: Create the first dated doc

Path: `docs/research/<today>-<thread_name>-initial.md` (today as `YYYY-MM-DD`)

```markdown
---
status: live
topic: <thread_name>
last_verified: <today>
area: <area>
---

# <thread_name> — initial framing

**Hypothesis**: <hypothesis>

**Context**: (one paragraph — what prompted this investigation, what we'd like to learn)

**Plan**: (bulleted, may be rough — will be refined as work progresses)

**What would falsify this**: (explicit — what evidence would make us walk away)
```

The "what would falsify this" line is required. If the user can't articulate it, that's a sign the thread isn't ready to open.

## Step 4: Add MEMORY.md entry

Append a single line under the appropriate section of MEMORY.md:

```markdown
- 🧭 <thread_name> — <hypothesis-summary>. See [_topics/<thread_name>.md](../../../path/to/docs/research/_topics/<thread_name>.md).
```

Keep the entry to one line. Do not summarize the dated doc content into MEMORY.md.

If MEMORY.md does not have a `## Research Threads` (or similar) section, create one.

## Step 5: Stop

Do not begin the investigation. The scaffold is done; the user runs the experiments.

Report back:
- Files created (paths)
- MEMORY.md entry added
- Reminder: "When the thread closes (shipped, falsified, or archived), update MEMORY.md icon and topic file status."

## Refusal modes (full list)

| Condition | Action |
|---|---|
| Thread name matches existing `🛑 FALSIFIED` entry | Refuse, show falsification reference |
| Thread name matches existing `🧭 ACTIVE THREAD` entry | Refuse, show active entry |
| Thread name matches existing `🚢 SHIPPED` entry | Warn, ask for confirmation, reference runbook |
| `research-discipline.md` pattern file missing | Warn, suggest copy from shadow-learn `bootstrap-patterns/` |
| User can't articulate falsification criterion | Refuse softly — "the thread isn't ready to open" |

## What this skill does NOT do

- Run experiments
- Write conclusions
- Update topic file as the thread progresses (the user does that in the same commit as new dated docs)
- Mark threads falsified/shipped (separate manual step at the end of the investigation)
