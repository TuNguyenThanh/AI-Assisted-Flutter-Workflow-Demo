---
name: figma-component
description: Build or update one design-system component (button, text, loading, header, card, input…) in lib/core/widgets from a Figma component / component set via Figma MCP, with its own widget test (variants, states, dark mode, 360dp + 1.3x text, semantics). Use when the user shares a Figma component link, asks to "create a component/widget", "add AppXxx", or a UI pattern repeats on 2+ screens.
argument-hint: <AppName> <figma-url-of-component-or-component-set>
allowed-tools: Read, Grep, Glob, Write, Edit, Agent, Bash(fvm dart format*), Bash(fvm flutter analyze*), Bash(fvm flutter test*), Bash(git diff*), Bash(curl -fsSL -o assets/*), Bash(sips *), Bash(rm test/zz_scratch_render_test.dart), mcp__figma__create_session, mcp__figma__get_design_context, mcp__figma__get_variable_defs, mcp__figma__get_screenshot, mcp__figma__get_metadata, mcp__figma__download_assets, mcp__claude_ai_Figma__create_session, mcp__claude_ai_Figma__get_design_context, mcp__claude_ai_Figma__get_variable_defs, mcp__claude_ai_Figma__get_screenshot, mcp__claude_ai_Figma__get_metadata, mcp__claude_ai_Figma__download_assets, ReadMcpResourceTool
---

# /figma-component <AppName> <figma-url>

One run = one component. Order for a new app:
`/figma-tokens` first (tokens must exist) → then components, simplest first:
`AppText` → `AppLoading` → `AppButton` → `AppTextField` → `AppHeader` → …
Screens are built only from these components.

```
Figma component set ──MCP──▶ (AI) API design ──▶ lib/core/widgets/app_<name>.dart
  variants / props / states         │              + export in widgets.dart
                                    ▼              + test/core/widgets/app_<name>_test.dart
                         stop if a token is missing → /figma-tokens
```

## 0. Check before creating
- Read `lib/core/widgets/widgets.dart` and every file it exports.
- If an existing component already covers ≥ 80% of the design, **extend it**
  (new variant/param) instead of creating a new one. Say which you chose.
- Read `lib/core/theme/app_theme.dart` and `app_tokens.g.dart` to know which
  tokens and component themes (`filledButtonTheme`, `inputDecorationTheme`…)
  already exist.

## 1. Read Figma (read-only)
Use the `figma` MCP server or the claude.ai Figma connector. If neither is
connected, stop and tell the user to run `/mcp` → figma → Authenticate.
- Parse URL: `?node-id=1-2` → nodeId `1:2`. Call `create_session` first if
  the server exposes it.
- Before the first `get_design_context`, load the Figma server's
  `figma-design-to-code` guidance (the `/figma-design-to-code` skill, or the
  `skill://figma/figma-design-to-code/SKILL.md` MCP resource) — the server
  requires it.
- Point at the **component set** (all variants), not one instance. Users
  often paste an instance from a screen: its `data-name` / `get_metadata`
  shows the component name; find the main component with `get_metadata` on
  the file's components page, or ask the user for the component-set link.
  If you only have an instance, say so in the report.
- `get_design_context` → variant properties, layout (auto-layout = Row/Column,
  gap, padding), text styles, which variables are bound.
- `get_variable_defs` → token names used.
- `get_screenshot` → visual reference for the final comparison.
- The React/Tailwind output is a **spec, not code**.

### Assets (icons, logos, images)
- First look for an exact match already in `assets/` or a Material icon that
  is the same glyph. Otherwise download it — never leave a Figma asset URL
  (they expire) in code.
- The project has **no `flutter_svg`** (adding packages needs the user's OK).
  Default: export PNG with `download_assets(defaultFormat: png)` at scale 1,
  2 and 3 → `assets/icons/<name>.png`, `assets/icons/2.0x/<name>.png`,
  `assets/icons/3.0x/<name>.png`; check sizes with `sips -g pixelWidth`.
- Open the 3x file and check the background is **transparent** — a baked-in
  white square shows up in dark mode. If it isn't, ask the designer to
  re-export (don't edit the asset yourself).
- Declare the folder under `flutter: assets:` in `pubspec.yaml`.

## 2. Design the API (write it down before coding)
Map Figma properties to Dart:
| Figma | Dart |
|---|---|
| Variant property `Type=Primary/Secondary` | `enum AppXxxVariant { primary, secondary }` |
| Variant `Size=S/M/L` | `enum AppXxxSize { small, medium, large }` (only if the design has it) |
| Boolean property `Show icon` | nullable `Widget? icon` |
| Text property `Label` | `required String label` |
| State `Disabled` (buttons, tappables) | `onPressed == null` (Material convention), not a bool |
| State `Disabled` (inputs) | `bool enabled = true` (mirrors `TextField.enabled`) |
| State `Loading` | `bool isLoading = false` |
| State `Hover/Pressed/Focused` | handled by Material `WidgetState` in the theme — no params |

Rules:
- Minimal API: only params the design actually varies. Named params,
  `required` first, `super.key` last, `const` constructor.
- Every value must map to a token: `AppSpacing.*`, `AppRadius.*`, `AppSize.*`,
  `Theme.of(context).textTheme.*`, `colorScheme.*`, `context.colors.*`.
  **If a value has no token, stop** and list the missing ones — the user
  runs `/figma-tokens`. Never hardcode hex, `Colors.*`, font sizes, paddings.
  Common gaps to check: odd spacings (6, 12), border widths (1.5, 2),
  screen-title sizes. If the user explicitly says to continue with the
  nearest token, do so and list every approximation in the report.
- Style that applies to every instance of a Material widget (e.g. all
  FilledButtons) goes in the component theme in `app_theme.dart`, not in the
  widget. The widget composes; the theme styles.
- Build on Material widgets (FilledButton, TextField, AppBar,
  CircularProgressIndicator…) to get focus, ripple, a11y for free.
- Layout from auto-layout: `Row/Column` + `SizedBox(width/height: AppSpacing.*)`.
  Never `Positioned`/fixed width from Figma coordinates; text must wrap or
  ellipsize, never overflow.

## 3. Write the component
`lib/core/widgets/app_<snake_name>.dart`, following `app_button.dart`:
```dart
import 'package:demo_ai_workflow/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

enum AppXxxVariant { primary, secondary }

/// <One line: what it is.>
///
/// - <Behaviour worth knowing: loading keeps size, decorative icon, …>
/// - Figma: <component url>
class AppXxx extends StatelessWidget {
  const AppXxx({
    required this.label,
    this.variant = AppXxxVariant.primary,
    super.key,
  });

  final String label;
  final AppXxxVariant variant;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // ...
  }
}
```
- Semantics: buttons are `button: true`; loading announces "<label>, loading";
  decorative icons `ExcludeSemantics`; errors `liveRegion: true`;
  headers `header: true`. Touch targets ≥ 48dp.
- Inputs with a visible label above the box (Figma `.Header` + `.Input`):
  follow `app_text_field.dart` — `ExcludeSemantics` on the visible label
  `Text`, `Semantics(label: label)` around the `TextField`, so screen readers
  hear one node "<label>, text field" (verified: the hint does not change
  that label). Test it with an **exact** `find.bySemanticsLabel('<label>')`
  and `isTextField` on the `TextField` node — see `app_text_field_test.dart`.
- Add `export 'app_<snake_name>.dart';` to `widgets.dart` (alphabetical).

## 4. Test it
Per CLAUDE.md, tests are written by the `test-writer` agent: spawn it with
the component file, the API table from step 2 and the case list below.
Tell it explicitly that components have **no `docs/specs/` file** — the API
table + case list replace the spec, and test names describe the case (no
`AC-n` prefix). It must not edit `lib/`; if it reports a bug, fix it here
and re-run.

File: `test/core/widgets/app_<snake_name>_test.dart` (one file per
component; don't add to `widgets_test.dart`), using a host like
`widgets_test.dart`. Required cases:
1. Each variant renders (find the underlying Material widget / text).
2. Each interactive state: tap callback, disabled (as mapped in step 2:
   `onPressed: null` for tappables, `enabled: false` for inputs),
   loading (no tap, spinner, **same size** as idle).
3. Dark mode: pump with `AppTheme.dark()` — no exception, colors come from
   the dark scheme.
4. Small screen + large text: `tester.view.physicalSize = Size(360, 640)`,
   `devicePixelRatio = 1`, `MediaQuery(textScaler: TextScaler.linear(1.3))`
   → `expect(tester.takeException(), isNull)` (no overflow). Reset the view
   in `addTearDown`.
5. Semantics: `tester.ensureSemantics()` + exact `find.bySemanticsLabel(...)`
   / flags for the a11y rules above.

## 5. Verify
```
fvm dart format lib test
fvm flutter analyze          # must be 0 issues
fvm flutter test             # the WHOLE suite, not only test/core/widgets
```
Components and `app_theme.dart` are shared: a change can pass its own test
and still break a screen's test (semantics, keys, sizes). If a feature test
fails, fix the component — don't change the feature test's expectation
(CLAUDE.md) unless the spec changed; if the change is intentional, stop and
tell the user which screens are affected.
Then compare with the Figma screenshot and report.

### Rendering the component for the visual comparison
Widget tests use the Ahem font (text = black boxes), so load real fonts:
1. Write a throwaway test `test/zz_scratch_render_test.dart` that:
   - loads fonts with `FontLoader` from the FVM SDK (`$FLUTTER_ROOT` is
     usually unset with FVM): `.fvm/flutter_sdk/bin/cache/artifacts/material_fonts/`
     `Roboto-Regular.ttf` + `Roboto-Medium.ttf` as `Roboto`, and
     `MaterialIcons-Regular.otf` as `MaterialIcons` (if the design uses another
     font family, load it from `assets/fonts/` under its own name);
   - sets `tester.view.physicalSize` / `devicePixelRatio = 2`;
   - precaches any `Image` inside `tester.runAsync`;
   - pumps the component in light, dark, and 360dp + 1.3x;
   - `matchesGoldenFile('file://<scratchpad>/<name>_<mode>.png')`.
2. Run it with `fvm flutter test test/zz_scratch_render_test.dart --update-goldens`,
   view the PNGs next to the Figma screenshot, then **delete the test file**
   with `rm test/zz_scratch_render_test.dart` (it is not a real golden test;
   it must not be left in the suite or the diff).
Text drawn with the theme's own `textStyle` (e.g. button labels) may still
show as boxes — that is the test font, not a bug.

## 6. Report to the user
- API table: param → Figma property.
- Files created/changed (incl. any `app_theme.dart` component-theme change).
- Deviations from Figma and why (e.g. "hover state skipped — mobile only").
- Missing tokens, if any (and that you stopped).
Do not commit; the user reviews first.
