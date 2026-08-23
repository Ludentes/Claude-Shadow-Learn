---
name: session-knowledge-extract
description: Use when the user wants to extract knowledge from today's agent sessions without running the Galatea pipeline. Triggers on "extract from sessions", "what did I teach you today", "learn from today", "session extract". Reads Claude Code, Codex CLI, and Kimi Code transcripts and writes to the project knowledge store.
---

# Session Knowledge Extract

Read today's sessions across Claude Code, Codex CLI, and Kimi Code, and extract durable knowledge using heuristic rules. No pipeline required — the agent reads and classifies directly. Writes to the project knowledge store at `.agents/memory/extracted-knowledge.md`.

## Paths

```bash
MEMORY_DIR="$(pwd)/.agents/memory"
```

The knowledge store lives in the project repo, so it works identically under
Claude Code, Codex CLI, and Kimi Code.

## Step 0: Load existing memory context

Read `AGENTS.md`, `$MEMORY_DIR/MEMORY.md`, and `$MEMORY_DIR/extracted-knowledge.md`.
Note what's already documented (skip in Step 4), known entities, and existing
sections to merge into. If nothing exists, proceed without context.

## Steps 1-2: Collect user turns from every tool

```bash
~/.agents/bin/session-turns --since 1d
```

This reads Claude Code, Codex CLI, and Kimi Code transcripts for the current
project and emits a normalized stream, oldest first:

```
--- [kimi 2026-08-23T15:40]
We always use pnpm, never npm
--- [claude 2026-08-23T14:02]
Don't put API calls in pages. They go in features/*/api/.
```

Per-tool counts go to stderr. Zero output means no sessions matched — check the
stderr line before concluding there was no signal. Process up to ~15 sessions'
worth of turns; if the output is very long, work from the most recent turns.

## Step 3: Apply the signal classifier

For each user turn, determine if it is **signal** or **noise**.

### KEEP — signal patterns

| Pattern | Type | Confidence | About |
|---------|------|-----------|-------|
| `@remember X` / `Remember: X` | fact | 0.95 | project (or user if starts with "I") |
| `I prefer/like/want/love X` | preference | 0.95 | user |
| `I always/never X` | rule | 0.95 | user |
| `We always/never/should X` | rule | 0.95 | team |
| `Always/Never/Must/Should X` (imperative) | rule | 0.95 | project |
| `No, that's wrong / No, use X instead` | correction | 0.9 | project |
| `Let's go with X` where X is a named technology | decision | 0.9 | project |
| `[Person] now does/wants/prefers X` | entity update | 0.9 | entity |
| Numbered steps 1-2-3 that are reusable procedures | procedure | 0.85 | project |
| `The project uses X` / `X is configured as Y` | fact | 0.8 | project |

### REJECT — noise patterns

**Always skip:**
- Single words or very short messages: "ok", "yes", "hi", "thanks", "sure", "got it", "done"
- Messages under 20 characters
- Messages that are only code blocks or file contents (starts with ` ``` ` and ends with ` ``` `)
- Messages that are mostly IDE line numbers: lines like `53 | <code>`

**Resolve before rejecting — context-free decisions:**
When a turn says "Let's go with 1/2/A/B" or "use the second one", check the immediately preceding assistant message. If it contains a numbered or lettered list, substitute the referenced item's content and KEEP it as a decision. Example: "Let's go with 2" + preceding "1. npm  2. pnpm  3. yarn" → extract "Use pnpm".

Only REJECT if there is no preceding list to resolve against, or if the reference is purely anaphoric ("it", "that", "your suggestion").

**Skip procedures where >50% of steps are session-specific** (file reads, specific paths, "full contents"). "commit"/"push" alone don't make a step session-specific.

**Skip by content quality:** under 20 chars, dominated by file paths (>30%), or contains "COMPLETE file"/"exact content"/"see below".

**Skip general knowledge** (not specific to this project):
- These exact themes only: "write tests / TDD", "git / commit / push" (workflow steps), "handle errors / error handling", "code review", "meaningful names / variable names", "single responsibility"
- "Run the linter", "use feature branches", "review your code" are NOT general-knowledge — keep them
- When in doubt, keep it — general-knowledge rejection is narrow

## Step 4: Deduplicate

Using what you read in Step 0, drop any entry whose core meaning is already captured in:
1. AGENTS.md (and CLAUDE.md, if the project still has one)
2. MEMORY.md (knowledge store index)
3. extracted-knowledge.md (previous runs)

Also deduplicate within the extracted batch — keep only one entry per distinct concept.

## Step 5: Tag entries with destinations

Each entry gets a destination tag based on its type. This tells `/memory-consolidate` where to route it.

**Destination rules:**
- Domain rules, preferences, style → `patterns/[domain].md` (knowledge store)
- Repeatable multi-step procedures → `docs/playbooks/[task].md` (project repo)
- Per-person/service context, state → `entities/[name].md` (knowledge store)
- General knowledge the model already knows → `skip`
- Can't classify → `unsorted`

**Procedure → playbook test:** If the extracted procedure has 3+ steps and could be reused (deploy, setup, debug, release, report), route to `docs/playbooks/`. If it's a process rule ("always X before Y"), route to `patterns/`.

**Playbook source tagging:** Extracted playbooks get `source: extracted, status: draft` frontmatter. They need user review before being trusted. User-authored playbooks (explicit "write a playbook for X") get `source: authored, status: reviewed`.

**The "different senior dev" test:** Would a senior dev at a different company, on a different project in the same stack, do this differently? If NO → tag as `skip`. General programming knowledge adds noise.

Only include entries with confidence >= 0.9.

Group entries by destination:

```markdown
## Extracted [date]

### → patterns/[domain].md
- [domain-specific rules, preferences, style]

### → docs/playbooks/[task].md (source: extracted, status: draft)
- [repeatable multi-step procedures]

### → entities/[name].md
- [per-person or per-service context, state updates]

### → skip (general knowledge)
- [entries filtered out — listed for transparency]

### → unsorted
- [entries that don't fit a clear destination]
```

**Style rules for content:**
- Write in third person or imperative ("Use X", "Prefer Y", not "I prefer Y")
- Include the key entity/technology name in the content
- Keep each entry to one sentence where possible
- Strip `@remember` / `Remember:` prefix from fact content
- Prefer factual and procedural entries over preference/opinion entries. Factual: "PostgreSQL on port 15432". Procedural: "Deploy requires CI green first". Preference (use sparingly): "Prefers terse commit messages".
- Omit empty sections

## Step 6: Write to staging area and confirm

Target: `$MEMORY_DIR/extracted-knowledge.md` (staging area — promoted by `/memory-consolidate`).

`mkdir -p "$MEMORY_DIR"` if needed. Merge into existing sections if file exists; create if not. Add MEMORY.md link if missing.

Show the user: new entries, their destination tags, full resulting file. Ask **Apply** or **Show only**. Do NOT write without confirmation.

Remind: "Run `/memory-consolidate` to promote these entries to their destination files."

## What NOT to extract

Even if it appears in user turns, skip:
- Task instructions given to the agent ("now implement X", "read this file and tell me")
- Approval of the agent's suggestions ("looks good", "that's right", "yes exactly")
- Questions ("what does X do?", "how does Y work?")
- Emotional reactions ("great!", "perfect", "interesting")
- Status updates about what the agent did ("you just added", "this created")

The goal is durable knowledge the user HOLDS, not the conversation flow.
