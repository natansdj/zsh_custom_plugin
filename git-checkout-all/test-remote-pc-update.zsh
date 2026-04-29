#!/usr/bin/env zsh
# Test script for git-remote-pc-update behavior.

set -euo pipefail

SCRIPT_DIR="${0:A:h}"
source "${SCRIPT_DIR}/lib/single-operations.zsh"

_fail() {
  echo "❌ $1" >&2
  exit 1
}

_assert_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" == *"$needle"* ]] || _fail "Expected to contain '${needle}', got: ${haystack}"
}

_assert_not_contains() {
  local haystack="$1"
  local needle="$2"
  [[ "$haystack" != *"$needle"* ]] || _fail "Expected NOT to contain '${needle}', got: ${haystack}"
}

_assert_line_count_eq() {
  local text="$1"
  local expected="$2"
  local actual
  actual="$(print -r -- "$text" | wc -l | tr -d ' ')"
  [[ "$actual" == "$expected" ]] || _fail "Expected ${expected} line(s), got ${actual}: ${text}"
}

echo "🧪 Testing git-remote-pc-update"
echo "=========================================================="
echo

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

BITBUCKET_URL="git@bitbucket.org:paycloudid/example-repo.git"
GITHUB_WORK_URL="git@github.work:PayCloud-ID/example-repo.git"

echo "Test 1: Cleanup legacy Bitbucket push URL when github.work already present"
echo "-----------------------------------------------------------"
repo1="${tmp_dir}/repo1"
mkdir -p "$repo1"
(
  cd "$repo1"
  git init -q
  git remote add origin "$GITHUB_WORK_URL"
  git remote set-url --add --push origin "$GITHUB_WORK_URL"
  git remote set-url --add --push origin "$BITBUCKET_URL"

  before_push="$(git remote get-url --push --all origin)"
  echo "Before push URLs:"
  echo "$before_push"
  _assert_contains "$before_push" "github.work"
  _assert_contains "$before_push" "bitbucket.org:paycloudid"

  git-remote-pc-update >/dev/null

  after_push="$(git remote get-url --push --all origin)"
  echo "After push URLs:"
  echo "$after_push"
  _assert_contains "$after_push" "github.work"
  _assert_not_contains "$after_push" "bitbucket.org:paycloudid"
  echo "✅ Passed"
)
echo

echo "Test 2: Migrate Bitbucket push URL to github.work and keep single push URL"
echo "-----------------------------------------------------------"
repo2="${tmp_dir}/repo2"
mkdir -p "$repo2"
(
  cd "$repo2"
  git init -q
  git remote add origin "$BITBUCKET_URL"
  git remote set-url --add --push origin "$BITBUCKET_URL"

  before_fetch="$(git remote get-url origin)"
  before_push="$(git remote get-url --push --all origin)"
  echo "Before fetch URL: $before_fetch"
  echo "Before push URLs:"
  echo "$before_push"
  _assert_contains "$before_push" "bitbucket.org:paycloudid"

  git-remote-pc-update >/dev/null

  after_fetch="$(git remote get-url origin)"
  after_push="$(git remote get-url --push --all origin)"
  echo "After fetch URL: $after_fetch"
  echo "After push URLs:"
  echo "$after_push"

  _assert_contains "$after_fetch" "github.work:PayCloud-ID"
  _assert_contains "$after_push" "github.work:PayCloud-ID"
  _assert_not_contains "$after_push" "bitbucket.org:paycloudid"
  _assert_line_count_eq "$after_push" "1"
  echo "✅ Passed"
)

echo
echo "✅ All tests completed!"
