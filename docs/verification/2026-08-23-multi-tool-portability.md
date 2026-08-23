# Manual Verification: Multi-Tool Portability

Verifies that shadow learning works under Claude Code, Codex CLI, and Kimi Code from one
installation. Every step is copy-paste runnable. Results from the 2026-08-23 run are at the
bottom.

Run the automated tests first — they cover the transcript normalizer in isolation:

```bash
./tests/run-tests.sh
```

Expected: `35 passed, 0 failed`.

## Fresh install with several tools present

```bash
SCRATCH=$(mktemp -d)
mkdir -p "$SCRATCH/home/.claude" "$SCRATCH/home/.codex" "$SCRATCH/proj"
(cd "$SCRATCH/proj" && git init -q)
(cd "$SCRATCH/proj" && HOME="$SCRATCH/home" /path/to/claude-shadow-learn/shadow-learn.sh init -y)
```

Expected: `claude → .../.claude/skills`, `codex → .../.codex/skills`, `Created AGENTS.md`,
`CLAUDE.md points at AGENTS.md`.

Check the tree and the symlink targets:

```bash
ls -l "$SCRATCH/home/.claude/skills/"
find "$SCRATCH/proj" -not -path '*/.git/*' -not -name '.git' | sort
```

Expected: three symlinks per tool pointing into `$SCRATCH/home/.agents/skills/`; the project
holds `AGENTS.md`, `CLAUDE.md`, `.agents/memory/{patterns,entities}`, and `docs/playbooks/`.

## Fresh install with only Kimi present

The claim under test: a colleague with no Claude Code and no Codex still gets a working setup.

```bash
K=$(mktemp -d)
mkdir -p "$K/home/.kimi-code" "$K/proj"
(cd "$K/proj" && HOME="$K/home" /path/to/claude-shadow-learn/shadow-learn.sh init -y)
ls -a "$K/home"
test -f "$K/proj/CLAUDE.md" && echo "CLAUDE.md created (wrong)" || echo "no CLAUDE.md (correct)"
ls "$K/home/.agents/skills/"
```

Expected: `kimi → reads ~/.agents/skills natively (no link needed)`; `$K/home` contains only
`.agents` and `.kimi-code` — no `.claude` or `.codex` conjured up; no `CLAUDE.md` in a project
whose user has no Claude Code; all three skills present in `~/.agents/skills/`.

## Re-running init

```bash
(cd "$SCRATCH/proj" && HOME="$SCRATCH/home" /path/to/claude-shadow-learn/shadow-learn.sh init -y)
```

Expected: `already present (kept local edits)` for patterns, subagents, and `AGENTS.md`;
`CLAUDE.md already points at AGENTS.md`; no duplicated content anywhere.

## The privacy prompt

```bash
P=$(mktemp -d)
mkdir -p "$P/home/.claude" "$P/proj"
(cd "$P/proj" && git init -q)
(cd "$P/proj" && printf 'n\n' | HOME="$P/home" /path/to/claude-shadow-learn/shadow-learn.sh init)
cat "$P/proj/.gitignore"
```

Expected: `.agents/memory/` in `.gitignore`. Re-run and confirm the line appears exactly once:

```bash
(cd "$P/proj" && printf 'n\n' | HOME="$P/home" /path/to/claude-shadow-learn/shadow-learn.sh init) >/dev/null
grep -c '^\.agents/memory/$' "$P/proj/.gitignore"
```

Expected: `1`.

## Existing skill directories are never clobbered

Run `init` with a real `~/.claude/skills/session-knowledge-extract` already present as a real
directory rather than a symlink.

Expected: `⚠ .../session-knowledge-extract exists and is not a symlink — left alone`, and the
original directory untouched. Losing a hand-edited skill to an install script is worse than
leaving it unlinked.

## migrate

```bash
S=$(mktemp -d); PROJ="$S/proj"; SLUG=$(echo "$PROJ" | tr '/' '-')
mkdir -p "$S/home/.claude/projects/$SLUG/memory/patterns" "$PROJ"
echo "- Reviews go in Russian" > "$S/home/.claude/projects/$SLUG/memory/patterns/review.md"
echo "# Index" > "$S/home/.claude/projects/$SLUG/memory/MEMORY.md"

(cd "$PROJ" && HOME="$S/home" /path/to/claude-shadow-learn/shadow-learn.sh migrate)
```

Expected: `MEMORY.md` and `patterns/review.md` copied, `2 copied, 0 kept`, the original reported
as left intact, and the warning about names and client details.

Refusal when the destination already has content:

```bash
(cd "$PROJ" && HOME="$S/home" /path/to/claude-shadow-learn/shadow-learn.sh migrate); echo "rc=$?"
```

Expected: `already has content`, `rc=1`.

Merge:

```bash
(cd "$PROJ" && HOME="$S/home" /path/to/claude-shadow-learn/shadow-learn.sh migrate --merge)
```

Expected: both files reported as `already present (kept)`, `0 copied, 2 kept`.

## health

```bash
(cd "$SCRATCH/proj" && HOME="$SCRATCH/home" /path/to/claude-shadow-learn/shadow-learn.sh health)
```

Expected: `AGENTS.md points at the knowledge store`, one `skills linked` line per detected tool,
and a `session-turns:` line carrying the per-tool turn counts. Run it again in a project with no
setup and confirm it reports what is missing instead of crashing.

## Kimi session-end hook

Kimi ships `hooks = []` in `config.toml`. Appending a `[[hooks]]` table alongside that key is a
TOML duplicate and would corrupt the file, so the installer removes the empty array first.

```bash
printf 'default_model = "x"\nhooks = []\ntelemetry = true\n' > "$SCRATCH/home/.kimi-code/config.toml"
HOME="$SCRATCH/home" /path/to/claude-shadow-learn/shadow-learn.sh install-hooks kimi
python3 -c "import tomllib; print(tomllib.load(open('$SCRATCH/home/.kimi-code/config.toml','rb'))['hooks'])"
```

Expected: the hook installed, and the config still parses as valid TOML.

A non-empty inline array must be refused rather than mangled:

```bash
printf 'hooks = [{ event = "Stop", command = "x" }]\n' > "$SCRATCH/home/.kimi-code/config.toml"
HOME="$SCRATCH/home" /path/to/claude-shadow-learn/shadow-learn.sh install-hooks kimi; echo "rc=$?"
```

Expected: refusal with instructions to merge by hand, `rc=1`, file unmodified.

## The cross-tool round trip

This is the load-bearing check — everything else is scaffolding for it. A correction stated in
one tool must be readable from another.

```bash
V=$(mktemp -d)/verify-proj; mkdir -p "$V"; (cd "$V" && git init -q)
(cd "$V" && /path/to/claude-shadow-learn/shadow-learn.sh init -y)

cd "$V" && kimi -p "Note this project convention and reply with one short sentence, no tool calls: we always use uv for Python here, never pip."

cd "$V" && ~/.agents/bin/session-turns --since 1d
```

Expected: the Kimi turn appears, tagged `[kimi ...]`, in a shell that is not Kimi. Then open
Claude Code in the same directory and run `/session-knowledge-extract`; the Kimi-originated
correction should reach `.agents/memory/extracted-knowledge.md`.

## No sessions at all

```bash
N=$(mktemp -d)
(cd "$N" && ~/.agents/bin/session-turns --since 1d >/tmp/out.txt 2>/tmp/err.txt); echo "exit=$?"
wc -c </tmp/out.txt; cat /tmp/err.txt
```

Expected: exit `0`, empty stdout, and a per-tool line on stderr. An empty result must be
distinguishable from a broken reader — that is what the stderr counts are for.

## Results — 2026-08-23

| Check | Result |
|---|---|
| Automated tests | Pass — 35 passed, 0 failed |
| Fresh install, Claude + Codex | Pass — symlinks correct, tree correct |
| Fresh install, Kimi only | Pass — no foreign tool dirs created, no spurious CLAUDE.md |
| Re-running init | Pass — idempotent, no duplicates |
| Privacy prompt | Pass — `.gitignore` written once |
| Existing skills not clobbered | Pass — verified against the real `~/.claude/skills` |
| migrate / refusal / --merge | Pass — all three |
| health | Pass — 7 OK, 3 WARN, 0 MISSING on a fresh install |
| Kimi hook install | Pass — valid TOML after install; inline array refused |
| **Cross-tool round trip** | **Pass** — a real `kimi -p` turn read back by `session-turns` |
| No sessions | Pass — exit 0, empty stdout, counts on stderr |
| PowerShell script | **Not run** — no `pwsh` on this machine |
| Codex reader | **Not run against a live install** — fixture-tested only |

### What the live run changed

Two defects surfaced only because the round trip was run for real, and neither would have been
caught by the fixture tests as originally written:

- **Kimi's session layout had moved.** The reader was built from a migrated `~/.kimi` session,
  which stores `wire.jsonl` at the session root using a `TurnBegin` protocol. Kimi Code 0.18
  writes `agents/main/wire.jsonl` using `turn.prompt` with millisecond timestamps. The first
  live round trip returned zero turns. The reader now handles both layouts, newest first, and
  stops at the first one that exists so a migrated session is not counted twice.
- **Claude Code records harness plumbing as user turns.** Skill bodies loaded by the Skill tool,
  `<system-reminder>` blocks, and slash-command expansions all carry `role: "user"`. Left
  unfiltered they swamped the real turns — a single session emitted the skill text of every
  skill invoked. They are now dropped by prefix.

### Remaining gaps

**Codex is not installed here.** Its reader is written against the documented rollout format and
accepts both user-message shapes seen across versions, but no live Codex session has been read.
Given that the Kimi reader — also written from real data, just from the wrong version — was
wrong until a live run corrected it, treat the Codex reader as unproven. A Codex user should run
the round trip above with `codex` in place of `kimi` and report what `session-turns --tool codex`
returns.

**PowerShell is unverified.** `shadow-learn.ps1` mirrors the bash script's behavior, substituting
copies for symlinks because Windows symlink creation needs elevation or developer mode. It was
checked statically only: balanced braces, no references to removed variables, every dispatched
function defined. No `pwsh` was available to execute it.
