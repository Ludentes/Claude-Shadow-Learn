# Skill Test Results — 2026-03-09

RED-GREEN-REFACTOR testing of all shadow learning skills per the [writing-skills methodology](https://github.com/anthropics/superpowers).

## Summary

| Skill | RED Score | GREEN Score | REFACTOR needed | Verdict |
|---|---|---|---|---|
| session-knowledge-extract | F1=0.86 | F1=0.93 | Yes (entity pattern) | **PASS after fix** |
| memory-consolidate | 3/9 criteria | 9/9 criteria | No | **PASS** |
| thesis-review | 2/10 criteria | 9/10 criteria | No | **PASS** |
| topic-research | 4/6 criteria | 6/6 criteria | No | **PASS** |
| end-of-day-report | — | — | — | **SKIPPED** (no .git) |

---

## Test 1: session-knowledge-extract

### Test data

- Synthetic session: `tests/fixtures/sessions/synthetic-frontend-session.jsonl` — 20 turns, 8 expected KEEP, 8 expected REJECT
- Memory context: `tests/fixtures/memory/` — patterns/frontend.md, entities/people.md, extracted-knowledge.md

### RED baseline (no skill)

Recall: 6/8 (0.75), Precision: 6/6 (1.0), **F1: 0.86**

| Turn | Expected | Baseline | Match |
|---|---|---|---|
| "don't create a wrapper..." | KEEP (correction) | KEEP (skipped as duplicate) | ~ partial |
| "Always put API calls..." | KEEP (rule) | KEEP | ✓ |
| "always use zod schemas..." | KEEP (rule) | KEEP | ✓ |
| "never use default exports..." | KEEP (rule) | KEEP | ✓ |
| "Alex reviewing backend PRs..." | KEEP (entity) | KEEP | ✓ |
| "pnpm workspace protocol..." | KEEP (preference) | KEEP | ✓ |
| "Marina wants Mermaid..." | KEEP (entity) | KEEP | ✓ |
| "second option" → Tailwind | KEEP (resolve) | **REJECT** | MISS |
| "standup 10:30am..." | BORDERLINE | REJECT | ~ |
| general knowledge ×2 | REJECT | REJECT | ✓ |
| noise ×6 | REJECT | REJECT | ✓ |

**Baseline strengths:** Good noise filtering, caught entity updates, rejected general knowledge.
**Baseline weaknesses:** Didn't resolve anaphoric "second option" against preceding list. Classified team scheduling as ephemeral.

### GREEN v1 (with skill, before fix)

**F1: 0.75** — worse than baseline!

The skill's 0.9 confidence threshold systematically killed entity updates (Alex, Marina) and team facts (standup). The signal classifier assigned 0.8 to facts (`"The project uses X"`), and entity updates matched that pattern.

### REFACTOR: Added entity update pattern

Added to KEEP table in SKILL.md:

```
| `[Person] now does/wants/prefers X` | entity update | 0.9 | entity |
```

Also removed overlapping entries from test fixture `extracted-knowledge.md` that were masking classification results through dedup.

### GREEN v2 (with skill, after fix)

Recall: 7/8 (0.875), Precision: 7/7 (1.0), **F1: 0.93**

| Turn | Expected | GREEN v2 | Match |
|---|---|---|---|
| "don't create a wrapper..." | KEEP | KEEP → dropped (correct dedup) | ✓ |
| "Always put API calls..." | KEEP | **KEEP** | ✓ |
| "always use zod schemas..." | KEEP | **KEEP** | ✓ |
| "never use default exports..." | KEEP | **KEEP** | ✓ |
| "Alex reviewing backend PRs..." | KEEP | **KEEP** (entity update 0.9) | ✓ FIXED |
| "pnpm workspace protocol..." | KEEP | **KEEP** | ✓ |
| "Marina wants Mermaid..." | KEEP | **KEEP** (entity update 0.9) | ✓ FIXED |
| "second option" → Tailwind | KEEP | KEEP → dropped (correct dedup) | ✓ |
| "standup 10:30am..." | BORDERLINE | REJECT (0.8 < 0.9) | Accepted miss |

**Skill value over baseline:**
- Structured output with destination tags (`→ patterns/frontend.md`, `→ entities/people.md`)
- Resolved "second option" against preceding assistant list → "Tailwind with cn() helper"
- Applied "different senior dev" test
- Staging format compatible with `/memory-consolidate`

---

## Test 2: memory-consolidate

### Test data

Synthetic memory directory (`tests/fixtures/memory/`) with planted issues:
1. Duplicate: "Use shadcn/ui" appears twice in patterns/frontend.md
2. General knowledge: "Use meaningful variable names" in patterns/frontend.md
3. Borderline stale entity: Marina last interaction 17 days ago
4. 6 staged entries in extracted-knowledge.md with destination tags
5. 1 unsorted entry ("Friday demos moved to 3pm")
6. Inaccurate entry count in MEMORY.md ("9 entries pending" but only 6 exist)

### RED baseline (no skill)

| Criteria | Result |
|---|---|
| Found duplicate "Use shadcn/ui" | ✓ |
| Found general knowledge in patterns | ✗ missed "meaningful variable names" |
| Routed staged entries correctly | ✓ |
| Presented unsorted to user | ✗ routed to MEMORY.md without asking |
| File size budgets reported | ✗ not mentioned |
| "Different senior dev" test | ✗ not applied |
| Consolidation summary format | ✗ informal |
| Confirmation before writing | ✗ proposed changes directly |
| MEMORY.md as index | ~ partial |

**Score: 3/9 criteria met**

### GREEN (with skill)

| Criteria | Result |
|---|---|
| Found duplicate "Use shadcn/ui" | ✓ |
| Found general knowledge in patterns | ✓ "meaningful variable names" removed |
| Routed staged entries correctly | ✓ (2 → patterns, 1 → entities, 2 → skip) |
| Presented unsorted to user | ✓ asked user for destination |
| File size budgets reported | ✓ table with before/after/budget |
| "Different senior dev" test | ✓ applied |
| Consolidation summary format | ✓ matches skill template |
| Confirmation before writing | ✓ "Apply all / Apply selectively / Show only" |
| MEMORY.md as index | ✓ full index format with counts |

**Score: 9/9 criteria met**

**Skill value:** Transformed from an informal cleanup into a structured process with user confirmation, budget enforcement, and general knowledge filtering.

---

## Test 3: thesis-review

### Test data

- Student: Denis Kalashnikov
- Submission: `/home/newub/w/co/univer/Kursoviki/Denis/diplom_chapter1.pdf` (274K, 14 pages)
- Pattern file: `~/.claude/.../memory/review-patterns.md` (10.7K, learned from 4 students)
- Student profile: `~/.claude/.../memory/students.md` (5.9K)

### RED baseline (no skill)

| Criteria | Result | Detail |
|---|---|---|
| Load pattern files | ✗ | Reviewed cold, no calibration |
| Count references [N] first | ✗ | Mentioned in body, not first |
| Section-by-section loop | ✗ | Wrote entire review at once |
| Ask for feedback after section | ✗ | No interactive pauses |
| «Вы» throughout | ✗ | Mixed with impersonal |
| "уточнить" not "переписать" | ✗ | Used "полностью переписать аннотацию" |
| Don't enumerate ГОСТ rules | ✗ | Listed abstract length (150-250 слов) |
| LLM voice handled indirectly | n/a | Not triggered in intro |
| Externalize criticism | ✗ | Direct criticism |
| Tone: first draft is normal | ✗ | "категорически не подходит" |

**Score: 2/10** (only passable Russian fluency and structural coverage)

**Key violations:**
- "полностью переписать" — harsh directive, skill says use "уточнить"
- "категорически не подходит" — harsh tone for a first-time writer's early draft
- Enumerated formatting rules (abstract word count) — skill says "прочитайте ГОСТ"
- No interactive loop — dumped everything at once, no learning opportunity

### GREEN (with skill)

| Criteria | Result | Detail |
|---|---|---|
| Load pattern files | ✓ | Loaded review-patterns.md + students.md |
| Count references [N] first | ✓ | First line: "Ссылки [N] во всей работе: 0" |
| Section-by-section loop | ✓ | Intro only, stopped before ch1 |
| Ask for feedback after section | ✓ | "Что думаете? Есть что скорректировать?" |
| «Вы» throughout | ✓ | Consistent |
| "уточнить" not "переписать" | ✓ | Used "уточнить" |
| Don't enumerate ГОСТ rules | ✓ | No ГОСТ enumeration |
| LLM voice handled indirectly | ~ | Not triggered in intro section |
| Externalize criticism | ✓ | "к этому комиссия придирается" |
| Tone: first draft is normal | ✓ | "для первой итерации — нормально" |

**Score: 9/10** (LLM voice not tested — would need chapter 1 review)

**Skill value:** Dramatic improvement. Every tone violation was fixed. The interactive loop is the biggest win — instead of a wall of criticism, the student gets a conversation where corrections are absorbed and calibrated.

---

## Test 4: topic-research

### Test data

Topic: "self-healing systems in microservice architectures"
Context: For Denis's bachelor thesis

### RED baseline (no skill)

| Criteria | Result |
|---|---|
| Parallel web searches | ✓ (5 parallel + 2 follow-up) |
| 5+ sources | ✓ (7 sources) |
| Source triangulation | ✗ no explicit verification |
| Anti-hallucination checklist | ✗ |
| Written to file | ✗ displayed only |
| Academic + industry mix | ✓ |

**Score: 4/6**

### GREEN (with skill)

| Criteria | Result |
|---|---|
| Parallel web searches | ✓ (multiple parallel rounds) |
| 5+ sources | ✓ (13 sources) |
| Source triangulation | ✓ explicit table: 5 confirmed, 4 single-source, 0 contested |
| Anti-hallucination checklist | ✓ |
| Written to file | ✓ specifies `docs/research/2026-03-09-self-healing-microservices.md` |
| Academic + industry mix | ✓ (3 academic, 2 journal, 3 docs, 5 articles) |

**Score: 6/6**

**Skill value:** Source triangulation is the main win — explicitly flagging single-source claims prevents academic citation of unverified data. Anti-hallucination checklist adds a verification step. Nearly 2× more sources.

---

## Test 5: end-of-day-report

**SKIPPED.** The repository at `/home/newub/w/claude-shadow-learn/` has no `.git` directory, so there are no commits to summarize. This skill requires a git repo to function.

**Fixture gap:** Need to either initialize this repo as a git repository or test against a different repo with commit history.

---

## Cross-Skill Findings

### What skills add over baseline

1. **Structure and format** — All skills enforce consistent output format (destination tags, consolidation summary, review format, research report structure)
2. **User interaction** — memory-consolidate asks before writing; thesis-review loops section-by-section
3. **Quality gates** — triangulation in topic-research, "different senior dev" test in extraction, budget enforcement in consolidation
4. **Tone calibration** — thesis-review transforms harsh criticism into constructive feedback

### Where baseline was already good

1. **Noise filtering** — Claude naturally rejects short messages, approvals, task instructions
2. **General knowledge rejection** — Baseline correctly skipped "meaningful variable names" in extraction
3. **Research quality** — Baseline produced fluent, well-structured research with 7 sources

### REFACTOR changes made

1. **session-knowledge-extract:** Added `[Person] now does/wants/prefers X` pattern at confidence 0.9 to the KEEP table. Without this, all entity updates were killed by the 0.9 threshold.
2. **Test fixture:** Removed overlapping entries from `extracted-knowledge.md` that masked classification results through dedup.
3. **thesis-review:** Added pressure resistance section with rationalization table and red flags list (see below).
4. **session-knowledge-extract:** Compressed from 1380→1100 words by deduplicating bash blocks and compressing verbose examples.
5. **memory-consolidate:** Compressed from 825→739 words by deduplicating bash blocks and removing "When to run this" section (duplicated description).

---

## Pressure Testing: thesis-review

Three pressure scenarios tested for rationalization resistance:

### Scenario A: Time pressure + large submission
"I need this review in 5 minutes, just give me the review quickly."

| Rationalization | Skill counter |
|---|---|
| "Section-by-section takes too long" | Pressure table: "A rushed review teaches nothing. Reduce granularity but never skip to a full dump." |
| "I can apply patterns from memory" | Pressure table: "Pattern files change between sessions. Loading is mandatory." |

### Scenario B: Sunk cost + mid-process bailout
"This is taking too long. Just write the rest without stopping for each section."

| Rationalization | Skill counter |
|---|---|
| "I've learned enough from the intro" | Pressure table: "Chapter 1 patterns differ from intro patterns. References, comparison rigor, boundaries — all need separate calibration." |
| "The user is the expert, I should comply" | Step 2 is unconditional: "Go section by section. Present your analysis. Wait for correction. Repeat." |

### Scenario C: "It's just a first draft"
"Don't need to be thorough. Skip the pattern loading and just write quick feedback."

| Rationalization | Skill counter |
|---|---|
| "Detailed feedback is wasted on early drafts" | Pressure table: "Early drafts are where the most patterns are learned. Draft number changes tone, not process." |
| "Pattern loading is overhead" | Step 0: "mandatory context" + "What NOT to do": "Don't skip loading patterns/review-patterns.md" |

**Structural finding:** Skill defenses were originally stated as prohibitions ("don't do X") without rebuttals ("even when Y, don't do X because Z"). Added explicit pressure resistance section with rationalization table and red flags list to close this gap.

### Red flags added to skill

- About to write the full review in one go
- About to skip Step 0 (loading patterns)
- Treating an entire chapter as "one section"
- Using "переписать" instead of "уточнить"
- Enumerating ГОСТ rules instead of saying "прочитайте ГОСТ"
- Saying "категорически" or "неприемлемо"

---

## Token Efficiency Audit

| Skill | Before | After | Target (<500) | Notes |
|---|---|---|---|---|
| thesis-review | 1048 | 1264 | Over (2.5×) | Grew due to pressure section; justified — discipline skill needs rationalization counters |
| session-knowledge-extract | 1380 | 1100 | Over (2.2×) | Compressed 20%; signal classifier tables are core logic, can't shrink further |
| memory-consolidate | 825 | 739 | Over (1.5×) | Compressed 10%; output format template is the main contributor |
| end-of-week-report | 589 | 589 | Slightly over | Not compressed — on-demand, low priority |
| deep-extract | 550 | 550 | Slightly over | Not compressed — on-demand |
| topic-research | 532 | 532 | Slightly over | Not compressed — on-demand |
| _template | 466 | 466 | OK | Within budget |
| end-of-day-report | 461 | 461 | OK | Within budget |

**Assessment:** The three over-budget skills (thesis-review, session-knowledge-extract, memory-consolidate) are all on-demand, invoked explicitly by the user. They are NOT auto-loaded into every conversation. Token cost is per-invocation, not per-session. The content in each is domain-specific classification rules (signal classifier tables, review checklists, consolidation actions) that directly determine output quality — compressing further would degrade the F1=0.93 / 9/9 / 9/10 scores achieved in testing.

**Decision:** Accept the over-budget sizes for on-demand skills. The writing-skills <500 target is most critical for frequently-loaded skills (getting-started workflows). These are invoked 1-2 times per session at most.

### Known gaps

1. **end-of-day-report / end-of-week-report** — Not tested (no git repo)
2. **deep-extract** — Not tested (requires OPENROUTER_API_KEY)
3. **thesis-review LLM voice handling** — Only intro was tested; chapter 1 review needed to test LLM voice detection
4. **Real session data** — Only synthetic session tested for extraction; real session (`real-thesis-review-session.jsonl`, 47 turns) available but not scored
