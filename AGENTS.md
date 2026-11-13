# AGENTS.md

- **Backend API:** đã chạy sẵn qua Docker tại `http://localhost:5001`
  - Android Emulator gọi: `http://10.0.2.2:5001`
  - Windows / iOS Simulator / thiết bị dùng `adb reverse`: `http://localhost:5001`
- **Tài khoản test:** `learner@demo.local` / `Demo1234!` (hoặc `learner.fresh@demo.local` / `Demo1234!`)
- **Auth:** `POST /api/auth/sign-in` trả về JWT `token`, gửi kèm header `Authorization: Bearer <token>`.
- **Tài liệu tham chiếu (đọc trước khi code):**
  - API & DTO: `docs/backend-ref/openapi.json`
  - Luật nghiệp vụ & thuật ngữ: `docs/backend-ref/PRODUCT.md`, `docs/backend-ref/CONTEXT.md`
  - Design system ("Bảng hiệu phòng thi"): `docs/backend-ref/DESIGN.md` (`BorderRadius.zero`, không shadow, keyline 1px/2px, bảng màu `#14181d` / `#0b4ea2` / `#f2b705` / `#b31217` / `#0a6b3c`)
  - UI Library (`forui` — **BẮT BUỘC tham khảo cho mọi thứ liên quan đến giao diện/widget/theme**): `docs/backend-ref/forui-llms.txt` (mục lục) và `docs/backend-ref/forui-llms-full.txt` (tài liệu API/widget/style chi tiết đầy đủ — luôn tra cứu file này trước khi code bất kỳ thành phần giao diện nào)
- **Phạm vi Phase 1:** Chỉ port app Mobile (Learner cắt gọn), không sửa backend .NET.

## Quy tắc Công cụ & Điều hướng Codebase (BẮT BUỘC cho Agent thi công)

### 1. Graphify Knowledge Graph (`graphify-out/graph.json`) — Cấm `grep` mù quáng
Dự án đã có đồ thị tri thức tại `graphify-out/graph.json` (kết nối toàn bộ code AST, `PRODUCT.md`, `CONTEXT.md`, `DESIGN.md`, `GLOSSARY.md`, `ADR-0001`, và `forui-llms-full.txt`). **Agent thi công BẮT BUỘC ưu tiên truy vấn Graphify (qua MCP `graphify` hoặc CLI) trước khi đọc file thô hoặc `grep` tràn lan:**
- **Các công cụ MCP `graphify` (nạp sẵn trong RAM):** `query_graph`, `get_node`, `get_neighbors`, `get_community`, `shortest_path`, `god_nodes`, `graph_stats` (hoặc CLI: `graphify query "<question>"`, `graphify path "<A>" "<B>"`, `graphify explain "<concept>"`).
- **Use-cases bắt buộc khi implement:**
  1. **Tìm kiến trúc & phụ thuộc module (`Impact Analysis`):** Khi sửa hoặc mở rộng một provider/model/widget trong `lib/`, gọi `get_neighbors` / `query_graph` để biết ngay các file/class liên quan thay vì `grep` toàn bộ repo.
  2. **Định vị nhanh thành phần `forui` & quy tắc `DESIGN.md`:** Dùng `query_graph` hoặc `get_node` (ví dụ: `FThemeData`, `FScaffold`, `FSheet`, `Exam-Hall Signage`) để nhảy thẳng tới đúng khái niệm và file nguồn thay vì đọc mò 19.000 dòng `forui-llms-full.txt`.
  3. **Kiểm tra chuỗi nghiệp vụ liên tầng:** Dùng `shortest_path` / `query_graph` (ví dụ: giữa `Placement Attempt` và `Learning Path`, hoặc `Order` và `Ledger`) để không bỏ sót ràng buộc domain.
  4. **Cập nhật đồ thị sau khi code:** Sau khi thêm/sửa các file code trong `lib/` hoặc `test/`, luôn chạy `graphify update .` (chỉ quét AST cho code, không tốn token LLM) để giữ đồ thị luôn mới cho các bước/ticket tiếp theo.

### 2. Context7 MCP (`resolve-library-id` → `query-docs`) — BẮT BUỘC tra cứu thư viện
- Khi viết code sử dụng bất kỳ thư viện/package Flutter & Dart nào (`flutter_riverpod`, `dio`, `go_router`, `flutter_secure_storage`, `just_audio`, `record`, `permission_handler`, v.v.), agent **BẮT BUỘC** gọi **Context7 MCP** (`resolve-library-id` sau đó `query-docs` theo từng khái niệm cụ thể) để lấy cú pháp API mới nhất, tuyệt đối không đoán mò hoặc dùng API đã deprecated.
- Riêng với thư viện giao diện **`forui`**, luôn kết hợp tra cứu trực tiếp `docs/backend-ref/forui-llms.txt` + `docs/backend-ref/forui-llms-full.txt` (và Graphify) làm nguồn chuẩn.

## Agent skills

### Issue tracker

Issues and specs live as GitHub issues (`gh` CLI). See `docs/agents/issue-tracker.md`.

### Triage labels

Default five-role vocabulary (`needs-triage`, `needs-info`, `ready-for-agent`, `ready-for-human`, `wontfix`). See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout (`GLOSSARY.md` and `docs/adr/` at repo root). See `docs/agents/domain.md`.

