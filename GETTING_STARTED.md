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
AGENTS.md               ← cross-tool agent instructions (Codex, Cursor, etc.)
MEMORY.md               ← auto memory writes (build commands, corrections)
patterns/*.md           ← shadow learning writes (domain rules, preferences)
entities/*.md           ← shadow learning writes (people, services, state)
extracted-knowledge.md  ← extraction safety net (staging area)

docs/playbooks/*.md     ← shadow learning writes (repeatable procedures)
                           lives in project repo, committed to git
```

---

## Setup

### Option A: Use the setup script (recommended)

```bash
# Linux / macOS
git clone https://github.com/Ludentes/Claude-Shadow-Learn.git
cd your-project
/path/to/Claude-Shadow-Learn/shadow-learn.sh init
```

```powershell
# Windows (PowerShell)
git clone https://github.com/Ludentes/Claude-Shadow-Learn.git
cd your-project
\path\to\Claude-Shadow-Learn\shadow-learn.ps1 init
```

This creates the directory structure, copies skills, adds the bootstrap snippet to your CLAUDE.md, and creates an AGENTS.md for cross-tool compatibility. Pass `-y` to skip prompts.

### Option B: Do it manually

```bash
# 1. Copy skills into Claude Code
cp -r skills/session-knowledge-extract  ~/.claude/skills/
cp -r skills/memory-consolidate         ~/.claude/skills/

# 2. Create directories
mkdir -p docs/playbooks
```

Then add the bootstrap snippet below to your project's `CLAUDE.md`.

No API keys, no config, no dependencies. Skills read/write to Claude Code's built-in memory directory.

### Bootstrap: Add to your project CLAUDE.md

Add this snippet to your project's `CLAUDE.md` (or `.claude/CLAUDE.md`). It tells Claude that pattern files exist and should be consulted. Without it, Claude won't know to look.

```markdown
## Shadow Learning

This project uses shadow learning. Learned patterns and entity context are stored in the auto memory directory.

Before work that involves judgment (reviews, architecture, writing):
- Read `patterns/*.md` files in the memory directory for domain-specific rules
- Read `entities/*.md` files for context about people, services, or systems
- Read `docs/playbooks/*.md` in the project repo for repeatable procedures

When the user corrects you, note the correction explicitly — it will be extracted later.
```

Copy-paste this into your CLAUDE.md. Adjust or expand as patterns accumulate — but keep it short. Long instructions get ignored under load ([evidence](docs/plans/2026-03-09-shadow-learning-process-design.md)).

**Why this matters:** Without this snippet, Claude reads MEMORY.md (auto memory index) but doesn't know to proactively load pattern files before doing work. The snippet bridges that gap. It's intentionally minimal — the skills and pattern files do the heavy lifting.

**Why not more?** Research shows detailed instructions in AGENTS.md/CLAUDE.md have diminishing returns (SkillsBench: comprehensive = -2.9pp). A short pointer to the files works better than inlining all the rules.

### AGENTS.md: Cross-Tool Compatibility

The init script also creates an `AGENTS.md` — an [emerging standard](https://agents.md/) for guiding AI coding agents across tools. Unlike CLAUDE.md (Claude-specific), AGENTS.md is read by OpenAI Codex, Cursor, Kilo Code, Factory, and others. Empirical research shows AGENTS.md reduces agent runtime by ~29% and tokens by ~17% ([arXiv 2601.20404](https://arxiv.org/abs/2601.20404)).

**CLAUDE.md** holds Claude-specific features: shadow learning bootstrap, skills, hooks.
**AGENTS.md** holds universal context: playbook pointers, conventions, correction instructions.

Both files are short by design — [research shows](https://devcenter.upsun.com/posts/agents-md-less-is-more/) overly long instruction files degrade agent performance.

### Optional: Auto-extract on session end

```bash
./shadow-learn.sh install-hooks    # Linux / macOS
.\shadow-learn.ps1 install-hooks   # Windows
```

This wires a Claude Code hook that runs `/session-knowledge-extract` when a session ends — no need to remember to run it manually.

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

This curve repeats for every new domain — code reviews, PM workflows, writing, anything with repeatable judgment. Validated across 4 real-world reviews where corrections dropped from many → few → minimal.

**What "leads" means:** Claude makes judgment calls (tone, structure, what to flag, what to skip) based on accumulated patterns. You review output rather than directing each step.

---

## Playbooks: Capturing What You Do, Not Just What You Know

Patterns capture **rules** — "always X", "never Y", "prefer Z". But a lot of valuable knowledge lives in **procedures** — the steps you follow to deploy, debug, set up a new machine, cut a release, onboard a teammate, generate a weekly report.

These are called **playbooks** (also known as runbooks). They're not just for SRE or DevOps. Every team has operational procedures that live in someone's head:

- How to deploy to production (and what to check after)
- How to set up a dev machine from scratch
- How to create a sprint in GitLab and assign tasks
- How to generate the monthly client report
- Morning standup routine — what to check, in what order
- How to run a Makefile for a specific build target
- How to onboard a new team member

These procedures are invisible until someone leaves or is on vacation. Then everyone scrambles.

**Shadow learning captures playbooks the same way it captures patterns** — by watching you work. When you walk through a deploy with Claude, the extraction pipeline picks up the steps and routes them to `docs/playbooks/` in your project repo. Next time, Claude already knows the procedure.

Unlike patterns and entities (which live in Claude's memory directory), **playbooks live in your project repo** — committed to git, visible in code review, available to every teammate. They're project documentation, not personal memory.

### What makes a good playbook

A playbook is worth capturing when:
- You've done it **more than once** (or plan to)
- The steps **matter** — wrong order or missed step causes problems
- Someone else might need to do it when you're unavailable

A playbook is NOT worth capturing when:
- It's a one-off (unique debug session, one-time migration)
- It's trivial (a single command everyone knows)
- It changes every time (no stable core steps)

### Two sources of playbooks

Playbooks track their origin via frontmatter:

| Source | How it's created | Status | Trust level |
|---|---|---|---|
| `authored` | You explicitly ask: "write a playbook for deploy" | `reviewed` | Trusted immediately |
| `extracted` | Auto-captured from session narration | `draft` | Needs your review |

This matters because auto-extracted playbooks may have gaps or wrong ordering. The `status: draft` marker tells Claude (and teammates) to follow with caution until someone reviews and upgrades it to `reviewed`.

### How playbooks emerge

You don't need to sit down and write playbooks. They emerge naturally:

1. You do something operational with Claude — deploy, setup, debug
2. You narrate what you're doing (see habits below)
3. `/session-knowledge-extract` picks up the procedure and routes it to `docs/playbooks/`
4. `/memory-consolidate` merges similar procedures and cleans up
5. Next time you (or a teammate) needs to do it, Claude already knows the steps

The more you narrate, the faster playbooks accumulate. After a few weeks, you have an operational knowledge base that didn't require any dedicated documentation effort.

---

## How to Correct (this matters)

Your corrections are the training signal. Their quality determines how fast and accurately Claude learns.

### Good corrections (Claude learns from these)

| What you say | What Claude learns |
|---|---|
| "No, always do X" | A new rule |
| "Not X, do Y instead" | A preference |
| "This is too strict, relax it" | Calibration of existing pattern |
| "For Alex, do X differently" | Per-entity note (not a general rule) |

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
~/.claude/projects/<project>/memory/     # Claude's memory (personal)
├── MEMORY.md              # Index — always loaded (<200 lines)
├── patterns/              # Domain rules (<150 lines each)
│   ├── frontend.md        #   FSD, shadcn, import rules
│   └── code-review.md     #   Review style calibration
├── entities/              # Per-entity context
│   └── people.md          #   Teammates, clients...
└── extracted-knowledge.md # Staging area from /session-knowledge-extract

docs/playbooks/            # Project repo (committed to git)
├── deploy.md              #   Production deploy steps
└── new-hire-setup.md      #   Onboarding checklist
```

### What gets saved

Things **specific to your team/project** that Claude wouldn't know otherwise:
- "We use FSD architecture with barrel exports in each slice"
- "TDD is strict — test first, always, no exceptions"
- "Alex follows docs literally — tell him to compress, not cut"

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

### Do: Narrate operational tasks

When you're doing something operational — deploying, setting up, debugging, releasing — talk through the steps:

```
"First I check the CI pipeline is green. Then I merge to main.
 Then I SSH into prod and run deploy.sh. After that I check
 the health endpoint and tail the logs for 2 minutes."
```

This is how playbooks get created. If you do it silently, Claude sees tool calls but misses the procedure. If you narrate, the extraction pipeline captures the steps and builds a playbook automatically.

**Key insight:** Playbooks aren't just for DevOps. Any repeatable procedure — creating GitLab issues, generating reports, running a build, setting up a local environment — is worth narrating the first time you do it with Claude.

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

### Do: Use `@remember` or "Remember:" for important facts

When you want something captured, prefix it with a clear signal:

```
@remember We use PostgreSQL on port 15432, not the default 5432.
Remember: I always want tests to run against a real database, not mocks.
```

This isn't a built-in Claude Code command — it's a convention that `/session-knowledge-extract` looks for. Not guaranteed, but it's the strongest extraction signal available.

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

### Check health anytime

```bash
./shadow-learn.sh health    # Linux / macOS
.\shadow-learn.ps1 health   # Windows
```

Reports pattern/entity/playbook counts, line budget usage, extraction freshness, and bootstrap status.

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

## Watch for Sycophancy

As Claude learns your preferences via pattern and entity files, it may start agreeing with you more and pushing back less. Research shows condensed user profiles significantly increase LLM agreeableness (MIT, Feb 2025). This is the opposite of what shadow learning aims for — the goal is calibration, not validation. If Claude stops challenging you, the learning loop breaks.

**Watch for:** Claude agreeing too readily, not flagging questionable decisions, or echoing your preferences back as universal truths.

**Test periodically:** Make a deliberately wrong choice (bad architecture, skipped tests) and see if Claude flags it. If it doesn't, your patterns may be too preference-heavy.

**Mitigate:** Prefer factual and procedural entries in your patterns (port numbers, architecture decisions, tool choices, deploy steps) over opinion and preference entries (style, tone, formatting). Facts don't increase agreeableness; preferences do.

---

## Skills Included

### Learning Skills (have LEARN step, link to pattern files)

| Skill | Invoke | What it does |
|---|---|---|
| `thesis-review` | `/thesis-review [student]` | Academic review with correction loop ([example](examples/thesis-review/)) |

### Utility Skills (fire-and-forget)

| Skill | Invoke | What it does |
|---|---|---|
| `session-knowledge-extract` | `/session-knowledge-extract` | Daily extraction safety net (free) |
| `memory-consolidate` | `/memory-consolidate` | Weekly routing, pruning, review |

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
  ✅ "First I do X, then Y, then Z"           → Claude learns a playbook
  ✅ "@remember [fact]" / "Remember: [rule]"   → Strongest extraction signal
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

ANYTIME
  ./shadow-learn.sh health                    → Check if everything is working
```

---

## Troubleshooting

Run `./shadow-learn.sh health` first — it catches most issues automatically.

| Problem | Fix |
|---|---|
| No sessions found | Check slug: `ls ~/.claude/projects/ \| grep <keyword>` |
| Skills not appearing | Confirm: `~/.claude/skills/<name>/SKILL.md` must exist |
| MEMORY.md over 200 lines | Run `/memory-consolidate` to prune and rebalance |
| Pattern file over 150 lines | Run `/memory-consolidate` or manually prune |
| Memory feels noisy | Review files — remove general knowledge entries |
| Not sure if it's working | Run `./shadow-learn.sh health` to check status |
