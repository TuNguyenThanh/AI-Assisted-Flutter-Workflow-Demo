# AI-assisted Flutter workflow — demo

Feature mẫu: **AUTH-001 — Login & Profile** (Flutter 3.47.4 qua FVM, Clean
Architecture, BLoC/Cubit, Dio, get_it, flutter_secure_storage), chạy với
API thật [DummyJSON](https://dummyjson.com) — tài khoản `emilys` / `emilyspass`.

> Đây là repo minh họa quy trình mình đang áp dụng ở dự án thật (code dự
> án thật không public được). README → `git log` →
> các file được link bên dưới.

---

## 1. Workflow requirement → production

```
Ticket (Jira) ──MCP──▶ Claude Code ─▶ Spec + AC ──⏸ mình duyệt──▶ Code từng layer
                                                                │  (hooks format/analyze mỗi lần sửa)
                                                                ▼
 Production ◀─ Release ◀─ Merge ◀─ CI gate ◀─ PR ◀─ /pr-ready ◀─ Review (subagent + mình) ◀─ Test (subagent)
```

| Bước | Làm gì | Bằng chứng |
|---|---|---|
| 1. Requirement | Claude đọc ticket & API contract trực tiếp qua MCP | [requirement](docs/requirements/AUTH-001-login-profile.md), [openapi](docs/api/openapi.yaml) |
| 2. Spec | Subagent `spec-writer` viết AC-1..7 → **mình sửa & duyệt** | [spec + Human review notes](docs/specs/AUTH-001-spec.md) |
| 3–4. Implement | Skill `/flutter-feature`: domain → data → presentation, 1 layer / commit | [`lib/features/auth`](lib/features/auth), `git log` |
| 5. Test | Subagent `test-writer` viết test từ spec, không đụng `lib/` | [`test/`](test) — 113 test, mỗi AC có test `AC-n` |
| 6. Review | Subagent `code-reviewer` + mình review diff | [session log](docs/session-logs/AUTH-001.md) |
| 7. Ship | `/pr-ready` → PR template → CI → merge → release | [ci.yml](.github/workflows/ci.yml), [PR template](.github/pull_request_template.md) |

Chi tiết, prompt mẫu, khi nào dùng Claude Code vs Cursor: **[docs/AI_WORKFLOW.md](docs/AI_WORKFLOW.md)**

## 2. Custom tooling

| Loại | File | Để làm gì |
|---|---|---|
| **Project memory** | [CLAUDE.md](CLAUDE.md), [.cursor/rules/](.cursor/rules) | Luật kiến trúc, security, Definition of Done. `CLAUDE.md` là bản đầy đủ; `.cursor/rules` là bản rút gọn cho Cursor |
| **MCP (Figma)** | [.mcp.json](.mcp.json), [.cursor/mcp.json](.cursor/mcp.json) | Figma MCP chính thức: AI đọc frame, design token, screenshot; luật chuyển Figma → Flutter trong [CLAUDE.md](CLAUDE.md) |
| **MCP server** | [tool/project_mcp/server.py](tool/project_mcp/server.py), [.mcp.json](.mcp.json) | `list_requirements`, `get_requirement`, `get_api_contract` — AI đọc requirement/API gốc thay vì mình copy-paste (thực tế: wrap Jira/Confluence) |
| **Skills** | [/flutter-feature](.claude/skills/flutter-feature/SKILL.md) | Quy trình feature end-to-end với 2 checkpoint con người |
| | [/figma-tokens](.claude/skills/figma-tokens/SKILL.md) | Figma variables → [design/tokens.json](design/tokens.json) → generator Dart ([tool/](tool/tokens/token_generator.dart)) validate role/mode/**WCAG contrast** → `AppTheme` light/dark. AI chỉ chuẩn hoá, script mới sinh code |
| | [/figma-component](.claude/skills/figma-component/SKILL.md) | Figma component set → 1 widget trong [lib/core/widgets/](lib/core/widgets/) (chỉ dùng token) + test riêng: variant, state, dark mode, 360dp + 1.3x text, semantics |
| | [/pr-ready](.claude/skills/pr-ready/SKILL.md) | Gate trước PR, chạy y hệt CI: format, token sync, analyze `--fatal-infos`, test, coverage ≥ 80%, AC↔test, quét diff, soạn PR body |
| **Subagents** | [spec-writer](.claude/agents/spec-writer.md) | Requirement → spec + acceptance criteria |
| | [test-writer](.claude/agents/test-writer.md) | Viết test độc lập từ spec, chỉ được sửa `test/` |
| | [code-reviewer](.claude/agents/code-reviewer.md) | Review read-only theo checklist lỗi AI hay mắc |
| **Hooks** | [post_edit_dart.sh](.claude/hooks/post_edit_dart.sh) | PostToolUse: auto format + analyze file vừa sửa, lỗi trả ngược cho AI |
| | [guard_files.sh](.claude/hooks/guard_files.sh) | PreToolUse: chặn sửa file generated, lockfile; chặn đọc secrets (cả qua Bash) |
| | [stop_check.sh](.claude/hooks/stop_check.sh) | Stop: AI không được báo "xong" khi analyze/test còn đỏ |
| **Permissions** | [.claude/settings.json](.claude/settings.json) | Allow lệnh an toàn; deny `git push`, `rm -rf`, `fastlane`, đọc `.env` |

## 3. Kiểm soát chất lượng

Nguyên tắc: *AI là junior viết rất nhanh — mình chịu trách nhiệm cho từng dòng.*

- **Trước khi code:** spec + AC được người duyệt; AI đọc nguồn gốc qua MCP.
- **Trong lúc code:** hooks format/analyze tức thì; lint `very_good_analysis` + `unawaited_futures` / `discarded_futures` là error; guard file nhạy cảm.
- **Trước khi xong:** Stop hook bắt test xanh; test do subagent khác viết từ spec.
- **Khi merge:** CI format / token sync / analyze / test / **coverage ≥ 80%** / **mỗi AC phải có test** / build APK; PR template có checklist riêng cho code AI; human approve bắt buộc.
- **Vòng lặp cải tiến:** mỗi lỗi AI lặp lại → thành 1 luật trong CLAUDE.md / hook / checklist.

Bảng các lỗi thực tế đã bắt được (và lớp nào bắt): **[docs/session-logs/AUTH-001.md](docs/session-logs/AUTH-001.md)** · Chi tiết: **[docs/QUALITY_GATES.md](docs/QUALITY_GATES.md)**

Ví dụ đầy đủ nhất là [#14](docs/session-logs/AUTH-001.md): `code-reviewer` quét toàn repo tìm ra lỗi interceptor bị treo mà review từng diff đã bỏ sót → `test-writer` viết test trước (15 test đỏ) → Stop hook không cho báo "xong" → sửa → luật mới vào checklist reviewer.

### Tự kiểm chứng trong 5 phút
Mở Claude Code trong repo rồi thử:
1. *"Đọc file .env"* hoặc *"chạy `cat .env`"* → `guard_files.sh` chặn (cả tool Read lẫn Bash).
2. *"Thêm `print('x')` vào `lib/main.dart`"* → `post_edit_dart.sh` báo `avoid_print` ngay, AI phải tự sửa.
3. *"Sửa `lib/core/theme/app_tokens.g.dart`"* → bị chặn, AI được chỉ sang `design/tokens.json` + generator.
4. *"Push lên GitHub"* → bị chặn bởi `permissions.deny` trong `.claude/settings.json`.
5. `/pr-ready` trên `main` → dừng ngay, yêu cầu làm trên feature branch.

---

## Design system

```
design/tokens.json ─(generator)─▶ core/theme/app_tokens.g.dart ─▶ core/theme/app_theme.dart ─▶ core/widgets/* ─▶ features/*/pages
   token (Figma)                    AppColorTokens/Spacing/          ThemeData (M3, light/dark)     component            chỉ ghép component,
                                    Radius/Size/Typography                                                               không style riêng
```
- **Tokens:** màu (light/dark, có kiểm tra contrast WCAG), spacing, radius, size, typography. Không hardcode màu/size trong widget.
- **Theme:** `ColorScheme.fromSeed` + ghi đè bằng token Figma → các role M3 không có token vẫn có màu tông hợp lý.
- **Components** ([lib/core/widgets](lib/core/widgets)): có test riêng cho trạng thái loading, disabled, dark mode, màn 360dp + chữ 1.3x, screen reader; ô nhập có autofill hints.
- Bước tiếp theo ở dự án thật: Widgetbook để designer duyệt component, golden test light/dark.

## Production readiness

**Đã có trong repo**
- Clean Architecture, lỗi được map theo tầng (`DioException` → `AppException` → `Failure`), `Result<T>` sealed nên `switch` bắt buộc exhaustive.
- Token trong Keychain / Android Keystore (`flutter_secure_storage`); lỗi storage không làm treo request hay crash app; không log header/body; base URL qua `--dart-define` (mặc định DummyJSON cho demo).
- Refresh token an toàn với request song song (`QueuedInterceptor`, chỉ refresh 1 lần); lỗi mạng khi refresh **không** đá user ra ngoài; request không bao giờ bị treo.
- Chống double-submit, không `emit` sau `close`, dispose controller, ảnh lỗi có fallback.
- 113 test (unit/bloc/widget/tool), coverage `lib/features` + `lib/core/widgets` 95.8% (gate ≥ 80%), CI chặn merge + build APK.

**Cố ý để ngoài phạm vi demo (dự án thật sẽ có)**
| Hạng mục | Ở dự án thật |
|---|---|
| Flavors dev/staging/prod, signing release | `--flavor` + `--dart-define-from-file`, keystore trong CI secrets |
| Crash/analytics | Firebase Crashlytics, `runZonedGuarded` + `FlutterError.onError` |
| Session hết hạn ở mọi màn hình | `AuthSessionCubit` toàn app lắng nghe stream "logged out" từ interceptor; hiện chỉ màn Profile xử lý |
| Đa ngôn ngữ | Message lỗi đang nằm trong `Failure` (domain) → chuyển sang `intl`/ARB, domain chỉ trả mã lỗi |
| Keychain iOS còn token sau khi gỡ app | Cờ first-run để xoá secure storage ở lần mở đầu tiên |
| Routing | `go_router` + redirect theo trạng thái đăng nhập |
| Release | Fastlane → TestFlight / Firebase App Distribution |

## Chạy thử

Flutter được ghim bằng [FVM](https://fvm.app) trong [.fvmrc](.fvmrc):

```bash
fvm use 3.47.4                    # cài (nếu chưa có) + tạo .fvm/flutter_sdk cho VS Code
fvm flutter pub get
fvm flutter run                   # login: emilys / emilyspass

# Kiểm tra giống hệt CI (hoặc gõ /pr-ready trong Claude Code)
fvm dart format --set-exit-if-changed lib test tool
fvm dart run tool/generate_tokens.dart --check
fvm flutter analyze --fatal-infos
fvm flutter test --coverage && bash scripts/coverage_check.sh 80
```

Chạy trên iPhone thật: `cp ios/Flutter/Local.xcconfig.example ios/Flutter/Local.xcconfig` rồi điền Apple Team ID (file này không commit).

Figma MCP: trong Claude Code gõ `/mcp` → chọn `figma` → Authenticate (OAuth với tài khoản Figma). Cursor: Settings → MCP → `figma` → Connect.

MCP server (cần [uv](https://docs.astral.sh/uv/)) — Claude Code tự khởi động qua `.mcp.json`:
```bash
uv run --script tool/project_mcp/server.py
```

## Cấu trúc

```
lib/
  core/            error (Failure, Result), network (Dio + AuthInterceptor refresh token), storage, di,
                   theme (AppTheme + app_tokens.g.dart sinh từ design/tokens.json),
                   widgets (AppButton, AppTextField, AppPasswordField, AppInlineError, AppErrorView, AppAvatar)
  features/auth/   domain / data / presentation (Cubit)
test/              unit + bloc + widget + tool tests (AC-n, regression)
docs/              requirement, spec, API contract, workflow, quality gates, session log
.claude/           settings.json (permissions + đăng ký hooks), skills/, agents/, hooks/
.cursor/           rules/ + mcp.json cho Cursor
.github/           CI, AI review (mặc định tắt), PR template
tool/              project_mcp/ (custom MCP server), tokens/ + generate_tokens.dart (design-token generator)
scripts/           coverage_check.sh (coverage gate dùng chung cho CI và /pr-ready)
design/            tokens.json — nguồn sự thật cho design system
```
