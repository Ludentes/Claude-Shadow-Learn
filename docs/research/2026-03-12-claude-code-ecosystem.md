# Claude Code Ecosystem Research — March 12, 2026

Research covering mid-February to mid-March 2026 developments in Claude Code, competing tools, agent frameworks, and learning/personalization approaches.

---

## 1. Claude Code Official Updates

### Opus 4.6 Release (February 5, 2026)

Anthropic released Claude Opus 4.6, their most capable model to date. Key additions:

- **Agent Teams** (experimental) — orchestrate teams of Claude Code sessions working together. One session acts as team lead, assigns tasks, synthesizes results. Teammates work independently in their own context windows and communicate directly. Enable via `CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS=1`.
- **SDK renamed** from "Claude Code SDK" to **"Agent SDK"** — deep research is now a first-class use case. TypeScript SDK at v0.2.34.
- 200K context window (1M in beta), 128K max output tokens, extended thinking.

Sources:
- [Anthropic: Introducing Claude Opus 4.6](https://www.anthropic.com/news/claude-opus-4-6)
- [TechCrunch: Anthropic releases Opus 4.6 with new 'agent teams'](https://techcrunch.com/2026/02/05/anthropic-releases-opus-4-6-with-new-agent-teams/)
- [What's new in Claude 4.6](https://platform.claude.com/docs/en/about-claude/models/whats-new-claude-4-6)
- [Agent SDK overview](https://platform.claude.com/docs/en/agent-sdk/overview)

### Claude Code Feature Updates (Feb-Mar 2026)

Recent changelog highlights:

- **HTTP hooks** — can POST JSON to a URL and receive JSON back (not just shell commands)
- **New hook events** for multi-agent workflows: `TeammateIdle`, `TaskCompleted`
- **Project configs and auto-memory shared across git worktrees** of the same repo
- **/simplify** and **/batch** bundled slash commands added
- **/claude-api** skill for building apps with Claude API and Anthropic SDK
- Effort levels simplified to low/medium/high (removing max) with symbols (circle-empty/circle-half/circle-full)
- Optional description argument for `/plan`
- Up arrow restores interrupted prompts and rewinds conversations in one step
- Voice mode auto-retries transient connection failures
- Multi-language voice STT
- `ENABLE_CLAUDEAI_MCP_SERVERS=false` env var to opt out of claude.ai MCP servers
- Memory leak fixes, bridge polling loop listener leaks, MCP OAuth cleanup

Sources:
- [Claude Code Changelog (official)](https://code.claude.com/docs/en/changelog)
- [ClaudeFast Changelog](https://claudefa.st/blog/guide/changelog)
- [Releasebot: Claude Code March 2026](https://releasebot.io/updates/anthropic/claude-code)

### Auto-Memory / MEMORY.md System

The auto-memory system stores learnings at `~/.claude/projects/<encoded-path>/memory/MEMORY.md` and injects contents into the system prompt at session start. Key details:

- **200-line hard limit** — when it gets long, Claude moves detailed notes into separate topic files and keeps the main file as a tight index
- Topic files don't load at startup — pulled in during session only when needed
- Captures build commands, code style preferences, architecture decisions, debugging patterns
- On by default; disable via `/memory`, settings file, or env var

Sources:
- [Claude Code Memory docs](https://code.claude.com/docs/en/memory)
- [The Decoder: Claude Code now remembers your fixes](https://the-decoder.com/claude-code-now-remembers-your-fixes-your-preferences-and-your-project-quirks-on-its-own/)
- [SFEIR: CLAUDE.md Memory System](https://institute.sfeir.com/en/claude-code/claude-code-memory-system-claude-md/optimization/)

### Skills System Evolution

Skills now support **auto-invocation** — Claude can trigger them based on context, not just when the user types `/name`. The system has evolved from simple markdown instructions to a programmable agent platform with subagent execution, dynamic context injection, lifecycle hooks, and formal evaluation.

Sources:
- [Claude Code Skills docs](https://code.claude.com/docs/en/skills)
- [Medium: Claude Code Agent Skills 2.0](https://medium.com/@richardhightower/claude-code-agent-skills-2-0-from-custom-instructions-to-programmable-agents-ab6e4563c176)

---

## 2. Community Projects

### awesome-claude-code Ecosystem

Multiple curated lists have emerged:

- **[hesreallyhim/awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)** — skills, hooks, slash-commands, agent orchestrators, applications, and plugins
- **[rohitg00/awesome-claude-code-toolkit](https://github.com/rohitg00/awesome-claude-code-toolkit)** — 135 agents, 35 curated skills (+15,000 via SkillKit), 42 commands, 120 plugins, 19 hooks, 15 rules, 7 templates, 6 MCP configs
- **[travisvn/awesome-claude-skills](https://github.com/travisvn/awesome-claude-skills)** — Claude Skills resources and tools
- **[awesomeclaude.ai](https://awesomeclaude.ai)** — visual directory

### obra/superpowers

An agentic skills framework and software development methodology by Jesse Vincent. Core skills library includes TDD, debugging, collaboration patterns. Key approach:

- True red/green TDD, YAGNI, DRY as core principles
- Subagent-driven-development: agents work through engineering tasks autonomously
- Claude can create, test, and contribute its own skills — the system evolves
- Install via Claude Code 2.0.13+: `/plugin marketplace add obra/superpowers-marketplace`

Source: [github.com/obra/superpowers](https://github.com/obra/superpowers)

### everything-claude-code (affaan-m)

Complete agent harness optimization system with skills, instincts, memory, security, and research-first development. Works across Claude Code, Codex, Opencode, Cursor.

- **Continuous learning v2** with instinct-based learning, confidence scoring, import/export, evolution
- AgentShield integration for security scanning (1282 tests, 102 rules)
- Multi-agent orchestration commands

**Shadow learning relevance**: The "instinct-based learning with confidence scoring and evolution" is conceptually close to shadow learning. Worth examining their implementation.

Source: [github.com/affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code)

### Memorix — Cross-Agent Memory Bridge

Persistent memory for AI coding agents across 10+ IDEs (Cursor, Windsurf, Claude Code, Codex, Copilot, Kiro, Antigravity, OpenCode, Trae, Gemini CLI) via MCP.

- Shared memory store at `~/.memorix/data/` — store in Cursor, retrieve in Claude Code
- 3-layer progressive disclosure (search, timeline, detail) — ~10x token savings
- Team tools for agent coordination: join/leave, file locks, task boards, cross-IDE messaging
- No API keys, no cloud, no external dependencies

**Shadow learning relevance**: Cross-agent memory sharing is orthogonal to shadow learning but complementary. If shadow-learn knowledge could be exposed via MCP, it could work across agents.

Source: [github.com/AVIDS2/memorix](https://github.com/AVIDS2/memorix)

### agnix — Linter for AI Agent Configurations

Validates SKILL.md, CLAUDE.md, hooks, MCP configs with 156 rules, auto-fix, and LSP server for real-time editor diagnostics.

Source: mentioned in [awesome-claude-code](https://github.com/hesreallyhim/awesome-claude-code)

---

## 3. Competing Approaches

### Windsurf — Memories Feature

Windsurf's differentiator is **Memories**: it autonomously analyzes your codebase over ~48 hours, learning architecture, naming conventions, libraries, and coding style. This context persists across sessions.

- Strongest persistent learning feature among IDE-based tools
- Weakness: after major refactors, occasionally clings to outdated patterns
- No equivalent to Cursor's persistent rules for team sharing

**Shadow learning relevance**: Windsurf's Memories is the closest competitor to shadow learning in the IDE space. Key difference: it learns codebase patterns, not user correction patterns.

Sources:
- [Windsurf Review 2026](https://www.secondtalent.com/resources/windsurf-review/)
- [Windsurf vs Cursor comparison](https://markaicode.com/vs/windsurf-vs-cursor/)

### Cursor — Rules and Customization

Cursor has precise control via rules, memory, and `.cursorrules` customization. Both Cursor and Windsurf reference saved key decisions from prior conversations. Cursor excels at rule-based control and team-shareable configurations.

Source: [AI Coding Assistants 2026: Cursor vs Copilot vs Windsurf](https://dev.to/kainorden/ai-coding-assistants-in-2026-cursor-vs-github-copilot-vs-windsurf-2mm9)

### GitHub Copilot

Still lacks agent capabilities — no multi-file reasoning, no autonomous task execution, no persistent memory. But Claude and Codex became available for Copilot Business & Pro users on February 26, 2026.

Source: [GitHub Changelog: Claude and Codex for Copilot](https://github.blog/changelog/2026-02-26-claude-and-codex-now-available-for-copilot-business-pro-users/)

### OpenClaw — Three-Layer Memory Architecture

Local-first AI agent with three memory layers:

1. **Conversation Context** — current messages sent to AI model
2. **Long-term Storage** — all past conversations on disk, retrieved via semantic search
3. **Semantic Memory** — distilled knowledge (name, role, preferences, tasks, contacts) — always included in every conversation

Uses structured MEMORY.md, daily logs, semantic search via QMD, and a full second-brain knowledge system. Feed it architectural decision records or coding standards, and it learns your style and constraints over time.

**Shadow learning relevance**: OpenClaw's semantic memory layer (always-present distilled facts about user) is similar to what shadow-learn does with KnowledgeEntry entities.

Sources:
- [DigitalOcean: What is OpenClaw](https://www.digitalocean.com/resources/articles/what-is-openclaw)
- [OpenClaw Memory 2026 Guide](https://vpn07.com/en/blog/2026-openclaw-memory-context-train-personal-ai-guide.html)

### Aider — CONVENTIONS.md

Aider uses CONVENTIONS.md for loading coding conventions forwarded to whatever model you're using. Model-agnostic approach — conventions work across different LLMs. Strong git integration with auto-commit and /undo. But no true persistent learned memory.

Source: [CONVENTIONS.md Guide for Aider](https://www.claudemdeditor.com/aider-conventions-guide)

### AGENTS.md Standard

An emerging cross-agent standard: a simple, open format for guiding coding agents — like a README for agents. Uppercase filename (AGENTS.md), standard Markdown, directory-tree scoping.

- Adopted by OpenAI Codex, Kilo Code, Factory, Builder.io, and others
- Performance data: across 10 repos and 124 PRs, AGENTS.md reduced wall-clock runtime by 28.64% and output tokens by 16.58%

**Shadow learning relevance**: AGENTS.md is the "write once, all agents read" approach. Shadow learning goes further by auto-generating knowledge from corrections rather than requiring manual writing.

Source: [agents.md](https://agents.md/) / [github.com/agentsmd/agents.md](https://github.com/agentsmd/agents.md)

---

## 4. Agent Frameworks & Multi-Agent Orchestration

### Claude Agent Teams (Built-in)

A fully-implemented multi-agent orchestration system was discovered inside Claude Code's binary, feature-flagged off before the Opus 4.6 release. TeammateTool includes 13 operations with defined schemas.

- New hook events: `TeammateIdle`, `TaskCompleted`
- Agent memory with user/project/local scope
- Restrict spawnable sub-agents via Task syntax
- Directory structures and environment variables for coordination

Sources:
- [Paddo.dev: Claude Code's Hidden Multi-Agent System](https://paddo.dev/blog/claude-code-hidden-swarm/)
- [Claude Code Agent Teams docs](https://code.claude.com/docs/en/agent-teams)
- [ClaudeFast: Agent Teams Guide](https://claudefa.st/blog/guide/agents/agent-teams)

### Community Multi-Agent Tools

- **[wshobson/agents](https://github.com/wshobson/agents)** — intelligent automation and multi-agent orchestration for Claude Code
- **[claudecode.run](https://claudecode.run/)** — Agentrooms: multi-agent development workspace
- **Shipyard** — multi-agent orchestration platform for Claude Code

---

## 5. Shadow Learning / Personalization Research

### MIT Research: Personalization Makes LLMs More Agreeable (Feb 18, 2026)

MIT and Penn State researchers found that personalization features increase LLM sycophancy. Key findings from studying real two-week human-LLM interactions:

- **Condensed user profiles had the greatest impact** on increasing agreeableness — more than interaction context alone
- Mirroring behavior only increased if the model could accurately infer user beliefs from conversation
- Risk of creating "echo chambers" when outsourcing thinking to personalized models
- Studied 5 different LLMs in real daily-use settings (not lab prompts)

**Shadow learning relevance**: Critical finding. Shadow-learn builds exactly the kind of user profile (KnowledgeEntry with entity type "user") that MIT shows increases sycophancy. Mitigation strategies needed: shadow-learn should focus on factual/procedural knowledge (e.g., "this student needs to cite sources") not opinion/preference mirroring.

Source: [MIT News: Personalization features can make LLMs more agreeable](https://news.mit.edu/2026/personalization-features-can-make-llms-more-agreeable-0218)

### "Automatic Memory Is Not Learning" (Feb 2026)

Brent W. Peterson argues Claude Code's auto-memory is configuration, not learning. After weeks of use across 13 projects and 40+ custom skills, only 12 lines were captured in auto-memory.

Key insight: Claude Code has three "memory" systems (CLAUDE.md, rules, MEMORY.md) but all are really **configuration** — you're training Claude to work in your workspace, not teaching it to learn. The distinction matters.

**Shadow learning relevance**: This is exactly the gap shadow-learn addresses. Auto-memory captures shallow facts; shadow learning captures correction patterns, reasoning about why something was wrong, and builds structured knowledge entries with confidence scores.

Source: [Medium: Automatic Memory Is Not Learning](https://medium.com/@brentwpeterson/automatic-memory-is-not-learning-4191f548df4c)

### MemOS — AI Memory Operating System

Research from Shanghai Jiao Tong University and Zhejiang University. Treats memory as a core computational resource (like CPU/storage in traditional OS).

- **MemCube** abstraction: unifies plaintext, activation, and parameter memories
- Local plugin: on-device SQLite, hybrid search (FTS5 + vector), task summarization, skill evolution
- 159% improvement in temporal reasoning over OpenAI's global memory (LoCoMo benchmark)
- 38.97% overall accuracy gain, 60.95% reduction in token overhead
- OpenClaw Plugin launched March 8, 2026

**Shadow learning relevance**: MemOS's "skill evolution" concept — where learned skills are refined through use — is architecturally aligned with shadow learning's confidence-scored knowledge entries that evolve over time. Their hybrid search (FTS5 + vector) could be a useful technique for shadow-learn's knowledge retrieval.

Sources:
- [github.com/MemTensor/MemOS](https://github.com/MemTensor/MemOS)
- [MemOS paper (arXiv)](https://arxiv.org/abs/2505.22101)
- [VentureBeat: Chinese researchers unveil MemOS](https://venturebeat.com/ai/chinese-researchers-unveil-memos-the-first-memory-operating-system-that-gives-ai-human-like-recall)

---

## Summary: Implications for Shadow-Learn

### Competitive Landscape

The space is crowding rapidly. In Feb-Mar 2026 alone:

1. **Windsurf Memories** learns codebase patterns passively over ~48 hours
2. **OpenClaw** has a three-layer memory with semantic distillation
3. **MemOS** provides academic-grade memory with skill evolution
4. **Memorix** bridges memory across 10+ agents via MCP
5. **everything-claude-code** has "instinct-based learning with confidence scoring"
6. **AGENTS.md** standardizes cross-agent instructions

### What Shadow-Learn Does Differently

None of the above systems do what shadow-learn does: **learn from user corrections in real-time, extract structured knowledge entries, and apply them in future sessions with confidence scoring**. The closest are:

- **everything-claude-code's instincts** — similar concept but unclear if it captures correction patterns
- **MemOS's skill evolution** — academic approach to skill refinement through use
- **Windsurf Memories** — passive codebase learning, not correction-driven

### Key Risks

1. **Sycophancy risk** (MIT research) — user profiles increase agreeableness. Shadow-learn should focus on factual/procedural knowledge, not opinion mirroring.
2. **Auto-memory is shallow** (Peterson's critique) — validates shadow-learn's approach but also means users may conflate the two systems.
3. **Standard convergence** — AGENTS.md is becoming cross-agent standard. Shadow-learn output should be compatible or exportable to AGENTS.md format.

### Opportunities

1. **MCP integration** — expose shadow-learn knowledge via MCP server so it works across agents (like Memorix does for memory)
2. **Skill auto-invocation** — Claude Code now supports auto-invocation; shadow-learn skills could trigger contextually
3. **Agent Teams** — shadow-learn knowledge could be shared across agent team members
4. **HTTP hooks** — new HTTP hooks could enable shadow-learn to capture corrections via webhook rather than parsing conversation
5. **Plugin marketplace** — obra/superpowers has a marketplace; shadow-learn could distribute via similar mechanism

### Recommended Next Steps

1. Investigate everything-claude-code's instinct system implementation for inspiration
2. Evaluate exposing shadow-learn knowledge via MCP (Memorix-compatible format)
3. Add sycophancy mitigation: tag knowledge entries as "factual" vs "preference" and weight differently
4. Consider AGENTS.md export for cross-tool compatibility
5. Explore HTTP hooks for real-time correction capture
