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

Validated across 4 real-world reviews where corrections dropped from many → few → minimal.

---

## Quick Start

### Option A: Use the setup script

```bash
# Linux / macOS
git clone https://github.com/Ludentes/Claude-Shadow-Learn.git
cd Claude-Shadow-Learn
./shadow-learn.sh init
```

```powershell
# Windows (PowerShell)
git clone https://github.com/Ludentes/Claude-Shadow-Learn.git
cd Claude-Shadow-Learn
.\shadow-learn.ps1 init
```

This creates the directory structure, copies skills, and adds the bootstrap snippet to your project's CLAUDE.md and an AGENTS.md for cross-tool compatibility. Pass `-y` to skip prompts.

### Option B: Do it manually

```bash
# 1. Copy skills into Claude Code
cp -r skills/session-knowledge-extract  ~/.claude/skills/
cp -r skills/memory-consolidate         ~/.claude/skills/

# 2. Create directories
mkdir -p docs/playbooks
```

Then create an `AGENTS.md` (see [agents.md](https://agents.md/) standard) and add this to your project's `CLAUDE.md`:

```markdown
## Shadow Learning
This project uses shadow learning. Before work involving judgment,
read `patterns/*.md` and `entities/*.md` in the memory directory.
Read `docs/playbooks/*.md` in the project repo for repeatable procedures.
When the user corrects you, note the correction explicitly.
```

### Check status

```bash
./shadow-learn.sh health    # Linux / macOS
.\shadow-learn.ps1 health   # Windows
```

No API keys, no config, no dependencies. Read [GETTING_STARTED.md](GETTING_STARTED.md) for the full guide.

---

## How It Works

### Knowledge Store

Shadow learning organizes knowledge into structured files inside Claude Code's auto memory directory:

```
~/.claude/projects/<project>/memory/     # Claude's memory (personal)
├── MEMORY.md              # Index — always loaded (<200 lines)
├── patterns/              # Domain rules (<150 lines each)
│   ├── frontend.md        #   FSD, shadcn, import rules
│   └── code-review.md     #   Review style calibration
├── entities/              # Per-entity context
│   └── people.md          #   Teammates, clients...
└── extracted-knowledge.md # Staging area

docs/playbooks/            # Project repo (committed to git)
├── deploy.md              #   Production deploy steps
└── new-hire-setup.md      #   Onboarding checklist
```

**Patterns** are domain-specific rules Claude applies during work. **Entities** are context about people, services, or systems. Both live in Claude's memory directory. **Playbooks** are repeatable procedures — deploy, setup, release, anything you do more than once. They live in the project repo (`docs/playbooks/`) so the whole team benefits.

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
| `thesis-review` | `/thesis-review [student]` | Academic review with correction loop ([example](examples/thesis-review/)) |

Learning skills enforce the full cycle: load patterns → apply → get corrected → update patterns. Create your own from `skills/_template/`.

### Utility Skills (fire-and-forget)

| Skill | Invoke | What it does |
|---|---|---|
| `session-knowledge-extract` | `/session-knowledge-extract` | Daily extraction safety net (free) |
| `memory-consolidate` | `/memory-consolidate` | Weekly routing, pruning, review |

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
| Human reviews, not gates | Review validation: non-blocking review worked |

