---
name: topic-research
description: "Use when the user needs in-depth research on a technical topic with multiple sources and citations. Triggers on 'research [topic]', 'find sources for', 'literature review', or any question needing 5+ sources. Do NOT use for simple lookups or debugging."
---

# Topic Research

Focused research skill. Uses parallel WebSearch + WebFetch for source gathering, triangulation for verification, structured output with citations.

## When to use / NOT use

- **Use**: Technical comparisons, architecture analysis, state-of-art reviews, multi-source investigation
- **Skip**: Simple lookups (just use WebSearch), debugging, questions answerable with 1-2 searches

## Process

### 1. Scope (30 seconds)

Define boundaries before searching:
- State the research question in one sentence
- List 3-5 search angles (subtopics, perspectives, comparisons)
- Note what's OUT of scope
- Choose depth: **quick** (5 sources, 1-2 min) or **standard** (10-15 sources, 5-10 min)

### 2. Parallel Retrieve

Launch ALL searches in a single message. Never search sequentially.

```
Correct (one message, all parallel):
  WebSearch: "OpenAI Harness architecture"
  WebSearch: "OpenAI Harness vs LangGraph"
  WebSearch: "OpenAI agent framework 2025"
  WebSearch: "Harness agent orchestration design"
  WebFetch: [official docs URL if known]

Wrong (sequential, one at a time):
  WebSearch → wait → WebSearch → wait → WebSearch
```

For each result, track: source URL, credibility (official docs > blog > forum), date, key claims.

### 3. Deep-dive (selective)

Use WebFetch on the 3-5 most promising URLs from Step 2. Read the actual content — search snippets are not enough for technical topics. Use Agent tool for parallel deep-dives on independent subtopics.

### 4. Triangulate

For every major claim, require 2+ independent sources. Flag:
- **Confirmed**: 2+ sources agree
- **Single-source**: Only one source, note this
- **Contested**: Sources disagree, present both sides

### 5. Write report

Save to `docs/research/YYYY-MM-DD-<topic-slug>.md` (or user-specified path).

Structure:

```markdown
# Research: <Topic>

**Date:** YYYY-MM-DD
**Sources:** [count] sources, [list key ones with URLs]

---

## Executive Summary
[3-5 sentences. Lead with the answer, not the question.]

## Key Findings

### <Finding 1 title>
[2-3 paragraphs of prose. Specific data, numbers, dates. Citations inline as [N].]

### <Finding 2 title>
[Same pattern.]

### <Finding N>
[As many as the evidence warrants.]

## Comparison (if applicable)
[Table or structured comparison. Use tables for feature matrices.]

## Open Questions
[What couldn't be answered. Gaps in sources. Contested claims.]

## Sources
[1] Author/Org. "Title". URL (Retrieved: date)
[2] ...
```

### Writing rules

- **Prose, not bullets**: Default to paragraphs. Bullets only for distinct lists (features, products)
- **Cite inline**: "The framework uses X for orchestration [1]" — never "Research suggests..."
- **Be specific**: "23% improvement" not "significant improvement"
- **Admit gaps**: "No sources address X" is better than guessing
- **No fabrication**: If you can't verify a claim, don't cite it. Say what you found, not what you wish you found.
- **Economy**: Every sentence carries information. Cut filler.

## Anti-hallucination checklist (verify before delivering)

- [ ] Every [N] citation has a matching entry in Sources
- [ ] Every Source entry was actually retrieved (not invented)
- [ ] Claims marked "single-source" where applicable
- [ ] No vague attributions ("studies show", "experts believe")
- [ ] Dates and numbers verified against source text
