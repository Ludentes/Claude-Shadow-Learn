---
name: session-knowledge-extract
description: Use when the user wants to extract knowledge from today's Claude Code sessions without running the Galatea pipeline. Triggers on "extract from sessions", "what did I teach Claude today", "learn from today", "session extract". Reads raw JSONL session files and writes to auto memory.
---

# Session Knowledge Extract

Read today's Claude Code sessions and extract durable knowledge using heuristic rules. No pipeline required — Claude reads and classifies directly. Writes to Claude Code's auto memory directory as `extracted-knowledge.md`, complementing the built-in auto memory.

## Paths

```bash
CWD=$(pwd)
PROJECT_SLUG=$(echo "$CWD" | tr '/' '-')
SESSION_DIR="$HOME/.claude/projects/$PROJECT_SLUG"
MEMORY_DIR="$SESSION_DIR/memory"
```

## Step 0: Load existing memory context

Read CLAUDE.md (project + user), `$MEMORY_DIR/MEMORY.md`, and `$MEMORY_DIR/extracted-knowledge.md`. Note what's already documented (skip in Step 4), known entities, and existing sections to merge into.

If nothing exists, proceed without context.

## Step 1: Find today's sessions

```bash
find "$SESSION_DIR" -name "*.jsonl" -not -name "history.jsonl" -mtime -1 | sort
```

If zero results: `ls ~/.claude/projects/ | grep <project-keyword>` to find the right dir.

## Step 2: Extract user turns from each session

For each session file, pull only user messages (skip assistant, system, tool_result):

```bash
python3 - <<'EOF' <session.jsonl
import json, sys
for line in sys.stdin:
    try:
        obj = json.loads(line.strip())
        msg = obj.get("message", obj)
        if msg.get("role") != "user":
            continue
        content = msg.get("content", "")
        if isinstance(content, list):
            content = " ".join(
                b.get("text", "") for b in content
                if isinstance(b, dict) and b.get("type") == "text"
            )
        content = content.strip()
        if len(content) > 10:
            print("---")
            print(content[:800])  # cap very long messages
    except Exception:
        pass
EOF
```

Run this for each session. Collect all user turns across sessions. Process up to ~15 sessions; skip the rest if there are many.

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
1. CLAUDE.md (project or user level)
2. MEMORY.md (auto memory entries)
3. extracted-knowledge.md (previous pipeline runs)

Also deduplicate within the extracted batch — keep only one entry per distinct concept.

## Step 5: Tag entries with destinations

Each entry gets a destination tag based on its type. This tells `/memory-consolidate` where to route it.

**Destination rules:**
- Domain rules, preferences, process steps → `patterns/[domain].md`
- Per-person/service context, state → `entities/[name].md`
- General knowledge the model already knows → `skip`
- Can't classify → `unsorted`

**The "different senior dev" test:** Would a senior dev at a different company, on a different project in the same stack, do this differently? If NO → tag as `skip`. General programming knowledge adds noise.

Only include entries with confidence >= 0.9.

Group entries by destination:

```markdown
## Extracted [date]

### → patterns/[domain].md
- [domain-specific rules, preferences, process steps]

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
- Omit empty sections

## Step 6: Write to staging area and confirm

Target: `$MEMORY_DIR/extracted-knowledge.md` (staging area — promoted by `/memory-consolidate`).

`mkdir -p "$MEMORY_DIR"` if needed. Merge into existing sections if file exists; create if not. Add MEMORY.md link if missing.

Show the user: new entries, their destination tags, full resulting file. Ask **Apply** or **Show only**. Do NOT write without confirmation.

Remind: "Run `/memory-consolidate` to promote these entries to their destination files."

## What Claude does NOT extract

Even if it appears in user turns, skip:
- Task instructions given to Claude ("now implement X", "read this file and tell me")
- Approval of Claude's suggestions ("looks good", "that's right", "yes exactly")
- Questions ("what does X do?", "how does Y work?")
- Emotional reactions ("great!", "perfect", "interesting")
- Status updates about what Claude did ("you just added", "this created")

The goal is durable knowledge the user HOLDS, not the conversation flow.
