# AUTH-001 — Technical spec

> Drafted by the `spec-writer` subagent from `get_requirement("AUTH-001")` +
> `get_api_contract()`. Reviewed and edited by me before any code was
> written — see **Human review notes** at the bottom.

## Acceptance criteria (each one maps to ≥1 test, test names start with `AC-n`)
| ID   | Given / When / Then | Test |
|------|---------------------|------|
| AC-1 | Valid credentials → tokens saved securely → navigate to Profile | `auth_repository_impl_test`, `login_cubit_test`, `login_page_test` |
| AC-2 | Wrong credentials (HTTP 400) → "Username or password is incorrect." and nothing stored | repo + cubit + widget |
| AC-3 | No network / timeout → "No internet connection…" | repo |
| AC-4 | Empty username or password < 6 chars → inline error, **no API call** | cubit |
| AC-5 | While submitting → button disabled + spinner; double tap sends 1 request | cubit + widget |
| AC-6 | Profile shows avatar/name/username/email; Logout clears tokens → Login | profile cubit, repo |
| AC-7 | `/auth/me` returns 401 and refresh fails → session cleared → Login | repo, interceptor |

## Design
```
presentation  LoginPage ─ LoginCubit        ProfilePage ─ ProfileCubit
                   │                              │
domain        LoginUseCase     GetProfileUseCase / LogoutUseCase
                   └──────────── AuthRepository (interface) ─┘
data          AuthRepositoryImpl ─ AuthRemoteDataSource (Dio) ─ TokenStorage (secure)
core          DioFactory + AuthInterceptor (bearer + refresh) · Failure · Result<T>
```
- Errors: Dio → `AppException` (data source) → `Failure` (repository) → `String` (state). UI never sees Dio.
- `Result<T>` is a sealed class → `switch` must be exhaustive.
- DI: `get_it`; cubits registered as factories (one per screen).

## Task breakdown
1. core: Failure/Exception/Result, TokenStorage, DioFactory
2. domain: User, AuthRepository, use cases
3. data: models, remote data source, repository impl
4. presentation: cubits + pages
5. tests per AC
6. README/CHANGELOG

## Human review notes (what I changed in the AI draft)
- ❌ Draft stored tokens with `shared_preferences` → ✅ `flutter_secure_storage` (requirement #6).
- ❌ Draft had no refresh-token flow, although BA notes mention it → ✅ added `AuthInterceptor` (QueuedInterceptor, retries once, separate Dio to avoid loops) and AC-7.
- ❌ Draft used `Bloc` with 6 events for a single form → ✅ `Cubit` is enough, less boilerplate.
- ➕ Added AC-5 (double tap) — QA always tests this on slow 3G.
- ➕ Logging rule: `LogInterceptor` must not log headers/body.

### LoginPage redesign from Figma (2026-11-18)
Source: Figma `oPeUQfgMIErzZ7BIWwzkMz`, frame "Login" (node `16:5`). Presentation
layer only — `LoginCubit`, domain and data unchanged; all `Key('login_…')` kept.
- ✅ Layout rebuilt with Column/slivers (no absolute positions): centered "Login"
  title, label-above text fields, "Forgot Password?" link right-aligned, pill
  primary button, "or login with" + Google button pinned to the bottom (scrolls
  on 360dp / 1.3x text). AppBar removed — the design has none.
- ➕ New component `AppTextField` (label above box + placeholder; label is
  attached to the field's semantics). `AppPasswordField` now builds on it, gains
  `hint`, and shows eye-off while hidden (as in Figma).
- ➕ `AppButton` gained an optional `icon` (used for the Google logo).
- 🎨 Theme: buttons are pills (`Radius/full`); inputs use `outlineVariant` border
  and muted placeholder; outlined button text uses `onSurface`. Affects every
  screen (Profile logout, error Retry).
- ⚠️ **Colors / font not from Figma yet.** Token sync is blocked: white on
  primary `#2b8761` is 4.43:1 (< 4.5 AA); waiting for the designer. The page uses
  theme roles only (`colorScheme.*`, `textTheme.*`), so it picks up the green
  primary, accent link (`secondary` = `#3c9afb`) and Gabarito automatically
  after `/figma-tokens`. Title uses `headlineSmall` (24) until `Title/Screen`
  (30/34 bold) is added as a token.
- ❌ Figma says "E-mail / Enter your email" → ✅ kept **Username** — the API
  (`POST /auth/login`) authenticates by username, an e-mail label would mislead.
  Designer to update the copy.
- ⚠️ "Forgot Password?" and "Login with Google" have no ticket/backend: they show
  a "not available yet" SnackBar and are disabled while submitting. Need a
  ticket each, or hide them before release.
- ⚠️ Google icon is a PNG (1x/2x/3x export) — no SVG package in the project.
  The export has a white background, visible as a square in dark mode; dark is
  deferred (no Dark frame in Figma). Re-export with transparent background.
- Status bar in the frame is the OS status bar — not built.
