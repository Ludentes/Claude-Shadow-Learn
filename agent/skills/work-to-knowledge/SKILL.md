---
name: work-to-knowledge
description: Extract reusable knowledge from a completed task's work session. Use after task completion, "extract from work", "what did I learn".
---

# Work-to-Knowledge Extraction

Run after an agent completes a task to extract reusable patterns from the work session.

## Context

This skill runs as part of a simulated agent's learning loop. Unlike human
session-knowledge-extract (which looks for user corrections), this extracts
knowledge from the agent's own work: what succeeded, what failed, what patterns
emerged.

## Arguments

- `task_summary` — what the task was and what was produced (required)
- `task_type` — coding | research | review | admin (required)
- `outcome` — success | partial | failed (required)
- `memory_dir` — path to agent's memory directory (required)
- `corrections` — any corrections received during the task (optional)
- `session_file` — path to Claude Code session JSONL for deeper analysis (optional)

## Step 0: Load Context

Read the agent's current knowledge:

1. Read `{memory_dir}/MEMORY.md` for the index
2. Read all files in `{memory_dir}/patterns/` for existing patterns
3. Read `{memory_dir}/extracted-knowledge.md` if it exists (pending entries)

## Step 1: Classify Knowledge

From the task summary, corrections, and session (if provided), identify:

### Patterns (reusable across tasks)

Extract if:
- The agent solved a non-trivial problem that could recur
- A specific tool/command/approach worked well for a task type
- The agent made a mistake and corrected it
- External feedback corrected the agent's approach

**"Different agent" test**: Would a different agent doing a similar task benefit
from knowing this? If NO → skip.

Tag each pattern:
- `domain`: coding | testing | git | research | review | communication | infra
- `confidence`: 0.5 (first observation), 0.7 (confirmed by success), 0.9 (confirmed by human)
- `source`: task:{task-id}

### Entity Updates

Extract if:
- New information about a person, service, or system was discovered
- An entity's status changed (e.g., "service X migrated to v2")

### Procedures (multi-step sequences)

Extract if:
- 3+ steps were taken in a specific order to accomplish a task type
- This sequence is likely reusable (not one-off)

## Step 2: Deduplicate

For each extracted item, check against existing patterns:
- **Exact match** → skip (already known)
- **Similar but more specific** → update existing entry with new detail
- **Contradicts existing** → flag conflict, keep both with notes
- **New** → add with initial confidence

## Step 3: Write

### On success or partial:

Append new entries to `{memory_dir}/extracted-knowledge.md`:

```markdown
## Extracted from: {task_summary}
Date: {date}
Outcome: {outcome}
Type: {task_type}

### → patterns/{domain}.md
- {pattern} (confidence: {score}, source: {task-id})

### → entities/{name}.md
- {entity update}

### → skip (general knowledge)
- {items that fail the "different agent" test}
```

### On failure:

Create a self-observation entry:

```markdown
### → patterns/{domain}.md (correction)
- Don't: {what went wrong} — {why it failed} (confidence: 0.5, source: {task-id})
```

Failure patterns start at low confidence. If the same failure recurs,
confidence increases.

## Step 4: Update Index

If new patterns were added, update `{memory_dir}/MEMORY.md` to reflect
the current file count and contents.

## What NOT to Extract

- Generic programming knowledge ("use meaningful names", "handle errors")
- One-off task details ("created file app/settings.tsx")
- Ephemeral state ("currently working on feature X")
- Things already enforced by linters/CI (code style, formatting)

## Confidence Evolution

| Event | Confidence Change |
|-------|------------------|
| First observation | 0.5 |
| Confirmed by task success | +0.1 (cap 0.8) |
| Confirmed by human feedback | set to 0.9 |
| Contradicted by failure | -0.2 (floor 0.2) |
| Contradicted by human | remove or rewrite |
| Not referenced in 30 days | -0.1 per period |

## Integration with Galatea

This skill is called by the coding adapter's post-task hook:

```
Task completes → work-to-knowledge runs → patterns updated → next task benefits
```

The tick loop should call this after setting task status to "done".
Provide the task summary from TaskState.progress[] and artifacts[].
