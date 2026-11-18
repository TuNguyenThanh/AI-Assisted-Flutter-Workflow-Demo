---
name: write-tests
description: Find test gaps and fill them — missing AC tests, uncovered lines, untested states — for a ticket, a file/folder, or the current diff, by briefing the test-writer subagent, then verify the tests are real (fail on broken code, no gaming) and coverage ≥ 80%. Use when the user asks to "write/add tests", "increase coverage", "cover AC-n", or coverage_check fails.
argument-hint: "[TICKET-ID | path under lib/ | diff]"
allowed-tools: Read, Grep, Glob, Agent, Bash(fvm flutter test*), Bash(bash scripts/coverage_check.sh*), Bash(git diff*), Bash(git status*), Bash(git branch --show-current), mcp__project-docs__get_requirement
---

# /write-tests [TICKET-ID | path | diff]

You **orchestrate**; the `test-writer` subagent writes the tests (CLAUDE.md:
the author of the code does not write its tests). You never edit `lib/`
in this skill — a test that reveals a bug goes to `/fix-bug`.

```
scope ──▶ gap analysis ──▶ brief ──▶ test-writer ──▶ verify (real? green? coverage?) ──▶ report
```

## 0. Scope
- `TICKET-ID` → `get_requirement("<ID>")` (includes the approved spec) and
  the feature folder it touches.
- `path` → that file/folder under `lib/`; find the spec whose feature
  matches, if any (`docs/specs/`).
- `diff` or no argument → `git diff main...HEAD --name-only` plus
  `git status --porcelain`, limited to `lib/**/*.dart` (skip `*.g.dart`).
- Nothing in scope → say so and stop.

## 1. Gap analysis (write the list before delegating)
1. **AC gaps** — for each `| AC-n` row in `docs/specs/<ID>-spec.md`,
   `Grep` test/ for `'<ID> AC-n:`. Missing → must-have (CI fails on
   these). A bare `'AC-n:'` test doesn't count — rename it.
2. **Coverage gaps** — `fvm flutter test --coverage`, then read
   `coverage/lcov.info` for the in-scope files: per file `LH/LF`, and the
   `DA:<line>,0` lines → map them to the branch they belong to (error
   path, `isClosed` return, empty list, null field…).
3. **State gaps** — for every cubit state / sealed subclass, every
   `Failure` the repository can return, every widget state (loading,
   error, empty, disabled): is there a test? Check the usual misses:
   network error vs 401, double tap while submitting, emit after close,
   dark mode, 360dp + 1.3x text, semantics labels.
4. **Existing weak tests** — tests that only `expect(x, isNotNull)` /
   `anything`, mock exactly what they assert, or have no `expect`/`verify`.
   List them; replacing them with real assertions is in scope.

Prioritise: AC gaps → error/edge paths → coverage → nice-to-have. Do not
chase 100%: generated files, `main.dart`, pure DI wiring are not worth it.

## 2. Brief the test-writer
One `Agent` call (`subagent_type: test-writer`) per feature, with:
- the spec path (or, for `lib/core/widgets` components with no spec, the
  public API + case list — test names then describe the case, no `AC-n`);
- the exact gap list from step 1, each with file:line;
- the layer → test style: unit (repository, data source with `MockDio`),
  `blocTest` (cubit), `testWidgets` with `Key('<feature>_<element>')`;
- existing helpers: `test/helpers/mocks.dart`, `test/helpers/fixtures.dart`,
  and the existing test file to extend (one test file per source file,
  same path under `test/`);
- the rule: test behaviour from the spec, not the implementation; if a
  test fails because the **code** is wrong, report it with file:line —
  don't change `lib/`, don't bend the assertion.

## 3. Verify the tests are real
- `fvm flutter test` — whole suite green.
- `git diff -- test/`: no removed `expect(`/`verify(`/tests, no `skip:`,
  no weakened matchers, no new `// ignore` (hooks block most; check anyway).
- Spot-check 1-2 new tests per file: would it fail if the line it covers
  were broken (e.g. the `isClosed` guard removed, the `Failure` mapped
  differently)? If not, it is a mirror test — send it back.
- `fvm flutter test --coverage` then `bash scripts/coverage_check.sh 80`.
- Every AC in scope now has a `'<ID> AC-n:'` test.

## 4. If a test reveals a bug
The suite must not stay red (the Stop hook blocks the turn). Ask the user:
- **fix now** → continue with `/fix-bug`, using that test as the RED test;
- **later** → take that one case out of the new file (it never entered
  the suite, so this is not weakening), put its code and the failure in
  the report as a bug ticket draft. Never `skip:` it.

## 5. Report
Table: gap → test name → file. Coverage before → after (scope + gate).
Bugs found (file:line, expected vs actual). Weak tests replaced. Gaps
left on purpose and why. Do not commit; the user reviews
(`test(<feature>): …`).
