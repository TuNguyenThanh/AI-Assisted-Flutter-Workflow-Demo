#!/usr/bin/env bash
# =============================================================================
# stop_check.sh — "you can't say done while CI would be red"
# =============================================================================
# PURPOSE
#   AI agents tend to announce "done" after the code merely compiles. This
#   hook runs the fast CI gates locally the moment Claude tries to finish a
#   turn, so failures are fixed in the same session instead of in CI/review.
#
# WHEN IT RUNS
#   Event: Stop (Claude is about to end its turn) — see .claude/settings.json.
#   Skipped when nothing it checks changed: no modified/untracked *.dart,
#   design/tokens.json, pubspec.yaml or analysis_options.yaml.
#
# WHAT IT CHECKS (same order and flags as .github/workflows/ci.yml)
#   1. dart format --set-exit-if-changed lib test tool
#   2. design tokens in sync (tool/generate_tokens.dart --check)
#   3. flutter analyze --fatal-infos   (infos count, exactly like CI)
#   4. flutter test
#   Coverage and the AC ↔ test check are left to /pr-ready and CI (slower).
#
# OUTCOME
#   exit 0 → all green (or nothing to check): Claude may stop.
#   exit 2 → first failing gate + its output go back to Claude, which must
#            keep working until it is fixed.
#   Loop guard: if Claude was already blocked once (`stop_hook_active`),
#   it is allowed to stop to avoid an infinite loop — but NOT silently: a
#   systemMessage warns the human that the task is not actually done.
#
# REQUIRES  jq; fvm (falls back to flutter/dart on PATH, e.g. in CI).
# TIMEOUT   600 s (settings.json) — the full test suite runs here.
# =============================================================================
set -uo pipefail

input=$(cat)
active=$(jq -r '.stop_hook_active // false' <<<"$input")

cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
if command -v fvm >/dev/null 2>&1 && [[ -f .fvmrc ]]; then
  FLUTTER=(fvm flutter); DART=(fvm dart)
else
  FLUTTER=(flutter); DART=(dart)
fi

# Nothing that the gates cover changed in the working tree → skip.
if git rev-parse --git-dir >/dev/null 2>&1 &&
   [[ -z "$(git status --porcelain -- '*.dart' design/tokens.json pubspec.yaml analysis_options.yaml)" ]]; then
  exit 0
fi

fail() {
  local title=$1 details=$2
  if [[ "$active" == "true" ]]; then
    jq -n --arg m "⚠️ Claude stopped while '$title' is still failing — do not treat this task as done." \
      '{systemMessage: $m}'
    exit 0
  fi
  {
    echo "Not done yet: $title"
    echo "$details"
  } >&2
  exit 2
}

if ! out=$("${DART[@]}" format --output=none --set-exit-if-changed lib test tool 2>&1); then
  fail "dart format (run: fvm dart format lib test tool)" "$(tail -20 <<<"$out")"
fi

if ! out=$("${DART[@]}" run tool/generate_tokens.dart --check 2>&1); then
  fail "design tokens out of sync (edit design/tokens.json, then run the generator)" "$(tail -20 <<<"$out")"
fi

if ! out=$("${FLUTTER[@]}" analyze --no-pub --fatal-infos 2>&1); then
  fail "flutter analyze --fatal-infos" "$(grep -E '(error|warning|info) •' <<<"$out" | head -20)"
fi

if ! out=$("${FLUTTER[@]}" test --no-pub 2>&1); then
  fail "tests are failing" "$(grep -E '(FAILED|Expected|Actual|\[E\])' <<<"$out" | head -30)"
fi
exit 0
