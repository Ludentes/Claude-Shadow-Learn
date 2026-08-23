# Multi-Tool Portability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make shadow learning work identically under Claude Code, Codex CLI, and Kimi Code from one installation.

**Architecture:** The knowledge store moves out of Claude's private `~/.claude/projects/<slug>/memory/` into the target project's `.agents/memory/`, reachable by all three tools through a single `AGENTS.md`. Skills install user-globally to `~/.agents/skills/` and are symlinked into each detected tool's skills directory. All remaining tool-specific code is confined to one new script, `~/.agents/bin/session-turns`, which normalizes each tool's session transcripts into a common stream of user turns.

**Tech Stack:** Bash, PowerShell, Python 3 (stdlib only), Markdown.

Spec: `docs/superpowers/specs/2026-08-23-multi-tool-portability-design.md`

---

## File Structure

**New files:**

| Path | Responsibility |
|---|---|
| `bin/session-turns` | Python 3 transcript normalizer. One reader function per tool, one dispatcher, one CLI. The only tool-aware code in the project. |
| `tests/run-tests.sh` | Minimal shell test runner (assert helpers + discovery). The repo has no automated runner today; this is the first. |
| `tests/test-session-turns.sh` | Behavioral tests for the normalizer against fixtures. |
| `tests/fixtures/tools/claude/projects/-tmp-proj/session-a.jsonl` | Claude fixture transcript. |
| `tests/fixtures/tools/codex/sessions/2026/08/23/rollout-2026-08-23T10-00-00-aaa.jsonl` | Codex fixture, `event_msg` user shape. |
| `tests/fixtures/tools/codex/sessions/2026/08/23/rollout-2026-08-23T11-00-00-bbb.jsonl` | Codex fixture, `response_item` user shape + `<user_instructions>` noise + a foreign cwd. |
| `tests/fixtures/tools/kimi/session_index.jsonl` | Kimi session index. |
| `tests/fixtures/tools/kimi/sessions/wd_proj_abc/ses_1/wire.jsonl` | Kimi fixture transcript. |
| `AGENTS.md.template` | The tool-neutral bootstrap `init` writes into a target project. |

**Modified files:**

| Path | Change |
|---|---|
| `shadow-learn.sh` | Paths → `.agents/memory/`; install to `~/.agents/`; multi-tool symlinking; new `migrate`; tool-aware `health` and `install-hooks`. |
| `shadow-learn.ps1` | Same, with copies instead of symlinks. |
| `skills/session-knowledge-extract/SKILL.md` | Steps 1–2 delegate to `session-turns`; paths → `.agents/memory/`. |
| `skills/memory-consolidate/SKILL.md` | Paths → `.agents/memory/`. |
| `skills/_template/SKILL.md` | Paths → `.agents/memory/`. |
| `skills/start-research-thread/SKILL.md` | Paths → `.agents/memory/`. |
| `AGENTS.md` | Becomes the full bootstrap (this repo eats its own dog food). |
| `CLAUDE.md` | Reduced to a pointer at `AGENTS.md`. |
| `README.md`, `GETTING_STARTED.md` | Multi-tool install, store relocation, migration, per-tool support matrix. |

---

## Task 1: Test runner scaffold

**Files:**
- Create: `tests/run-tests.sh`

- [ ] **Step 1: Write the runner**

```bash
#!/usr/bin/env bash
# Minimal test runner. Sources every tests/test-*.sh and reports results.
set -uo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_DIR="$(dirname "$TESTS_DIR")"
export REPO_DIR TESTS_DIR

PASS=0
FAIL=0
CURRENT=""

it() { CURRENT="$1"; }

assert_eq() {
  local expected="$1" actual="$2"
  if [ "$expected" = "$actual" ]; then
    PASS=$((PASS + 1))
    echo "  ok   $CURRENT"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL $CURRENT"
    echo "    expected: [$expected]"
    echo "    actual:   [$actual]"
  fi
}

assert_contains() {
  local haystack="$1" needle="$2"
  if [[ "$haystack" == *"$needle"* ]]; then
    PASS=$((PASS + 1))
    echo "  ok   $CURRENT"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL $CURRENT"
    echo "    expected to contain: [$needle]"
    echo "    actual:              [$haystack]"
  fi
}

assert_not_contains() {
  local haystack="$1" needle="$2"
  if [[ "$haystack" != *"$needle"* ]]; then
    PASS=$((PASS + 1))
    echo "  ok   $CURRENT"
  else
    FAIL=$((FAIL + 1))
    echo "  FAIL $CURRENT"
    echo "    expected NOT to contain: [$needle]"
    echo "    actual:                  [$haystack]"
  fi
}

for test_file in "$TESTS_DIR"/test-*.sh; do
  [ -e "$test_file" ] || continue
  echo "$(basename "$test_file")"
  # shellcheck disable=SC1090
  source "$test_file"
done

echo ""
echo "$PASS passed, $FAIL failed"
[ "$FAIL" -eq 0 ]
```

- [ ] **Step 2: Make it executable and run it**

Run: `chmod +x tests/run-tests.sh && ./tests/run-tests.sh`
Expected: prints `0 passed, 0 failed` and exits 0 (no test files yet).

- [ ] **Step 3: Commit**

```bash
git add tests/run-tests.sh
git commit -m "test: add minimal shell test runner"
```

---

## Task 2: Claude reader

**Files:**
- Create: `bin/session-turns`
- Create: `tests/fixtures/tools/claude/projects/-tmp-proj/session-a.jsonl`
- Create: `tests/test-session-turns.sh`

Claude stores one directory per project under `~/.claude/projects/`, named by replacing `/` with `-` in the absolute project path. User turns are lines with `message.role == "user"`; `message.content` is either a string or a list of blocks where only `type == "text"` blocks carry user text.

- [ ] **Step 1: Write the Claude fixture**

```bash
mkdir -p tests/fixtures/tools/claude/projects/-tmp-proj
cat > tests/fixtures/tools/claude/projects/-tmp-proj/session-a.jsonl <<'EOF'
{"type":"user","message":{"role":"user","content":"We always use pnpm in this project, never npm."}}
{"type":"assistant","message":{"role":"assistant","content":"Understood."}}
{"type":"user","message":{"role":"user","content":[{"type":"text","text":"Don't put API calls in pages. They go in features/*/api/."},{"type":"image","source":{}}]}}
{"type":"user","message":{"role":"user","content":[{"type":"tool_result","content":"ignored tool output"}]}}
not json at all
{"type":"user","message":{"role":"user","content":"ok"}}
EOF
```

The `tool_result`-only turn and the malformed line must produce no output. `"ok"` is deliberately kept — length filtering is the extraction skill's job, not the normalizer's.

- [ ] **Step 2: Write the failing test**

Create `tests/test-session-turns.sh`:

```bash
# shellcheck shell=bash
FIX="$TESTS_DIR/fixtures/tools"
ST="$REPO_DIR/bin/session-turns"

run_st() {
  SL_CLAUDE_HOME="$FIX/claude" \
  SL_CODEX_HOME="$FIX/codex" \
  SL_KIMI_HOME="$FIX/kimi" \
  python3 "$ST" "$@" 2>/dev/null
}

out=$(run_st --tool claude --project /tmp/proj --since 100000d)

it "claude: extracts a plain string user turn"
assert_contains "$out" "We always use pnpm in this project, never npm."

it "claude: extracts text blocks from list content"
assert_contains "$out" "Don't put API calls in pages."

it "claude: skips assistant turns"
assert_not_contains "$out" "Understood."

it "claude: skips tool_result-only turns"
assert_not_contains "$out" "ignored tool output"

it "claude: tags turns with the tool name"
assert_contains "$out" "--- [claude"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `./tests/run-tests.sh`
Expected: FAIL on every assertion — `bin/session-turns` does not exist, so `run_st` outputs nothing.

- [ ] **Step 4: Write the minimal implementation**

Create `bin/session-turns`:

```python
#!/usr/bin/env python3
"""Normalize AI coding-tool session transcripts into a common stream of user turns.

Emits, oldest first:

    --- [<tool> <ISO-8601 minute>]
    <user turn text>

Every reader is best-effort: unreadable files, unknown line shapes, and absent
tools are skipped rather than raised. Per-tool counts go to stderr so a caller
can distinguish "no signal" from "reader broken".
"""

import argparse
import json
import os
import re
import sys
import time
from pathlib import Path

MAX_TURN_CHARS = 800


def home(env_var, default):
    """Session root for a tool, overridable for tests."""
    return Path(os.environ.get(env_var, os.path.expanduser(default)))


def read_lines(path):
    """Yield parsed JSON objects from a JSONL file, skipping bad lines."""
    try:
        with open(path, "r", encoding="utf-8", errors="replace") as handle:
            for line in handle:
                line = line.strip()
                if not line:
                    continue
                try:
                    yield json.loads(line)
                except (ValueError, TypeError):
                    continue
    except OSError:
        return


def text_from_content(content):
    """Claude/Codex content is a string or a list of typed blocks."""
    if isinstance(content, str):
        return content
    if not isinstance(content, list):
        return ""
    parts = []
    for block in content:
        if not isinstance(block, dict):
            continue
        if block.get("type") in ("text", "input_text", "output_text"):
            parts.append(block.get("text", ""))
    return " ".join(p for p in parts if p)


def read_claude(root, project, cutoff):
    slug = str(project).replace("/", "-")
    session_dir = root / "projects" / slug
    if not session_dir.is_dir():
        return
    for path in sorted(session_dir.glob("*.jsonl")):
        if path.name == "history.jsonl":
            continue
        if path.stat().st_mtime < cutoff:
            continue
        stamp = path.stat().st_mtime
        for obj in read_lines(path):
            message = obj.get("message", obj)
            if not isinstance(message, dict) or message.get("role") != "user":
                continue
            text = text_from_content(message.get("content", "")).strip()
            if text:
                yield stamp, text


READERS = {"claude": read_claude}


def parse_since(value):
    match = re.fullmatch(r"(\d+)([dh])", value)
    if not match:
        raise argparse.ArgumentTypeError("--since must look like 7d or 12h")
    amount = int(match.group(1))
    seconds = amount * (86400 if match.group(2) == "d" else 3600)
    return time.time() - seconds


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--tool", default="auto",
                        choices=["auto"] + sorted(READERS))
    parser.add_argument("--since", default="1d", type=parse_since)
    parser.add_argument("--project", default=os.getcwd())
    parser.add_argument("--max-sessions", type=int, default=15)
    args = parser.parse_args()

    project = Path(args.project).resolve()
    tools = sorted(READERS) if args.tool == "auto" else [args.tool]

    roots = {
        "claude": home("SL_CLAUDE_HOME", "~/.claude"),
    }

    turns = []
    for tool in tools:
        root = roots[tool]
        if not root.is_dir():
            print(f"{tool}: not installed", file=sys.stderr)
            continue
        found = list(READERS[tool](root, project, args.since))
        print(f"{tool}: {len(found)} user turns", file=sys.stderr)
        turns.extend((stamp, tool, text) for stamp, text in found)

    turns.sort(key=lambda item: item[0])
    for stamp, tool, text in turns:
        when = time.strftime("%Y-%m-%dT%H:%M", time.localtime(stamp))
        print(f"--- [{tool} {when}]")
        print(text[:MAX_TURN_CHARS])


if __name__ == "__main__":
    main()
```

- [ ] **Step 5: Run test to verify it passes**

Run: `chmod +x bin/session-turns && ./tests/run-tests.sh`
Expected: `5 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add bin/session-turns tests/test-session-turns.sh tests/fixtures/tools/claude
git commit -m "feat: add session-turns normalizer with Claude reader"
```

---

## Task 3: Codex reader

**Files:**
- Modify: `bin/session-turns` (add `read_codex`, register it)
- Create: `tests/fixtures/tools/codex/sessions/2026/08/23/rollout-2026-08-23T10-00-00-aaa.jsonl`
- Create: `tests/fixtures/tools/codex/sessions/2026/08/23/rollout-2026-08-23T11-00-00-bbb.jsonl`
- Modify: `tests/test-session-turns.sh`

Codex writes `~/.codex/sessions/YYYY/MM/DD/rollout-*.jsonl`. Line 1 is `session_meta`, whose `payload.cwd` identifies the project. User turns appear in two shapes across versions; accept both. Turns wrapped in `<user_instructions>` or `<environment_context>` are injected context, not user speech.

- [ ] **Step 1: Write the Codex fixtures**

```bash
mkdir -p tests/fixtures/tools/codex/sessions/2026/08/23
cat > tests/fixtures/tools/codex/sessions/2026/08/23/rollout-2026-08-23T10-00-00-aaa.jsonl <<'EOF'
{"timestamp":"2026-08-23T10:00:00Z","type":"session_meta","payload":{"id":"aaa","cwd":"/tmp/proj"}}
{"timestamp":"2026-08-23T10:01:00Z","type":"event_msg","payload":{"type":"user_message","message":"Cut the intro to two pages."}}
{"timestamp":"2026-08-23T10:02:00Z","type":"event_msg","payload":{"type":"agent_message","message":"Shortening the intro."}}
EOF
cat > tests/fixtures/tools/codex/sessions/2026/08/23/rollout-2026-08-23T11-00-00-bbb.jsonl <<'EOF'
{"timestamp":"2026-08-23T11:00:00Z","type":"session_meta","payload":{"id":"bbb","cwd":"/tmp/proj"}}
{"timestamp":"2026-08-23T11:01:00Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"<user_instructions>be terse</user_instructions>"}]}}
{"timestamp":"2026-08-23T11:02:00Z","type":"response_item","payload":{"type":"message","role":"user","content":[{"type":"input_text","text":"Deploys must wait for CI green."}]}}
{"timestamp":"2026-08-23T11:03:00Z","type":"response_item","payload":{"type":"message","role":"assistant","content":[{"type":"output_text","text":"Noted."}]}}
EOF
cat > tests/fixtures/tools/codex/sessions/2026/08/23/rollout-2026-08-23T12-00-00-ccc.jsonl <<'EOF'
{"timestamp":"2026-08-23T12:00:00Z","type":"session_meta","payload":{"id":"ccc","cwd":"/tmp/other-project"}}
{"timestamp":"2026-08-23T12:01:00Z","type":"event_msg","payload":{"type":"user_message","message":"Belongs to a different project."}}
EOF
```

- [ ] **Step 2: Write the failing test**

Append to `tests/test-session-turns.sh`:

```bash
out=$(run_st --tool codex --project /tmp/proj --since 100000d)

it "codex: extracts event_msg user_message shape"
assert_contains "$out" "Cut the intro to two pages."

it "codex: extracts response_item message/input_text shape"
assert_contains "$out" "Deploys must wait for CI green."

it "codex: skips agent messages"
assert_not_contains "$out" "Shortening the intro."

it "codex: skips assistant response_items"
assert_not_contains "$out" "Noted."

it "codex: skips injected user_instructions"
assert_not_contains "$out" "be terse"

it "codex: filters sessions from other projects"
assert_not_contains "$out" "Belongs to a different project."
```

- [ ] **Step 3: Run test to verify it fails**

Run: `./tests/run-tests.sh`
Expected: the six new assertions fail — `--tool codex` is not a valid choice yet, so `run_st` exits non-zero with no output.

- [ ] **Step 4: Write the implementation**

In `bin/session-turns`, add after `read_claude`:

```python
INJECTED_PREFIXES = ("<user_instructions>", "<environment_context>")


def read_codex(root, project, cutoff):
    session_dir = root / "sessions"
    if not session_dir.is_dir():
        return
    for path in sorted(session_dir.rglob("rollout-*.jsonl")):
        if path.stat().st_mtime < cutoff:
            continue
        stamp = path.stat().st_mtime
        session_cwd = None
        for obj in read_lines(path):
            payload = obj.get("payload")
            if not isinstance(payload, dict):
                continue
            kind = obj.get("type")

            if kind == "session_meta":
                session_cwd = payload.get("cwd")
                if session_cwd and Path(session_cwd) != project:
                    break
                continue

            text = ""
            if kind == "event_msg" and payload.get("type") == "user_message":
                text = payload.get("message", "")
            elif (kind == "response_item"
                  and payload.get("type") == "message"
                  and payload.get("role") == "user"):
                text = text_from_content(payload.get("content", ""))

            text = text.strip()
            if text and not text.startswith(INJECTED_PREFIXES):
                yield stamp, text
```

Register it and add its root. Replace the `READERS` assignment with:

```python
READERS = {"claude": read_claude, "codex": read_codex}
```

and inside `main()`, extend `roots`:

```python
    roots = {
        "claude": home("SL_CLAUDE_HOME", "~/.claude"),
        "codex": home("SL_CODEX_HOME", "~/.codex"),
    }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `./tests/run-tests.sh`
Expected: `11 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add bin/session-turns tests/test-session-turns.sh tests/fixtures/tools/codex
git commit -m "feat: add Codex reader to session-turns"
```

---

## Task 4: Kimi reader

**Files:**
- Modify: `bin/session-turns` (add `read_kimi`, register it)
- Create: `tests/fixtures/tools/kimi/session_index.jsonl`
- Create: `tests/fixtures/tools/kimi/sessions/wd_proj_abc/ses_1/wire.jsonl`
- Create: `tests/fixtures/tools/kimi/sessions/wd_other_def/ses_2/wire.jsonl`
- Modify: `tests/test-session-turns.sh`

Kimi Code maps sessions to projects in `~/.kimi-code/session_index.jsonl`, one JSON object per line with `sessionDir` and `workDir`. Inside each session directory, `wire.jsonl` records events as `{"timestamp": <float>, "message": {"type": ..., "payload": {...}}}`; user turns are `type == "TurnBegin"` with `payload.user_input`. Read `wire.jsonl` rather than `context.jsonl` because compaction rewrites the latter and drops earlier turns.

- [ ] **Step 1: Write the Kimi fixtures**

```bash
mkdir -p tests/fixtures/tools/kimi/sessions/wd_proj_abc/ses_1
mkdir -p tests/fixtures/tools/kimi/sessions/wd_other_def/ses_2
cat > tests/fixtures/tools/kimi/session_index.jsonl <<'EOF'
{"sessionId":"ses_1","sessionDir":"SESSIONS/wd_proj_abc/ses_1","workDir":"/tmp/proj"}
{"sessionId":"ses_2","sessionDir":"SESSIONS/wd_other_def/ses_2","workDir":"/tmp/other-project"}
EOF
cat > tests/fixtures/tools/kimi/sessions/wd_proj_abc/ses_1/wire.jsonl <<'EOF'
{"type":"metadata","protocol_version":"1.10"}
{"timestamp":1787000000.0,"message":{"type":"TurnBegin","payload":{"user_input":"Reviews go in Russian, never English."}}}
{"timestamp":1787000060.0,"message":{"type":"AssistantMessage","payload":{"text":"Understood, Russian it is."}}}
{"timestamp":1787000120.0,"message":{"type":"TurnBegin","payload":{"user_input":"Use uv for new Python projects."}}}
EOF
cat > tests/fixtures/tools/kimi/sessions/wd_other_def/ses_2/wire.jsonl <<'EOF'
{"timestamp":1787000000.0,"message":{"type":"TurnBegin","payload":{"user_input":"Kimi turn from a different project."}}}
EOF
```

`sessionDir` in the real index holds absolute paths. The fixture uses a literal `SESSIONS/` prefix that the reader rewrites to the configured root, so the fixture stays machine-independent — see Step 4.

- [ ] **Step 2: Write the failing test**

Append to `tests/test-session-turns.sh`:

```bash
out=$(run_st --tool kimi --project /tmp/proj --since 100000d)

it "kimi: extracts TurnBegin user_input"
assert_contains "$out" "Reviews go in Russian, never English."

it "kimi: extracts every turn in a session"
assert_contains "$out" "Use uv for new Python projects."

it "kimi: skips assistant messages"
assert_not_contains "$out" "Understood, Russian it is."

it "kimi: filters sessions from other projects via session_index"
assert_not_contains "$out" "Kimi turn from a different project."

it "kimi: uses the wire timestamp, not file mtime"
assert_contains "$out" "--- [kimi 2026-"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `./tests/run-tests.sh`
Expected: the five new assertions fail — `--tool kimi` is not a valid choice yet.

- [ ] **Step 4: Write the implementation**

In `bin/session-turns`, add after `read_codex`:

```python
def read_kimi(root, project, cutoff):
    index = root / "session_index.jsonl"
    if not index.is_file():
        return
    for entry in read_lines(index):
        work_dir = entry.get("workDir")
        session_dir = entry.get("sessionDir")
        if not work_dir or not session_dir:
            continue
        if Path(work_dir) != project:
            continue
        # Fixtures use a SESSIONS/ placeholder so they stay machine-independent.
        if session_dir.startswith("SESSIONS/"):
            path = root / "sessions" / session_dir[len("SESSIONS/"):] / "wire.jsonl"
        else:
            path = Path(session_dir) / "wire.jsonl"
        if not path.is_file():
            continue
        for obj in read_lines(path):
            message = obj.get("message")
            if not isinstance(message, dict):
                continue
            if message.get("type") != "TurnBegin":
                continue
            payload = message.get("payload")
            if not isinstance(payload, dict):
                continue
            text = str(payload.get("user_input", "")).strip()
            if not text:
                continue
            stamp = obj.get("timestamp")
            if not isinstance(stamp, (int, float)):
                stamp = path.stat().st_mtime
            if stamp < cutoff:
                continue
            yield stamp, text
```

Update the registry:

```python
READERS = {"claude": read_claude, "codex": read_codex, "kimi": read_kimi}
```

and extend `roots` in `main()`, preferring the current `~/.kimi-code` layout and falling back to the legacy `~/.kimi`:

```python
    kimi_root = home("SL_KIMI_HOME", "~/.kimi-code")
    if not kimi_root.is_dir():
        legacy = Path(os.path.expanduser("~/.kimi"))
        if legacy.is_dir():
            kimi_root = legacy

    roots = {
        "claude": home("SL_CLAUDE_HOME", "~/.claude"),
        "codex": home("SL_CODEX_HOME", "~/.codex"),
        "kimi": kimi_root,
    }
```

- [ ] **Step 5: Run test to verify it passes**

Run: `./tests/run-tests.sh`
Expected: `16 passed, 0 failed`.

- [ ] **Step 6: Commit**

```bash
git add bin/session-turns tests/test-session-turns.sh tests/fixtures/tools/kimi
git commit -m "feat: add Kimi Code reader to session-turns"
```

---

## Task 5: Auto-detection, ordering, and tolerance

**Files:**
- Modify: `tests/test-session-turns.sh`

The behavior already exists from Tasks 2–4; these tests pin it so a later refactor cannot silently break the cross-tool contract.

- [ ] **Step 1: Write the tests**

Append to `tests/test-session-turns.sh`:

```bash
out=$(run_st --project /tmp/proj --since 100000d)

it "auto: reads every installed tool"
assert_contains "$out" "We always use pnpm in this project, never npm."

it "auto: includes codex turns"
assert_contains "$out" "Deploys must wait for CI green."

it "auto: includes kimi turns"
assert_contains "$out" "Use uv for new Python projects."

missing=$(SL_CLAUDE_HOME="$FIX/claude" \
          SL_CODEX_HOME="/nonexistent/codex" \
          SL_KIMI_HOME="/nonexistent/kimi" \
          python3 "$ST" --project /tmp/proj --since 100000d 2>/dev/null)

it "auto: tolerates absent tools"
assert_contains "$missing" "We always use pnpm in this project, never npm."

it "auto: absent tool contributes nothing"
assert_not_contains "$missing" "Deploys must wait for CI green."

stderr=$(SL_CLAUDE_HOME="$FIX/claude" \
         SL_CODEX_HOME="/nonexistent/codex" \
         SL_KIMI_HOME="$FIX/kimi" \
         python3 "$ST" --project /tmp/proj --since 100000d 2>&1 >/dev/null)

it "auto: reports absent tools on stderr"
assert_contains "$stderr" "codex: not installed"

it "auto: reports per-tool counts on stderr"
assert_contains "$stderr" "kimi: 2 user turns"

recent=$(run_st --project /tmp/proj --since 1h)

it "since: excludes old sessions"
assert_eq "" "$recent"

it "empty result exits 0"
run_st --project /tmp/nothing-here --since 1h >/dev/null
assert_eq "0" "$?"
```

- [ ] **Step 2: Run tests**

Run: `./tests/run-tests.sh`
Expected: `25 passed, 0 failed`.

If `since: excludes old sessions` fails because the fixture files were just created and so have a recent mtime, fix it by backdating the Codex and Claude fixtures in the test setup rather than by loosening the assertion. Add this immediately below the `run_st` definition at the top of `tests/test-session-turns.sh`:

```bash
# Backdate fixtures so --since filtering is testable.
find "$FIX" -name '*.jsonl' -exec touch -d '30 days ago' {} +
```

Then re-run. Kimi's turns are excluded by their in-file timestamps, which are already historical.

- [ ] **Step 3: Commit**

```bash
git add tests/test-session-turns.sh
git commit -m "test: pin auto-detection, ordering, and tolerance behavior"
```

---

## Task 6: AGENTS.md template and this repo's own instruction files

**Files:**
- Create: `AGENTS.md.template`
- Modify: `AGENTS.md`
- Modify: `CLAUDE.md`

- [ ] **Step 1: Write the template**

```bash
cat > AGENTS.md.template <<'EOF'
# AGENTS.md

This project uses shadow learning: the agent reads learned patterns before
judgment work, and the user's corrections become new patterns.

Works with Claude Code, Codex CLI, and Kimi Code. All three read this file.

## Before work that involves judgment

Read these first — reviews, architecture decisions, and writing all depend on them:

- `.agents/memory/patterns/*.md` — domain rules learned from past corrections
- `.agents/memory/entities/*.md` — context about people, services, and systems
- `docs/playbooks/*.md` — repeatable procedures (deploy, setup, release)

## When the user corrects you

Note the correction explicitly in your reply. Corrections are the input to
learning; an unremarked correction is a lost pattern.

## Maintaining the store

- `session-turns` normalizes transcripts from any supported tool
- `/session-knowledge-extract` stages new knowledge to `.agents/memory/extracted-knowledge.md`
- `/memory-consolidate` routes staged entries to patterns, entities, and playbooks

## Conventions

- Hard rules (import order, commit format) belong in linters and hooks, not here
- Memory is for things requiring judgment — tone, structure, quality bar
- Keep instruction files concise; long files degrade agent performance
EOF
```

- [ ] **Step 2: Adopt it in this repo**

```bash
cp AGENTS.md.template AGENTS.md
cat > CLAUDE.md <<'EOF'
# CLAUDE.md

See [AGENTS.md](AGENTS.md) — it holds the shadow learning instructions and is
shared with Codex CLI and Kimi Code. Everything there applies here.
EOF
```

- [ ] **Step 3: Verify**

Run: `head -5 AGENTS.md && cat CLAUDE.md`
Expected: `AGENTS.md` starts with `# AGENTS.md`; `CLAUDE.md` is the three-line pointer.

- [ ] **Step 4: Commit**

```bash
git add AGENTS.md.template AGENTS.md CLAUDE.md
git commit -m "docs: make AGENTS.md the canonical instruction surface"
```

---

## Task 7: Repoint the skills at the new paths

**Files:**
- Modify: `skills/session-knowledge-extract/SKILL.md`
- Modify: `skills/memory-consolidate/SKILL.md`
- Modify: `skills/_template/SKILL.md`
- Modify: `skills/start-research-thread/SKILL.md`

- [ ] **Step 1: Replace Steps 1–2 of session-knowledge-extract**

In `skills/session-knowledge-extract/SKILL.md`, replace the `## Paths`, `## Step 1: Find today's sessions`, and `## Step 2: Extract user turns from each session` sections (everything from `## Paths` up to but not including `## Step 3: Apply the signal classifier`) with:

````markdown
## Paths

```bash
MEMORY_DIR="$(pwd)/.agents/memory"
```

The knowledge store lives in the project repo, so it works identically under
Claude Code, Codex CLI, and Kimi Code.

## Step 0: Load existing memory context

Read `AGENTS.md`, `$MEMORY_DIR/MEMORY.md`, and `$MEMORY_DIR/extracted-knowledge.md`.
Note what's already documented (skip in Step 4), known entities, and existing
sections to merge into. If nothing exists, proceed without context.

## Steps 1-2: Collect user turns from every tool

```bash
~/.agents/bin/session-turns --since 1d
```

This reads Claude Code, Codex CLI, and Kimi Code transcripts for the current
project and emits a normalized stream, oldest first:

```
--- [kimi 2026-08-23T15:40]
We always use pnpm, never npm
--- [claude 2026-08-23T14:02]
Don't put API calls in pages. They go in features/*/api/.
```

Per-tool counts go to stderr. Zero output means no sessions matched — check the
stderr line before concluding there was no signal. Process up to ~15 sessions'
worth of turns; if the output is very long, work from the most recent turns.
````

- [ ] **Step 2: Repoint the remaining path references**

```bash
sed -i 's|\$HOME/.claude/projects/\$PROJECT_SLUG/memory|$(pwd)/.agents/memory|g; s|\$HOME/.claude/projects/\$(echo \$(pwd) \| tr '"'"'/'"'"' '"'"'-'"'"')/memory|$(pwd)/.agents/memory|g; s|memory/patterns/|.agents/memory/patterns/|g; s|memory/entities/|.agents/memory/entities/|g' \
  skills/memory-consolidate/SKILL.md \
  skills/_template/SKILL.md \
  skills/start-research-thread/SKILL.md
```

- [ ] **Step 3: Verify nothing still points at the Claude-private store**

Run: `grep -rn '\.claude/projects' skills/ || echo CLEAN`
Expected: `CLEAN`.

Run: `grep -rn '\.agents/memory' skills/ | wc -l`
Expected: a non-zero count.

If the `sed` produced a doubled path such as `.agents/.agents/memory/patterns/`, fix those occurrences by hand before committing:

Run: `grep -rn '\.agents/\.agents' skills/ || echo NO-DOUBLES`
Expected: `NO-DOUBLES`.

- [ ] **Step 4: Commit**

```bash
git add skills/
git commit -m "feat: repoint skills at the tool-neutral .agents/memory store"
```

---

## Task 8: `shadow-learn.sh init` — multi-tool install

**Files:**
- Modify: `shadow-learn.sh:1-60` (path constants and snippets)
- Modify: `shadow-learn.sh` (`cmd_init`)

- [ ] **Step 1: Replace the path constants**

In `shadow-learn.sh`, replace the block from `CLAUDE_SKILLS_DIR=` through `MEMORY_DIR=` with:

```bash
AGENTS_HOME="$HOME/.agents"
AGENTS_SKILLS_DIR="$AGENTS_HOME/skills"
AGENTS_BIN_DIR="$AGENTS_HOME/bin"
MEMORY_DIR="$PWD/.agents/memory"
```

`PROJECT_SLUG` is no longer needed anywhere; delete its assignment.

- [ ] **Step 2: Replace the two heredoc snippets with the template**

Delete the `BOOTSTRAP='...'` and `AGENTS_SNIPPET='...'` assignments. `init` now copies `AGENTS.md.template`, so there is exactly one copy of that text.

- [ ] **Step 3: Add tool detection and linking helpers**

Insert before `cmd_init`:

```bash
# Tools that need skills linked into their own directory.
# Kimi reads ~/.agents/skills natively and is handled separately.
detect_tools() {
  [ -d "$HOME/.claude" ] && echo "claude:$HOME/.claude/skills"
  [ -d "$HOME/.codex" ]  && echo "codex:$HOME/.codex/skills"
  return 0
}

link_skill() {
  local src="$1" dest="$2"
  if [ -L "$dest" ]; then
    ln -sfn "$src" "$dest"
    return 0
  fi
  if [ -e "$dest" ]; then
    warn "$dest exists and is not a symlink — left alone"
    return 1
  fi
  ln -s "$src" "$dest"
}
```

- [ ] **Step 4: Rewrite `cmd_init`'s body**

Replace everything between `echo ""` after the `Shadow Learning Init` banner and the final `Done.` echo with:

```bash
  # Project store
  echo "Knowledge store: $MEMORY_DIR"
  mkdir -p "$MEMORY_DIR/patterns" "$MEMORY_DIR/entities" "docs/playbooks"
  ok "patterns/"
  ok "entities/"
  ok "docs/playbooks/"
  echo ""

  # User-global skills and normalizer
  echo "Installing to $AGENTS_HOME"
  mkdir -p "$AGENTS_SKILLS_DIR" "$AGENTS_BIN_DIR"
  if [ ! -d "$SKILLS_DIR/session-knowledge-extract" ]; then
    fail "Skills not found at $SKILLS_DIR"
    echo "  Run this script from the claude-shadow-learn repo directory."
    exit 1
  fi
  for skill in session-knowledge-extract memory-consolidate start-research-thread; do
    if [ -d "$SKILLS_DIR/$skill" ]; then
      cp -r "$SKILLS_DIR/$skill" "$AGENTS_SKILLS_DIR/"
      ok "skills/$skill"
    fi
  done
  cp "$REPO_DIR/bin/session-turns" "$AGENTS_BIN_DIR/session-turns"
  chmod +x "$AGENTS_BIN_DIR/session-turns"
  ok "bin/session-turns"
  echo ""

  # Link into each installed tool
  echo "Linking skills into installed tools"
  while IFS=: read -r tool dir; do
    [ -n "${tool:-}" ] || continue
    mkdir -p "$dir"
    for skill_path in "$AGENTS_SKILLS_DIR"/*/; do
      [ -d "$skill_path" ] || continue
      link_skill "${skill_path%/}" "$dir/$(basename "$skill_path")"
    done
    ok "$tool → $dir"
  done < <(detect_tools)
  if [ -d "$HOME/.kimi-code" ] || [ -d "$HOME/.kimi" ]; then
    ok "kimi → reads ~/.agents/skills natively (no link needed)"
  fi
  echo ""

  # Seed bootstrap patterns
  echo "Seeding bootstrap patterns into $MEMORY_DIR/patterns/"
  if [ -d "$BOOTSTRAP_PATTERNS_DIR" ]; then
    for pattern_file in "$BOOTSTRAP_PATTERNS_DIR"/*.md; do
      [ -e "$pattern_file" ] || continue
      local name
      name=$(basename "$pattern_file")
      if [ -f "$MEMORY_DIR/patterns/$name" ]; then
        ok "$name already present (kept local edits)"
      else
        cp "$pattern_file" "$MEMORY_DIR/patterns/$name"
        ok "$name (copied)"
      fi
    done
  fi
  echo ""

  # AGENTS.md
  if [ -f "AGENTS.md" ]; then
    ok "AGENTS.md already exists (kept local edits)"
  else
    cp "$REPO_DIR/AGENTS.md.template" "AGENTS.md"
    ok "Created AGENTS.md"
  fi

  # CLAUDE.md pointer
  if [ -f "CLAUDE.md" ] && grep -q "AGENTS.md" "CLAUDE.md" 2>/dev/null; then
    ok "CLAUDE.md already points at AGENTS.md"
  elif [ -d "$HOME/.claude" ]; then
    [[ -s "CLAUDE.md" ]] && echo "" >> "CLAUDE.md"
    echo "See [AGENTS.md](AGENTS.md) for shadow learning instructions." >> "CLAUDE.md"
    ok "CLAUDE.md points at AGENTS.md"
  fi

  # Privacy choice
  if ! grep -q '^\.agents/memory/' .gitignore 2>/dev/null; then
    local share=false
    if $auto_yes; then
      share=true
    else
      echo ""
      echo "  .agents/memory/ holds learned patterns and entity notes."
      echo "  Committing it shares learning with your team; it may contain names"
      echo "  or client details."
      read -r -p "  Commit .agents/memory/ to git? [Y/n] " answer
      [[ ! "$answer" =~ ^[Nn]$ ]] && share=true
    fi
    if $share; then
      ok ".agents/memory/ will be committed (shared with the team)"
    else
      echo ".agents/memory/" >> .gitignore
      ok ".agents/memory/ added to .gitignore (private)"
    fi
  fi
```

- [ ] **Step 5: Run it against a scratch HOME**

```bash
SCRATCH=$(mktemp -d)
mkdir -p "$SCRATCH/home/.claude" "$SCRATCH/home/.codex" "$SCRATCH/proj"
cd "$SCRATCH/proj" && git init -q
HOME="$SCRATCH/home" "$OLDPWD/shadow-learn.sh" init -y
```

Expected output includes `claude → …/.claude/skills`, `codex → …/.codex/skills`, and `Created AGENTS.md`.

Verify the links and tree:

```bash
ls -l "$SCRATCH/home/.claude/skills/" | head
ls "$SCRATCH/proj/.agents/memory/"
cd "$OLDPWD"
```

Expected: symlinks pointing into `$SCRATCH/home/.agents/skills/`, and `entities`, `extracted-knowledge.md` absent but `patterns` and `entities` directories present.

- [ ] **Step 6: Run it twice to confirm idempotence**

```bash
HOME="$SCRATCH/home" bash -c 'cd '"$SCRATCH"'/proj && '"$PWD"'/shadow-learn.sh init -y'
```

Expected: `AGENTS.md already exists (kept local edits)` and no duplicated `.gitignore` line.

Run: `grep -c 'agents/memory' "$SCRATCH/proj/.gitignore" 2>/dev/null || echo 0`
Expected: `0` (the `-y` path chooses "commit", so nothing is written to `.gitignore`).

- [ ] **Step 7: Commit**

```bash
git add shadow-learn.sh
git commit -m "feat: multi-tool init — .agents store, global skills, per-tool links"
```

---

## Task 9: `migrate`, `health`, and `install-hooks`

**Files:**
- Modify: `shadow-learn.sh` (`cmd_health`, `cmd_install_hooks`, `usage`, dispatcher)
- Modify: `shadow-learn.sh` (add `cmd_migrate`)

- [ ] **Step 1: Add `cmd_migrate`**

Insert before `cmd_health`:

```bash
cmd_migrate() {
  local merge=false
  [[ "${1:-}" == "--merge" ]] && merge=true

  local slug legacy
  slug=$(echo "$PWD" | tr '/' '-')
  legacy="$HOME/.claude/projects/$slug/memory"

  echo -e "${BOLD}Migrate legacy Claude store${RESET}"
  echo ""

  if [ ! -d "$legacy" ]; then
    fail "No legacy store at $legacy"
    return 1
  fi

  if [ -d "$MEMORY_DIR" ] && [ -n "$(ls -A "$MEMORY_DIR" 2>/dev/null)" ] && ! $merge; then
    fail "$MEMORY_DIR already has content"
    echo "  Re-run with --merge to add missing files without overwriting."
    return 1
  fi

  mkdir -p "$MEMORY_DIR"
  local copied=0 kept=0
  while IFS= read -r src; do
    local rel dest
    rel="${src#"$legacy"/}"
    dest="$MEMORY_DIR/$rel"
    if [ -f "$dest" ]; then
      ok "$rel already present (kept)"
      kept=$((kept + 1))
    else
      mkdir -p "$(dirname "$dest")"
      cp "$src" "$dest"
      ok "$rel"
      copied=$((copied + 1))
    fi
  done < <(find "$legacy" -type f -name "*.md")

  echo ""
  echo "  $copied copied, $kept kept"
  echo "  Original left intact at $legacy"
  warn "Review .agents/memory/ for names or client details before committing."
}
```

- [ ] **Step 2: Make `health` tool-aware**

Replace `cmd_health`'s checks 7 and 8 (the `CLAUDE.md` bootstrap check and the `AGENTS.md` check) with:

```bash
  # 7. Instruction file
  if [ -f "AGENTS.md" ] && grep -q '\.agents/memory' "AGENTS.md" 2>/dev/null; then
    ok "AGENTS.md points at the knowledge store"
    ok_count=$((ok_count + 1))
  else
    fail "AGENTS.md missing or not pointing at .agents/memory — run: ./shadow-learn.sh init"
    fail_count=$((fail_count + 1))
  fi

  # 8. Per-tool reachability
  local any_tool=false
  for pair in "claude:$HOME/.claude/skills" "codex:$HOME/.codex/skills"; do
    local tool="${pair%%:*}" dir="${pair#*:}"
    [ -d "$(dirname "$dir")" ] || continue
    any_tool=true
    if [ -e "$dir/session-knowledge-extract" ]; then
      ok "$tool: skills linked"
      ok_count=$((ok_count + 1))
    else
      warn "$tool: skills not linked — run: ./shadow-learn.sh init"
      warn_count=$((warn_count + 1))
    fi
  done
  if [ -d "$HOME/.kimi-code" ] || [ -d "$HOME/.kimi" ]; then
    any_tool=true
    if [ -d "$HOME/.agents/skills/session-knowledge-extract" ]; then
      ok "kimi: skills present in ~/.agents/skills (native)"
      ok_count=$((ok_count + 1))
    else
      warn "kimi: ~/.agents/skills missing — run: ./shadow-learn.sh init"
      warn_count=$((warn_count + 1))
    fi
  fi
  $any_tool || warn "No supported agent tool detected"

  # 9. Transcript reader
  if [ -x "$HOME/.agents/bin/session-turns" ]; then
    local turn_report
    turn_report=$("$HOME/.agents/bin/session-turns" --since 7d 2>&1 >/dev/null | tr '\n' ' ')
    ok "session-turns: $turn_report"
    ok_count=$((ok_count + 1))
  else
    warn "session-turns not installed — run: ./shadow-learn.sh init"
    warn_count=$((warn_count + 1))
  fi
```

- [ ] **Step 3: Make `install-hooks` tool-aware**

Replace `cmd_install_hooks`'s signature line and add dispatch at its top:

```bash
cmd_install_hooks() {
  local tool="${1:-claude}"
  case "$tool" in
    claude) install_hooks_claude ;;
    kimi)   install_hooks_kimi ;;
    codex)
      warn "Codex hook installation is not automated."
      echo "  Codex's hook schema is not verified against a live install."
      echo "  See GETTING_STARTED.md for the config.toml block to add by hand."
      ;;
    *) fail "Unknown tool: $tool (expected claude, kimi, or codex)" ; return 1 ;;
  esac
}
```

Rename the existing body to `install_hooks_claude()`, unchanged except for the prompt text, and add:

```bash
install_hooks_kimi() {
  local config="$HOME/.kimi-code/config.toml"
  [ -f "$config" ] || config="$HOME/.kimi/config.toml"
  if [ ! -f "$config" ]; then
    fail "No Kimi config found at ~/.kimi-code/config.toml"
    return 1
  fi
  if grep -q "session-knowledge-extract" "$config" 2>/dev/null; then
    ok "Hook already installed in $config"
    return
  fi
  cat >> "$config" <<'EOF'

[[hooks]]
event = "SessionEnd"
command = "kimi -p 'Run the session-knowledge-extract skill on the session that just ended. Write results without asking.'"
EOF
  ok "Hook installed: session-knowledge-extract on SessionEnd"
  echo "  File: $config"
}
```

- [ ] **Step 4: Update `usage` and the dispatcher**

Replace the `Commands:` block in `usage` with:

```bash
  echo "Commands:"
  echo "  init [-y]                 Set up shadow learning for the current project"
  echo "  health                    Check status across all installed tools"
  echo "  migrate [--merge]         Move a legacy ~/.claude memory store into .agents/memory/"
  echo "  install-hooks [TOOL]      Auto-extract on session end (claude|kimi|codex)"
  echo ""
  echo "Supported tools: Claude Code, Codex CLI, Kimi Code"
```

Replace the `case` dispatcher's `install-hooks` line and add `migrate`:

```bash
  migrate)        shift; cmd_migrate "${1:-}" ;;
  install-hooks)  shift; cmd_install_hooks "${1:-claude}" ;;
```

- [ ] **Step 5: Verify against the scratch project**

```bash
SCRATCH=$(mktemp -d)
mkdir -p "$SCRATCH/home/.claude/projects/$(echo "$SCRATCH/proj" | tr '/' '-')/memory/patterns" "$SCRATCH/proj"
echo "- Reviews go in Russian" > "$SCRATCH/home/.claude/projects/$(echo "$SCRATCH/proj" | tr '/' '-')/memory/patterns/review.md"
cd "$SCRATCH/proj" && HOME="$SCRATCH/home" "$OLDPWD/shadow-learn.sh" migrate
```

Expected: `patterns/review.md` listed as copied, `1 copied, 0 kept`, and the warning about names.

Run: `HOME="$SCRATCH/home" "$OLDPWD/shadow-learn.sh" migrate`
Expected: `$MEMORY_DIR already has content` and a non-zero exit.

Run: `HOME="$SCRATCH/home" "$OLDPWD/shadow-learn.sh" migrate --merge`
Expected: `patterns/review.md already present (kept)`, `0 copied, 1 kept`.

Run: `HOME="$SCRATCH/home" "$OLDPWD/shadow-learn.sh" health; cd "$OLDPWD"`
Expected: a report that names the detected tools and does not crash.

- [ ] **Step 6: Commit**

```bash
git add shadow-learn.sh
git commit -m "feat: add migrate, tool-aware health, and per-tool hook install"
```

---

## Task 10: PowerShell parity

**Files:**
- Modify: `shadow-learn.ps1`

Windows gets copies rather than symlinks — creating symlinks there needs elevation or developer mode, and a failed link is worse than a copy the user re-runs `init` to refresh.

- [ ] **Step 1: Mirror the path constants**

Replace the `$ClaudeSkillsDir` / `$ProjectSlug` / `$MemoryDir` assignments with:

```powershell
$AgentsHome      = Join-Path $HOME ".agents"
$AgentsSkillsDir = Join-Path $AgentsHome "skills"
$AgentsBinDir    = Join-Path $AgentsHome "bin"
$MemoryDir       = Join-Path (Get-Location) ".agents\memory"
```

- [ ] **Step 2: Mirror init**

Apply the same sequence as Task 8: create `$MemoryDir\patterns`, `$MemoryDir\entities`, `docs\playbooks`; copy the three skills into `$AgentsSkillsDir` and `bin\session-turns` into `$AgentsBinDir`; copy (not link) each skill into `$HOME\.claude\skills` and `$HOME\.codex\skills` when those parent directories exist; seed bootstrap patterns; copy `AGENTS.md.template` to `AGENTS.md` when absent; append the `AGENTS.md` pointer to `CLAUDE.md`; prompt about `.gitignore`.

Print an explicit note after linking:

```powershell
Write-Warn "Windows: skills are copied, not linked. Re-run init after editing a skill."
```

- [ ] **Step 3: Mirror migrate, health, install-hooks, and usage**

Same behavior as Task 9. `install-hooks kimi` appends the identical TOML block; `install-hooks codex` prints the same manual-setup notice.

- [ ] **Step 4: Verify it parses**

Run: `pwsh -NoProfile -Command "& { . ./shadow-learn.ps1 -? }"` if `pwsh` is available; otherwise `pwsh -NoProfile -Command "\$null = [ScriptBlock]::Create((Get-Content -Raw ./shadow-learn.ps1))"`.
Expected: no parse errors. If `pwsh` is not installed, note in the commit message that the script is unverified on this machine and record it in `tests/TEST_RESULTS.md`.

- [ ] **Step 5: Commit**

```bash
git add shadow-learn.ps1
git commit -m "feat: PowerShell parity for multi-tool install"
```

---

## Task 11: Documentation

**Files:**
- Modify: `README.md`
- Modify: `GETTING_STARTED.md`
- Modify: `tests/TEST_PLAN.md`

- [ ] **Step 1: Update README.md**

Change the title line and Quick Start to lead with multi-tool support. Replace the "Knowledge Store" tree with the `.agents/` layout from the spec. Add this table after the Quick Start:

```markdown
## Supported Tools

| | Claude Code | Codex CLI | Kimi Code |
|---|---|---|---|
| Instructions | `AGENTS.md` (via `CLAUDE.md` pointer) | `AGENTS.md` | `AGENTS.md` |
| Skills | linked into `~/.claude/skills/` | linked into `~/.codex/skills/` | reads `~/.agents/skills/` natively |
| Knowledge store | `.agents/memory/` | `.agents/memory/` | `.agents/memory/` |
| Transcript extraction | yes | yes | yes |
| Session-end hook | `./shadow-learn.sh install-hooks claude` | manual (see GETTING_STARTED) | `./shadow-learn.sh install-hooks kimi` |

The Codex reader is written against the documented rollout format but has not
been verified against a live Codex install. Report mismatches as an issue.
```

Replace the manual-install Option B block with:

```bash
# 1. Install skills and the transcript normalizer
mkdir -p ~/.agents/skills ~/.agents/bin
cp -r skills/session-knowledge-extract skills/memory-consolidate skills/start-research-thread ~/.agents/skills/
cp bin/session-turns ~/.agents/bin/ && chmod +x ~/.agents/bin/session-turns

# 2. Link into the tools you use (Kimi needs no link)
for s in ~/.agents/skills/*/; do ln -s "${s%/}" ~/.claude/skills/"$(basename "$s")"; done
for s in ~/.agents/skills/*/; do ln -s "${s%/}" ~/.codex/skills/"$(basename "$s")"; done

# 3. Create the store and instructions
mkdir -p .agents/memory/patterns .agents/memory/entities docs/playbooks
cp AGENTS.md.template AGENTS.md
```

- [ ] **Step 2: Update GETTING_STARTED.md**

Add a "Migrating from a Claude-only setup" section:

```markdown
## Migrating from a Claude-only setup

Earlier versions kept patterns in `~/.claude/projects/<slug>/memory/`. To move
an existing store into the tool-neutral location:

```bash
./shadow-learn.sh migrate
```

This copies every `.md` file into `.agents/memory/`, leaves the original intact,
and never overwrites a file that already exists at the destination. Pass
`--merge` to fill gaps in a store that already has content.

Review the result before committing — patterns and entity notes can contain
names, client details, or other things you may not want in a shared repo. If in
doubt, add `.agents/memory/` to `.gitignore`.
```

Add a "Codex session-end hook" section:

```markdown
## Codex session-end hook (manual)

`install-hooks` does not automate Codex, because its hook schema is not verified
here. Add the equivalent to `~/.codex/config.toml` yourself, adapting to your
Codex version's hook syntax, and run:

```bash
codex exec "Run the session-knowledge-extract skill on the session that just ended."
```

Until then, run `/session-knowledge-extract` manually at the end of the day —
it reads Codex transcripts regardless of whether a hook triggered it.
```

- [ ] **Step 3: Update tests/TEST_PLAN.md**

Add at the top of the Test Data section:

```markdown
### Automated tests

```bash
./tests/run-tests.sh
```

Covers `bin/session-turns`: per-tool user-turn extraction, project filtering,
`--since` filtering, malformed-line tolerance, absent-tool tolerance, and the
Codex injected-context exclusion. Fixtures live in `tests/fixtures/tools/`.
```

- [ ] **Step 4: Verify docs match reality**

Run: `grep -n 'claude/projects' README.md GETTING_STARTED.md || echo CLEAN`
Expected: matches appear only inside the migration section that describes the old path.

Run: `./tests/run-tests.sh`
Expected: all tests still pass.

- [ ] **Step 5: Commit**

```bash
git add README.md GETTING_STARTED.md tests/TEST_PLAN.md
git commit -m "docs: multi-tool install, migration, and support matrix"
```

---

## Task 12: End-to-end verification guide

**Files:**
- Create: `docs/verification/2026-08-23-multi-tool-portability.md`

Per project convention, a large task ships with a manual verification guide.

- [ ] **Step 1: Write the guide**

Cover, as copy-paste steps with expected output:

- Fresh `init` in a scratch project with all three tools present; assert the resulting tree and symlink targets.
- Fresh `init` with only Kimi present; assert no `~/.claude` or `~/.codex` directories are created and that Kimi still finds the skills.
- Re-running `init`; assert no duplicated `.gitignore` lines and no clobbered edits.
- `migrate` happy path, the already-populated refusal, and `--merge`.
- A real round trip: state a correction in a Kimi session, end it, run `/session-knowledge-extract` from Claude Code in the same project, and confirm the Kimi-originated correction reaches `.agents/memory/extracted-knowledge.md`. This is the single most important check — it is the cross-tool claim.
- `health` output with each tool present and absent.
- Edge case: a project with no sessions at all; assert `session-turns` exits 0 with empty stdout and a per-tool count on stderr.

- [ ] **Step 2: Run the guide yourself and record results**

Execute every step, and append a Results section noting what passed, what failed, and anything not verifiable on this machine (Codex, and PowerShell if `pwsh` is absent).

- [ ] **Step 3: Commit**

```bash
git add docs/verification/2026-08-23-multi-tool-portability.md
git commit -m "docs: manual verification guide for multi-tool portability"
```

---

## Self-Review

**Spec coverage.** Store relocation → Tasks 7, 8. `AGENTS.md` as single surface → Task 6. Normalizer with three readers → Tasks 2, 3, 4. Auto-detection and tolerance → Task 5. Skill repointing → Task 7. `init` with symlinks and detection → Task 8. `migrate`, `health`, `install-hooks` → Task 9. PowerShell parity → Task 10. Docs → Task 11. Testing section → Tasks 1–5 plus Task 12's guide. Error handling (absent tools, malformed lines, non-clobbering) → Tasks 5, 8, 9. Every spec section maps to a task.

**Naming consistency.** `session-turns` (not `session_turns`) everywhere; `~/.agents/skills` and `~/.agents/bin` throughout; `.agents/memory/` for the per-project store; `SL_CLAUDE_HOME` / `SL_CODEX_HOME` / `SL_KIMI_HOME` for the test overrides; `read_claude` / `read_codex` / `read_kimi` registered in `READERS`; `link_skill` and `detect_tools` used only in Task 8. `text_from_content` is defined in Task 2 and reused in Task 3. `MAX_TURN_CHARS` defined and used in Task 2.

**Known gap, accepted.** The Codex reader has fixture tests but no live verification, since Codex is not installed on this machine. Task 11 documents this in the README and Task 12 records it in the verification results.
