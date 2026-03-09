# Shadow Learning: Getting Started

Claude learns from your corrections. The better your corrections, the faster Claude improves. This guide teaches you how to set up shadow learning, correct effectively, and maintain your knowledge store.

---

## What This Does

Claude Code has built-in auto memory (`MEMORY.md`) that captures what Claude notices during work — build commands, corrections, debugging insights. This works well for the easy 80%.

**claude-shadow-learn** catches the other 20% and structures it:
- Organizes knowledge into **pattern files** (domain rules) and **entity files** (people, services)
- Provides **learning skills** that enforce a correct → learn → apply loop
- Provides **extraction and maintenance** tools as safety nets

```
CLAUDE.md               ← you write (team instructions, architecture)
MEMORY.md               ← auto memory writes (build commands, corrections)
patterns/*.md           ← shadow learning writes (domain rules, preferences)
entities/*.md           ← shadow learning writes (people, services, state)
extracted-knowledge.md  ← extraction safety net (staging area)
```

---

## Setup (2 minutes)

```bash
# Copy skills into Claude Code
cp -r skills/session-knowledge-extract  ~/.claude/skills/
cp -r skills/memory-consolidate         ~/.claude/skills/

# Optional: additional skills
cp -r skills/deep-extract               ~/.claude/skills/
cp -r skills/end-of-day-report          ~/.claude/skills/
cp -r skills/end-of-week-report         ~/.claude/skills/
cp -r skills/topic-research             ~/.claude/skills/
```

No API keys, no config, no dependencies. Skills read/write to Claude Code's built-in memory directory.

---

## Your First Session

No patterns exist yet. That's fine — you lead, Claude watches.

1. **Work normally.** Do whatever you were going to do with Claude Code.
2. **When Claude does something wrong, correct it out loud:** "Don't do X. Instead do Y."
3. **When you make a choice, say why:** "Let's use pnpm because we standardized on it."
4. **At the end of the session,** run `/session-knowledge-extract`. Review what it found. Apply if it looks right.

That's it. By session 2-3, Claude starts applying the patterns you've taught it. By session 4+, you're mostly spot-checking.

---

## How Shadow Learning Works

```
Session 1: You lead, Claude watches       → Claude has no patterns. You do the work, Claude observes.
Session 2: Claude tries, you correct a lot → Claude applies what it learned. Many corrections needed.
Session 3: Claude tries, you correct less  → Patterns are calibrated. Fewer corrections.
Session 4+: Claude leads, you spot-check   → Claude handles routine judgment. You catch edge cases.
```

This curve repeats for every new domain — code reviews, PM workflows, writing, anything with repeatable judgment. Validated across 4 thesis reviews where corrections dropped from many → few → minimal.

**What "leads" means:** Claude makes judgment calls (tone, structure, what to flag, what to skip) based on accumulated patterns. You review output rather than directing each step.

---

## How to Correct (this matters)

Your corrections are the training signal. Their quality determines how fast and accurately Claude learns.

### Good corrections (Claude learns from these)

| What you say | What Claude learns |
|---|---|
| "No, always do X" | A new rule |
| "Not X, do Y instead" | A preference |
| "This is too strict, relax it" | Calibration of existing pattern |
| "For Denis, do X differently" | Per-entity note (not a general rule) |

### The golden correction format

```
"Don't [what Claude did]. Instead [what you want].
 Because [why — optional but helps calibration]."
```

**Examples:**
- "Don't put API calls in pages. They go in `features/*/api/`."
- "Don't wrap simple shadcn components. Only wrap when customizing."
- "This intro is 5 pages. Cut to 2. Nobody reads long intros."
- "Don't catch generic Exception. Be specific — NotFoundError, ConflictError."

### Weak corrections (Claude can't learn from these)

| What you do | Why it doesn't work |
|---|---|
| Silently rewrite Claude's output | Claude doesn't see the correction |
| "This is wrong" | Wrong how? No pattern to extract |
| "Fix it" | Fix what? No direction |
| Accept and privately disagree | Worst case: wrong pattern reinforced |

---

## Your Knowledge Store

### File Organization

```
~/.claude/projects/<project>/memory/
├── MEMORY.md              # Index — always loaded (<200 lines)
├── patterns/              # Domain rules (<150 lines each)
│   ├── frontend.md        #   FSD, shadcn, import rules
│   └── review-patterns.md #   Thesis review calibration
├── entities/              # Per-entity context
│   └── people.md          #   Denis, Anna, teammates...
└── extracted-knowledge.md # Staging area from /session-knowledge-extract
```

### What gets saved

Things **specific to your team/project** that Claude wouldn't know otherwise:
- "We use FSD architecture with barrel exports in each slice"
- "TDD is strict — test first, always, no exceptions"
- "Denis follows docs literally — tell him to compress, not cut"

### What does NOT get saved

General knowledge the model already has. Saving it adds noise and **actually hurts performance** (SkillsBench research: comprehensive documentation = -2.9pp vs compact = +18.8pp).

**The test:** Would a senior developer at a different company, on a different project in the same stack, do this differently? If **yes** → save it. If **no** → skip it.

**Never save:**
- "Use meaningful variable names" — Claude already knows
- "Handle errors properly" — generic
- "Write tests for edge cases" — generic
- Project structure / dependencies — Claude reads these each session

---

## Habits for Optimal Shadow Learning

Shadow learning happens *during* your normal work. No extra effort — just small changes to how you interact with Claude.

### Do: Correct out loud

When Claude does something wrong, tell it what you wanted and why. This is the #1 habit.

```
Claude puts an API call in a page component.
❌ You silently move it to features/auth/api/.
✅ "Don't put API calls in pages. They go in features/*/api/."
```

The correction must happen in the conversation. If Claude doesn't see it, it can't learn.

### Do: State preferences when you notice them

When you catch yourself thinking "I'd rather do it this way," say it:

- "I prefer pnpm workspace protocol for internal packages."
- "Always use named exports, never default."
- "For this team, we use strict TDD — test first, no exceptions."

Explicit preferences ("I prefer", "always", "never") are extracted with high confidence. Implicit ones ("hmm, let me change this") are invisible to the system.

### Do: Name people and context

When talking about teammates, clients, or services, use names and say what's relevant:

- "Alex is now reviewing backend PRs too, not just frontend."
- "Marina prefers Mermaid diagrams in specs."
- "The billing service uses event sourcing — don't assume CRUD."

Entity context helps Claude calibrate its output per person or per system.

### Do: Explain decisions

When choosing between options, say why:

- "Let's go with Tailwind — we need consistency with shadcn."
- "Use zod, not yup. We standardized on zod across all projects."
- "JWT over sessions because we're going microservices."

The reasoning is what makes a pattern transferable vs. a one-off.

### Don't: Silently fix Claude's output

If you copy Claude's output, edit it, and paste it somewhere — Claude learned nothing. The worst case: Claude remembers the wrong version as correct.

If fixing is faster than explaining, fix first, then tell Claude: "I changed X to Y because Z."

### Don't: Accept and privately disagree

If Claude does something you don't like but you let it slide, Claude may record it as a confirmed pattern. This is the most damaging anti-pattern — it reinforces the wrong behavior.

Push back: "This is too strict" or "Not how we do it" is enough.

### Don't: Give vague corrections

| You say | Claude learns |
|---|---|
| "This is wrong" | Nothing — wrong how? |
| "Fix it" | Nothing — fix what? |
| "Make it better" | Nothing — better in what way? |
| "Don't put API calls in pages. Use features/*/api/." | A specific, reusable rule |

### Don't: Over-instruct with general knowledge

Telling Claude "use meaningful variable names" or "handle errors properly" adds noise. Claude already knows these things. Save your corrections for things **specific to your project** that Claude wouldn't know otherwise.

### Do: Use `@remember` for important facts

When you want something explicitly captured:

```
@remember We use PostgreSQL on port 15432, not the default 5432.
@remember I always want tests to run against a real database, not mocks.
```

These are extracted with confidence 1.0 — highest priority.

### Do: Review your memory files periodically

Your pattern and entity files are like a PR from a junior who's been taking notes on how you work. Skim them occasionally:

- Is anything wrong or outdated?
- Is anything too strict? Too lenient?
- Did something get saved that shouldn't have?

Edit directly — these are your files. You're the source of truth, not Claude.

---

## Daily Workflow

```
Morning:   Start working. Claude loads memory files automatically.
During:    Correct out loud. State preferences. Name people.
End of day: Run /session-knowledge-extract (catches what was missed).
Weekly:    Run /memory-consolidate (routes, prunes, reviews).
```

### End of coding day

```
/session-knowledge-extract
```

Claude reads today's sessions, extracts knowledge, tags each entry with its destination (`patterns/`, `entities/`, or skip), and writes to `extracted-knowledge.md` as a staging area. This is a **safety net** — if you correct out loud during work, most knowledge is already captured.

### Weekly maintenance + review (10 minutes)

```
/memory-consolidate
```

This promotes staged entries to their destination files, checks for bloat, and prunes stale patterns. **This is your review moment:**

1. Scan pattern files — anything wrong? Too strict? Outdated?
2. Scan entity files — anyone inactive? State stale?
3. Edit directly — these are your files, not Claude's

Think of it like reviewing a PR from a junior developer who's been taking notes on how you work.

---

## Creating a Learning Skill

After you've done the same type of work **3+ times** and corrected Claude each time, consider creating a learning skill. A learning skill encodes a repeatable procedure with a built-in LEARN step.

### When to create one

- You keep giving the same corrections
- The work has repeatable structure (steps, checklist)
- Claude makes judgment calls you need to calibrate

### When NOT to create one

- The work is one-off or varies too much
- A pattern file alone is sufficient (Claude reads it automatically)
- Simple enough for a CLAUDE.md instruction

### How to create one

```bash
# Copy the template
cp -r skills/_template skills/my-skill

# Edit SKILL.md — fill in your domain-specific steps
# PATTERN.md and ENTITY.md are templates for your knowledge files

# Install
cp -r skills/my-skill ~/.claude/skills/
```

The template has the full skeleton: load → apply → correct → produce → learn. Fill in your domain-specific steps (keep them to 10-15 lines) and point it at your pattern file.

**Important:** The skill is not the product — the pattern file is. A mature pattern file works even without the skill. The skill just enforces the correction loop that populates the pattern file faster.

**Important:** Never auto-generate skills. SkillsBench research shows self-generated skills hurt performance (-1.3pp). Only humans should create skills.

---

## Hard Rules: Use Hooks, Not Memory

For rules that must never be violated, don't rely on memory — use deterministic enforcement:

| Rule | Enforcement |
|---|---|
| Import order | ESLint rule or pre-commit hook |
| Conventional commits | commitlint |
| No direct shadcn imports | ESLint no-restricted-imports |
| Test before implementation | Learning skill (enforced by step order) |

Memory is for things that require **judgment** — tone, structure, when to ask vs proceed, quality bar. If you can enforce it with a tool, do that.

---

## Skills Included

### Learning Skills (have LEARN step, link to pattern files)

| Skill | Invoke | What it does |
|---|---|---|
| `thesis-review` | `/thesis-review [student]` | VKR review with section-by-section correction loop |

### Utility Skills (fire-and-forget)

| Skill | Invoke | What it does |
|---|---|---|
| `session-knowledge-extract` | `/session-knowledge-extract` | Daily extraction safety net (free) |
| `memory-consolidate` | `/memory-consolidate` | Weekly routing, pruning, review |
| `deep-extract` | `/deep-extract` | Cloud LLM extraction (~$0.05/session) |
| `topic-research` | `/topic-research [topic]` | Web research with citations |
| `end-of-day-report` | `/end-of-day-report` | Standup summary from git |
| `end-of-week-report` | `/end-of-week-report` | Weekly summary from git |

---

## Choosing Between Free and Cloud Extraction

| | `/session-knowledge-extract` | `/deep-extract` |
|---|---|---|
| API key required | No | Yes (OpenRouter) |
| Recall | ~55% | ~95% |
| Speed | Instant | 5–15 s/session |
| Cost | Free | ~$0.05/session |
| Good for | Daily use, air-gapped | Historical catch-up, max recall |

---

## Reference Scenarios

See [docs/REFERENCE_SCENARIOS.md](docs/REFERENCE_SCENARIOS.md) for detailed examples of shadow learning across three personas:

1. **Frontend dev** (React, shadcn/ui, FSD, pnpm) — component architecture patterns
2. **Python dev** (uv, TDD, FastAPI) — strict TDD workflow, testing strategy
3. **PM** (Brief → IRD → Gate → Personas → Scenarios → Stories) — pipeline discipline

Each scenario shows the full learning curve from cold start to autonomous operation.

---

## Cheat Sheet

Pin this somewhere visible until the habits become automatic.

```
DURING WORK
  ✅ "Don't X. Instead Y. Because Z."        → Claude learns a rule
  ✅ "I prefer / always / never X"            → Claude learns a preference
  ✅ "Alex now does X" / "Marina wants Y"     → Claude learns about people
  ✅ "@remember [fact]"                        → Guaranteed capture
  ✅ "Let's go with X because Y"              → Claude learns a decision + reasoning
  ❌ Silently fix Claude's output             → Claude learns nothing
  ❌ "This is wrong" / "Fix it"               → Too vague to learn from
  ❌ Accept output you disagree with           → Reinforces wrong pattern
  ❌ "Use meaningful variable names"           → Noise (Claude already knows)

END OF DAY
  /session-knowledge-extract                  → Catches what you missed

WEEKLY
  /memory-consolidate                         → Routes, prunes, reviews
  Skim pattern files — edit anything wrong    → You are the source of truth
```

---

## Troubleshooting

| Problem | Fix |
|---|---|
| No sessions found | Check slug: `ls ~/.claude/projects/ \| grep <keyword>` |
| Skills not appearing | Confirm: `~/.claude/skills/<name>/SKILL.md` must exist |
| MEMORY.md over 200 lines | Run `/memory-consolidate` to prune and rebalance |
| Pattern file over 150 lines | Run `/memory-consolidate` or manually prune |
| `OPENROUTER_API_KEY` missing | Only needed for `/deep-extract`. Set in `.env` |
| Memory feels noisy | Review files — remove general knowledge entries |
