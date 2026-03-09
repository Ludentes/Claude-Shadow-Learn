# claude-shadow-learn

Claude learns from your corrections. Each time you fix Claude's output, it updates
pattern files so the next attempt is better. This repo provides the tools and
structure to make that loop reliable.

```
Session 1: You lead, Claude watches
Session 2: Claude tries, you correct a lot
Session 3: Claude tries, you correct a little
Session 4+: Claude leads, you spot-check
```

Validated across 4 thesis reviews where corrections dropped from many → few → minimal.

---

## Quick Start

```bash
# Copy skills into Claude Code
cp -r skills/session-knowledge-extract  ~/.claude/skills/
cp -r skills/memory-consolidate         ~/.claude/skills/

# Optional
cp -r skills/deep-extract               ~/.claude/skills/
cp -r skills/end-of-day-report          ~/.claude/skills/
cp -r skills/end-of-week-report         ~/.claude/skills/
cp -r skills/topic-research             ~/.claude/skills/
```

No API keys, no config, no dependencies. Read [GETTING_STARTED.md](GETTING_STARTED.md) for setup and usage.

---

## How It Works

### Knowledge Store

Shadow learning organizes knowledge into structured files inside Claude Code's auto memory directory:

```
~/.claude/projects/<project>/memory/
├── MEMORY.md              # Index — always loaded (<200 lines)
├── patterns/              # Domain rules (<150 lines each)
│   ├── frontend.md        #   FSD, shadcn, import rules
│   └── review-patterns.md #   Thesis review calibration
├── entities/              # Per-entity context
│   └── people.md          #   Denis, Anna, teammates...
└── extracted-knowledge.md # Staging area
```

**Patterns** are domain-specific rules Claude applies during work. **Entities** are context about people, services, or systems. Both are populated through the correction loop.

### The Correction Loop

The core mechanism: you correct Claude → Claude records the pattern → next time Claude applies it.

Good corrections are specific:
- "Don't put API calls in pages. They go in `features/*/api/`."
- "This intro is 5 pages. Cut to 2."

Weak corrections ("this is wrong", "fix it") don't produce learnable patterns.

### What Gets Saved

Only knowledge specific to your team/project. **The test:** would a senior dev at a different company, on a different project in the same stack, do this differently? If yes → save it. If no → skip it.

---

## Skills

### Learning Skills (have a LEARN step, link to pattern files)

| Skill | Invoke | What it does |
|---|---|---|
| `thesis-review` | `/thesis-review [student]` | VKR review with section-by-section correction loop |

Learning skills enforce the full cycle: load patterns → apply → get corrected → update patterns. Create your own from `skills/_template/`.

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

## Creating Your Own Learning Skill

After you've done the same type of work **3+ times** and corrected Claude each time:

```bash
cp -r skills/_template skills/my-skill
# Edit SKILL.md with your domain-specific steps
cp -r skills/my-skill ~/.claude/skills/
```

The template has the full skeleton: load → apply → correct → produce → learn. The skill is not the product — the pattern file is. A mature pattern file works even without the skill.

See [GETTING_STARTED.md](GETTING_STARTED.md) for details on when to create skills vs when a pattern file alone is sufficient.

---

## Daily Workflow

```
Morning:   Start working. Claude loads memory files automatically.
During:    Correct Claude when it gets things wrong. Be explicit.
End of day: Run /session-knowledge-extract (catches what was missed).
Weekly:    Run /memory-consolidate (routes, prunes, reviews).
```

---

## Architecture

```
Layer 4: Human behavior       GETTING_STARTED.md — how to correct, when to review
Layer 3: Learning skills      skills/ — enforce load→apply→correct→learn cycle
Layer 2: Knowledge store      patterns/, entities/ — structured, bounded files
Layer 1: Extraction/maint.    /session-knowledge-extract, /memory-consolidate
```

Hard rules (import order, commit format) belong in linters and hooks, not memory. Memory is for things that require **judgment** — tone, structure, quality bar.

---

## Reference Scenarios

See [docs/REFERENCE_SCENARIOS.md](docs/REFERENCE_SCENARIOS.md) for detailed examples across three personas:

1. **Frontend dev** (React, shadcn/ui, FSD, pnpm) — component architecture patterns
2. **Python dev** (uv, TDD, FastAPI) — strict TDD workflow, testing strategy
3. **PM** (Brief → IRD → Gate → Personas → Scenarios → Stories) — pipeline discipline

Each scenario shows the learning curve from cold start to autonomous operation.

---

## Design Decisions

Key choices backed by research (see [design doc](docs/plans/2026-03-09-shadow-learning-process-design.md)):

| Decision | Evidence |
|---|---|
| Never auto-generate skills | SkillsBench: self-generated skills = -1.3pp |
| Keep pattern files <150 lines | SkillsBench: compact +18.8pp vs comprehensive -2.9pp |
| 2-3 skills per domain max | SkillsBench: optimal count = +18.6pp |
| Hard rules via hooks, not memory | AGENTS.md eval: instructions get ignored under load |
| Human reviews, not gates | Thesis review validation: non-blocking review worked |

---

## Extraction: Free vs Cloud

| | `/session-knowledge-extract` | `/deep-extract` |
|---|---|---|
| API key required | No | Yes (OpenRouter) |
| Recall | ~55% | ~95% |
| Speed | Instant | 5–15 s/session |
| Cost | Free | ~$0.05/session |
| Good for | Daily use, air-gapped | Historical catch-up, max recall |
