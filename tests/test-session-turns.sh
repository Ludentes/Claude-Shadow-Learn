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
