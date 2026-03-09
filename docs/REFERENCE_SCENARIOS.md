# Shadow Learning Reference Scenarios

**Date**: 2026-03-09
**Purpose**: Concrete scenarios for evaluating shadow learning with Claude Code's built-in memory
**Status**: Living document - update as understanding evolves

---

## Overview

These scenarios describe how shadow learning works in practice using Claude Code's native memory system (MEMORY.md, topic files, skills). Each scenario follows the same cycle: user works → Claude observes patterns → user corrects → knowledge updates → next session starts better.

Unlike Galatea (which has a dedicated runtime, KnowledgeEntry store, and pipeline), these scenarios use only what Claude Code provides: auto memory directory, skills, and CLAUDE.md.

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
