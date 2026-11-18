# Session log — AUTH-001 (trích)

> Ghi lại các điểm mình phải can thiệp. Mục đích: chứng minh code AI
> **luôn đi qua review**, và mỗi lỗi lặp lại được biến thành luật trong
> `CLAUDE.md` / hook / checklist.
>
> Cột **Nguồn**: `repo` = xảy ra thật khi build repo demo này (xem
> `git log`); `dự án` = lỗi điển hình mình gặp ở dự án thật, đưa vào spec
> từ đầu.

| # | Nguồn | AI làm gì | Phát hiện bởi | Mình sửa thế nào | Biến thành luật |
|---|---|---|---|---|---|
| 1 | dự án | Lưu `accessToken` bằng `SharedPreferences` | Review spec | Dùng `flutter_secure_storage` qua `TokenStorage` | CLAUDE.md › Security |
| 2 | dự án | `LoginPage` tạo `TextEditingController` nhưng không `dispose` | `code-reviewer` subagent | Thêm `dispose()` | Checklist reviewer #2 |
| 3 | dự án | Không có refresh token → 401 là đá về Login | Mình đọc lại note BA | `AuthInterceptor` (QueuedInterceptor, retry 1 lần, Dio riêng tránh loop) + AC-7 | Spec template có mục "session expiry" |
| 4 | dự án | `emit` sau `await` không check `isClosed` → crash khi back nhanh | Test-writer viết test regression | `if (isClosed) return;` | CLAUDE.md › Architecture |
| 5 | repo | `LogInterceptor()` mặc định log cả header `Authorization` | Review diff | `LogInterceptor(requestHeader: false)` | CLAUDE.md › Security |
| 6 | repo | Đặt tên `Error` cho Result → che `dart:core.Error` | Review diff | Đổi thành `Failed` | — |
| 7 | repo | Switch `DioExceptionType` thiếu `transformTimeout` | Hook analyze (lỗi `non_exhaustive_switch`) | Thêm case | Lint đã chặn sẵn |
| 8 | repo | `CircleAvatar` dùng `NetworkImage` không xử lý lỗi → ảnh hỏng ném exception | Widget test (`profile_page_test`) | `onForegroundImageError` → fallback chữ cái đầu | Checklist reviewer: network image phải có fallback |
| 9 | repo | Coverage `lib/features` chỉ 65% (thiếu test data source, ProfilePage) | Coverage gate (`scripts/coverage_check.sh`) | Bổ sung 13 test → 94% | CI gate ≥ 80% |
| 10 | repo | MCP server dùng `mcp.server.fastmcp` nhưng `mcp` 2.x đã đổi tên | Chạy thử server | Pin `mcp<2` | Pin version mọi dependency của tooling |
| 11 | repo | Thêm `flutter_secure_storage` nhưng không chỉnh Android config → build fail (cần minSdk 23, compileSdk 36) dù 40 test vẫn xanh | Build thử `flutter build apk` | Cập nhật `android/app/build.gradle.kts` | Thêm job `build-android` vào CI; checklist: thêm plugin native → build cả 2 nền tảng |
| 12 | repo | `AuthInterceptor` bọc refresh **và** retry chung 1 `try`: retry bị 500/timeout cũng xoá token (đá user ra); lỗi mạng khi refresh cũng logout; response refresh sai format ném `TypeError` làm request treo vĩnh viễn; 2 request 401 song song refresh 2 lần | Review lại trước khi gửi (đọc code như reviewer ngoài) | Tách retry riêng; chỉ logout khi refresh bị 401/403; mọi nhánh đều gọi `handler`; bỏ qua refresh nếu token đã đổi. +5 test regression | Checklist reviewer: mọi nhánh interceptor phải gọi handler; phân biệt "token hỏng" và "mạng hỏng" |
| 13 | repo | `LogInterceptor` vẫn log **response header** — DummyJSON trả token trong `Set-Cookie` | Review lại | `responseHeader: false` | CLAUDE.md › Security: không log header cả 2 chiều |
| 14 | repo | Fix #12 **chưa đủ**: các lệnh đọc/xoá secure storage nằm *ngoài* `try` (`onRequest`, đầu `onError`, `clear()` trong nhánh 401/403). Storage ném `PlatformException` (VD: Android restore backup) → handler không được gọi → request treo, `QueuedInterceptor` kẹt mọi request sau. Repository cũng để lỗi storage lọt qua domain: `login` quay spinner mãi, `hasSession` crash trước `runApp` | `code-reviewer` quét **toàn repo** (review từng diff ở #12 đã bỏ sót) | Test trước: `test-writer` viết 21 test, 15 test fail trên code cũ (stop hook không cho báo "xong" khi còn đỏ); nó còn báo thêm `clear()` trong nhánh 401 của repository → sửa + 1 test (tổng 22). Sau đó: `SecureTokenStorage` map `PlatformException` → `StorageException`; interceptor bọc cả luồng 401 trong 1 `try` luôn gọi handler; repository trả `StorageFailure`, `logout`/`hasSession` không ném | Checklist reviewer: mọi `await` I/O trong interceptor phải nằm trong `try` gọi handler; định kỳ review toàn repo, không chỉ diff |

## Thời gian (ước lượng)
- Spec: 15' (AI) + 15' (mình sửa).
- Implement + test: ~1h với AI, so với ~4h làm tay.
- Review: 30' — **không cắt bớt bước này** dù AI viết nhanh.
