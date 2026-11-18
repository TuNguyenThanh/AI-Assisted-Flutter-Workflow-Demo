---
name: fix-bug
description: Fix a bug test-first — reproduce it, find the root cause, write a failing regression test (via test-writer), apply the smallest fix that respects Clean Architecture, then prove it with the full gate. Use when the user reports a bug, a crash, wrong behaviour, a failing test in main, or says "fix", "doesn't work", "broken", with or without a ticket id (e.g. /fix-bug BUG-012).
argument-hint: <BUG-ID | short description of the bug>
---

# /fix-bug <BUG-ID | description>

Rule of the skill: **no fix without a test that failed first.** A fix that
is not pinned by a regression test comes back. Always use the FVM-pinned SDK
(`fvm flutter …`, `fvm dart …`).

```
report ──▶ reproduce ──▶ root cause ──▶ ⏸ (only if big) ──▶ RED test ──▶ fix ──▶ GREEN + gate
                                                            └────── same turn ──────┘
```
The red test and the fix must happen **in the same turn**: the Stop hook
runs the whole suite and blocks ending a turn while a test is red.

## 0. Scope
- Ticket id given → `get_requirement("<ID>")` (`project-docs` MCP; bug
  tickets live in `docs/requirements/<ID>-*.md`). Free-text description →
  use it; if there is no id, ask the user for one or use `regression` as
  the test prefix below.
- Collect: steps to reproduce, expected vs actual, logs/stack trace,
  platform. If expected behaviour is unclear, check `docs/specs/*-spec.md`
  (the AC is the source of truth) and the API contract
  (`get_api_contract`). Still unclear → ask; do not guess the "right"
  behaviour.
- Branch `fix/<ID>-<short-name>` from `main` (never fix on `main`).

## 1. Reproduce and locate
- Find the code path: `Grep` the feature, read cubit → use case →
  repository → data source. Note which layer is wrong.
- Check `git log -p --follow <file>` for the change that introduced it —
  a recent regression changes the fix (revert vs patch).
- Reproduce in the cheapest layer that shows it (unit > bloc > widget).
  If it only shows on device (native config, plugin, platform channel),
  say so: a widget test cannot pin it; list manual verification steps.

## 2. Root cause (write it down)
State in 2-4 lines: *what* is wrong, *why* it happens, *where*
(file:line). Then `Grep` for the **same pattern elsewhere** (e.g. other
`emit` after `await` without `isClosed`, other interceptor branches not
calling the handler) and list every hit — same bug, same fix.

Common causes in this repo (check first): missing `if (isClosed) return;`,
`BuildContext` across an async gap, exception escaping a data source
instead of `AppException`, `Failure` not mapped in the repository, an
interceptor path that never calls the handler or treats a network error
as logout, DTO field not matching `docs/api/openapi.yaml`.

⏸ **Stop and ask the human before coding** only if the fix: changes a
spec/AC, the public API of a shared component in `lib/core/`, the
architecture, security behaviour (tokens, session), or needs a new
package. Otherwise continue.

## 3. Regression test — RED
Delegate to the **test-writer** subagent. Brief it with: the bug report
(it replaces the spec here), the root cause, the file to test, and these
rules:
- Name: `'<ID>: <expected behaviour>'`, e.g. `'BUG-012: …'` (or
  `'regression: …'` without an id) — `/pr-ready` requires it on a
  `fix/<ID>-…` branch. If the bug breaks an existing AC, also say which
  `<TICKET> AC-n` in the report.
- The test **must fail now**, for the reason in the root cause — not
  because of a typo, missing stub or compile error. Do not make it pass.
- Put it in the existing test file of that unit; shared mocks in
  `test/helpers/mocks.dart`, fixtures in `test/helpers/fixtures.dart`.

Run only that test and read the failure message. Wrong reason → send it
back to test-writer.

## 4. Fix — smallest change
- Fix in the layer that owns the bug, following CLAUDE.md (Result /
  Failure across the domain boundary, `isClosed` guards, tokens via
  `TokenStorage`, design tokens in UI). Apply it to every hit from step 2.
- No drive-by refactors; no unrelated formatting churn.
- Never change an existing test's expectation to make it pass, unless
  the spec was wrong — then stop and ask (step 2 ⏸).
- Hooks format/analyze every edited file; fix what they report.

## 5. Verify — GREEN
1. The regression test passes; temporarily confirm it would catch the bug
   again by reasoning about it (do not commit a revert).
2. `fvm flutter analyze --fatal-infos` → 0 issues.
3. `fvm flutter test --coverage` → whole suite green.
4. `bash scripts/coverage_check.sh 80`.

## 6. Report and close
- Summary for the human: root cause, fix (files), regression test name,
  other places fixed, what to verify manually on device.
- Spec: if the bug exposed a missing behaviour, propose a new `AC-n` row
  (and its test) or a "Human review notes" entry — do not rewrite ACs
  silently.
- If the root cause is a mistake AI tends to repeat, propose one line for
  `CLAUDE.md` or the `code-reviewer` checklist (docs/QUALITY_GATES.md).
  These are guardrails: propose the text, the human approves the edit.
- Commit (needs the user's OK): `fix(<feature>): <what> (<ID>)`, body =
  root cause + test name. Before the PR: `/pr-ready <ID>`.
