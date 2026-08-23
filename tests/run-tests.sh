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
