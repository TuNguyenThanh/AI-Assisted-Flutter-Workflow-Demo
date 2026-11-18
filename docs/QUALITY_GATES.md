# Kiểm soát chất lượng code AI sinh ra

Nguyên tắc: **AI là junior viết rất nhanh — mình là người chịu trách nhiệm.**
Không tin output, mà dựng nhiều lớp kiểm tra tự động + checkpoint con người.

| Giai đoạn | Cơ chế | File |
|---|---|---|
| Trước khi code | Luật dự án cho AI (kiến trúc, security, DoD) | [CLAUDE.md](../CLAUDE.md), [.cursor/rules](../.cursor/rules) |
| | Spec + AC được người duyệt trước | [spec](specs/AUTH-001-spec.md) |
| | AI đọc requirement/API gốc qua MCP, giảm "bịa" field | [server.py](../tool/project_mcp/server.py) |
| Trong lúc code | Auto format + analyze từng file sau mỗi edit; chặn "lách cho xanh": `ignore_for_file`, `// ignore` không lý do, `skip:` test, `print`, màu hardcode, `shared_preferences` | [post_edit_dart.sh](../.claude/hooks/post_edit_dart.sh) |
| | Chặn secrets (kể cả lách bằng `.e""nv`, glob `.en?`), generated/lock; guardrail (hooks, settings, agents, CI, scripts, lint) phải được người duyệt; chặn tắt hooks, `settings.local.json`, chạy `claude` bỏ qua permission | [guard_files.sh](../.claude/hooks/guard_files.sh) |
| | **Sandbox subagent ép bằng code, không chỉ prompt**: `test-writer` chỉ ghi `test/`, `spec-writer` chỉ `docs/specs/`, `code-reviewer` không ghi; shell allow-list, cấm `&&`/`;`/`$( )`/redirect/`..` | [guard_files.sh](../.claude/hooks/guard_files.sh) |
| | Permission: tắt bypass mode; deny `git push`, `--no-verify`, `rm -rf`, `sudo`, `fastlane`, đọc secret; ask cho git ghi đè + sửa guardrail | [settings.json](../.claude/settings.json) |
| | Lint nghiêm `very_good_analysis` + `unawaited_futures` = error | [analysis_options.yaml](../analysis_options.yaml) |
| | Guardrail cũng có test: 80+ case allow/ask/deny chạy trong CI + shellcheck | [test_hooks.sh](../scripts/test_hooks.sh) |
| Trước khi báo xong | Stop hook = CI nhanh: format, token sync, analyze `--fatal-infos`, test. Nếu Claude vẫn dừng khi còn đỏ → cảnh báo hiện cho người | [stop_check.sh](../.claude/hooks/stop_check.sh) |
| Test | Subagent viết test độc lập từ spec, AC ↔ test | [test-writer.md](../.claude/agents/test-writer.md) |
| Review | Subagent review read-only theo checklist lỗi AI | [code-reviewer.md](../.claude/agents/code-reviewer.md) |
| | Human review từng dòng + test trên device | [session log](session-logs/AUTH-001.md) |
| Merge | CI: hook tests, format, analyze, test, coverage ≥ 80% (floor cố định trong script) | [ci.yml](../.github/workflows/ci.yml) |
| | PR template có checklist riêng cho code AI | [PR template](../.github/pull_request_template.md) |

## Những lỗi AI hay mắc trong Flutter (checklist mình review)
1. `emit` sau `await` khi Cubit đã close → `StateError`.
2. Quên `dispose` controller / cancel subscription.
3. Dùng `BuildContext` sau async gap.
4. Lưu token vào SharedPreferences, log header Authorization.
5. Gọi API / param không tồn tại trong version package đang dùng.
6. Catch-all `catch (e) {}` nuốt lỗi; lộ `DioException` lên UI.
7. Test "mirror" implementation, hoặc sửa expectation cho test pass.
8. Rebuild cả màn hình vì không dùng `buildWhen`/`const`.

## Chỉ số mình theo dõi
- % PR có comment "AI-generated issue" ở bước human review.
- Số lần hook/CI chặn trước khi tới reviewer.
- Bug production truy được về code AI → bổ sung vào CLAUDE.md / checklist
  (vòng lặp cải tiến: mỗi lỗi lặp lại thành 1 luật).
