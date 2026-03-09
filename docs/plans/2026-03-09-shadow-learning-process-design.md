# Shadow Learning Process Design

**Date**: 2026-03-09
**Status**: Approved design — ready for implementation
**Scope**: Tools, artifacts, instructions, and procedures for shadow learning with Claude Code

---

## Context

Shadow learning is a cycle: user works → Claude observes patterns → user corrects → knowledge updates → next session starts better. This design defines the complete system for making that cycle reliable across any domain.

Validated by: 4 thesis reviews (Mikhail → Sophiya → Anna → Denis) where corrections decreased from many → few → minimal across iterations. Three reference scenarios (frontend dev, Python dev, PM) extend the pattern to other domains.

### Design Constraints

- Uses only Claude Code built-in capabilities: auto-memory directory, skills, CLAUDE.md
- No external runtime, no API keys required for core functionality
- Target audience: team members and public GitHub users bringing their own domains
- Cold start default, with import path for existing knowledge

### Key Research (SkillsBench + AGENTS.md evaluation)

| Finding | Implication |
|---------|-------------|
| Curated skills: +16.2pp average | Human-curated skills work |
| Self-generated skills: -1.3pp | Never auto-generate skills |
| 2-3 focused skills: +18.6pp | Keep skill count low |
| Detailed/compact: +18.8pp | Dense > comprehensive |
| Comprehensive docs: -2.9pp | More is worse |
| SWE weakest domain: +4.5pp | Models already know how to code — only save non-obvious knowledge |
| Instructions get ignored (HN) | Enforce hard rules via hooks/CI, not memory |

---

## Architecture

```
┌─────────────────────────────────────────────────────────┐
│  LAYER 4: Human Behavior (GETTING_STARTED.md)           │
│  How the user corrects to maximize learning signal       │
│  Weekly 10-min review of memory files                   │
├─────────────────────────────────────────────────────────┤
│  LAYER 3: Learning Skills (skills/*/SKILL.md)           │
│  Multi-step procedures with built-in LEARN phase        │
│  2-3 per project max. Compact, not comprehensive.       │
├─────────────────────────────────────────────────────────┤
│  LAYER 2: Knowledge Store (memory/)                     │
│  patterns/*.md — domain rules (<150 lines each)         │
│  entities/*.md — people, services, state                │
│  extracted-knowledge.md — staging area                  │
│  MEMORY.md — index (<200 lines)                         │
├─────────────────────────────────────────────────────────┤
│  LAYER 1: Extraction & Maintenance (utility skills)     │
│  /session-knowledge-extract — daily safety net          │
│  /memory-consolidate — weekly routing + pruning         │
│  /deep-extract — optional high-recall cloud pipeline    │
└─────────────────────────────────────────────────────────┘
```

Layer 1 catches what was missed. Layer 2 stores what was learned. Layer 3 applies what was stored and creates correction opportunities. Layer 4 teaches the human to produce high-quality corrections.

### Automation Boundary

- **Inline learning (semi-automatic)**: Claude Code's built-in auto-memory handles explicit corrections during work. Learning skills update pattern files as part of their procedure. No blocking gates — Claude writes freely.
- **Extraction and consolidation (manual commands)**: User runs `/session-knowledge-extract` daily and `/memory-consolidate` weekly. These are explicit, not automatic.
- **Quality control (mandated human review)**: User reviews memory files during weekly `/memory-consolidate` run — same as reviewing a PR. Non-blocking: patterns are saved immediately, reviewed periodically.

---

## Layer 2: Knowledge Store

### File Organization

```
~/.claude/projects/<project>/memory/
├── MEMORY.md              # Index — always loaded, <200 lines
├── patterns/              # Domain-specific learned patterns
│   ├── frontend.md        #   FSD, shadcn, import rules
│   ├── python-backend.md  #   TDD, FastAPI, uv
│   └── review-patterns.md #   Thesis review calibration
├── entities/              # Per-entity context
│   ├── people.md          #   Denis, Anna, teammates...
│   └── services.md        #   auth-service, deploy pipeline...
└── extracted-knowledge.md # Staging area from /session-knowledge-extract
```

### Three File Types

| Type | Directory | Purpose | Who writes |
|------|-----------|---------|------------|
| **Patterns** | `patterns/` | Learned rules for a domain. Transferable. | Learning skills + auto-memory + /extract |
| **Entities** | `entities/` | Per-person/thing context. State tracking. | Learning skills + user |
| **Extracted** | root | Staging area. Gets promoted by /consolidate. | `/session-knowledge-extract` only |

### File Size Budgets

| File | Max lines | Rationale |
|------|-----------|-----------|
| MEMORY.md | 200 | Claude Code truncates after this |
| Pattern file | 150 | Compact > comprehensive (SkillsBench) |
| Entity file | No hard limit | But prune inactive entities |
| extracted-knowledge.md | Ephemeral | Consumed by /consolidate |

### Pattern File Template

```markdown
# [Domain Name] Patterns

> Source: [which skill/workflow populates this]
> Last updated: [date]
> Sessions learned from: [count — shows maturity]

## Architecture / Structure
- [How things are organized — layers, layout, pipeline stages]

## Process / Workflow
- [Order of operations — what comes first, dependencies]
- [Decision points — when to ask user vs proceed]
- [Habits — "always run tests before committing"]

## Conventions
- [Naming, formatting, style — specific to THIS project/team]

## Quality Bar
- [What "good enough" means — thresholds, metrics]
- [What triggers a redo vs. refinement]

## Preferences
- [Tools: "uv not pip", "pnpm not npm"]
- [Style: "prose over bullets", "conventional commits"]
- [Communication: "terse corrections", "Вы not ты"]

## Don't (learned from corrections)
- [Each traces to a real correction, not general knowledge]

## Tone & Voice (if applicable)
- [How outputs should read — formal, casual, encouraging]
- [Audience-specific adjustments]
```

### Entity File Templates

#### People

```markdown
## [Name]
- **Role**: [student, teammate, client, stakeholder]
- **Context**: [relationship to user's work]
- **Status**: [active task, waiting, blocked, done]
- **Strengths**: [what they're good at]
- **Watch for**: [recurring issues, tendencies]
- **Communication style**: [literal, big-picture, needs examples, terse]
- **History**: [key past interactions, one dense paragraph]
- **Next expected**: [upcoming deadline, meeting, deliverable]
```

#### Team

```markdown
## Shared Conventions
- [Commit format, branch naming, review process]

## Division of Labor
- [Who owns what — overlap zones to watch]

## Handoff Patterns
- [How work moves between people — PR flow, feedback cycles]
```

### MEMORY.md as Index

```markdown
# Project Memory

## Patterns (N files, M total rules)
- [frontend.md](patterns/frontend.md) — FSD, shadcn, imports (12 rules, 3 sessions)
- [python-backend.md](patterns/python-backend.md) — TDD, FastAPI (8 rules, 2 sessions)

## Entities (N tracked)
- [people.md](entities/people.md) — Anna, Denis, Mikhail, Sophiya

## Staging
- [extracted-knowledge.md](extracted-knowledge.md) — 3 entries pending consolidation
```

### What NEVER Goes in Memory

#### General knowledge (model already knows)
- Programming best practices (DRY, SOLID, clean code)
- Language syntax or standard library usage
- Common design patterns (factory, observer, etc.)
- "Use meaningful names", "handle errors", "write tests"

#### Obvious from codebase
- Project structure (Claude reads it each session)
- Dependencies (Claude reads package.json/pyproject.toml)
- Framework conventions (Claude knows React, FastAPI, etc.)

#### Temporary state
- Current task details ("working on feature X")
- In-progress debugging ("tried A, didn't work")
- Session-specific context

#### The Test

> Would a senior developer at a DIFFERENT company, working on a DIFFERENT project in the same stack, do this differently?
>
> **YES** → Save it (specific to this user/team/project)
> **NO** → Skip it (model already knows)

### Deterministic Enforcement Over Memory

For rules that truly matter, prefer hooks/CI:

| Rule type | Enforcement | Example |
|-----------|-------------|---------|
| Import order | ESLint / pre-commit | FSD layer imports |
| Test before impl | Skill procedure (step order) | TDD workflow |
| Conventional commits | commitlint hook | feat/fix/chore format |
| No direct shadcn imports | ESLint no-restricted-imports | Use shared/ui wrappers |
| Pattern/preference | Memory file (best-effort) | "Prose over bullets" |

**Rule of thumb**: If you can enforce it with a tool, do that. Memory is for things that require judgment — tone, structure, when to ask vs proceed, quality bar.

---

## Layer 3: Learning Skills

### Two Tiers

| Tier | Has LEARN step | Links to pattern file | Example |
|------|---------------|----------------------|---------|
| **Learning skill** | Yes | Yes — reads/updates `patterns/*.md` | thesis-review, pm-pipeline |
| **Utility skill** | No | No — standalone | end-of-day-report, topic-research |

**The distinction**: Does this skill make decisions the user might correct? Yes → learning skill. No → utility skill.

### Learning Skill Template

```markdown
---
name: [skill-name]
description: "Shadow learning skill for [domain]. Loads patterns,
  applies them, absorbs corrections, updates knowledge."
---

# [Skill Name] (Shadow Learning Skill)

## Pattern File
`memory/patterns/[domain].md` — read at start, update at end.

## Cold Start
If pattern file doesn't exist: "No patterns yet. I'll follow
your lead — you do it, I'll learn. I'll lead from next time."

## Arguments
[What the user passes in]

## Step 0: Load Knowledge
Read pattern file + any entity files referenced.
Note: how many rules exist? How mature are the patterns?

## Steps 1-N: Apply + Correct Loop
[Domain-specific steps — the actual work]

After each step: present analysis, ask "Anything to correct?"
When corrected, classify:
- New pattern → will add to pattern file
- Calibration → will update existing pattern
- One-off → note in conversation only

## Step N+1: Produce Output
[Create the deliverable — review, code, document]

## Step N+2: Update Knowledge (LEARN)
**Not optional.** Every run should leave knowledge better.

Update pattern file:
- New patterns from corrections
- Calibrations to existing patterns
- Remove patterns that proved wrong

Update entity files if applicable.

Report: "From this run I [learned X / updated Y / no changes]."
```

### Design Rules (from SkillsBench)

1. **Keep skills compact.** 10-15 lines for domain-specific steps, not 50.
2. **2-3 learning skills per project max.** More = diminishing returns.
3. **Skills don't create skills.** Only humans create learning skills.
4. **Pattern file is the real product.** The skill is the procedure that populates it. A mature pattern file works even without the skill — Claude reads it at session start via auto-memory.

---

## Layer 1: Extraction & Maintenance

### `/session-knowledge-extract` (updated)

Reads today's JSONL sessions, writes to `extracted-knowledge.md` with destination tags:

```markdown
## Extracted 2026-03-09

### → patterns/frontend.md
- "Wrap shadcn only when customizing, simple components use directly"

### → entities/people.md
- "Denis: draft1 reviewed, research file provided"

### → skip (general knowledge)
- "Use meaningful variable names" ← FILTERED OUT

### → unsorted
- "Prefers prose over bullet lists in reviews"
```

### `/memory-consolidate` (updated)

1. Reads `extracted-knowledge.md` — promotes tagged entries to destination files
2. Reads all `patterns/*.md` — checks for bloat (>150 lines), duplicates, contradictions
3. Reads `entities/*.md` — prunes inactive entities, updates stale state
4. Rewrites MEMORY.md index with current file list and metadata
5. Reports: "Promoted 3 entries, pruned 2 stale patterns, MEMORY.md at 142/200 lines"

### `/deep-extract` (unchanged)

Cloud LLM pipeline for higher recall. Writes to same staging area. Same routing during consolidate.

### Cadence

| Tool | When | Trigger |
|------|------|---------|
| `/session-knowledge-extract` | End of workday | User runs manually |
| `/memory-consolidate` | Weekly | User runs manually — this is the review moment |
| `/deep-extract` | Optional | When user suspects missed patterns |

---

## Layer 4: Human Guide

### The Core Insight

The user is part of the learning loop. How they correct determines what gets learned. This guide teaches effective correction.

### How Shadow Learning Works

```
Session 1: You lead, Claude watches
Session 2: Claude tries, you correct a lot
Session 3: Claude tries, you correct a little
Session 4+: Claude leads, you spot-check
```

### How to Correct (this matters)

#### Good corrections (Claude learns from these)

```
"No, always do X"            → becomes a rule
"Not X, do Y instead"        → becomes a preference
"This is too strict, relax"  → calibrates existing pattern
"For Denis, do X differently" → per-entity note, not a rule
```

#### Weak corrections (Claude can't learn from these)

```
*silently rewrites output*    → Claude doesn't see it
"this is wrong"               → wrong how? no pattern
"fix it"                      → fix what? no direction
*accepts and privately disagrees* → worst: wrong pattern reinforced
```

#### The Golden Format

```
"Don't [what Claude did]. Instead [what you want].
 Because [why — optional but helps calibration]."
```

Examples:
- "Don't put API calls in pages. They go in features/*/api/."
- "Don't wrap simple shadcn components. Only wrap when customizing."
- "This intro is 5 pages. Cut to 2. Nobody reads long intros."

### Weekly Review (10 minutes)

1. Run `/memory-consolidate`
2. Scan pattern files — anything wrong? Too strict? Outdated?
3. Scan entity files — anyone inactive? State stale?
4. Edit directly — these are your files, not Claude's

Think of it like reviewing a PR from a junior developer who's been taking notes on how you work.

### When to Create a Learning Skill

After you've done the same type of work **3+ times** and corrected Claude each time:

1. Copy `skills/_template/SKILL.md`
2. Fill in domain-specific steps
3. Point it at your pattern file
4. Install: `cp -r skills/my-skill ~/.claude/skills/`

**Signs you need a skill**: Same corrections repeating. Repeatable structure. Claude makes judgment calls you calibrate.

**Signs you don't**: One-off work. Pattern file alone is sufficient. Simple enough for a CLAUDE.md instruction.

### What NOT to Teach

Don't correct Claude on things it already knows. The "different senior dev" test applies. Correcting on general knowledge adds noise and hurts performance (SkillsBench: comprehensive docs = -2.9pp).

---

## Key Design Decisions

| Decision | Rationale | Evidence |
|----------|-----------|----------|
| Semi-auto inline + manual extract/consolidate | Auto-memory handles corrections; explicit commands for safety net | Thesis review: inline captured ~95% |
| Mandated review, not human gate | Non-blocking; user reviews weekly like a PR | Reduces friction, prevents interruption fatigue |
| 2-3 pattern files, <150 lines | Compact > comprehensive | SkillsBench: +18.8pp vs -2.9pp |
| No auto-generated skills | Self-generated skills hurt performance | SkillsBench: -1.3pp average |
| Staging area for extraction | Prevents unreviewed content polluting pattern files | Separation of concerns |
| Entity templates with recommended fields | Structured enough to be useful, free-form enough to adapt | Thesis review: Denis entity was most useful with structured fields |
| Human correction guide | User is part of the system; correction quality = learning quality | Thesis review: explicit corrections > silent edits |
| "Different senior dev" test | Filters general knowledge that adds noise | SkillsBench: SWE only +4.5pp (model already knows) |
| Deterministic enforcement for hard rules | Instructions get ignored | HN discussion: hooks/CI > prompting |

---

## Implementation Plan

### Phase 1: Knowledge Store Structure
- [ ] Create `patterns/` and `entities/` directories in memory template
- [ ] Create pattern file and entity file templates in `skills/_template/`
- [ ] Update MEMORY.md template with index format
- [ ] Add "Don't Save" rules to knowledge store documentation

### Phase 2: Update Existing Skills
- [ ] Update `/session-knowledge-extract` to tag entries with destinations
- [ ] Update `/memory-consolidate` to route staged entries and enforce file size budgets
- [ ] Update `/thesis-review` to use `patterns/review-patterns.md` path convention

### Phase 3: Learning Skill Template
- [ ] Create `skills/_template/SKILL.md` with the learning skill skeleton
- [ ] Document the two-tier system (learning vs utility) in repo README

### Phase 4: Human Guide
- [ ] Write GETTING_STARTED.md with correction guide and weekly review instructions
- [ ] Update README.md to reference the guide

### Phase 5: Validate
- [ ] Test cold start scenario (new user, no patterns)
- [ ] Test import scenario (user with existing CLAUDE.md/memory)
- [ ] Verify against reference scenarios (frontend, Python, PM)
