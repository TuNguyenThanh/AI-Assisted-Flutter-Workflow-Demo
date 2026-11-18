# CLAUDE.md — project rules for AI agents

Flutter app, Clean Architecture + BLoC/Cubit. Read this before every task.

## Commands
Flutter version is pinned in `.fvmrc` (3.47.4). Always prefix with `fvm`.
- Format: `fvm dart format lib test tool`
- Analyze: `fvm flutter analyze --fatal-infos` (very_good_analysis, must be 0 issues — same as CI)
- Test: `fvm flutter test` · coverage: `fvm flutter test --coverage`
- Run: `fvm flutter run --dart-define=API_BASE_URL=https://dummyjson.com`
- After switching Flutter version: `fvm flutter clean && fvm flutter pub get`
- IDE uses the same SDK via `.vscode/settings.json` (`dart.flutterSdkPath`). If `pubspec.lock` changes without a dependency change, a non-FVM SDK resolved it — `git restore pubspec.lock && fvm flutter pub get`, never commit it.

## Architecture (strict)
```
lib/
  core/            # shared: error, network, storage, di — no feature imports
  features/<name>/
    domain/        # entities, repository interfaces, use cases — pure Dart, NO flutter/dio imports
    data/          # models (DTO), data sources, repository impl
    presentation/  # cubit/ (+ part state), pages/, widgets/
```
- Dependency direction: presentation → domain ← data. Domain imports nothing from data/presentation.
- Data sources throw `AppException`; repositories return `Result<T>` (`Success` / `Failed(Failure)`); never throw across the domain boundary.
- Cubit by default. Use Bloc only when events need transformers (debounce, droppable).
- States: `Equatable`, immutable. Sealed classes for mutually exclusive states.
- After every `await` in a Cubit: `if (isClosed) return;` before `emit`.
- DI in `core/di/injection.dart` (get_it). Cubits = `registerFactory`.
- Import with `package:demo_ai_workflow/...`, no relative imports in `lib/`.

## Security
- Tokens only via `TokenStorage` (flutter_secure_storage). Never SharedPreferences.
- Never log request/response headers or bodies, tokens, or passwords.
- Interceptors: every code path must call the handler; only a rejected refresh token (401/403) ends the session, never a network error.
- Never hardcode base URLs or keys → `--dart-define`.

## Figma → Flutter (Figma MCP)
- Get design via `get_design_context` (node from the Figma URL in the ticket), tokens via `get_variable_defs`, and `get_screenshot` to compare.
- Figma MCP returns React + Tailwind by default: treat it as a **spec, not code**. Rebuild with Flutter widgets (Column/Row/Padding), never `Positioned` with absolute coordinates from Figma.
- Reuse components from `lib/core/widgets/widgets.dart` (AppButton, AppTextField, AppPasswordField, AppInlineError, AppErrorView, AppAvatar) before writing new UI. A pattern used on 2+ screens becomes a component there, with its own test (states, dark mode, semantics).
- Material roles: `Theme.of(context).colorScheme.*`; tokens without a Material slot (e.g. `success`): `context.colors.*`.
- Design tokens live in `design/tokens.json` → generated `lib/core/theme/app_tokens.g.dart` (`/figma-tokens` skill). In widgets use `AppSpacing.*`, `AppRadius.*`, `Theme.of(context).textTheme.*`, `context.colors.*` — never hex colors, `Colors.*`, or raw font sizes/paddings.
- New/changed tokens: edit `design/tokens.json` and run `fvm dart run tool/generate_tokens.dart`; never edit the `.g.dart` file.
- Reuse existing widgets before creating new ones; assets go to `assets/` with `pubspec.yaml` entries.
- Must work on small screens (360dp), large text scale (1.3x) and dark mode if the design defines it.

## Testing
- Every acceptance criterion in `docs/specs/<TICKET>-spec.md` has a test whose name starts with `'<TICKET> AC-n: '` (e.g. `'AUTH-001 AC-1: …'` — CI matches the ticket id, not just `AC-n`).
- Every bug fix has a regression test named `'<BUG-ID>: …'` (or `'regression: …'` without an id).
- Mocks with `mocktail` in `test/helpers/mocks.dart`; cubits with `bloc_test`.
- Widgets: find by `Key('<feature>_<element>')`.

## Workflow
1. Read the ticket via MCP: `get_requirement("<ID>")`, API via `get_api_contract`.
2. Use plan mode / `spec-writer` agent → write `docs/specs/<ID>-spec.md` → WAIT for human approval.
3. Implement layer by layer (domain → data → presentation), small commits.
4. Tests via `test-writer` agent (`/write-tests` finds gaps and briefs it); review via `code-reviewer` agent.
5. `/pr-ready` before opening a PR.

Bugs: `/fix-bug <ID>` — reproduce → root cause → failing regression test → smallest fix, on a `fix/<ID>-…` branch.

## Definition of done
- [ ] `/pr-ready` passes (same checks as CI: `fvm flutter analyze --fatal-infos` 0 issues, `fvm dart format` clean, tokens in sync, all tests green)
- [ ] Every AC has a test; coverage of `lib/features/**` + `lib/core/widgets/**` ≥ 80% (`scripts/coverage_check.sh`)
- [ ] No TODO without ticket id; no `print`; no `// ignore` without a reason comment
- [ ] Spec "Human review notes" updated if the design changed

## Guardrails (enforced by hooks — tested by `bash scripts/test_hooks.sh`)
- `.claude/`, `.github/`, `scripts/`, `.cursor/rules/`, `CLAUDE.md`, `analysis_options.yaml`, MCP config are guardrails: changing them needs the human's explicit approval (hook asks); subagents can't.
- Subagent sandboxes: `test-writer` writes only `test/`, `spec-writer` only `docs/specs/`, `code-reviewer` nothing; their shell is allow-listed, one command at a time.
- A green check must come from fixing code: never skip tests, weaken assertions, add `ignore_for_file`, add `// ignore:` without a reason comment, or lower the coverage floor (80%).
- If a hook blocks you, don't look for another route to the same action — tell the human what you needed and why.
- Hooks need `jq`. The Stop hook runs format, token sync, analyze `--fatal-infos` and tests before you may finish.

## Don'ts
- Don't edit generated files (`*.g.dart`, `*.freezed.dart`) or lockfiles — hooks will block you.
- Don't add packages without asking.
- Don't "fix" a failing test by changing its expectation unless the spec changed.
