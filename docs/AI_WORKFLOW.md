# Workflow: từ requirement đến production với Claude Code + Cursor

Ví dụ xuyên suốt: ticket **AUTH-001 — Login & Profile**. Lịch sử commit
trong repo đi đúng theo các bước dưới đây (`git log --oneline --reverse`).

## Phân vai công cụ
| Công cụ | Dùng khi | Lý do |
|---|---|---|
| **Claude Code** (terminal/VS Code) | Task nhiều file, cần đọc ticket/API, chạy test, refactor, viết spec | Agentic: có MCP, hooks, subagents, skills, plan mode |
| **Cursor** | Chỉnh UI nhỏ, sửa inline, hỏi nhanh về 1 đoạn code, Tab-complete | Vòng lặp nhanh trong editor; dùng chung luật qua `.cursor/rules/` |
| **Mình** | Duyệt spec, review diff, test trên device thật, quyết định merge | AI không chịu trách nhiệm production — mình chịu |

## 7 bước

### 1. Requirement → AI đọc trực tiếp từ nguồn
- Ticket nằm ở Jira (demo: `docs/requirements/`). MCP server tự viết
  [`tool/project_mcp/server.py`](../tool/project_mcp/server.py) expose
  `get_requirement`, `get_api_contract` → Claude đọc đúng bản gốc, không
  phụ thuộc mình copy-paste thiếu.
- Design: **Figma MCP** chính thức (`.mcp.json` cho Claude Code,
  `.cursor/mcp.json` cho Cursor). Paste link frame Figma → AI đọc layout,
  design token, screenshot. Output của Figma MCP là React/Tailwind nên
  `CLAUDE.md` có mục "Figma → Flutter" bắt AI dựng lại bằng widget Flutter
  và đưa màu/chữ/spacing vào `ThemeData` thay vì hardcode.
- Design system: skill `/figma-tokens <link style guide>` đọc Figma
  variables → AI chuẩn hoá vào `design/tokens.json` (có bảng mapping để
  review) → script `tool/generate_tokens.dart` validate (đủ role, light/dark
  khớp nhau, contrast WCAG AA) và sinh `app_tokens.g.dart`. CI fail nếu
  file sinh ra lệch với `tokens.json`. Tách phần "phán đoán" (AI) và phần
  "chắc chắn" (script) để token không phụ thuộc vào việc AI viết đúng hay sai.

### 2. Spec / Plan — checkpoint con người #1
```
> /flutter-feature AUTH-001
  (skill gọi subagent spec-writer → docs/specs/AUTH-001-spec.md)
```
- Plan mode + subagent `spec-writer` sinh: bảng Acceptance Criteria
  `AC-1..7`, sơ đồ layer, task breakdown, open questions.
- **Mình review và sửa spec trước khi có dòng code nào** — xem mục
  "Human review notes" trong [spec](specs/AUTH-001-spec.md): đổi
  SharedPreferences → secure storage, thêm refresh token, Bloc → Cubit,
  thêm AC-5 double tap.
- Lý do: sửa 1 dòng spec rẻ hơn sửa 10 file code.

### 3. Scaffold theo convention
- `CLAUDE.md` + `.cursor/rules/` mô tả kiến trúc, nên code AI sinh ra
  theo cùng 1 khuôn: `domain → data → presentation`, `Result<T>`, `Failure`.

### 4. Implement — từng layer, commit nhỏ
- Claude Code làm domain → data → presentation, mỗi layer 1 commit để
  review được.
- **Hook PostToolUse** tự `dart format` + `dart analyze` ngay sau mỗi lần
  AI sửa file; lỗi được trả ngược cho Claude sửa liền (không đợi tới CI).
- **Hook PreToolUse** chặn AI sửa file generated, lockfile, secrets.
- Cursor: tinh chỉnh UI LoginPage (padding, icon ẩn/hiện password).

### 5. Test — tách người viết code và người viết test
- Subagent `test-writer` chỉ được viết trong `test/`, viết từ **spec**
  chứ không từ implementation → tránh test "copy" lại bug.
- Mỗi AC có test tên `<TICKET> AC-n: ...` (vd. `AUTH-001 AC-1: ...`) →
  truy vết được requirement ↔ test, không nhầm AC giữa các ticket.
- Bug: `/fix-bug` viết test hồi quy `<BUG-ID>: ...` đỏ trước rồi mới sửa;
  `/write-tests` tìm chỗ thiếu test và giao cho `test-writer`.

### 6. Review — 2 lớp
1. Subagent `code-reviewer` (read-only) theo checklist các lỗi AI hay mắc:
   lifecycle, `emit` sau `close`, leak controller, log token, API bịa.
2. Mình đọc diff từng dòng. Những gì mình bắt được ghi ở
   [session log](session-logs/AUTH-001.md).
- **Stop hook**: Claude không thể báo "xong" khi analyze/test còn đỏ.

### 7. Ship
- `/pr-ready`: chạy y hệt CI (format, token sync, analyze `--fatal-infos`,
  test + coverage ≥ 80% cho `lib/features` + `lib/core/widgets`), đối chiếu
  AC ↔ test, quét diff, soạn PR description theo template.
- PR → CI ([ci.yml](../.github/workflows/ci.yml)) → (tùy chọn, mặc định tắt — bật bằng biến `AI_REVIEW_ENABLED`) AI review
  trên PR → human approve → merge.
- Release (ở dự án thật): build theo flavor với `--dart-define`,
  Fastlane → TestFlight / Firebase App Distribution → QA → store. AI
  không có quyền chạy `fastlane` / `git push` (deny trong
  `.claude/settings.json`).

## Prompt mẫu mình hay dùng
```text
Đọc AUTH-001 qua MCP. Trước khi code: liệt kê những điểm requirement
mơ hồ và các edge case (mạng chậm, 401, double tap, app bị kill giữa
request). Chưa viết code.
```
```text
Implement chỉ layer data cho AUTH-001 theo spec đã duyệt. Tái sử dụng
Result/Failure/TokenStorage có sẵn. Không thêm package mới.
Xong thì dừng, tóm tắt các quyết định bạn không chắc chắn.
```
```text
Review diff này như 1 senior khó tính. Chỉ báo vấn đề thật, có file:line.
Đặc biệt kiểm tra: emit sau await, dispose, log thông tin nhạy cảm.
```
