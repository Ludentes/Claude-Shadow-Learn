# Shadow Learning Reference Scenarios

**Date**: 2026-03-09
**Purpose**: Concrete scenarios for evaluating shadow learning with Claude Code's built-in memory
**Status**: Living document - update as understanding evolves

---

## Overview

These scenarios describe how shadow learning works in practice using Claude Code's native memory system (MEMORY.md, topic files, skills). Each scenario follows the same cycle: user works → Claude observes patterns → user corrects → knowledge updates → next session starts better.

Unlike Galatea (which has a dedicated runtime, KnowledgeEntry store, and pipeline), these scenarios use only what the agent tools provide: the in-repo knowledge store at `.agents/memory/`, skills, and `AGENTS.md`. They apply equally under Claude Code, Codex CLI, and Kimi Code.

---

## Scenario 1: Frontend Developer (React, shadcn/ui, FSD, pnpm)

### Context

- **User**: Mid-level frontend developer
- **Technology**: React 19, TypeScript, shadcn/ui, Feature-Sliced Design (FSD), pnpm, Vite
- **Infrastructure**: Self-hosted GitLab, CI/CD with GitLab runners
- **Goal**: Claude learns the user's component patterns, FSD conventions, and design system choices

---

### Phase 1: First Week — Observation

**Duration**: 5 working days
**Mode**: User works normally, Claude assists

```
Day 1: New Feature — Dashboard Page
├── User scaffolds FSD structure: app/ → pages/ → features/ → entities/ → shared/
├── Creates DashboardPage in pages/dashboard/
├── Pulls in shadcn/ui Card, Table, Badge components
├── User corrects Claude: "Don't put API calls in pages, they go in features"
├── User corrects Claude: "We use barrel exports in each FSD slice"
└── Commits with conventional commit: "feat(dashboard): add dashboard page skeleton"

Day 2: Shared UI Kit
├── User creates shared/ui/data-table — wraps shadcn Table with sorting/filtering
├── Refuses to use shadcn DataTable directly: "Too opinionated, we need our wrapper"
├── Shows pattern: shared/ui/* re-exports from index.ts, each component has its own dir
├── Corrects Claude on import paths: "@/shared/ui/data-table" not "@/components/ui/table"
└── Commits: "feat(ui): add DataTable wrapper over shadcn Table"

Day 3: Feature Implementation
├── Creates features/dashboard-analytics/ with model/, ui/, api/ subdirs
├── User: "Features own their API layer. Don't use a global api/ folder."
├── Shows pattern: useQuery hooks live in features/*/api/, not in a shared hooks dir
├── Zod schemas co-located with API hooks, not in a separate types/ dir
├── Test file next to component: widget.tsx + widget.test.tsx
└── Commits: "feat(analytics): add dashboard analytics feature"

Day 4-5: Continued development
├── More features, same patterns reinforced
├── User rejects Claude's suggestion to use React.memo: "Premature optimization"
├── User shows preference: CSS variables for theming, not Tailwind config overrides
└── User corrects import order: external → @/shared → @/entities → @/features → relative
```

### What Gets Captured (memory/frontend-patterns.md)

```markdown
# Frontend Patterns

## FSD Architecture
- Layers (top to bottom): app → pages → features → entities → shared
- Each slice has barrel export (index.ts)
- Import rule: layer can only import from layers below it
- API calls live in features/*/api/, never in pages
- Zod schemas co-located with API hooks in features/*/api/
- Tests co-located: component.tsx + component.test.tsx

## shadcn/ui Usage
- Always wrap shadcn primitives in shared/ui/* before using in features
- Each shared/ui component gets its own directory with index.ts export
- Import from shared/ui wrapper, never from @/components/ui directly
- Don't use shadcn DataTable — too opinionated, use our DataTable wrapper

## Code Style
- Import order: external → @/shared → @/entities → @/features → relative
- No React.memo unless profiler shows actual problem
- CSS variables for theming, not Tailwind config
- Conventional commits: feat/fix/chore(scope): message
- pnpm only — no npm or yarn

## Don't
- Don't put API calls in pages layer
- Don't create global api/ or hooks/ directories
- Don't import shadcn components directly in features
- Don't use React.memo preemptively
```

### Phase 2: Second Week — Claude Leads

**Session**: User asks Claude to implement a new feature.

```
User: "Add a user settings page. Profile info, notification preferences, theme toggle."

Claude retrieves: frontend-patterns.md
├── Creates pages/settings/ with route + layout
├── Creates features/profile-settings/ with model/ ui/ api/ subdirs
├── Creates features/notification-preferences/ (separate feature, not all-in-one)
├── Wraps shadcn Switch in shared/ui/toggle-switch/ (new wrapper)
├── API hooks in features/*/api/ with co-located Zod schemas
├── Tests next to components
├── Imports follow the order rule
└── Commits with conventional format

User corrections (fewer this time):
├── "Split notification-preferences into its own feature — good call"
├── "The toggle wrapper is unnecessary, Switch is simple enough to use directly"
└── "Add a shared/lib/theme.ts for the theme logic, not in the feature"
```

### What Gets Updated

```markdown
# Update to frontend-patterns.md

## shadcn/ui Usage (UPDATED)
- Wrap shadcn primitives in shared/ui/ WHEN they need project-specific behavior
- Simple components (Switch, Badge) can be used directly if no customization needed
- Rule of thumb: if you're just re-exporting with no changes, skip the wrapper

## FSD Architecture (ADDED)
- Cross-cutting concerns (theme, i18n) go in shared/lib/, not in features
```

### Learning Trace

```
Session 1: 5 corrections → 5 new patterns captured
Session 2: 2 corrections → 2 pattern refinements (wrapper rule, shared/lib)
Session 3: 0 corrections → patterns stable
```

---

### Shadow Learning Scenarios

#### SL-1.1: Correction Creates New Pattern

**Event**: Claude puts useQuery hook in pages/dashboard/api.ts

**User**: "Don't put API calls in pages, they go in features"

**What happens**:
1. Claude acknowledges correction in conversation
2. At session end (or via `/session-knowledge-extract`), pattern is captured
3. Written to `memory/frontend-patterns.md` under "FSD Architecture"
4. Next session: Claude reads patterns file, places API calls correctly

**Memory artifact**:
```markdown
## FSD Architecture
- API calls live in features/*/api/, never in pages
```

#### SL-1.2: Correction Refines Existing Pattern

**Event**: Claude wraps every shadcn component in shared/ui, including simple Switch

**User**: "The toggle wrapper is unnecessary, Switch is simple enough to use directly"

**Existing pattern**: "Always wrap shadcn primitives in shared/ui/* before using in features"

**What happens**:
1. Pattern was too strict — needs nuance
2. Update existing pattern instead of adding new one
3. Rule becomes conditional: wrap when customization is needed

**Before**:
```markdown
- Always wrap shadcn primitives in shared/ui/* before using in features
```

**After**:
```markdown
- Wrap shadcn primitives in shared/ui/ WHEN they need project-specific behavior
- Simple components (Switch, Badge) can be used directly if no customization needed
```

#### SL-1.3: Skill Emerges from Repeated Procedure

**Event**: After 4 features created following same structure, Claude recognizes the pattern is procedural.

**What happens**:
1. Claude (or user via `/session-knowledge-extract`) notices repeated procedure
2. Creates `skills/create-fsd-feature/SKILL.md`

**Skill content**:
```markdown
---
name: create-fsd-feature
description: "Scaffold a new FSD feature slice with standard structure"
---

# Create FSD Feature

## Arguments
Feature name (e.g., "dashboard-analytics")

## Steps
1. Create feature directory: `src/features/{name}/`
2. Create subdirectories: model/, ui/, api/
3. Create barrel export: index.ts
4. Create API hook in api/ with co-located Zod schema
5. Create main UI component in ui/
6. Create test file next to component
7. Export public API from index.ts (only what pages layer needs)
```

#### SL-1.4: One-Off vs Reusable Pattern

**Event**: User says "For this project, put the GraphQL codegen output in shared/api/generated/"

**Classification**: One-off (project-specific), not a general FSD rule.

**What happens**:
- Captured in project's CLAUDE.md, not in memory/frontend-patterns.md
- Won't transfer to other projects

---

## Scenario 2: Python Developer (uv, TDD, FastAPI)

### Context

- **User**: Backend developer
- **Technology**: Python 3.12+, uv, FastAPI, SQLAlchemy 2.0, Pydantic v2, pytest
- **Infrastructure**: Self-hosted GitLab, Docker, PostgreSQL
- **Goal**: Claude learns TDD workflow, API design patterns, and Python conventions

---

### Phase 1: First Week — Observation

```
Day 1: New Service Setup
├── User initializes with `uv init`, not pip or poetry
├── User: "Always uv. Never pip install directly."
├── Project structure: src/{package}/ with __init__.py, not flat
├── User creates conftest.py with fixtures BEFORE any code
├── User writes first test BEFORE first endpoint
└── Commits: "chore: initial project structure with uv"

Day 2: First Endpoint — TDD
├── User writes test: test_create_user_returns_201
├── Test uses httpx.AsyncClient, not requests
├── Test fails (no endpoint yet) — user says "Good, red first"
├── User implements POST /users — test passes
├── User writes 3 more tests: validation error, duplicate email, missing field
├── Only THEN adds edge case handling to the endpoint
├── User corrects Claude: "Don't add error handling I haven't tested for"
└── Commits: "feat(users): add create user endpoint with tests"

Day 3: Database Layer
├── User writes repository tests against real PostgreSQL (via testcontainers)
├── No mocks for DB — "If the query is wrong, I want to know"
├── SQLAlchemy models in models/, Pydantic schemas in schemas/ — separate
├── User shows pattern: repository returns domain objects, not ORM models
├── Dependency injection via FastAPI Depends, not global imports
└── Commits: "feat(users): add user repository with integration tests"

Day 4: Error Handling
├── User creates custom exception hierarchy: AppError → NotFoundError, ConflictError, etc.
├── Exception handlers registered in app factory, not scattered
├── User corrects Claude: "Don't catch generic Exception. Be specific."
├── User: "Pydantic validation errors → 422 automatically. Don't double-handle."
└── Commits: "feat(errors): add structured error handling"

Day 5: Authentication
├── User writes auth tests first: valid token, expired, missing, malformed
├── JWT with python-jose, not PyJWT
├── User corrects: "Don't put auth logic in the endpoint. Dependency injection."
├── Auth as a Depends() that returns current user or raises 401
└── Commits: "feat(auth): add JWT auth with dependency injection"
```

### What Gets Captured (memory/python-backend-patterns.md)

```markdown
# Python Backend Patterns

## Tooling
- Package manager: uv (never pip install directly)
- Test runner: pytest with pytest-asyncio
- HTTP testing: httpx.AsyncClient (not requests)
- DB testing: testcontainers (real PostgreSQL, no mocks for DB queries)

## TDD Workflow (STRICT)
1. Write failing test first — "red first"
2. Implement minimal code to pass
3. Write more tests for edge cases
4. Only then add error handling for tested scenarios
5. NEVER add error handling without a test that exercises it
6. NEVER write implementation before the test exists

## Project Structure
- src/{package}/ with proper __init__.py
- models/ — SQLAlchemy ORM models
- schemas/ — Pydantic v2 schemas (separate from models)
- repositories/ — data access, returns domain objects not ORM models
- routes/ or endpoints/ — FastAPI route handlers
- Dependencies: via FastAPI Depends(), not global imports

## FastAPI Patterns
- App factory pattern (create_app() function)
- Exception handlers registered centrally in app factory
- Auth as Depends() returning current user or raising 401
- Don't put business logic in endpoint functions — delegate to services/repos
- Pydantic handles 422 automatically — don't double-handle validation

## Error Handling
- Custom exception hierarchy: AppError base → specific subclasses
- Never catch generic Exception — be specific
- Exception handlers in app factory, not per-endpoint
- Let Pydantic validation errors flow through (422 automatic)

## Don't
- Don't mock the database — use testcontainers
- Don't add error handling without corresponding tests
- Don't put auth logic in endpoints — use dependency injection
- Don't use pip install — always uv
- Don't mix ORM models with Pydantic schemas
```

### Phase 2: Second Week — Claude Leads

```
User: "Add a task management feature. CRUD for tasks, assigned to users, with status transitions."

Claude retrieves: python-backend-patterns.md
├── Writes test_create_task_returns_201 FIRST
├── Uses httpx.AsyncClient
├── Creates Task model (SQLAlchemy) and TaskCreate/TaskResponse schemas (Pydantic) separately
├── Writes TaskRepository with testcontainers integration tests
├── Auth via Depends(get_current_user)
├── Status transitions as domain logic in service layer, not in endpoint
├── Custom InvalidTransitionError(AppError)
├── Tests for every error path before implementing handlers
└── Commits with conventional format

User corrections:
├── "Good — you wrote tests first without me having to remind you"
├── "Status transitions need their own test file, they're complex enough"
└── "Add a conftest.py fixture for creating a task with dependencies (user must exist)"
```

### Shadow Learning Scenarios

#### SL-2.1: TDD Violation Caught

**Event**: Claude writes a try/except for a database unique constraint violation without a corresponding test.

**User**: "Don't add error handling I haven't tested for"

**What happens**:
1. Claude removes the handler
2. User writes the test: `test_create_task_duplicate_title_returns_409`
3. Test fails (no handler)
4. NOW Claude adds the handler
5. Pattern reinforced in memory: "NEVER add error handling without a test"

**Key insight**: The pattern isn't "write tests" — it's "tests come FIRST, implementation follows." Order matters.

#### SL-2.2: Testing Strategy Refined

**Event**: Claude mocks the database for a repository test.

**User**: "No mocks for DB — if the query is wrong, I want to know"

**Classification**: Strong preference, borderline hard rule.

**Memory update**:
```markdown
## DB Testing
- Use testcontainers with real PostgreSQL
- No mocking database queries — integration tests catch real SQL issues
- Mocks acceptable for: external HTTP APIs, email sending, file storage
```

**Nuance captured later**: User mocks an HTTP call to Stripe in a payment test. Pattern becomes: "Real DB, mocked external services."

#### SL-2.3: Skill Emerges — New Endpoint

**After 5 endpoints follow identical TDD cycle**, Claude proposes a skill:

```markdown
---
name: add-fastapi-endpoint
description: "TDD workflow for adding a new FastAPI endpoint"
---

# Add FastAPI Endpoint (TDD)

## Arguments
Resource name (e.g., "tasks"), HTTP method, path

## Shadow Learning Cycle
This skill follows strict TDD. Corrections to test strategy update python-backend-patterns.md.

## Steps
1. Write the happy-path test in tests/test_{resource}.py
2. Run test — confirm it fails (red)
3. Implement minimal endpoint in routes/{resource}.py
4. Run test — confirm it passes (green)
5. Write edge case tests (validation, auth, not found, conflict)
6. Run tests — confirm they fail
7. Implement error handling for each failing test
8. Run all tests — confirm green
9. Create/update Pydantic schemas in schemas/{resource}.py
10. Create/update repository in repositories/{resource}.py with integration test
```

#### SL-2.4: Conflicting Correction

**Event**: User says "For this endpoint, skip the test — it's a health check, just return 200"

**Classification**: One-off exception, not a change to TDD rule.

**What happens**:
- NOT written to python-backend-patterns.md
- Noted in conversation only
- TDD rule stays strict for all other endpoints

---

## Scenario 3: Product Manager (Brief → IRD → Gate → Personas → Scenarios → Stories)

### Context

- **User**: Product manager, non-technical
- **Pipeline**: L0 Brief (CIRCLES) → L1 IRD (EARS) → GATE → L2 Personas → L3 Scenarios → L3.5 Mocks → L4 Conceptual Model → L5 Stories
- **Tools**: Claude Code for document generation, Miro/FigJam for visuals
- **Goal**: Claude learns the PM's decision-making style, quality bar, and stakeholder communication patterns

---

### Phase 1: First Project — User Leads

```
Project: Internal tool for customer support team

L0: Brief (CIRCLES)
├── User provides raw notes from customer interviews
├── Claude helps structure using CIRCLES framework
├── User corrects: "The problem statement is too solution-oriented. Back up."
├── User: "Appetite is 6 weeks — that's a decision, not an estimate"
├── User rejects Claude's attempt to scope features: "We're in problem space, not solution space"
├── Claude learns: problem ≠ solution, appetite ≠ estimate
└── Brief saved to docs/L0-brief.md

L1: IRD (EARS)
├── Claude generates requirements from brief
├── User corrects: "These aren't testable. Use EARS patterns explicitly."
├── User shows: "WHEN [trigger] the system SHALL [response]" format
├── User: "Group by user goal, not by system component"
├── User adds MoSCoW priorities: Must/Should/Could/Won't
├── User: "Out of Scope must be specific — 'limited admin' means nothing"
└── IRD saved to docs/L1-ird.md

GATE: GO / PIVOT / KILL
├── Claude presents evidence for/against
├── User: "You're being too optimistic. Where's the risk?"
├── User forces honest assessment: 2 of 4 assumptions are unvalidated
├── Decision: GO, but with explicit conditions to re-evaluate at L3
├── User: "Always document WHY we decided GO — future us needs this"
└── Gate decision saved to docs/GATE-decision.md

L2: Personas
├── Claude creates 4 personas
├── User: "Too many. Merge the two support agents — they have identical goals"
├── User: "Persona goals must be behavioral, not demographic"
├── User: "Mark everything as [ASSUMPTION] unless we have interview data"
├── Final: 2 personas with clear behavioral goals
└── Personas saved to docs/L2-personas.md

L3: Scenarios
├── Claude maps journeys per persona
├── User: "Touchpoints must be specific — 'uses app' is not a touchpoint"
├── User adds pain scores (1-5) and identifies intervention points
├── User: "Always include at least one failure scenario per persona"
├── User: "This scenario should reference the persona by name, not 'the user'"
└── Scenarios saved to docs/L3-scenarios.md

L3.5: Mocks
├── Claude sketches key screens based on high-pain scenario steps
├── User: "Only mock screens for pain scores 4-5. Don't mock everything."
├── User: "3-5 screens max. More means scope is too large."
└── Mocks saved to docs/L3.5-mocks.md

L4: Conceptual Model
├── Claude extracts entities from scenarios
├── User: "This is not a database schema. No IDs, no foreign keys."
├── User: "Every entity must trace back to a scenario. No orphans."
├── User: "Resolve synonyms — we can't have 'ticket' and 'case' meaning the same thing"
├── User: "Invariants are the most important part — what must ALWAYS be true?"
└── Model saved to docs/L4-conceptual-model.md

L5: Stories
├── Claude creates story map from scenarios
├── User: "Walking skeleton first — thinnest path a real user could use"
├── User: "Never 'As a user' — always 'As [persona name]'"
├── User: "Acceptance criteria in Given/When/Then. If you can't test it, rewrite it."
├── User: "Every story must trace to a persona + scenario step. No floating stories."
├── Final: 12 stories, walking skeleton identified (3 stories), rest prioritized
└── Stories saved to docs/L5-stories.md
```

### What Gets Captured (memory/pm-patterns.md)

```markdown
# PM Pipeline Patterns

## Pipeline Structure
- L0 Brief → L1 IRD → GATE → L2 Personas → L3 Scenarios → L3.5 Mocks → L4 Conceptual Model → L5 Stories
- Each step builds on all previous outputs
- Never skip the GATE — it prevents wasted effort
- Mocks (L3.5) are optional — skip if no UI or if handing to design team

## L0 Brief
- Use CIRCLES framework for problem comprehension
- Problem space ≠ solution space — stay in problem space during L0
- Appetite is a TIME BUDGET (decision), not an estimate (guess)
- Don't scope features during brief — that's L1's job
- Raw interview notes/emails go in as input, structured brief comes out

## L1 IRD
- Every functional requirement uses EARS syntax explicitly: WHEN/WHILE/IF/SHALL
- Group by user goal, not system component
- MoSCoW priorities on every requirement
- "Out of Scope" must be specific: "no admin dashboard" not "limited admin"
- Non-functional requirements need measurable thresholds

## GATE
- Force honest risk assessment — reject optimistic-by-default
- Document WHY the decision was made (future reference)
- List unvalidated assumptions explicitly
- GO can have conditions: "re-evaluate at L3 if assumption X fails"
- KILL is a valid and valuable outcome — document it

## L2 Personas
- 2-3 max (not more — if you have 4+, merge)
- Goals are behavioral ("needs to track weekly expenses") not demographic ("35-year-old")
- Frustrations describe current workarounds, not absent features
- Mark [ASSUMPTION] vs [VALIDATED] on every attribute
- Name personas — never "the user"

## L3 Scenarios
- At least one scenario per persona
- Touchpoints must be specific ("taps notification in mobile app" not "uses app")
- Pain scores (1-5) on every step — intervention points are 4-5
- At least one failure/edge case scenario per persona
- Reference personas by name

## L3.5 Mocks
- Only for pain score 4-5 steps
- 3-5 screens max — more means scope creep
- Fat-marker level — not pixel-perfect

## L4 Conceptual Model
- NOT a database schema — no IDs, no foreign keys, no data types
- Every entity traces to a scenario (no orphans)
- Resolve synonyms (one term per concept)
- Relationships in plain English
- Invariants are the most important deliverable

## L5 Stories
- "As [persona name], I want... so that..." — never "As a user"
- Walking skeleton first — thinnest viable path
- Acceptance criteria in Given/When/Then (testable)
- Every story traces to persona + scenario step
- No story larger than one sprint

## Tone & Communication
- Push back on solution-oriented thinking during problem space (L0-GATE)
- Be honest about risks — don't sugarcoat
- Document decisions, not just outcomes
- Quality checks at each step before advancing
```

### Phase 2: Second Project — Claude Leads

```
User: "New project: employee onboarding portal. Here are the stakeholder interview notes."

Claude retrieves: pm-patterns.md
├── Starts with CIRCLES framework unprompted
├── Asks user for appetite before scoping
├── Stays in problem space, doesn't propose solutions
├── Generates IRD with EARS syntax, grouped by user goal
├── Forces honest GATE with explicit risk list
├── Creates 2 personas (not 4), behavioral goals, all marked [ASSUMPTION]
├── Scenarios with pain scores, specific touchpoints, failure paths
├── Conceptual model with invariants, no IDs, traced to scenarios
├── Stories with persona names, Given/When/Then, walking skeleton identified
└── Each step saved as docs/L{N}-{name}.md

User corrections (fewer):
├── "Good — you stayed in problem space during L0. Last time I had to correct that."
├── "GATE is too short — add a 'what would make us KILL this' section"
└── "Walking skeleton should include the onboarding checklist — it's the core value"
```

### Shadow Learning Scenarios

#### SL-3.1: Problem vs Solution Drift

**Event**: During L0, Claude suggests "We could use a wizard-style onboarding flow"

**User**: "We're in problem space, not solution space"

**Pattern already exists**: Claude should have caught this from memory.

**What happens**:
1. Pattern was in memory but Claude didn't apply it strongly enough
2. Reinforcement: add to "Don't" section: "Don't suggest solutions during L0 or GATE"
3. This is a **calibration**, not a new pattern

#### SL-3.2: GATE Improvement

**Event**: User says "Add a 'what would make us KILL this' section to GATE"

**Classification**: New pattern — improves GATE template.

**Memory update**:
```markdown
## GATE (UPDATED)
- Include explicit "KILL criteria" — what evidence would make us abandon this
- Forces team to define their own red lines upfront
```

#### SL-3.3: Stakeholder Communication Pattern

**Event**: User asks Claude to write a status update for executives.

**User**: "Executives don't care about EARS or personas. Lead with business impact, then timeline, then risk. One page."

**New pattern captured**:
```markdown
## Stakeholder Updates
- Executives: business impact → timeline → risk. One page max.
- Engineering leads: technical brief with architecture decisions
- Dev team: sprint-ready story backlog with acceptance criteria
- Tailor depth to audience — never send the full pipeline output upstream
```

#### SL-3.4: Skill Emerges — PM Pipeline

**After 2 projects**, the full pipeline procedure is stable enough for a skill:

```markdown
---
name: pm-pipeline
description: "Shadow learning skill for PM pipeline. Loads PM patterns, runs L0-L5, absorbs corrections, updates knowledge."
---

# PM Pipeline (Shadow Learning Skill)

## Shadow Learning Cycle
load pm-patterns.md → apply to new project → get corrected → update patterns → next project starts better

## Arguments
Project name or brief description

## Steps
1. Load memory/pm-patterns.md
2. Run L0 (CIRCLES) — present brief, ask for corrections
3. Run L1 (EARS) — present IRD, ask for corrections
4. Run GATE — force honest assessment, ask for corrections
5. Run L2-L5 section by section
6. After each level: "What do you think? Anything to correct?"
7. Classify corrections: new pattern / calibration / one-off
8. Produce final documents
9. Update pm-patterns.md with learnings
10. Report: "From this project I [learned X / updated Y / no new patterns]"
```

---

## Scenario 4: Long-Horizon Research / Investigation

### Context

- **User**: ML engineer (but the pattern applies to any long-running investigation — security audit, vendor evaluation, performance hunt, debugging a flaky production system over weeks)
- **Project**: Choosing an embedding + retrieval strategy for a new semantic search feature. Three months of spikes, ablations, vendor comparisons, and one painful pivot.
- **Goal**: Claude learns not just *what we decided* but *how to maintain its own memory* across a horizon longer than its context window. The user is more capable than Claude here because they remember March in May. The lesson is meta: copy that ability.

This scenario is shaped differently from the first three. There, the human demonstrated **technique** (FSD, TDD, PM pipeline). Here, the human demonstrates **how to survive context loss** — and the patterns Claude captures include rules about its own memory hygiene.

---

### Phase 1: First Four Weeks — User Leads the Memory Discipline

**Duration**: 4 weeks
**Mode**: User runs the investigation. Claude assists with experiments and writeups. Most corrections are about how to *record*, not what to *do*.

```
Week 1: Hypothesis & Baseline
├── User opens a new thread: "Can we drop our reranker if we switch to bge-m3?"
├── Creates docs/research/2026-03-02-bge-m3-baseline.md with frontmatter:
│   ├── status: live
│   ├── topic: embedding-strategy
│   ├── last_verified: 2026-03-02
│   └── area: retrieval
├── Creates docs/research/_topics/embedding-strategy.md — the topic index
├── Adds MEMORY.md entry: "🧭 embedding-strategy — exploring bge-m3 vs current stack"
├── User corrects Claude: "Don't summarize the doc into MEMORY.md. One line, link out."
├── User runs the baseline eval, Claude helps with the harness
├── Result: bge-m3 alone underperforms current stack by 4pp nDCG@10
└── Commit: "research: bge-m3 baseline, underperforms current"

Week 2: First Pivot Attempt
├── User: "What if we add query expansion before bge-m3?"
├── Claude proposes deleting last week's doc since the conclusion changed
├── User: "No. Append-only. Mark it superseded, write a new dated doc."
├── User shows the discipline:
│   ├── Old doc gets superseded_by: 2026-03-09-query-expansion-bge-m3.md
│   ├── New doc gets supersedes: 2026-03-02-bge-m3-baseline.md
│   ├── Topic file updated to "current belief: query expansion + bge-m3 might close the gap"
│   └── MEMORY.md entry unchanged — still one line, pointing at the topic
├── Query expansion + bge-m3 ties the baseline. Not a win.
└── Commit: "research: query expansion + bge-m3 ties baseline"

Week 3: Falsification
├── User: "Add a learned-sparse model (SPLADE) as a hybrid component"
├── Five days of experiments, three dated docs
├── Result: SPLADE + bge-m3 loses to current stack on the long-tail queries
├── User writes the falsification doc explicitly:
│   ├── docs/research/2026-03-23-splade-hybrid-falsified.md
│   ├── status: live (the verdict is live, even though the approach is dead)
│   ├── Body explains *why* it failed with the data that killed it
│   └── Concludes with the pivot: "rerankers are doing more than we credited them for"
├── User updates MEMORY.md:
│   ├── Adds: "🛑 splade-hybrid — falsified 2026-03-23, rerankers irreplaceable on long-tail"
│   └── Updates: "🧭 embedding-strategy — pivoting to reranker improvement"
├── User: "Three weeks from now I will forget why we walked away. The dead-end note is the point."
├── Claude proposes archiving the falsified doc. User: "No. It stays in research/, status:live, indexed."
└── Commit: "research: SPLADE hybrid falsified, pivoting to reranker work"

Week 4: New Direction — Reranker Quality
├── User opens a sub-thread: improve the reranker rather than replace it
├── Creates docs/research/_topics/reranker-tuning.md
├── User cross-links: "see falsification at 2026-03-23 for why we're here"
├── Three dated docs across the week: distillation experiments
├── User catches Claude quoting an out-of-date baseline number from week 1:
│   ├── "That baseline was on the old holdout split. Re-quote against current."
│   ├── Pattern: never quote a baseline from its own log — re-eval on current holdout
│   └── New rule added to patterns/research-discipline.md
└── Commit: "research: distillation experiments, baseline re-verified"
```

### What Gets Captured (memory/patterns/research-discipline.md)

```markdown
# Long-Horizon Research Discipline

## The Three-Layer Document Model
- Dated evidence (docs/research/YYYY-MM-DD-*.md) — append-only, never edited substantively after settling
- Topic indexes (docs/research/_topics/*.md) — mutable interpretation, "what we currently believe"
- MEMORY.md — one-line triage with status icon + slug, points to topic file
- Each layer rots at a different rate. Mixing them creates churn on stable docs or stale claims in the live index.

## Frontmatter Trust Signals
Every research/blog doc carries:
- status: live | superseded | archived
- topic: <topic-file-slug>
- last_verified: ISO date — human signature on "still true"
- supersedes: / superseded_by: when applicable
- verified_against (architecture docs): repo + commit + paths

## Append-Only Discipline
- Never overwrite a dated doc to fix its conclusion
- A superseded conclusion gets a new dated doc + supersedes/superseded_by pointers
- Old doc stays in place — the audit trail is what lets future-us answer "why did we believe X in March?"

## Falsification as a First-Class Outcome
- When a hypothesis dies, write a dated doc that says explicitly why, with the data
- MEMORY.md gets a 🛑 FALSIFIED entry naming the doc and pointing at the replacement approach
- Never delete the falsified doc. It prevents re-exploring in three weeks.
- A topic file may pivot; falsified branches stay searchable in one hop from MEMORY.md.

## MEMORY.md Status Icons
- 🧭 ACTIVE THREAD — currently working
- 🛑 FALSIFIED — explored, ruled out, do not re-propose
- 🚢 SHIPPED — landed in production, runbook exists
- 📚 RESEARCH — completed investigation, conclusions live in topic file
- 🆕 RULE — new project rule, applies going forward
- Status icon signals load-bearing-ness at a glance. Triage tool, not knowledge store.

## Read-Order on a Fresh Session
1. MEMORY.md — scan for the thread's status icon and slug
2. The linked topic file — current beliefs
3. The most recent dated doc(s) referenced by the topic file — load-bearing detail
4. The runbook, if a shipped artifact is involved
5. git log --oneline -20 on the relevant subtree — catches anything since the topic file was last touched
6. ONLY THEN read code

Reading code before the topic file is how you re-propose approaches that were ruled out months ago.

## Compaction-Safe Writing
- Information that is not on disk does not exist. Save findings the moment they are produced, not "when the session ends."
- Intermediates must fully reconstruct decision-relevant state: configs at top of every result dir, eval logs tied to a holdout fingerprint
- Generation is resumable: skip-if-exists per output, append new plan cells rather than killing the run

## Verification Discipline
- Never quote a baseline from its own log — re-eval on current holdout
- A metric is only as good as the question it can distinguish — symmetries hide failure modes
- "Tests pass" without showing the green output is not evidence, it is a wish

## Two-Strikes Refactoring
- Don't backfill frontmatter or runbooks mechanically across the corpus
- When a doc is substantively touched without frontmatter, add it then — the doc has earned the attention
- Lazy/just-in-time. Each artifact earns the work when touched.

## Feedback: Save the Why AND the Confirmation
- Every correction memory carries: Rule / Why / How to apply
- Save confirmations of non-obvious choices too — not just corrections
- Saving only "don't do X" makes future-us progressively more timid; validated choices need explicit recording

## Don't
- Don't summarize a dated doc into MEMORY.md — one-line pointer only
- Don't delete falsified docs — they prevent re-exploration
- Don't quote a recalled function/flag/file name without re-checking it exists now
- Don't propose approaches without reading the topic file first
```

### Phase 2: Weeks 5-8 — Claude Maintains Memory Under Supervision

**Mode**: Claude takes over the mechanical discipline (frontmatter, MEMORY.md updates, supersedes pointers). User runs experiments and catches drift.

```
Week 5: New Spike — Cross-Encoder Distillation
├── Claude (unprompted) creates docs/research/2026-03-30-cross-encoder-distill.md
│   ├── Frontmatter populated correctly: status, topic, last_verified, area
│   └── Adds MEMORY.md pointer with 🧭 ACTIVE THREAD icon
├── User: "Good. Last time I had to write that scaffold for you."
├── Claude runs distillation, writes intermediate parquet of eval results
├── At session end, Claude updates topic file with new dated-doc reference
└── User spot-checks. No corrections.

Week 6: Stale Claim Caught
├── User asks "What was our best nDCG@10 last month?"
├── Claude quotes 0.612 from the 2026-03-23 falsification doc
├── User: "Check the topic file. The holdout was re-cut on 2026-03-28."
├── Claude re-reads the topic file — finds the holdout-change note
├── Claude re-evaluates: actual number under new holdout is 0.587
├── User: "This is exactly the trap. The doc said 'true on 2026-03-23'. It's now May."
├── Update to research-discipline.md:
│   ├── "Before quoting a number from a dated doc, check last_verified vs current holdout/config fingerprint"
│   └── Captured as a rule, not a one-off
└── No commit — discipline correction

Week 7: Re-Proposed Dead Approach (Read-Order Violation)
├── Claude, fresh session, asked "should we try learned sparse retrieval?"
├── Without checking MEMORY.md first, Claude proposes SPLADE hybrid
├── User: "We falsified that in March. Did you read MEMORY.md?"
├── Claude acknowledges, reads MEMORY.md, finds 🛑 splade-hybrid entry
├── Reads the falsification doc, summarizes why it died
├── User: "Now you remember. Next time, read first."
├── This is a calibration of an existing rule, not a new pattern
├── research-discipline.md "Read-Order" section gets a worked example appended
└── Claude proposes an *adjacent but distinct* approach instead

Week 8: Confirmation Saved
├── User decides to ship the distilled cross-encoder rather than chase one more pp
├── User: "Ship at +2.3pp. We could chase more but the data says diminishing returns."
├── Claude saves this as a confirmation memory:
│   ├── Rule: "Ship when curve flattens; don't chase the last pp"
│   ├── Why: "Three months in, opportunity cost > marginal gain. Validated by our own ablation curve."
│   └── How to apply: when an investigation's gains-per-week halve twice in a row, propose shipping
├── User: "Good. If you'd only saved corrections, future-you would over-iterate."
└── Commit: "research: ship-or-iterate heuristic captured"
```

### Phase 3: Weeks 9-12 — Claude Leads, User Spot-Checks

**Mode**: Claude maintains the research log, falsification index, and topic files independently. The shipped artifact gets a runbook.

```
Week 9-10: Productionization
├── Distilled cross-encoder rolls to staging
├── Claude writes docs/runbooks/semantic-search.md with frontmatter:
│   ├── status: current
│   ├── last_verified: 2026-05-04
│   ├── verified_against: repo + commit + paths
│   └── Pipeline diagram, CLI, failure modes, on-disk layout
├── Updates MEMORY.md: 🚢 semantic-search SHIPPED → docs/runbooks/semantic-search.md
├── Updates embedding-strategy topic file: status flips from "actively exploring" to "shipped, see runbook"
└── User reviews runbook. One correction: "Add the holdout fingerprint to verified_against — we'll need it for re-evals."

Week 11: A/B Result Triggers Re-Verification
├── A/B test result comes back: +1.8pp business metric, p<0.05
├── Claude (unprompted) appends an A/B section to the runbook
├── Updates last_verified
├── Creates docs/research/2026-05-18-semantic-search-ab.md as the dated evidence
├── User: no corrections. Discipline is stable.
└── Commit: "research: semantic search A/B confirms ship"

Week 12: Cross-Thread Reference From a New Project
├── New thread opens on a different feature: "Can we reuse the distilled cross-encoder for X?"
├── Claude (fresh session) reads MEMORY.md first
├── Finds 🚢 semantic-search → runbook
├── Reads the runbook, then the most recent dated docs on the embedding-strategy topic
├── Notes the holdout fingerprint and the diminishing-returns confirmation
├── Proposes reuse with appropriate caveats from the prior investigation
└── User: "This is what good memory looks like. You wouldn't have done this in March."
```

### Shadow Learning Scenarios

#### SL-4.1: Falsification Discipline

**Event**: A hypothesis dies. Claude proposes deleting the dated doc since "the conclusion changed."

**User**: "No. Append-only. Mark it superseded, write a new dated doc. And add a 🛑 entry to MEMORY.md."

**What happens**:
1. The original doc keeps `status: live` if the *verdict* is still load-bearing (we now know this *doesn't* work — that's the live finding)
2. Or `status: superseded` with `superseded_by:` if a newer investigation reframes the question
3. MEMORY.md gets a 🛑 FALSIFIED entry pointing at the doc and at the replacement approach
4. Pattern captured: "Never delete falsified docs. They prevent re-exploration."

**Why this matters**: Without the falsification trail, week 7's "should we try SPLADE?" question gets answered by re-running the experiment. With it, the answer is one hop from MEMORY.md and takes 90 seconds.

#### SL-4.2: Read-Order Violation

**Event**: Claude, fresh session, proposes an approach that was ruled out two months ago. The patterns file exists. Claude didn't read it.

**User**: "Did you read MEMORY.md?"

**Classification**: Not a new pattern — a calibration of an existing one that wasn't being applied strongly enough.

**What happens**:
1. The Read-Order section in research-discipline.md was correct but treated as advisory
2. Calibration: append a worked example showing the cost of skipping it
3. Add a procedural step to any research-related skill: "FIRST read MEMORY.md and find the thread's topic file. Confirm the proposed approach is not in a 🛑 entry. Only then propose."
4. The pattern moves from advisory to gated

**Key insight**: A pattern Claude *has* but doesn't *apply* is functionally absent. Calibration through worked examples is how advisory rules become gated rules.

#### SL-4.3: Stale-Claim Catch via `last_verified`

**Event**: Claude quotes a number from a dated doc. The number was true on that date but the holdout was re-cut since.

**User**: "Check the topic file. The holdout was re-cut on 2026-03-28."

**Pattern captured**:
```markdown
## Quoting Numbers from Dated Docs
- Before quoting a metric from a dated doc, check last_verified against the current holdout/config fingerprint
- If the fingerprint changed, the number is stale — re-evaluate or qualify the citation
- A dated doc records what was true on that date, not now
```

**Why this matters**: This is the trap vamp's `feedback_calibration_blind_spots` warns about. Frontmatter (`last_verified`) makes the staleness check mechanical instead of vibes-based.

#### SL-4.4: Save the Confirmation, Not Just the Correction

**Event**: User makes a non-obvious call (ship at +2.3pp rather than iterate). Claude initially doesn't save anything because no correction was given.

**User**: "Save this. If you only ever save my corrections, you'll get more timid over time."

**What happens**:
1. Memory entry written with Rule / Why / How to apply
2. The *why* is what makes it portable to future ship-or-iterate decisions
3. Anti-sycophancy: confirmation memory keeps Claude calibrated rather than over-cautious

**Why this matters**: Saving only "don't do X" produces an agent that defaults to inaction. Validated calls need explicit recording too, with their reasoning.

#### SL-4.5: Skill Emerges — `start-research-thread`

**After three independent threads** (embedding strategy, reranker tuning, semantic-search A/B), the open-a-research-thread procedure is stable enough for a skill:

```markdown
---
name: start-research-thread
description: "Open a new long-horizon research thread with the three-layer doc model. Creates topic file, first dated doc, and MEMORY.md pointer with correct frontmatter."
---

# Start Research Thread

## Arguments
Thread name (kebab-case, e.g., "embedding-strategy")
Hypothesis or question (one sentence)

## Steps
1. Read MEMORY.md and patterns/research-discipline.md
2. Confirm the thread name isn't already a 🛑 FALSIFIED entry — if it is, refuse and explain
3. Create docs/research/_topics/{thread-name}.md with skeleton:
   - Current belief: "<the hypothesis>"
   - Dated docs: (empty list, will grow)
   - Status: open
4. Create docs/research/{today-ISO}-{thread-name}-initial.md with frontmatter:
   - status: live
   - topic: {thread-name}
   - last_verified: {today}
   - area: <inferred or asked>
5. Add MEMORY.md entry: "🧭 {thread-name} — <one-sentence hook>"
6. Stop. Do not begin the investigation — the user runs the experiments. Your job was the scaffold.

## Shadow Learning Cycle
When a thread closes (shipped or falsified), update patterns/research-discipline.md if the closing taught a new rule about discipline itself.
```

#### SL-4.6: Cross-Thread Reuse

**Event**: A new feature might benefit from the distilled cross-encoder. Fresh Claude session.

**Without the discipline**: Claude proposes building it from scratch, or asks the user "did we ever do anything like this?"

**With the discipline**: Claude reads MEMORY.md → finds 🚢 semantic-search → reads the runbook → finds the diminishing-returns confirmation → proposes reuse *with the caveats from the prior investigation*.

**No new pattern needed**. This is the system working as designed. Worth recording in the patterns file as a positive worked example, because Phase 1-2 had the negative ones.

---

### Why This Scenario Is Shaped Differently

The first three scenarios teach Claude **technique** by watching a more skilled practitioner. Scenario 4 teaches Claude **memory hygiene** by watching someone who has survived six months of context loss.

The pragmatic lesson — and the one that gives shadow-learn its real edge — is that the human's advantage isn't taste or experience. It's that **they wrote things down**, **they kept the writeups dated and append-only**, and **they put trust signals on every doc**. None of this requires a runtime. All of it requires discipline.

The closing table in this document (below) lists capabilities like "confidence scores," "evidence linking," and "automatic decay" as things Claude Code memory cannot do. Half of that is wrong now. With frontmatter (`last_verified`, `verified_against`, `superseded_by`, status icons in MEMORY.md), markdown files carry trust signals and decay markers natively. You don't need a runtime; you need conventions a Claude session can apply mechanically.

---

## Cross-Scenario Patterns

### How Knowledge Flows

```
Session N                          Memory                         Session N+1
┌──────────┐                  ┌──────────────┐                 ┌──────────┐
│ User      │  corrections    │ topic-file.md│   loaded at     │ Claude   │
│ corrects  │ ───────────────→│ (patterns)   │ ──────────────→ │ applies  │
│ Claude    │                 │              │   session start  │ patterns │
└──────────┘                  │ MEMORY.md    │                 └──────────┘
                              │ (index)      │
                              │              │
                              │ SKILL.md     │
                              │ (procedure)  │
                              └──────────────┘
```

### Knowledge Types and Where They Live

| Type | Example | Storage | Transfers? |
|------|---------|---------|------------|
| **Pattern** | "API calls in features/, not pages/" | memory/topic-file.md | Yes — across projects in same domain |
| **Procedure** | "TDD: test first, implement second" | skills/*/SKILL.md | Yes — skill is portable |
| **Hard rule** | "Always uv, never pip" | CLAUDE.md or memory/ | Yes — global or per-project |
| **Preference** | "Conventional commits" | CLAUDE.md | Yes — global |
| **One-off** | "GraphQL codegen in shared/api/generated/" | Project CLAUDE.md only | No — project-specific |
| **Calibration** | "Wrap shadcn only when customizing" | Updates existing pattern | Yes — refines existing knowledge |

### The Learning Curve

Every scenario follows the same decay curve for corrections:

```
Corrections
per session
    │
  5 │ ██
    │ ██
  4 │ ██
    │ ██
  3 │ ██  ██
    │ ██  ██
  2 │ ██  ██  ██
    │ ██  ██  ██
  1 │ ██  ██  ██  ██
    │ ██  ██  ██  ██  ░░
  0 │─██──██──██──██──░░──
    └──1───2───3───4───5── Session
```

Validated from thesis review scenario: Mikhail (user-led) → Sophiya (many corrections) → Anna (few) → Denis (minimal).

### Safety Nets

| Tool | When | What it catches |
|------|------|----------------|
| `/session-knowledge-extract` | End of session | Patterns Claude didn't write to memory during work |
| `/memory-consolidate` | Weekly | Duplicates, stale patterns, bloated files |
| Skills with LEARN step | During work | Forces knowledge update as part of procedure |
| CLAUDE.md preferences | Always loaded | Hard rules that must never be violated |

### What This System Cannot Do (Galatea Can)

| Capability | Claude Code Memory | Galatea |
|------------|-------------------|---------|
| Confidence scores on knowledge | No — everything is equally weighted | Yes — KnowledgeEntry.confidence |
| Evidence linking | No — free text | Yes — evidence array with source refs |
| Automatic decay/expiry | No — manual cleanup | Yes — temporal validity, superseded_by |
| Cross-agent knowledge sharing | No — per-user memory | Yes — persona export/import |
| Structured entity tracking | No — free text mentions | Yes — entities array, about field |
| Pipeline automation | Manual (user runs skills) | Automated (transcript → store) |

The gap is acceptable for single-user workflows. These scenarios prove that markdown artifacts + skills + the correction loop produce effective learning without a dedicated runtime.
