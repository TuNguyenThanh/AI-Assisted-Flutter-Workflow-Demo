---
name: flutter-feature
description: Implement a Flutter feature end-to-end from a ticket id (e.g. /flutter-feature AUTH-001) following this repo's Clean Architecture + Cubit conventions — spec, layer-by-layer code, tests, review. Use when the user asks to build/implement a feature or ticket.
argument-hint: <TICKET-ID>
---

# /flutter-feature <TICKET-ID>

Follow these phases in order. Do not skip the human checkpoints (⏸).
Always use the FVM-pinned SDK (`.fvmrc`): `fvm flutter …`, `fvm dart …`.
Work on a feature branch (`feat/<ID>-<short-name>`), never on `main`.

## 1. Understand
- `get_requirement("<ID>")` and `get_api_contract(<path>)` via the
  `project-docs` MCP server.
- If the ticket has a Figma link, use the `figma` MCP server (or the
  claude.ai Figma connector): call `create_session` with the fileKey first,
  load the `figma-design-to-code` guidance (the `/figma-design-to-code`
  skill or the `skill://figma/figma-design-to-code/SKILL.md` resource)
  before the first `get_design_context`, then:
  `get_metadata` (screen structure) → `get_design_context` per frame →
  `get_variable_defs` (tokens) → `get_screenshot` (visual reference).
  List any token not yet in `design/tokens.json` and any state missing from
  the design (loading, error, empty, disabled) as open questions.
- If no approved spec exists, delegate to the **spec-writer** subagent.
- ⏸ Show the AC table and open questions. Wait for approval.

## 2. Scaffold
Create the folders from CLAUDE.md for `lib/features/<feature>/`. Reuse:
`core/error/result.dart`, `core/error/failures.dart`,
`core/error/exceptions.dart`, `core/storage/token_storage.dart`,
`core/network/dio_factory.dart`, and UI components from
`core/widgets/widgets.dart`.

## 3. Implement — one layer per commit
1. domain: entities (Equatable), repository interface, use cases.
2. data: DTO `fromJson` matching the OpenAPI schema exactly; data source
   maps `DioException` → `AppException` in one `_guard`; repository maps
   → `Failure` and returns `Result<T>`.
3. presentation: Cubit + `part` state; `isClosed` guard after await;
   pages use `BlocConsumer` with `listenWhen` for navigation;
   `Key('<feature>_<element>')` on interactive widgets. Build UI from the
   Figma design context following the "Figma → Flutter" rules in CLAUDE.md,
   from existing components first. A missing component, or a pattern that
   appears on 2+ screens, goes through `/figma-component` (not inline in
   the page); a missing token goes through `/figma-tokens`. Then compare
   with `get_screenshot` and list visual differences for the human.
4. Register in `core/di/injection.dart` (Cubits = `registerFactory`).
Hooks auto-format and analyze each file; fix every reported issue
immediately. Commits need the user's OK (`git commit` is in `ask`).

## 4. Test
Delegate to the **test-writer** subagent with the spec path. Then run
`fvm flutter test --coverage` and `bash scripts/coverage_check.sh 80`.

## 5. Review
Delegate to the **code-reviewer** subagent. Fix blockers/majors.
If the design changed during implementation, update the spec's
"Human review notes".
⏸ Summarise the diff for the human reviewer: what changed, what you were
unsure about, what to check manually on device.

## 6. Gate
Run `/pr-ready <ID>`. It must pass before the PR is opened.

## Commit convention
`feat(<feature>): ...`, `test(<feature>): ...`, `fix(<feature>): ...`,
`docs(<ID>): ...` — body references the ticket id.
