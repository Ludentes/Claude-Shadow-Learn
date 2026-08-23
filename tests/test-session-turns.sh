# shellcheck shell=bash
FIX="$TESTS_DIR/fixtures/tools"
ST="$REPO_DIR/bin/session-turns"

run_st() {
  SL_CLAUDE_HOME="$FIX/claude" \
  SL_CODEX_HOME="$FIX/codex" \
  SL_KIMI_HOME="$FIX/kimi" \
  python3 "$ST" "$@" 2>/dev/null
}

# Backdate fixtures so --since filtering is testable.
find "$FIX" -name '*.jsonl' -exec touch -d '30 days ago' {} +

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

run_st --project /tmp/nothing-here --since 1h >/dev/null
rc=$?
it "empty result exits 0"
assert_eq "0" "$rc"

bad_rc=0
run_st --project /tmp/proj --since notatime >/dev/null 2>&1 || bad_rc=$?
it "invalid --since exits non-zero"
assert_eq "2" "$bad_rc"
