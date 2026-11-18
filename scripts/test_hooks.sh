#!/usr/bin/env bash
# Tests for the Claude Code hooks in .claude/hooks/. Run locally and in CI:
#   bash scripts/test_hooks.sh
# Each case feeds the hook the same JSON Claude Code sends and checks the
# decision (allow / ask / deny). A guardrail without a test is a guess.
set -uo pipefail

root=$(cd "$(dirname "$0")/.." && pwd -P)
export CLAUDE_PROJECT_DIR=$root
GUARD=$root/.claude/hooks/guard_files.sh
POST=$root/.claude/hooks/post_edit_dart.sh
OFF="disable""AllHooks"
pass=0
fail=0

ok() { pass=$((pass + 1)); }
ko() { fail=$((fail + 1)); echo "FAIL: $1"; }

# --- JSON builders ----------------------------------------------------------
with_agent() { if [[ -n "${1:-}" ]]; then jq -c --arg a "$1" '. + {agent_type: $a}'; else cat; fi; }
bash_j() { jq -nc --arg c "$1" '{tool_name: "Bash", tool_input: {command: $c}}' | with_agent "${2:-}"; }
file_j() { # tool path [agent] [content]
  jq -nc --arg t "$1" --arg p "$2" --arg c "${4:-x}" \
    '{tool_name: $t, tool_input: {file_path: $p, content: $c, old_string: "a", new_string: $c}}' |
    with_agent "${3:-}"
}
grep_j() { jq -nc --arg g "$1" '{tool_name: "Grep", tool_input: {pattern: "x", glob: $g}}'; }

# expect <allow|ask|deny> <description> <json>
expect() {
  local want=$1 desc=$2 json=$3 out code got
  out=$(printf '%s' "$json" | "$GUARD" 2>/dev/null)
  code=$?
  if [[ $code -eq 2 ]]; then got=deny
  elif [[ $code -eq 0 && "$out" == *'"permissionDecision": "ask"'* ]]; then got=ask
  elif [[ $code -eq 0 ]]; then got=allow
  else got="error($code)"
  fi
  if [[ "$got" == "$want" ]]; then ok; else ko "[guard] $desc — want $want, got $got"; fi
}

echo "== guard_files.sh: secrets"
expect deny  "Read .env"                         "$(file_j Read "$root/.env")"
expect deny  "Read nested .env.production"       "$(file_j Read "$root/app/.env.production")"
expect deny  "Read key.properties"               "$(file_j Read "$root/android/key.properties")"
expect deny  "cat .env"                          "$(bash_j 'cat .env')"
expect deny  "quote trick .e\"\"nv"              "$(bash_j 'cat .e""nv')"
expect deny  "backslash trick .e\\nv"            "$(bash_j 'cat .e\nv')"
expect deny  "single-quoted '.env'"              "$(bash_j "cat '.env'")"
expect deny  "glob .en?"                         "$(bash_j 'cat .en?')"
expect deny  "glob .env*"                        "$(bash_j 'head .env*')"
expect deny  "find -name *.jks"                  "$(bash_j 'find . -name "*.jks"')"
expect deny  "copy key.properties"               "$(bash_j 'cp android/key.properties /tmp/k')"
expect deny  "Grep glob **/.env*"                "$(grep_j '**/.env*')"
expect allow "Grep glob *.dart"                  "$(grep_j '*.dart')"
expect allow "commit message mentioning .env"    "$(bash_j 'git commit -m "ignore .env files"')"
expect allow "heredoc body mentioning .env"      "$(bash_j $'cat <<EOF\nnever commit .env\nEOF')"

echo "== guard_files.sh: generated files + lockfiles"
expect deny  "Edit app_tokens.g.dart"            "$(file_j Edit "$root/lib/core/theme/app_tokens.g.dart")"
expect allow "Read app_tokens.g.dart"            "$(file_j Read "$root/lib/core/theme/app_tokens.g.dart")"
expect deny  "Write pubspec.lock"                "$(file_j Write "$root/pubspec.lock")"
expect deny  "sed -i on .g.dart"                 "$(bash_j "sed -i '' s/a/b/ lib/core/theme/app_tokens.g.dart")"
expect deny  "redirect into pubspec.lock"        "$(bash_j 'echo x > pubspec.lock')"
expect allow "token generator"                   "$(bash_j 'fvm dart run tool/generate_tokens.dart')"

echo "== guard_files.sh: guardrails (main agent)"
expect ask   "Edit a hook"                       "$(file_j Edit "$root/.claude/hooks/guard_files.sh")"
expect ask   "Edit an agent prompt"              "$(file_j Edit "$root/.claude/agents/test-writer.md")"
expect ask   "Write CLAUDE.md"                   "$(file_j Write "$root/CLAUDE.md")"
expect ask   "Edit CI workflow"                  "$(file_j Edit "$root/.github/workflows/ci.yml")"
expect ask   "lower coverage via sed"            "$(bash_j "sed -i '' s/80/50/ scripts/coverage_check.sh")"
expect ask   "append to analysis_options.yaml"   "$(bash_j 'echo x >> analysis_options.yaml')"
expect deny  "Write settings.local.json"         "$(file_j Write "$root/.claude/settings.local.json")"
expect deny  "shell-write settings.local.json"   "$(bash_j 'echo {} > .claude/settings.local.json')"
expect deny  "turn hooks off in settings"        "$(file_j Write "$root/.claude/settings.json" '' "{\"$OFF\": true}")"
expect deny  "turn hooks off via shell"          "$(bash_j "jq '.$OFF=true' s.json > .claude/settings.json")"
expect allow "docs may mention the off switch"   "$(file_j Write "$root/docs/notes.md" '' "never set $OFF")"
expect deny  "user-level settings"               "$(file_j Write "$HOME/.claude/settings.json")"
expect deny  "nested claude, skip permissions"   "$(bash_j 'claude --dangerously-skip-permissions -p hi')"
expect deny  "claude config set"                 "$(bash_j 'claude config set foo bar')"
expect allow "read a hook"                       "$(bash_j 'cat .claude/hooks/guard_files.sh')"
expect allow "coverage gate"                     "$(bash_j 'bash scripts/coverage_check.sh 80')"
expect allow "tests piped to tail"               "$(bash_j 'fvm flutter test 2>&1 | tail -5')"
expect allow "Edit feature code"                 "$(file_j Edit "$root/lib/features/auth/presentation/pages/login_page.dart")"

echo "== guard_files.sh: test-writer sandbox"
TW="test-writer"
expect allow "write under test/"                 "$(file_j Write "$root/test/foo_test.dart" $TW)"
expect deny  "write lib/"                        "$(file_j Write "$root/lib/foo.dart" $TW)"
expect deny  "escape test/ with .."              "$(file_j Write "$root/test/../lib/foo.dart" $TW)"
expect deny  "write docs/"                       "$(file_j Write "$root/docs/x.md" $TW)"
expect deny  "edit own agent prompt"             "$(file_j Edit "$root/.claude/agents/test-writer.md" $TW)"
expect deny  "write outside project"             "$(file_j Write /tmp/x.dart $TW)"
expect allow "run tests"                         "$(bash_j 'fvm flutter test test/core' $TW)"
expect allow "run tests 2>&1 | tail"             "$(bash_j 'fvm flutter test 2>&1 | tail -20' $TW)"
expect allow "format test/"                      "$(bash_j 'fvm dart format test' $TW)"
expect deny  "format lib/"                       "$(bash_j 'fvm dart format lib' $TW)"
expect deny  "format test/ and lib/"             "$(bash_j 'fvm dart format test lib' $TW)"
expect deny  "rm lib file"                       "$(bash_j 'rm lib/main.dart' $TW)"
expect deny  "chain after tests"                 "$(bash_j 'fvm flutter test && rm -rf lib' $TW)"
expect deny  "command substitution"              "$(bash_j 'fvm flutter test $(rm lib/main.dart)' $TW)"
expect deny  "pipe into xargs"                   "$(bash_j 'fvm flutter test | xargs rm' $TW)"
expect deny  "git checkout lib"                  "$(bash_j 'git checkout lib/main.dart' $TW)"
expect deny  "analyze --write"                   "$(bash_j 'fvm flutter analyze --write=lib/x.dart' $TW)"
expect deny  "git diff --output"                 "$(bash_j 'git diff --output=lib/x.dart' $TW)"
expect deny  "python one-liner"                  "$(bash_j "python3 -c 'open(\"lib/x\",\"w\")'" $TW)"
expect deny  "start claude"                      "$(bash_j 'claude -p hi' $TW)"

echo "== guard_files.sh: code-reviewer sandbox"
CR="code-reviewer"
expect allow "git diff main...HEAD"              "$(bash_j 'git diff main...HEAD' $CR)"
expect allow "git status"                        "$(bash_j 'git status --porcelain' $CR)"
expect allow "git log | head"                    "$(bash_j 'git log --oneline | head -5' $CR)"
expect allow "analyze"                           "$(bash_j 'fvm flutter analyze' $CR)"
expect allow "read files"                        "$(file_j Read "$root/lib/main.dart" $CR)"
expect deny  "write any file"                    "$(file_j Write "$root/test/x_test.dart" $CR)"
expect deny  "git commit"                        "$(bash_j 'git commit -m x' $CR)"
expect deny  "git branch -D"                     "$(bash_j 'git branch -D main' $CR)"
expect deny  "git diff escaping with .."         "$(bash_j 'git diff ../other' $CR)"

echo "== guard_files.sh: spec-writer sandbox"
SW="spec-writer"
expect allow "write docs/specs/"                 "$(file_j Write "$root/docs/specs/AUTH-002-spec.md" $SW)"
expect deny  "write lib/"                        "$(file_j Write "$root/lib/x.dart" $SW)"
expect deny  "any shell"                         "$(bash_j 'ls' $SW)"

echo "== guard_files.sh: built-in subagents"
expect allow "Explore may list files"            "$(bash_j 'ls lib' Explore)"
expect deny  "general-purpose may not edit guardrails" "$(file_j Edit "$root/.claude/settings.json" general-purpose)"

# --- post_edit_dart.sh ------------------------------------------------------
echo "== post_edit_dart.sh"
fixtures=()
cleanup() { for f in "${fixtures[@]+"${fixtures[@]}"}"; do rm -f "$f"; done; }
trap cleanup EXIT

# expect_post <0|2> <description> <repo-relative path> <content> [stderr substring]
expect_post() {
  local want=$1 desc=$2 rel=$3 content=$4 needle=${5:-} err code
  printf '%s\n' "$content" >"$root/$rel"
  fixtures+=("$root/$rel")
  err=$(jq -nc --arg p "$root/$rel" '{tool_name: "Write", tool_input: {file_path: $p}}' | "$POST" 2>&1 >/dev/null)
  code=$?
  if [[ $code -ne $want ]]; then
    ko "[post] $desc — want exit $want, got $code: $(head -3 <<<"$err")"
  elif [[ -n "$needle" && "$err" != *"$needle"* ]]; then
    ko "[post] $desc — stderr lacks '$needle': $(head -3 <<<"$err")"
  else ok
  fi
  rm -f "$root/$rel"
}

LIBF=lib/zz_hook_fixture.dart
TESTF=test/zz_hook_fixture_test.dart
WIDF=lib/core/widgets/zz_hook_fixture.dart
expect_post 0 "clean file"                  $LIBF 'int add(int a, int b) => a + b;'
expect_post 2 "print in lib/"               $LIBF $'void f() {\n  print(1);\n}' "no print"
expect_post 2 "ignore without reason"       $LIBF $'// ignore: unused_element\nvoid _f() {}' "needs a reason"
expect_post 2 "ignore_for_file"             $LIBF $'// ignore_for_file: type=lint\nint a = 1;' "not allowed"
expect_post 0 "ignore with reason"          $LIBF $'// Kept as an example for the hook test.\n// ignore: unused_element\nvoid _f() {}\nint a = 1;'
expect_post 0 "ignore text inside a string" $LIBF "const s = '// ignore_for_file: x';"
expect_post 2 "shared_preferences import"   $LIBF $'import \'package:shared_preferences/shared_preferences.dart\';\n\nint a = 1;' "shared_preferences"
expect_post 0 "SharedPreferences in a comment" $LIBF $'/// Never store tokens in SharedPreferences.\nint a = 1;'
expect_post 2 "raw color in a widget"       $WIDF $'import \'package:flutter/material.dart\';\n\nconst c = Colors.red;' "raw color"
expect_post 2 "skipped test"                $TESTF $'import \'package:flutter_test/flutter_test.dart\';\n\nvoid main() {\n  test(\'a\', () {}, skip: true);\n}' "skipping tests"

echo
echo "hook tests: $pass passed, $fail failed"
[[ $fail -eq 0 ]]
