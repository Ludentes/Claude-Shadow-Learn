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
