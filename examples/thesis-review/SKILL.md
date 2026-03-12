---
name: thesis-review
description: "Use when reviewing a student's bachelor thesis (VKR) draft — intro, chapter 1, or full submission. Triggers on 'review thesis', 'review VKR', 'thesis review', or student name with submission context."
---

# Thesis Review (Shadow Learning Skill)

This skill implements a **shadow learning loop**: load patterns → apply to new case → get corrected → update patterns → produce output. Each review trains the next. The thesis review is the task; the learning is the point.

## Shadow Learning Cycle

```
┌─────────────────────────────────────────────────┐
│  1. LOAD: patterns/review-patterns.md + entities/ │
│  2. APPLY: section-by-section analysis          │
│  3. CORRECT: user fixes mistakes/calibrates     │
│  4. PRODUCE: write review with corrections      │
│  5. LEARN: update patterns + student profile    │
│     ↓                                           │
│  Next review starts at 1 with better patterns   │
└─────────────────────────────────────────────────┘
```

If this is the FIRST review (no patterns/review-patterns.md exists), tell the user: "No patterns yet. I'll follow your lead — you review, I'll learn. We can switch to me leading from the second student onward."

## Arguments

Optional: student name (e.g., "Anna", "Denis"). If not provided, ask.

## Step 0: Load knowledge

Read ALL of these. They are mandatory context — the entire skill depends on them.

```bash
MEMORY_DIR="$HOME/.claude/projects/$(echo $(pwd) | tr '/' '-')/memory"
```

| File | Purpose | If missing |
|---|---|---|
| `$MEMORY_DIR/patterns/review-patterns.md` | Learned review rules — your primary instruction set | Switch to learning mode (user leads) |
| `$MEMORY_DIR/entities/students.md` | Per-student context, history, notes | Ask user for student info |

| VKR guidelines (path in students.md) | Department requirements | Proceed without — patterns encode the important parts |

**Before proceeding**, mentally note:
- What patterns exist (how many review cycles have happened?)
- What's known about this specific student
- Any previous reviews for this student (draft1 → draft2 etc.)

## Step 1: Read submission

From the argument or by asking, identify the student. Read their students.md entry for:
- Thesis title, submission path, format
- Previous review notes
- Student-specific notes (personality, strengths, known issues)

Read the full submission. For PDFs >10 pages, use the `pages` parameter in chunks.

**Before analyzing**: Count references [N] in the submission. This single number tells you a lot about chapter 1 quality. Report it immediately.

## Step 2: Section-by-section analysis (APPLY + CORRECT loop)

Do NOT write a full review. Go section by section. Present your analysis. Wait for correction. Repeat.

This is where learning happens: every correction from the user is a new pattern or a calibration of an existing one.

### Intro checklist (from review-patterns.md):

1. **Funnel / Актуальность**: General → specific → problem → our slice → цель. Under 2 pages total?
2. **References [N]**: Every claim backed? Flag each unsupported assertion with what citation is needed.
3. **Language**: English loans in intro (БЯМ not LLM)? Abbreviations introduced? First paragraph flawless?
4. **Цель**: Derives from thesis title?
5. **Задачи**: Unambiguous? Chain logically? No scope leaks? Don't presuppose solutions?
6. **Terminology**: Any loaded terms (like "база знаний") that overstate the deliverable?
7. **Other sections**: Подход (conceptual only!), положения, структура — present? Appropriate depth?

### Chapter 1 checklist:

1. **Structure**: Numbered subsections? Opening overview paragraph explaining chapter logic?
2. **Reference density**: Count [N] citations. This is THE metric.
3. **Content completeness**: Major tools/papers/frameworks covered? Missing anything obvious?
   - If gaps found: offer to run `/topic-research` and provide a research file
4. **Comparison rigor**: Explicit criteria stated? Table or matrix? Basis for "X is better than Y"?
5. **Boundaries**: Any section that's actually ch2 material (own architecture/solution)?
6. **Attribution**: Classifications/taxonomies — sourced or author's own? Either is fine but must be stated.
7. **Связка**: Conclusions leading to chapter 2?

### LLM voice (handle carefully):

Don't flag LLM usage directly. Instead:
- **Indirect**: Ask for chapter overview + explicit comparison criteria → forces student's own structure
- **Direct** (only when very obvious): Commission risk framing. "Текст кричит нейронка. Ближе к защите поймите отношение комиссии."
- Never frame as moral failing. Never say "rewrite clunkier."

### After each section:

Present your findings and explicitly ask: "What do you think?" or "Anything to correct?"

**When the user corrects you**, acknowledge and note whether this is:
- A **new pattern** (not in patterns/review-patterns.md) → will add in Step 5
- A **calibration** of existing pattern (too strict/lenient) → will update in Step 5
- A **one-off** for this specific student → note in entity file only

## Step 3: Produce review

Once all sections are covered and corrections absorbed, write the review to `[student_dir]/review-draft[N].md`.

Increment N based on existing files (if draft1 exists, write draft2).

### Format:

```markdown
# Рецензия на [что именно] ВКР — [Имя]

**Тема**: [полное название]

---

## Общая оценка

[2-3 sentences. Start positive. Then the main issue. Prose, not bullets.]

---

## [Section name]

[Feedback in prose. «Вы» throughout. Specific, actionable.]

---

## Что уточнить — итого

### [Section]
1. [Actionable item]
2. ...
```

### Tone (from patterns):
- «Вы» always
- "Для первой итерации — нормально"
- "Уточнить" not "переписать"
- Externalize: "к этому комиссия придирается"
- Formatting: "прочитайте ГОСТ" (don't enumerate rules)
- Literal students: compress, not cut
- Prose over bullet lists where possible

## Step 4: Update knowledge (LEARN)

This step is **not optional**. Every review should leave the knowledge better than it found it.

### Always update entities/students.md:
- Review status (draft1 done, draft2 done, etc.)
- Key findings summary (one dense paragraph)
- Any new student-specific notes

### Update patterns/review-patterns.md IF corrections revealed:
- A new pattern (add to appropriate section)
- An existing pattern was wrong or too strict/lenient (edit it)
- A new common student issue (add to "Common Student Issues")

### Do NOT update patterns/review-patterns.md for:
- One-off corrections specific to a student's domain
- Stylistic preferences that contradict existing patterns
- Things already captured

### Report what you learned:
Tell the user: "From this review I [learned X / updated Y / no new patterns]." This makes the learning visible.

## Pressure resistance

These steps are non-negotiable regardless of time pressure, user urgency, or draft number.

| Pressure | Rationalization | Reality |
|---|---|---|
| "Just give me the review quickly" | "Section-by-section takes too long" | A rushed review teaches nothing. If time is short, reduce section granularity (2-3 checkpoints) but never skip to a full dump. |
| "Skip the rest, I see your style" | "I've learned enough from the intro" | Chapter 1 patterns differ from intro patterns. References, comparison rigor, boundaries — all need separate calibration. |
| "It's just a first draft, be quick" | "Detailed feedback is wasted on early drafts" | Early drafts are where the most patterns are learned. Draft number changes **tone**, not **process**. |
| "Don't bother loading patterns" | "I can apply them from memory" | Pattern files change between sessions. Loading is mandatory — that's Step 0. |

### Red flags — STOP and reconsider

- About to write the full review in one go
- About to skip Step 0 (loading patterns)
- Treating an entire chapter as "one section"
- Using "переписать" instead of "уточнить"
- Enumerating ГОСТ rules instead of saying "прочитайте ГОСТ"
- Saying "категорически" or "неприемлемо"

**All of these mean: slow down, re-read the skill, apply the patterns.**

## What NOT to do

- Don't write a review before going section by section
- Don't skip loading patterns/review-patterns.md
- Don't flag LLM usage as inherently bad
- Don't enumerate ГОСТ formatting rules
- Don't be harsh — first-time writers, early drafts
- Don't skip Step 4 (knowledge update) — that's the learning
