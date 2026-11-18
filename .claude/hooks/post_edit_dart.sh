#!/usr/bin/env bash
# =============================================================================
# post_edit_dart.sh — instant feedback after every Dart edit
# =============================================================================
# PURPOSE
#   Catch AI mistakes seconds after they are written, on the one file just
#   edited, instead of minutes later in the Stop hook or hours later in CI.
#   Also closes the usual shortcuts for turning a red check "green" without
#   fixing the code.
#
# WHEN IT RUNS
#   Event: PostToolUse, matcher Edit|Write|MultiEdit — see settings.json.
#   Only for *.dart files; generated files (*.g.dart, *.freezed.dart) skip.
#
# WHAT IT DOES
#   1. `dart format` the file (auto-fix, never blocks).
#   2. Anti-gaming checks:
#      - any `// ignore_for_file:`                      → not allowed
#      - `// ignore:` without a reason comment above it → not allowed
#      - `skip:` on a test (test/ only)                 → not allowed
#      - print / debugPrint in lib/                     → not allowed
#      - import of package:shared_preferences in lib/   → not allowed
#        (tokens go through TokenStorage — CLAUDE.md › Security)
#      - Color(0x…) / Colors.* in lib/core/widgets or features/*/presentation
#                                                       → use design tokens
#   3. `dart analyze --fatal-infos` on the file.
#
# OUTCOME
#   exit 0 → file is clean.
#   exit 2 → every problem (file:line + rule) goes back to Claude, which must
#            fix it before moving on. The edit itself is already applied.
#
# REQUIRES  jq; fvm (falls back to dart on PATH).
# TESTS     scripts/test_hooks.sh (section "post_edit_dart.sh").
# =============================================================================
set -uo pipefail

input=$(cat)
cd "${CLAUDE_PROJECT_DIR:-.}" || exit 0
if command -v fvm >/dev/null 2>&1 && [[ -f .fvmrc ]]; then
  DART=(fvm dart)
else
  DART=(dart)
fi

file=$(jq -r '.tool_input.file_path // empty' <<<"$input")
[[ "$file" == *.dart ]] || exit 0
[[ -f "$file" ]] || exit 0
rel=${file#"$PWD"/}
[[ "$rel" == *.g.dart || "$rel" == *.freezed.dart ]] && exit 0

problems=()

# --- Anti-gaming checks (lib/, test/, tool/) -------------------------------
# A `// ignore` (not inside a string) needs a reason comment on the line
# above; file-wide suppression is never allowed.
while IFS= read -r hit; do
  [[ -n "$hit" ]] && problems+=("$hit")
done < <(awk -v f="$rel" -v q="'" '
  BEGIN {
    # Comment that is not inside a string literal: no quote before `//`.
    pre = "^[^" q "\"]*//[ \t]*"
  }
  $0 ~ (pre "ignore_for_file:") {
    printf "%s:%d: `ignore_for_file` is not allowed — fix the code or use a single `// ignore:` with a reason\n", f, NR
  }
  $0 ~ (pre "ignore:") {
    p = prev; sub(/^[ \t]+/, "", p)
    if (p !~ /^\/\// || p ~ /^\/\/[ \t]*ignore/) {
      printf "%s:%d: `// ignore:` needs a reason comment on the line above\n", f, NR
    }
  }
  { prev = $0 }
' "$file")

if [[ "$rel" == lib/* ]]; then
  while IFS= read -r l; do
    [[ -n "$l" ]] && problems+=("$rel:${l%%:*}: no print/debugPrint in lib/")
  done < <(grep -nE '(^|[^.[:alnum:]_])(print|debugPrint)\(' "$file")

  if grep -qE "^import ['\"]package:shared_preferences/" "$file"; then
    problems+=("$rel: shared_preferences is not allowed in this app — tokens go through TokenStorage (CLAUDE.md › Security); ask before adding packages")
  fi
fi

# UI code must use design tokens, never raw colors.
if [[ "$rel" == lib/core/widgets/* || "$rel" =~ ^lib/features/[^/]+/presentation/ ]]; then
  while IFS= read -r l; do
    [[ -n "$l" ]] && problems+=("$rel:${l%%:*}: raw color — use colorScheme.* / context.colors.* (CLAUDE.md › Figma)")
  done < <(grep -nE '(Color\(0x|Colors\.[a-z])' "$file" | grep -v 'Colors.transparent')
fi

if [[ "$rel" == test/* ]]; then
  while IFS= read -r l; do
    [[ -n "$l" ]] && problems+=("$rel:${l%%:*}: skipping tests is not allowed — fix the code or report the bug")
  done < <(grep -nE "(^|[^[:alnum:]_])skip:[[:space:]]*(true|[\"'])" "$file")
fi

# --- Format + analyze ------------------------------------------------------
"${DART[@]}" format "$file" >/dev/null 2>&1
if ! output=$("${DART[@]}" analyze --fatal-infos "$file" 2>&1); then
  while IFS= read -r l; do
    [[ -n "$l" ]] && problems+=("$l")
  done < <(grep -E '(error|warning|info) -' <<<"$output" | head -20)
fi

if ((${#problems[@]})); then
  {
    echo "Fix these in $rel before continuing:"
    printf '  %s\n' "${problems[@]}"
  } >&2
  exit 2
fi
exit 0
