# Deep Dive: Continuous Learning v2, AGENTS.md, Ecosystem Trends — March 13, 2026

---

## 1. Continuous Learning v2 (everything-claude-code)

### Architecture

Instinct-based learning system by affaan-m. Units of knowledge are **atomic instincts** (not skills or patterns).

```
skills/continuous-learning-v2/
├── hooks/
│   ├── pre-tool-use.js       # 100% deterministic capture
│   └── post-tool-use.js
├── commands/
│   ├── instinct-status.md    # View learned instincts
│   ├── instinct-export.md    # Share instincts
│   ├── instinct-import.md    # Import from others
│   └── evolve.md             # Cluster instincts → skills
└── observer-agent.md         # Background Haiku agent
```

Data storage:
- `~/.claude/instincts/observations.jsonl` — raw events (not shared)
- `~/.claude/instincts/learned/` — compiled instincts as markdown with YAML frontmatter

### Instinct Format

```yaml
---
name: [instinct name]
confidence: [0.3-0.85]
domain: [code-style|testing|git|debugging|etc]
---
# Action
[What the instinct does]
# Evidence
[Why the agent learned this]
# Examples
[Concrete examples]
```

### Key Mechanisms

- **Observation**: hooks capture every PreToolUse/PostToolUse deterministically (v1 was probabilistic ~50-80%)
- **Pattern detection**: background Haiku agent analyzes observations for corrections, error resolutions, repeated workflows
- **Confidence scoring**: 0.3–0.85 range, decays on contradiction, configurable auto-apply threshold
- **Evolution**: `/evolve` clusters related instincts into higher-level artifacts
- **Promotion**: `/promote` moves project instincts → global scope
- **Import/export**: shareable markdown files (raw observations stay local)

### Comparison to Shadow Learning

| Aspect | Shadow Learning | CLv2 |
|--------|----------------|------|
| Capture | Post-hoc extraction (daily) | Real-time hooks (100%) |
| Unit size | Patterns (~150 lines) | Atomic instincts (~20 lines) |
| Confidence | Not scored | 0.3–0.85, decays |
| Evolution | Manual consolidation | Automatic clustering |
| Sharing | Copy pattern files | Built-in import/export |
| Human review | Required (corrections) | Optional (high confidence = auto) |
| Dependencies | None (pure markdown) | Node.js hooks, Haiku API |

### What We Should Take

1. **Confidence scoring** — add to KnowledgeEntry schema (we already have `confidence` field, need decay)
2. **Domain tagging** — our patterns already do this by file (frontend.md, review.md)
3. **Nothing else** — their hooks + Haiku dependency contradicts our zero-dependency design

### What We Should NOT Take

- Real-time hook observation (heavy, requires Node.js)
- Background Haiku agent (API cost, complexity)
- Auto-apply at high confidence (we want human-in-the-loop always)

---

## 2. AGENTS.md Standard

### Specification

- Simple markdown, no strict schema — intentionally minimal
- Directory scoping: nearest AGENTS.md in tree wins (hierarchical override)
- Common sections: Build & Test, Architecture, Security, Git Workflows, Conventions

### Adoption

- OpenAI Codex, Cursor, Factory, Kilo Code, Amp, Jules (Google)
- Stewarded by Agentic AI Foundation (Linux Foundation)
- 60,000+ open-source projects

### Performance (Lulla et al., Jan 2026, arXiv 2601.20404)

- 10 repos, 124 PRs
- 28.64% median wall-clock runtime reduction
- 16.58% output token reduction
- No quality degradation

### AGENTS.md vs CLAUDE.md

| Aspect | AGENTS.md | CLAUDE.md |
|--------|-----------|----------|
| Scope | Universal (all tools) | Claude-specific |
| Features | Basic context | Skills, hooks, plugins |
| Portability | Cross-tool | Anthropic only |

### Coexistence Pattern

- AGENTS.md: universal project context (architecture, build, conventions)
- CLAUDE.md: Claude-specific features (shadow learning bootstrap, skills, hooks)
- Bridge: CLAUDE.md references AGENTS.md

### Research Warning

Upsun Developer Center research: overly long AGENTS.md files are counterproductive. Keep concise.

---

## 3. Ecosystem Trends (March 2026)

### Memory Frameworks Maturing

- **Mem0**: 26% accuracy boost, 91% lower latency, 90% token savings
- **Letta**: memory as first-class agent component with editable blocks
- **EverMemOS**: self-organizing memory for structured long-horizon reasoning

### Memory Taxonomy Consensus

Emerging standard: factual memory, experiential memory, working memory. Our structure maps:
- entities/ = factual
- patterns/ = experiential
- session context = working

### Skill Marketplaces Exploding

- 351,000+ skills indexed (SkillsMP)
- Anthropic launched Claude Marketplace (limited preview)
- Skills ecosystem reached 350k in ~2 months

### Agent Teams Production-Ready

- Coordinator + teammates with independent context windows
- Direct inter-agent messaging
- Use cases: parallel research, feature ownership, competing hypotheses

### MemOS OpenClaw Plugin (Mar 8)

- Cloud: 72% token savings, multi-agent memory sharing
- Local: 100% on-device, SQLite, hybrid search, skill evolution
- Their "skill evolution" concept aligns with shadow learning

---

## 4. Actionable Recommendations for Shadow-Learn

### Add Now

1. **AGENTS.md support** — generate AGENTS.md from shadow-learn patterns (cross-tool export)
2. **Confidence decay** — when a pattern gets contradicted, lower confidence

### Add Soon

3. **Domain tags in frontmatter** — explicit categorization for pattern files
4. **AGENTS.md in init script** — create alongside CLAUDE.md

### Watch / Don't Add Yet

5. Real-time hook observation (too heavy for our zero-dep design)
6. Background agent analysis (API cost not justified yet)
7. Skill marketplace publishing (wait for ecosystem to stabilize)
8. Agent teams for parallel work (experimental, not core to learning)

---

Sources:
- [everything-claude-code](https://github.com/affaan-m/everything-claude-code)
- [AGENTS.md spec](https://github.com/agentsmd/agents.md)
- [arXiv 2601.20404](https://arxiv.org/abs/2601.20404)
- [Upsun: AGENTS.md less is more](https://devcenter.upsun.com/posts/agents-md-less-is-more/)
- [Mem0](https://github.com/mem0ai/mem0), [Letta](https://github.com/letta-ai/letta)
- [MemOS](https://github.com/MemTensor/MemOS)
