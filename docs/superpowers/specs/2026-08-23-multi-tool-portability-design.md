# Multi-Tool Portability Design

Status: design
Date: 2026-08-23
Scope: make shadow learning work under Claude Code, Codex CLI, and Kimi Code from one installation.

## Problem

Shadow learning currently assumes Claude Code in three places:

- **Store location.** Patterns, entities, and `MEMORY.md` live in `~/.claude/projects/<slug>/memory/`. No other tool reads that path, and nothing there is shareable with a colleague.
- **Transcript reader.** `/session-knowledge-extract` hardcodes Claude's `~/.claude/projects/<slug>/*.jsonl` layout and message schema.
- **Skill installation.** `shadow-learn.sh init` copies skills to `~/.claude/skills/` only.

Everything else — the correction loop, the signal classifier, the pattern/entity/playbook taxonomy — is tool-agnostic prose that any agent can follow.

## What the target tools actually support

Verified against the installed Kimi Code binary (`~/.kimi-code/bin/kimi`, v0.18.0) and published Codex documentation.

| Capability | Claude Code | Codex CLI | Kimi Code |
|---|---|---|---|
| Instruction file | `CLAUDE.md` (also reads `AGENTS.md`) | `AGENTS.md` | `AGENTS.md` walking up from cwd, plus `~/.agents/AGENTS.md`, `~/.kimi-code/AGENTS.md` |
| Skills | `~/.claude/skills/`, `.claude/skills/` | `~/.codex/skills/`, `.codex/skills/` | `.agents/skills/`, `~/.agents/skills/`, `.kimi-code/skills/`, `~/.kimi-code/skills/` |
| Skill format | `SKILL.md` + frontmatter | same | same |
| Hooks | `SessionStart`/`Stop`/`PreToolUse`/… in `settings.json` | lifecycle hooks in `config.toml` | `SessionStart`/`SessionEnd`/`PreToolUse`/`PostToolUse` via `hooks` in `config.toml` |
| Session transcripts | `~/.claude/projects/<slug>/*.jsonl` | `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl` | `~/.kimi-code/sessions/wd_<slug>/ses_<id>/{context,wire}.jsonl`, indexed by `~/.kimi-code/session_index.jsonl` |
| Auto-memory directory | yes | no | no |

The premise "Kimi has no memory" is only true of the last row. Kimi reads `.agents/skills` and `AGENTS.md` natively — it is the *best*-positioned of the three for a tool-neutral layout, because `.agents/` is exactly the convention it already discovers.

## Approaches considered

**Per-tool adapters over the existing Claude-native store.** Keep `~/.claude/projects/<slug>/memory/` canonical; teach Codex and Kimi to read it through generated pointer files. Rejected: it enshrines one vendor's private path as the source of truth, breaks the moment a colleague doesn't have Claude installed, and still leaves nothing to share.

**Full abstraction layer — a `shadow-learn` daemon or MCP server that serves memory to any client.** Rejected on YAGNI. The store is a handful of markdown files; a server adds a process, a protocol, and a failure mode to solve a problem that a directory path already solves.

**Move the store into the repo under `.agents/`, keep skills as portable markdown, add one normalizer script for transcripts.** Selected. It removes the vendor path instead of routing around it, matches the convention Kimi already discovers, makes learning shareable with colleagues (the actual motivation), and confines all remaining tool-specific code to a single script with one function per tool.

## Architecture

Two directory trees are involved and the spec distinguishes them throughout: the **toolkit repo** (this repo — ships `skills/`, `bootstrap-patterns/`, `bin/`, the setup scripts) and the **target project** (where a user runs `init`). `init` copies from the former into the latter. The tree below is a target project after `init`.

Skills are installed **user-globally**, the store is **per-project**. Conflating the two would break the moment a second project exists, since `~/.claude/skills/<name>` can only resolve to one location.

```
~/.agents/                        # user-global, tool-neutral
├── skills/                       # canonical skill source; Kimi reads natively
│   ├── session-knowledge-extract/
│   ├── memory-consolidate/
│   └── start-research-thread/
└── bin/session-turns             # transcript normalizer (the only tool-aware code)

~/.claude/skills/<name>  -> ~/.agents/skills/<name>   (symlink)
~/.codex/skills/<name>   -> ~/.agents/skills/<name>   (symlink)

target project/
├── AGENTS.md                     # canonical instructions — all three tools read this
├── CLAUDE.md                     # thin: points at AGENTS.md, plus Claude-only extras
├── .agents/
│   ├── memory/
│   │   ├── MEMORY.md             # index, <200 lines
│   │   ├── patterns/*.md         # domain rules, <150 lines each
│   │   ├── entities/*.md         # per-person/service context
│   │   └── extracted-knowledge.md
│   └── skills/                   # optional: project-specific learning skills
│       └── thesis-review/
└── docs/playbooks/*.md
```

In the toolkit repo the skill sources stay at `skills/` and the normalizer is authored at `bin/session-turns`; `init` copies both into `~/.agents/`.

One source of truth per skill; an edit is live in all three tools without a re-sync step. Project-specific learning skills (the `_template` descendants — `thesis-review` and its kin) go in the project's own `.agents/skills/`, which Kimi discovers natively and which Claude and Codex reach through their project skill dirs (`.claude/skills`, `.codex/skills`) symlinked to it — a per-project link, so no collision.

### Components

**`AGENTS.md` — the single instruction surface.** Carries the shadow-learning bootstrap that today lives in `CLAUDE.md`: read `.agents/memory/patterns/*.md` and `.agents/memory/entities/*.md` before judgment work, read `docs/playbooks/*.md` for procedures, note corrections explicitly. `CLAUDE.md` shrinks to a reference to `AGENTS.md` plus anything genuinely Claude-only. Kimi and Codex pick up `AGENTS.md` with no configuration.

**`.agents/memory/` — the store.** Same taxonomy as today, relocated. Being in the repo makes it reviewable in PRs and shareable across a team — the point of the exercise. Teams that want it private add `.agents/memory/` to `.gitignore`; `init` asks and writes that line if declined, so the choice is explicit rather than accidental. Student names, client details, and similar content are the reason this prompt exists rather than a default.

**`~/.agents/bin/session-turns` — the transcript normalizer.** A single Python script (`#!/usr/bin/env python3`), stdlib only. Interface:

```
session-turns [--tool claude|codex|kimi|auto] [--since 1d] [--project PATH] [--max-sessions N]
```

Writes to stdout a normalized stream the extraction skill can classify without knowing which tool produced it:

```
--- [kimi 2026-08-23T15:40]
We always use pnpm, never npm
--- [claude 2026-08-23T14:02]
Don't put API calls in pages. They go in features/*/api/.
```

`--tool auto` (the default) probes for each tool's session root and reads whichever exist. `--project` defaults to `$PWD`; each reader filters to sessions whose working directory matches, using the mechanism the tool provides — Claude's slug-encoded directory name, Codex's `session_meta.payload.cwd`, Kimi's `session_index.jsonl` `workDir` field.

One reader function per tool, each returning `(timestamp, text)` pairs:

- *Claude* — `~/.claude/projects/<slug>/*.jsonl`, excluding `history.jsonl`. Lines with `message.role == "user"`; content is a string or a list of blocks, keeping `type == "text"`. This is the existing inline logic, lifted out of the skill unchanged.
- *Codex* — `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`. Line 1 is `session_meta`; read `payload.cwd` to filter. User turns appear in more than one shape across versions, so accept both `{"type":"event_msg","payload":{"type":"user_message","message":…}}` and `{"type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":…}]}}`. Drop synthetic turns wrapped in `<user_instructions>` or `<environment_context>` — those are injected context, not things the user said.
- *Kimi* — resolve session directories for the project through `~/.kimi-code/session_index.jsonl` (`workDir` field), then read `wire.jsonl` for `message.type == "TurnBegin"` and take `payload.user_input`. `wire.jsonl` is preferred over `context.jsonl` because compaction rewrites the latter, dropping earlier turns. Fall back to the legacy `~/.kimi/sessions/` layout when `~/.kimi-code` is absent.

Unknown line shapes, unreadable files, and missing tool directories are skipped silently per-item; the script never aborts a run because one tool is absent or one line is malformed. It exits 0 with empty output when nothing matches, and reports counts per tool on stderr so a human can tell "no signal" from "reader broken".

**Skills.** Installed to `~/.agents/skills/`. `session-knowledge-extract` loses its hardcoded paths: Step 1–2 become "run `~/.agents/bin/session-turns --since 1d`", and Step 6 targets `.agents/memory/extracted-knowledge.md` in the current project. `memory-consolidate` and `_template` get the same path substitution. Skill *content* — the classifier, the destination rules, the "different senior dev" test — is unchanged; it was already tool-agnostic.

**`shadow-learn.sh` / `.ps1`.** Commands change as follows.

- `init` creates `.agents/memory/{patterns,entities}` and `docs/playbooks/` in the project, seeds bootstrap patterns, writes `AGENTS.md`, reduces `CLAUDE.md` to a pointer, installs skills and `session-turns` into `~/.agents/`, then links `~/.agents/skills/*` into every detected tool's user skills directory. Detection is directory presence: `~/.claude`, `~/.codex`, `~/.kimi-code` (or `~/.kimi`). Kimi needs no link — it reads `~/.agents/skills` directly — so `init` reports it as "native". Symlinks on POSIX; the PowerShell script copies, because symlink creation on Windows needs elevation or developer mode.
- `health` reports per tool: instruction file present, skills reachable, transcript reader finding sessions. Existing budget and staleness checks keep working against the new paths.
- `migrate` (new) copies an existing `~/.claude/projects/<slug>/memory/` into `.agents/memory/`, leaving the original untouched, and prompts about `.gitignore`. Idempotent: existing destination files are kept, not overwritten.
- `install-hooks` gains a tool argument. Claude keeps the current `Stop` hook in `.claude/settings.local.json`. Kimi gets a `SessionEnd` entry in `~/.kimi-code/config.toml` invoking `kimi -p`. Codex hook wiring is documented rather than automated — its hook schema is the one thing here I could not verify against an installed binary, and writing an unverified TOML block into a colleague's config is worse than a README paragraph.

### Data flow

```
user corrects agent (any tool)
        ↓
transcript written by that tool
        ↓
~/.agents/bin/session-turns --since 1d   ← only tool-aware step
        ↓  normalized turns
/session-knowledge-extract  (classify, dedupe, tag destinations)
        ↓
.agents/memory/extracted-knowledge.md
        ↓
/memory-consolidate  (route, merge, prune)
        ↓
.agents/memory/patterns/*.md, entities/*.md, docs/playbooks/*.md
        ↓
read at start of next session by any tool, via AGENTS.md
```

### Error handling

Absent tools are normal, not errors — `session-turns` skips a missing session root and says so on stderr. Malformed JSONL lines are skipped individually. `init` never overwrites an existing skill, pattern, or `AGENTS.md`; it reports "already present (kept local edits)", matching current behavior. A symlink target that already exists as a real directory is left alone with a warning rather than clobbered, so an existing `~/.claude/skills/session-knowledge-extract` install is never destroyed. `migrate` refuses to run if `.agents/memory/` already has content unless given `--merge`.

## Testing

`session-turns` is the only new logic, so it carries the tests. It takes overridable session-root environment variables (`SL_CLAUDE_HOME`, `SL_CODEX_HOME`, `SL_KIMI_HOME`) so tests can point it at fixtures without touching the real `$HOME`. Fixtures under `tests/fixtures/sessions/` gain one synthetic transcript per tool — Claude and Kimi fixtures derived from real local files with content replaced, Codex from the documented schema in both accepted shapes. A shell test runs the normalizer against each fixture directory and asserts the extracted turns, exercising: correct user-turn extraction per tool, project filtering, `--since` filtering, malformed-line tolerance, missing-tool tolerance, and the `<user_instructions>` exclusion for Codex.

`shadow-learn.sh init` and `migrate` get a test that runs them against a scratch `HOME` and repo and asserts the resulting tree, including that a second `init` changes nothing.

The Codex reader is the one component without a live end-to-end check. It is written tolerantly against both documented shapes and marked in the README as needing confirmation from a Codex user; the fixture tests pin the parsing behavior so a real-world mismatch is a fixture fix, not a rewrite.

## Out of scope

Automated Codex hook installation. Migration of existing colleagues' stores from other tools. Any sync of `.agents/memory/` between machines beyond git. Gemini CLI, Cursor, and other tools — the `.agents/` layout accommodates them, but adding readers before someone needs one is speculative.

## Success criteria

- A colleague who uses only Codex, or only Kimi, can clone the repo, run `init`, and get pattern-aware behavior with no Claude Code installed.
- Corrections made in any of the three tools are picked up by one `/session-knowledge-extract` run.
- Editing a skill once takes effect in all installed tools with no re-sync.
- Adding a fourth tool means one reader function and one detection entry.
