---
name: pr-ready
description: Pre-PR gate. Runs the same checks as CI (format, token sync, analyze, tests, coverage, AC traceability), scans the diff against the AI-code checklist and drafts the PR description. Use when the user says the feature is done or asks to open a PR.
argument-hint: "[TICKET-ID]"
---

# /pr-ready [TICKET-ID]

Mirror `.github/workflows/ci.yml` exactly — if this passes locally, CI must
pass. Always use the FVM-pinned SDK (`.fvmrc`), never bare `flutter`/`dart`.

## 0. Scope
- Ticket id: the argument; else from the branch name (`feat/AUTH-001-…`);
  else ask the user.
- `git branch --show-current` and `git status --porcelain`:
  - On `main` → stop: work must be on a feature branch.
  - Uncommitted changes → stop and list them; the gate and the review run
    on what will be in the PR (`main...HEAD`), so commit first.

## 1. CI checks (stop at the first failure and fix it)
1. `bash scripts/test_hooks.sh` (CI job `hooks`; CI also runs `shellcheck`)
2. `fvm dart format --set-exit-if-changed lib test tool`
3. `fvm dart run tool/generate_tokens.dart --check` (tokens.json ↔ `.g.dart`)
4. `fvm flutter analyze --fatal-infos`
5. `fvm flutter test --coverage`
6. `bash scripts/coverage_check.sh 80` (`lib/features/` + `lib/core/widgets/`;
   80 is the floor — the script rejects lower values)
7. AC ↔ test traceability (step 3 below).

`build-android` is currently commented out in `ci.yml`; say so in the
results table and recommend a local `fvm flutter build apk --debug` when
the diff touches `pubspec.yaml`, `android/` or `ios/`.

"Fix" means fixing the code. Never make a check pass by skipping tests,
weakening assertions, adding `// ignore`, lowering thresholds or editing
CI / hooks / `analysis_options.yaml` — hooks block most of these; if one is
the only way forward, stop and ask the human.

## 2. Diff scan
`git diff main...HEAD --stat`, then scan `git diff main...HEAD` for:
- `print(`, `TODO` without ticket id, `// ignore` without a reason comment.
- Security: `SharedPreferences` near "token", logging of headers/bodies/
  tokens/passwords, `http://`, hardcoded base URLs or keys.
- Figma rules: hex colors / `Color(0x`, `Colors.`, raw `fontSize:` /
  `EdgeInsets` numbers, `Positioned` with Figma coordinates (outside `*.g.dart`).
- Edited generated files (`*.g.dart`, `*.freezed.dart`) or lockfiles.
- New packages in `pubspec.yaml` → confirm the user approved them.
- Gate gaming (list each one for the human, blocker unless the spec
  changed): `git diff main...HEAD -- test/` lines removing `expect(`,
  `verify(`, `test(` / `testWidgets(` / `blocTest(`; deleted test files
  (`git diff --diff-filter=D --name-only main...HEAD -- test/`); `skip:`;
  any change under `.claude/`, `.github/`, `scripts/`, or to
  `analysis_options.yaml` / `CLAUDE.md`.

## 3. Spec ↔ tests
- Map each `AC-n` in `docs/specs/<ID>-spec.md` to a test name
  (`grep -rn "AC-" test/`). Any AC without a test → blocker.
- If the UI/design changed, the spec's "Human review notes" must be updated.

## 4. PR body
Draft it from `.github/pull_request_template.md`, filling: ticket, summary,
AC→test table, "AI involvement" (which parts were generated, what the human
changed), manual test steps, screenshots placeholder. Leave the checklist
boxes for the human to tick.

## 5. Stop
Do NOT push or open the PR yourself — print the results table and the PR
body for the human.
