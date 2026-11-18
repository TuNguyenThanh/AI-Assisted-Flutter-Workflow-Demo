#!/usr/bin/env bash
# =============================================================================
# guard_files.sh — the gatekeeper: decides allow / ask / deny BEFORE a tool runs
# =============================================================================
# PURPOSE
#   Prompts (CLAUDE.md, agent .md files) only *ask* the AI to behave; this
#   hook *enforces* it. It runs before every file or shell tool call and
#   blocks what must never happen, even if the model ignores its prompt,
#   is prompt-injected, or tries a workaround.
#
# WHEN IT RUNS
#   Event: PreToolUse, matcher Edit|Write|MultiEdit|NotebookEdit|Read|Grep|Bash
#   — see .claude/settings.json. Runs for the main agent AND for subagents
#   (Claude Code adds `agent_type` to the input when a subagent calls a tool).
#
# RULES
#   1. Secrets / signing files (.env*, key.properties, *.jks, *.keystore,
#      *.p12, *.mobileprovision, google-services.json,
#      GoogleService-Info.plist): never read, written, grepped or touched via
#      shell. Quoting tricks (.e""nv, .e\nv) and globs (.en?, *.jks) count.
#   2. Generated files (*.g.dart, *.freezed.dart…) and lockfiles: never
#      edited by hand — edit the source and regenerate / `pub get`.
#   3. Guardrails (.claude/, .github/, scripts/, .cursor/rules/, CLAUDE.md,
#      analysis_options.yaml, MCP config): the main agent needs explicit
#      human approval ("ask"); subagents are denied. Applies to tool edits
#      and shell writes (sed -i, >, cp, mv…).
#      Always denied: turning all hooks off in a settings file, editing
#      .claude/settings.local.json or ~/.claude/, starting Claude Code with
#      bypassed permissions or changing its config.
#   4. Subagent sandboxes (by `agent_type`):
#        test-writer   → writes only under test/; shell: flutter test/analyze,
#                        dart format test…, read-only git
#        code-reviewer → no writes; shell: analyze + read-only git
#        spec-writer   → writes only docs/specs/; no shell
#      Sandboxed shell = one allow-listed command at a time: no && ; || $( )
#      backticks, no redirects except 2>&1, no `..` paths, no --output/--write,
#      pipes only into grep/head/tail/wc/sort/uniq. Built-in subagents
#      (Explore, Plan, general-purpose…) get rules 1-3 only.
#
# OUTCOME
#   exit 0, no output → allowed.
#   exit 0 + JSON permissionDecision "ask" → the human approves or rejects.
#   exit 2 → denied; the reason on stderr goes back to Claude.
#
# LIMITS  It inspects command text, so it cannot see through every shell
#         trick (e.g. building a filename from variables). It is one layer:
#         keep real secrets out of the working tree and use the sandbox.
# REQUIRES  jq. Compatible with macOS bash 3.2.
# TESTS     scripts/test_hooks.sh (80+ allow/ask/deny cases, run in CI).
# =============================================================================
set -uo pipefail
set -f # never let the shell glob-expand anything we inspect

input=$(cat)
field() { jq -r "$1 // empty" <<<"$input"; }

tool=$(field '.tool_name')
agent=$(field '.agent_type')
root=${CLAUDE_PROJECT_DIR:-$(field '.cwd')}
root=$(cd "$root" 2>/dev/null && pwd -P) || root=$PWD

# Built from two parts so this file can itself be edited without tripping
# its own check.
OFF_SWITCH="disable""AllHooks"

deny() { echo "BLOCKED by guard_files.sh: $1" >&2; exit 2; }
ask() {
  jq -n --arg r "guard_files.sh: $1" '{hookSpecificOutput: {
    hookEventName: "PreToolUse", permissionDecision: "ask",
    permissionDecisionReason: $r}}'
  exit 0
}
# Guardrail change: subagents never, main agent only with human approval.
guarded() {
  [[ -n "$agent" ]] && deny "subagent '$agent' may not change guardrails ($1)"
  ask "changes a guardrail ($1) — approve only if you asked for it"
}

# ---------------------------------------------------------------- patterns
# Basenames of secret / signing material (bash patterns).
SECRET_PATTERNS=(.env '.env.*' key.properties '*.jks' '*.keystore' '*.p12'
  '*.mobileprovision' google-services.json GoogleService-Info.plist)
# Sample names a glob in a shell command must not be able to match.
SECRET_SAMPLES=(.env .env.local .env.production key.properties upload.jks
  release.keystore cert.p12 app.mobileprovision google-services.json
  GoogleService-Info.plist)

is_secret_name() {
  local name=$1 p
  for p in "${SECRET_PATTERNS[@]}"; do
    # shellcheck disable=SC2053 # $p is intentionally a pattern
    [[ "$name" == $p ]] && return 0
  done
  return 1
}

# Can glob pattern $1 match any secret file name?
glob_hits_secret() {
  local g=$1 s
  for s in "${SECRET_SAMPLES[@]}"; do
    # shellcheck disable=SC2053
    [[ "$s" == $g ]] && return 0
  done
  return 1
}

# Repo-relative path class: secret | settings_local | generated | lock |
# guardrail | other.
classify() {
  local rel=$1 name=${1##*/}
  if is_secret_name "$name"; then echo secret; return; fi
  case "$rel" in
    .claude/settings.local.json) echo settings_local ;;
    *.g.dart | *.freezed.dart | *.gr.dart | *.config.dart) echo generated ;;
    pubspec.lock | */Podfile.lock | Podfile.lock) echo lock ;;
    .claude/* | .github/* | scripts/* | .cursor/rules/* | CLAUDE.md | \
      analysis_options.yaml | .mcp.json | .cursor/mcp.json) echo guardrail ;;
    *) echo other ;;
  esac
}

# Repo-relative, symlink-free path; "OUTSIDE:<abs>" if not in the project.
resolve() {
  local p=$1 dir base suffix=""
  [[ "$p" == /* ]] || p="$root/$p"
  dir=$(dirname "$p"); base=$(basename "$p")
  while [[ ! -d "$dir" && "$dir" != / ]]; do
    suffix="/$(basename "$dir")$suffix"; dir=$(dirname "$dir")
  done
  dir=$(cd "$dir" && pwd -P)
  p="$dir$suffix/$base"; p=${p//\/\//\/}
  if [[ "$p" == "$root" ]]; then echo .
  elif [[ "$p" == "$root"/* ]]; then echo "${p#"$root"/}"
  else echo "OUTSIDE:$p"
  fi
}

has_dotdot() { [[ "$1" == *"/../"* || "$1" == ../* || "$1" == */.. || "$1" == .. ]]; }

# ------------------------------------------------------- file-based tools
if [[ "$tool" != "Bash" ]]; then
  raw=$(field '.tool_input.file_path // .tool_input.notebook_path // .tool_input.path')
  is_write=false
  case "$tool" in Edit | Write | MultiEdit | NotebookEdit) is_write=true ;; esac

  # Turning all hooks off via a settings (JSON) file is never allowed;
  # mentioning it in docs or scripts is fine.
  if $is_write && [[ "$raw" == *.json ]] &&
    grep -q "$OFF_SWITCH" <<<"$(jq -r '.tool_input | tostring' <<<"$input")"; then
    deny "'$OFF_SWITCH' may not be written by the agent"
  fi

  # Grep: block globs aimed at secret files.
  if [[ "$tool" == "Grep" ]]; then
    g=$(field '.tool_input.glob')
    if [[ -n "$g" ]] && { glob_hits_secret "$g" || glob_hits_secret "${g##*/}"; }; then
      deny "Grep glob '$g' targets secret files"
    fi
  fi

  [[ -n "$raw" ]] || exit 0
  if [[ -n "$agent" ]] && has_dotdot "$raw"; then
    deny "subagent '$agent' may not use '..' in paths ($raw)"
  fi
  if $is_write && [[ -n "$agent" && -L "$raw" ]]; then
    deny "subagent '$agent' may not write through a symlink ($raw)"
  fi
  rel=$(resolve "$raw")

  class=$(classify "$rel")
  [[ "$class" == secret ]] && deny "secrets / signing files are off-limits to the agent ($raw)"
  $is_write || exit 0

  case "$class" in
    settings_local) deny "settings.local.json can override project hooks and permissions" ;;
    generated) deny "generated file — edit its source and regenerate (design tokens: design/tokens.json + 'fvm dart run tool/generate_tokens.dart') ($raw)" ;;
    lock) deny "lockfiles change only via 'fvm flutter pub get' / 'pod install' ($raw)" ;;
  esac

  if [[ "$rel" == OUTSIDE:* ]]; then
    abs=${rel#OUTSIDE:}
    [[ "$abs" == "$HOME"/.claude/* ]] && deny "user-level Claude settings are off-limits ($abs)"
    [[ -n "$agent" ]] && deny "subagent '$agent' may not write outside the project ($abs)"
    exit 0
  fi

  case "$agent" in
    "") ;;
    test-writer) [[ "$rel" == test/* ]] || deny "test-writer may only write under test/ — report bugs in lib/ instead of fixing them ($rel)" ;;
    spec-writer) [[ "$rel" == docs/specs/* ]] || deny "spec-writer may only write docs/specs/ ($rel)" ;;
    code-reviewer) deny "code-reviewer is read-only" ;;
    *) ;; # built-in agents (Explore, Plan, general-purpose…): rules 1-3 only
  esac

  [[ "$class" == guardrail ]] && guarded "$rel"
  exit 0
fi

# ------------------------------------------------------------------- Bash
cmd=$(field '.tool_input.command')
[[ -n "$cmd" ]] || exit 0

# Inspect only the command, not text it carries: drop heredoc bodies and
# -m "…" commit messages so a message mentioning .env is no false positive.
scan=$(awk '{ print } /<<-?[[:space:]]*["'"'"']?[A-Za-z_]+/ { exit }' <<<"$cmd" |
  sed -E "s/(-m|--message)[[:space:]]+(\"[^\"]*\"|'[^']*')//g")
# Defeat quoting tricks: cat .e""nv / cat .e\nv / cat '.env'.
norm=$(tr -d "\"'\\\\" <<<"$scan")
# Harmless redirections are not writes.
writes=$(sed -E 's/[0-9]*>&[0-9]+//g; s/[0-9]*>+[[:space:]]*\/dev\/null//g' <<<"$norm")
WRITE_OP='(>|(^|[[:space:]])(sed[[:space:]]+(-[a-zA-Z]*i|--in-place)|perl[[:space:]]+-[a-zA-Z]*i|tee|mv|cp|rm|rmdir|truncate|dd|chmod|chown|ln|install|touch|unlink|python3?|ruby|node|osascript)([[:space:]]|$))'
is_shell_write=false
grep -Eq "$WRITE_OP" <<<"$writes" && is_shell_write=true

# A nested Claude Code run would bypass this session's permissions/hooks.
if grep -Eq '(^|[[:space:]/;&|(])claude([[:space:]]|$)' <<<"$norm"; then
  [[ -n "$agent" ]] && deny "subagent '$agent' may not start Claude Code"
  grep -Eq -- '--dangerously-skip-permissions|bypassPermissions|(^|[[:space:]])config[[:space:]]+(set|add)' <<<"$norm" &&
    deny "starting Claude Code with bypassed permissions / changing its config is not allowed"
fi
if $is_shell_write && grep -q "$OFF_SWITCH" <<<"$norm"; then
  deny "'$OFF_SWITCH' may not be set by the agent"
fi

# Secrets: any token whose basename is (or can glob-match) a secret file.
for tok in $(tr '|;&<>()=`$' '          ' <<<"$norm"); do
  base=${tok##*/}
  [[ -n "$base" ]] || continue
  is_secret_name "$base" && deny "secrets / signing files are off-limits to the agent (command: $cmd)"
  case "$base" in
    *[*?[]*) glob_hits_secret "$base" && deny "glob '$base' can match secret files (command: $cmd)" ;;
  esac
done

# Writes to protected files through the shell.
if $is_shell_write; then
  for tok in $(tr '|;&<>()=`$' '          ' <<<"$writes"); do
    case "$tok" in -*) continue ;; esac
    [[ "$tok" == */* || "$tok" == *.* || "$tok" == CLAUDE.md ]] || continue
    rel=$(resolve "$tok")
    if [[ "$rel" == OUTSIDE:* ]]; then
      [[ "${rel#OUTSIDE:}" == "$HOME"/.claude/* ]] && deny "user-level Claude settings are off-limits (command: $cmd)"
      continue
    fi
    case "$(classify "$rel")" in
      settings_local) deny "settings.local.json can override project hooks and permissions (command: $cmd)" ;;
      generated | lock) deny "generated files / lockfiles change only via their generator or 'pub get' (command: $cmd)" ;;
      guardrail) guarded "$rel via shell" ;;
    esac
  done
fi

# Subagent shell sandboxes: allow-listed commands only, no chaining.
[[ -n "$agent" ]] || exit 0
case "$agent" in
  test-writer)
    ALLOWED='^(fvm )?(flutter test|flutter analyze|dart format|dart analyze)( |$)|^git (status|diff|log|show)( |$)' ;;
  code-reviewer)
    ALLOWED='^(fvm )?(flutter analyze|dart analyze)( |$)|^git (status|diff|log|show|rev-parse)( |$)|^git branch --show-current$' ;;
  spec-writer) deny "spec-writer has no shell access" ;;
  *) exit 0 ;; # built-in agents: rules 1-3 only
esac
FILTERS='^(grep|head|tail|wc|sort|uniq)( |$)'

scan=${scan//2>&1/} # merging stderr is harmless; any other redirect is not
if grep -Eq '(;|&&|\|\||`|\$\(|<\(|>|<)' <<<"$scan" || [[ "$scan" == *$'\n'* ]]; then
  deny "subagent '$agent': chaining, substitution and redirection are not allowed — run one command at a time ($cmd)"
fi
grep -Eq '(^|[[:space:]])--(output|write)(=|[[:space:]]|$)' <<<"$scan" &&
  deny "subagent '$agent': --output/--write would create files ($cmd)"
for tok in $scan; do
  has_dotdot "$tok" && deny "subagent '$agent' may not use '..' in paths ($cmd)"
done

first=true
IFS='|' read -r -a segs <<<"$scan"
for seg in "${segs[@]}"; do
  seg=$(sed -E 's/^[[:space:]]+//; s/[[:space:]]+$//' <<<"$seg")
  if $first; then
    grep -Eq "$ALLOWED" <<<"$seg" || deny "subagent '$agent' may not run: $seg"
    # dart format writes files: test-writer only, and only under test/.
    if [[ "$seg" == *"dart format"* ]]; then
      [[ "$agent" == test-writer ]] || deny "subagent '$agent' may not format files"
      for a in ${seg#*format}; do
        case "$a" in -*) ;; test | test/*) ;; *) deny "test-writer may only format files under test/ ($a)" ;; esac
      done
    fi
    first=false
  else
    grep -Eq "$FILTERS" <<<"$seg" || deny "subagent '$agent' may only pipe into grep/head/tail/wc/sort/uniq ($seg)"
  fi
done
exit 0
