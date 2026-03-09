---
name: my-skill
description: "Use when [triggering conditions — what the user says or does that signals this skill applies]. Triggers on '[phrase 1]', '[phrase 2]', '[phrase 3]'."
---

# [Skill Name] (Shadow Learning Skill)

This skill implements a **shadow learning loop**: load patterns → apply to new case → get corrected → update patterns → produce output. Each run trains the next.

## Pattern File

`memory/patterns/[domain].md` — read at start, update at end.

## Cold Start

If pattern file doesn't exist: "No patterns yet. I'll follow your lead — you do it, I'll learn. I'll lead from next time."

## Arguments

[What the user passes in — e.g., student name, feature name, project brief]

## Step 0: Load Knowledge

Read ALL of these:

| File | Purpose | If missing |
|---|---|---|
| `$MEMORY_DIR/patterns/[domain].md` | Learned rules — primary instruction set | Switch to cold start (user leads) |
| `$MEMORY_DIR/entities/[relevant].md` | Per-entity context | Ask user for context |

Before proceeding, note:
- How many rules exist (how mature are the patterns?)
- What's known about this specific case
- Any previous runs for this case

## Steps 1-N: Apply + Correct Loop

[Your domain-specific steps go here. Keep to 10-15 lines. Examples:]

1. [Read/analyze the input]
2. [Apply patterns to produce analysis/output for section 1]
3. Present findings. Ask: "Anything to correct?"
4. [Apply patterns to section 2]
5. Present findings. Ask: "What do you think?"
6. [Continue section by section...]

**When the user corrects you**, classify:
- **New pattern** (not in pattern file) → will add in LEARN step
- **Calibration** (existing pattern too strict/lenient) → will update in LEARN step
- **One-off** (specific to this case) → note in entity file only

## Step N+1: Produce Output

[Create the deliverable — review document, code, report, etc.]
[Save to appropriate location]

## Step N+2: Update Knowledge (LEARN)

**Not optional.** Every run should leave knowledge better.

### Always update entity files:
- Status (done, in-progress, etc.)
- Key findings summary (one dense paragraph)
- Any new entity-specific notes

### Update pattern file IF corrections revealed:
- A new pattern → add to appropriate section
- An existing pattern was wrong or miscalibrated → edit it
- A new common issue → add to issues/don't section

### Do NOT update pattern file for:
- One-off corrections specific to this case's domain
- Things already captured
- General knowledge the model already knows

### Report what you learned:
Tell the user: "From this run I [learned X / updated Y / no new patterns]."

## What NOT to Do

- Don't produce output before going through the correction loop
- Don't skip loading the pattern file
- Don't skip the LEARN step — that's the point
- Don't save general knowledge to the pattern file
