---
name: figma-tokens
description: Build or update the Flutter design-system tokens (colors light/dark, spacing, radius, typography) from a Figma file via Figma MCP, then regenerate the theme code. Use when the user shares a Figma link for a design system / style guide, asks to "sync tokens", "update theme from Figma", or design colors/fonts changed.
argument-hint: <figma-url-of-style-guide-or-screen> [dark-mode-frame-url]
allowed-tools: Read, Grep, Glob, Write, Edit, Bash(fvm dart run tool/generate_tokens.dart*), Bash(git diff*), Bash(fvm flutter test*), Bash(fvm flutter analyze*), mcp__figma__create_session, mcp__figma__get_variable_defs, mcp__figma__get_screenshot, mcp__figma__get_metadata, mcp__claude_ai_Figma__create_session, mcp__claude_ai_Figma__get_variable_defs, mcp__claude_ai_Figma__get_screenshot, mcp__claude_ai_Figma__get_metadata
---

# /figma-tokens <figma-url> [dark-frame-url]

Pipeline — the AI does the *judgement* part, a script does the
*deterministic* part:

```
Figma ──MCP──▶ (AI) normalize ──▶ design/tokens.json ──▶ tool/generate_tokens.dart
                                   + token_mapping.md        │ validate: roles, modes,
                                     (reviewed in PR)        │ names, WCAG contrast
                                                             ▼
                                            lib/core/theme/app_tokens.g.dart
                                            (AppColorTokens, AppSpacing, AppRadius,
                                             AppSize, AppTypography) → AppTheme.light/dark
```

## 1. Read Figma (read-only)
Use the Figma MCP server (`figma` from `.mcp.json`, or the claude.ai Figma
connector — whichever is connected; if neither is, stop and tell the user
to run `/mcp` → figma → Authenticate).
- Parse the URL: `figma.com/design/<fileKey>/<name>?node-id=1-2` → nodeId `1:2`.
- If the server exposes `create_session`, call it first with the fileKey.
- `get_variable_defs(fileKey, nodeId)` → variables used in that frame.
- `get_screenshot` of the same frame → keep as visual reference.
- `get_variable_defs` returns values for the frame's **current mode only**.
  For dark mode use the second URL (a frame set to Dark). If none is given,
  ask for it — never derive dark colors yourself.

## 2. Normalize into `design/tokens.json`
Schema (the generator rejects anything else):
```json
{
  "$source": "<figma url> (light) | <figma url> (dark) — synced YYYY-MM-DD",
  "color":      { "light": { "<role>": "#RRGGBB[AA]" }, "dark": { ... } },
  "spacing":    { "<name>": <px> },
  "radius":     { "<name>": <px> },
  "size":       { "<name>": <px> },
  "typography": { "<name>": { "fontSize": 16, "fontWeight": 400,
                              "lineHeight": 24, "letterSpacing": 0.5,
                              "fontFamily": "Inter" } }
}
```
Rules:
- **Never invent a value.** Every value must come from a Figma variable/style.
- Map Figma names to roles (`Colors/Brand/Primary` → `primary`,
  `Text/On Brand` → `onPrimary`, `Spacing/16` → a scale name like `md`).
  Required color roles: `primary onPrimary secondary onSecondary error
  onError surface onSurface outline`. Extra roles (e.g. `success`,
  `warning`) are allowed and become `context.colors.<role>`.
- `size` holds fixed dimensions that are not spacing (icon sizes, avatar,
  `minTouchTarget`) → `AppSize.*`. Keep existing size tokens unless the
  design removes them (code uses them).
- Names must be lowerCamelCase Dart identifiers (`2xl` → `xxl`).
- Typography names: use Material `TextTheme` slots when the meaning
  matches (`headlineSmall`, `bodyMedium`, `labelLarge`…) so they wire into
  the theme automatically.
- Figma `Font(... lineHeight: 150%)` → px: `fontSize * 1.5`.
  `letterSpacing: 2%` → px: `fontSize * 0.02`. Colors `#RRGGBBAA` keep
  Figma's order — the generator converts to Flutter's `0xAARRGGBB`.
- Write/refresh `design/token_mapping.md`: table *Figma name → token →
  value*, plus a list of Figma variables you ignored and why.

## 3. Generate + validate
```bash
fvm dart run tool/generate_tokens.dart
```
- If it fails on **contrast** (`onX` vs `X` < 4.5:1) or a **missing role**:
  do NOT tweak colors to make it pass. Report the exact pairs/roles for the
  designer and stop.
- Never edit `app_tokens.g.dart` by hand (the guard hook blocks it).
- Do not change `lib/core/theme/app_theme.dart` unless a new Material
  role needs mapping — that is a reviewed engineering decision.

## 4. Verify
- `fvm flutter analyze && fvm flutter test`
- `git diff design/tokens.json` — summarize for the human: colors changed
  (old → new), tokens added/removed, any token whose removal breaks code
  (grep usages of `AppSpacing.<name>`, `AppSize.<name>` etc.).
- Grep for hardcoded styling that should now use tokens:
  `grep -rnE "Color\(0x|Colors\.|EdgeInsets\.all\([0-9]|fontSize: [0-9]" lib --exclude=*.g.dart`
- ⏸ Show the summary + Figma screenshot; wait for approval before commit.

## Commit
`feat(theme): sync design tokens from Figma (<frame name>)` — body lists
changed tokens and the Figma URLs.
