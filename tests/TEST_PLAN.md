# Skill Testing Plan (RED-GREEN-REFACTOR)

Test each skill by running a subagent WITHOUT the skill (RED — baseline), then WITH the skill (GREEN — compliance), then fixing any gaps found (REFACTOR).

## Test Data

### Fixtures

```
tests/fixtures/
├── memory/                          # Synthetic memory directory for memory-consolidate
│   ├── MEMORY.md                    # Index with deliberate issues
│   ├── patterns/frontend.md         # 8 rules, 1 duplicate, 1 general-knowledge entry
│   ├── entities/people.md           # 2 people, 1 stale (Marina, 17 days ago)
│   └── extracted-knowledge.md       # 9 staged entries with destination tags
├── sessions/
│   ├── synthetic-frontend-session.jsonl   # 20 turns: 7 signal, 6 noise, 3 decisions, 4 general knowledge
│   └── real-thesis-review-session.jsonl   # Symlink to real session (47 user turns)
```

### Real data references

| Data | Path | Notes |
|---|---|---|
| Denis's thesis | `/home/newub/w/co/univer/Kursoviki/Denis/diplom_chapter1.pdf` | 274K PDF |
| Review patterns | `~/.claude/projects/-home-newub-w-claude-shadow-learn/memory/review-patterns.md` | 10.7K, 4 students |
| Student profiles | `~/.claude/projects/-home-newub-w-claude-shadow-learn/memory/students.md` | 5.9K |

---

## Test 1: session-knowledge-extract

**What we're testing:** Does it correctly classify signal vs noise, tag destinations, filter general knowledge?

### Expected outcomes from synthetic session

The synthetic session has 20 user turns. Correct classification:

| Turn | Expected | Type | Why |
|---|---|---|---|
| "hey, can you add a new button..." | REJECT | task instruction | Telling Claude what to do |
| "No, don't create a wrapper..." | KEEP | correction → rule | "Don't X. Instead Y." |
| "Always put API calls in features/*/api/..." | KEEP | rule | Imperative, project-specific |
| "ok looks good" | REJECT | approval | <20 chars |
| "yes" | REJECT | approval | <20 chars |
| "For forms, always use zod schemas..." | KEEP | rule | Imperative, project-specific |
| "Read `src/features/auth/ui/...`" | REJECT | task instruction | Session-specific file read |
| "We never use default exports..." | KEEP | rule | Imperative with reasoning |
| "Alex is now reviewing backend PRs..." | KEEP | entity update | "[Person] now does X" pattern (0.9) |
| "I prefer using pnpm workspace protocol..." | KEEP | preference | "I prefer X" |
| "Marina said she wants Mermaid diagrams..." | KEEP | entity update | "[Person] wants X" pattern (0.9) |
| "Let's go with the second option" | KEEP (resolve) | decision | Must resolve against list → "Tailwind with cn()" |
| "Use meaningful variable names" | REJECT | general knowledge | Fails "different senior dev" test |
| "Handle errors properly..." | REJECT | general knowledge | Generic |
| "Team standup moved to 10:30am..." | BORDERLINE | fact (0.8) | Team-specific but ephemeral; accepted miss |
| "commit and push" | REJECT | task instruction | Workflow command |

**Expected: 8 KEEP, 8 REJECT**

### RED (baseline)

Prompt for subagent (NO skill loaded):

```
Read the session file at tests/fixtures/sessions/synthetic-frontend-session.jsonl.
Extract any durable knowledge from the user's messages — things worth remembering
for future sessions. Write the results as a markdown list.
```

**What to watch for:** Does it keep general knowledge? Miss corrections? Fail to resolve "the second option"? Skip entity updates?

### GREEN (with skill)

Prompt for subagent (skill loaded):

```
/session-knowledge-extract

Use the session file at: tests/fixtures/sessions/synthetic-frontend-session.jsonl
Memory directory: tests/fixtures/memory/
```

**Success criteria:**
- [ ] 7-8 entries kept (not fewer, not many more)
- [ ] General knowledge entries ("meaningful variable names", "handle errors") filtered
- [ ] "Let's go with the second option" resolved to "Tailwind with cn() helper"
- [ ] Entries tagged with destinations (→ patterns/frontend.md, → entities/people.md)
- [ ] "different senior dev" test applied
- [ ] Task instructions rejected ("read this file", "commit and push")

---

## Test 2: memory-consolidate

**What we're testing:** Does it route staged entries, find duplicates, enforce budgets, present diff?

### Planted issues in fixtures

1. **Duplicate:** `patterns/frontend.md` has "Use shadcn/ui for all UI components" twice
2. **General knowledge:** "Use meaningful variable names" is in the pattern file
3. **Stale entity:** Marina's last interaction was 17 days ago (not >30, borderline)
4. **Staged entries:** 9 entries in extracted-knowledge.md with destination tags
5. **Unsorted entry:** "Team standup moved to 10:30am" — where does this go?

### RED (baseline)

Prompt for subagent (NO skill loaded):

```
Review the memory directory at tests/fixtures/memory/.
Read all files: MEMORY.md, patterns/frontend.md, entities/people.md, extracted-knowledge.md.
Clean up and organize the memory — remove duplicates, route staged entries,
fix any issues you find. Show me what you'd change.
```

**What to watch for:** Does it miss the duplicate? Route entries without asking? Skip the unsorted entry? Forget file size budgets?

### GREEN (with skill)

```
/memory-consolidate

Memory directory: tests/fixtures/memory/
```

**Success criteria:**
- [ ] Duplicate "Use shadcn/ui" caught and merged
- [ ] "Use meaningful variable names" removed (general knowledge)
- [ ] 3 entries from extracted-knowledge.md routed to patterns/frontend.md
- [ ] 2 entries routed to entities/people.md
- [ ] 3 entries marked as skip (general knowledge)
- [ ] 1 unsorted entry presented to user for decision
- [ ] File size budgets reported
- [ ] Diff shown, confirmation asked before writing
- [ ] MEMORY.md updated as index

---

## Test 3: thesis-review

**What we're testing:** Does it go section-by-section? Load patterns? Wait for corrections? Update knowledge?

### RED (baseline)

Prompt for subagent (NO skill loaded):

```
Review Denis Kalashnikov's bachelor thesis draft.
The submission is at: /home/newub/w/co/univer/Kursoviki/Denis/diplom_chapter1.pdf
He's writing about self-healing systems in microservices.
Write a review in Russian.
```

**What to watch for:**
- Does it dump the entire review at once? (violation: should go section-by-section)
- Does it skip loading pattern files? (violation: no calibration)
- Does it flag LLM usage as bad? (violation: tone rule)
- Does it use harsh language? (violation: first-time writer, early draft)
- Does it enumerate GOST rules? (violation: say "read GOST", don't list rules)

### GREEN (with skill)

```
/thesis-review Denis
```

**Success criteria:**
- [ ] Loads patterns/review-patterns.md and entities/students.md
- [ ] Goes section by section, waits for feedback after each
- [ ] Counts references [N] and reports immediately
- [ ] Uses «Вы» throughout
- [ ] Tone: "уточнить" not "переписать", "для первой итерации — нормально"
- [ ] LLM voice handled indirectly (asks for chapter overview, explicit criteria)
- [ ] Does NOT enumerate GOST formatting rules
- [ ] Produces review in correct format after all sections covered
- [ ] Updates students.md and patterns (LEARN step)

---

## Test 4: topic-research

### RED (baseline)

```
Research self-healing systems in microservice architectures.
Find at least 5 sources. Write a summary with citations.
```

### GREEN (with skill)

```
/topic-research self-healing systems in microservice architectures
```

**Success criteria:**
- [ ] Parallel web searches (not sequential)
- [ ] 5+ distinct sources with proper citations
- [ ] Source triangulation (cross-references)
- [ ] Written to a file (not just displayed)
- [ ] Academic + industry sources mixed

---

## Test 5: end-of-day-report / end-of-week-report

These depend on git history. Test in the current repo.

### RED (baseline)

```
Summarize what was done today based on git commits.
```

### GREEN (with skill)

```
/end-of-day-report
```

**Success criteria:**
- [ ] Reads git log for today
- [ ] Groups by area/theme
- [ ] Standup-ready format
- [ ] Enriches with docs/plans if available

---

## Running Tests

### Subagent approach

For RED tests, launch a subagent with the prompt above. Do NOT load the skill.
For GREEN tests, launch a subagent that invokes the skill.

Compare outputs side-by-side. Document:
1. What the baseline got wrong
2. What the skill fixed
3. What the skill still gets wrong (→ REFACTOR)

### Scoring

For session-knowledge-extract, score against the expected classification table:
- **Precision:** correct keeps / total keeps
- **Recall:** correct keeps / expected keeps
- **F1:** harmonic mean

Target: F1 > 0.8 for synthetic, F1 > 0.7 for real session.
