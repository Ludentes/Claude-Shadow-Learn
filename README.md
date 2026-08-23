# claude-shadow-learn

Your coding agent learns from your corrections. Each time you fix its output, it
updates pattern files so the next attempt is better. This repo provides the tools
and structure to make that loop reliable.

Works with **Claude Code**, **Codex CLI**, and **Kimi Code** — one knowledge store,
shared across all three, so a correction made in one tool is applied by the others.

```
Session 1: You lead, the agent watches
Session 2: The agent tries, you correct a lot
Session 3: The agent tries, you correct a little
Session 4+: The agent leads, you spot-check
```

Validated across 4 real-world reviews where corrections dropped from many → few → minimal.

---

## Quick Start

### Option A: Install as a Claude Code plugin

```
/plugin marketplace add opcheese/skills-catalog
/plugin install shadow-learn-memory@opcheese-skills
```

Gets you the three skills and the transcript normalizer. The knowledge store
creates itself on first extract; the one thing to add by hand is the "Before
work that involves judgment" block from [`AGENTS.md.template`](AGENTS.md.template)
into your project's `CLAUDE.md`, which is what makes the agent read the store
back. Claude Code only — use the setup script if you want Codex CLI or Kimi
Code reading the same store, and the `AGENTS.md` written for you.

### Option B: Use the setup script

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

Run it from the directory of the project you want shadow learning in. It detects which
agent tools you have installed, creates the knowledge store, installs skills and the
transcript normalizer, and writes an `AGENTS.md`. Pass `-y` to skip prompts.

### Option C: Do it manually

```bash
# 1. Install skills and the transcript normalizer
mkdir -p ~/.agents/skills ~/.agents/bin
cp -r skills/session-knowledge-extract skills/memory-consolidate skills/start-research-thread ~/.agents/skills/
cp bin/session-turns ~/.agents/bin/ && chmod +x ~/.agents/bin/session-turns

# 2. Link into the tools you use (Kimi needs no link)
for s in ~/.agents/skills/*/; do ln -s "${s%/}" ~/.claude/skills/"$(basename "$s")"; done
for s in ~/.agents/skills/*/; do ln -s "${s%/}" ~/.codex/skills/"$(basename "$s")"; done

# 3. Create the store and instructions
mkdir -p .agents/memory/patterns .agents/memory/entities docs/playbooks
cp AGENTS.md.template AGENTS.md
```

### Check status

```bash
./shadow-learn.sh health    # Linux / macOS
.\shadow-learn.ps1 health   # Windows
```

No API keys, no config, no dependencies beyond `python3`. Read [GETTING_STARTED.md](GETTING_STARTED.md) for the full guide.

---

## Supported Tools

| | Claude Code | Codex CLI | Kimi Code |
|---|---|---|---|
| Instructions | `AGENTS.md` (via `CLAUDE.md` pointer) | `AGENTS.md` | `AGENTS.md` |
| Skills | linked into `~/.claude/skills/` | linked into `~/.codex/skills/` | reads `~/.agents/skills/` natively |
| Knowledge store | `.agents/memory/` | `.agents/memory/` | `.agents/memory/` |
| Transcript extraction | yes | yes | yes |
| Session-end hook | `./shadow-learn.sh install-hooks claude` | manual (see GETTING_STARTED) | `./shadow-learn.sh install-hooks kimi` |

The Codex reader is written against the documented rollout format but has not
been verified against a live Codex install. Report mismatches as an issue.

---

## How It Works

### Knowledge Store

Everything lives in the project repo, so every tool reads the same store:

```
your-project/
├── AGENTS.md                  # Instructions — all three tools read this
├── CLAUDE.md                  # Thin pointer at AGENTS.md
├── .agents/memory/            # The knowledge store
│   ├── MEMORY.md              #   Index (<200 lines)
│   ├── patterns/              #   Domain rules (<150 lines each)
│   │   ├── frontend.md        #     FSD, shadcn, import rules
│   │   └── code-review.md     #     Review style calibration
│   ├── entities/              #   Per-entity context
│   │   └── people.md          #     Teammates, clients...
│   └── extracted-knowledge.md #   Staging area
└── docs/playbooks/            # Repeatable procedures
    ├── deploy.md              #   Production deploy steps
    └── new-hire-setup.md      #   Onboarding checklist
```

Skills and the transcript normalizer install once, user-globally:

```
~/.agents/
├── skills/                    # Canonical source (Kimi reads it natively)
└── bin/session-turns          # Transcript normalizer

~/.claude/skills/<name>  →  ~/.agents/skills/<name>   (symlink)
~/.codex/skills/<name>   →  ~/.agents/skills/<name>   (symlink)
```

**Patterns** are domain-specific rules the agent applies during work. **Entities** are context about people, services, or systems. **Playbooks** are repeatable procedures — deploy, setup, release, anything you do more than once.

Committing `.agents/memory/` shares learning with your team. `init` asks first, because patterns and entity notes can hold names or client details; answer no and it adds the directory to `.gitignore`.

### The Correction Loop

The core mechanism: you correct the agent → it records the pattern → next time it applies the pattern.

Good corrections are specific:
- "Don't put API calls in pages. They go in `features/*/api/`."
- "This intro is 5 pages. Cut to 2."

Weak corrections ("this is wrong", "fix it") don't produce learnable patterns.

Corrections are picked up regardless of which tool you were using. `session-turns`
reads Claude Code, Codex CLI, and Kimi Code transcripts for the current project and
emits one normalized stream:

```
$ ~/.agents/bin/session-turns --since 1d
--- [kimi 2026-08-23T15:40]
We always use pnpm, never npm
--- [claude 2026-08-23T14:02]
Don't put API calls in pages. They go in features/*/api/.
```

### What Gets Saved

Only knowledge specific to your team/project. **The test:** would a senior dev at a different company, on a different project in the same stack, do this differently? If yes → save it. If no → skip it.

---

## Skills

### Learning Skills (have a LEARN step, link to pattern files)

| Skill | Invoke | What it does |
|---|---|---|
| `thesis-review` | `/thesis-review [student]` | Academic review with correction loop ([example](examples/thesis-review/)) |

Learning skills enforce the full cycle: load patterns → apply → get corrected → update patterns. Create your own from `templates/skill/`.

### Utility Skills (fire-and-forget)

| Skill | Invoke | What it does |
|---|---|---|
| `session-knowledge-extract` | `/session-knowledge-extract` | Daily extraction safety net (free) |
| `memory-consolidate` | `/memory-consolidate` | Weekly routing, pruning, review |
| `start-research-thread` | `/start-research-thread` | Scaffold a long-horizon research thread (topic file + dated doc + MEMORY entry) |

### Subagents

| Agent | When | What it does |
|---|---|---|
| `frontmatter-tagger` | Dispatched when a research/blog doc lacks frontmatter | Mechanical Haiku subagent — returns 3-6 lines of YAML or SKIP |

Installed to `.claude/agents/` by the init script. Project-scoped because the topic indexes it reads are per-project.

---

## Creating Your Own Learning Skill

After you've done the same type of work **3+ times** and corrected the agent each time:

```bash
# Project-specific skill — Kimi reads .agents/skills natively;
# link it into the other tools' project skill dirs as needed.
mkdir -p .agents/skills
cp -r templates/skill .agents/skills/my-skill
# Edit SKILL.md with your domain-specific steps

# Or install it user-globally, for every project
cp -r templates/skill ~/.agents/skills/my-skill
```

The template has the full skeleton: load → apply → correct → produce → learn. The skill is not the product — the pattern file is. A mature pattern file works even without the skill.

See [GETTING_STARTED.md](GETTING_STARTED.md) for details on when to create skills vs when a pattern file alone is sufficient.

---

## Daily Workflow

```
Morning:   Start working in any tool. It loads AGENTS.md and the memory files.
During:    Correct the agent when it gets things wrong. Be explicit.
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

