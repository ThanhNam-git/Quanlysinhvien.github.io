# CLAUDE.md

Hướng dẫn cho Claude Code khi làm việc trong repo này.

## Tổng quan dự án

**Hệ thống quản lý công việc trong cơ quan nhà nước** (đồ án chuyên ngành). Quản lý giao việc, thực hiện, review kết quả và tự động tính KPI cho công chức trong phạm vi **một phòng ban**, mô phỏng theo Nghị định 335/2025/NĐ-CP (thang 100 điểm).

Tài liệu nghiệp vụ gốc: `Tai_lieu_nghiep_vu_He_thong_quan_ly_cong_viec.docx` — là nguồn sự thật; khi có mâu thuẫn, đối chiếu lại file này.

- **Trong phạm vi:** giao việc, nhận việc, cập nhật tiến độ, nộp kết quả, review, đóng việc, ủy quyền, thông báo, KPI.
- **Ngoài phạm vi:** chấm công, lương, KPI tổng hợp của module nhân sự, giao việc liên phòng (bản đầu).

## Cấu trúc repo

| Thư mục | Nội dung | Stack | Chạy |
|---|---|---|---|
| `backend/` | REST API (`/api/v1`, JSON) | Spring Boot 4.1, Java 21, Maven, PostgreSQL, Flyway, Spring Security | `./mvnw spring-boot:run` (cổng 8080) |
| `frontend/` | Giao diện web, gọi REST API của backend | Next.js 16 App Router, TypeScript, Tailwind CSS 4, shadcn/ui | `npm run dev` (cổng 3000) |

```text
Trình duyệt → frontend (Next.js) → REST /api/v1 → backend (Spring Boot) → PostgreSQL
```

Cả hai dự án đều **chia code theo feature**, dùng chung tên feature: `account`, `organization`, `task`, `delegation`, `notification`, `kpi`, `report`.

Mỗi dự án có `CLAUDE.md` riêng (stack, lệnh chạy, cấu hình) và `instruction/architecture.md` (kiến trúc bắt buộc). **Đọc file của dự án tương ứng trước khi viết code:**

- Backend: `backend/CLAUDE.md`, `backend/instruction/architecture.md` — Feature-Based Clean Architecture, quy ước REST API, xử lý lỗi `ProblemDetail`.
- Frontend: `frontend/CLAUDE.md`, `frontend/instruction/architecture.md` — Feature-Based, cách gọi API, quy ước UI shadcn/ui.

Khi thêm/đổi endpoint: sửa backend trước, rồi cập nhật `types.ts` và `api.ts` của feature tương ứng ở frontend.

## Thuật ngữ

| Viết tắt / thuật ngữ | Nghĩa |
|---|---|
| TP | Trưởng phòng (1 người/phòng) |
| PP | Phó phòng (0..n) |
| NV | Nhân viên (0..n) |
| Assigner | Người giao task |
| Assignee | Người thực hiện task |
| Reviewer | Người duyệt kết quả |
| Trình TP | Loại task PP giao ngược lên TP (việc cần thẩm quyền TP) |

**Quan trọng:** quyền giao việc dựa trên **chức vụ trong phòng ban** (TP/PP/NV), không dựa trên role hệ thống. Role hệ thống (Admin, HR, Member) chỉ quyết định quyền quản trị. Mỗi người chỉ có một chức vụ trong một phòng tại một thời điểm. Admin/HR gán chức vụ, tạo ủy quyền thay khi TP vắng đột xuất, xem toàn bộ, nhưng **không tham gia luồng duyệt**.

## Quy tắc giao việc

Luồng chuẩn: **TP → PP → NV**. TP nhận nhiệm vụ, giao PP; PP chia task con (gắn task cha) giao NV; NV nộp → PP review; xong hết task con thì PP nộp task cha → TP review. TP vẫn được giao thẳng NV.

Ma trận giao việc (cùng phòng):

| Người giao ↓ / Nhận → | TP | PP | NV | Chính mình |
|---|---|---|---|---|
| TP | — | Trực tiếp | Trực tiếp | Được |
| PP (bình thường) | Chỉ Trình TP, TP phải chấp nhận | Không | Trực tiếp | Được |
| PP (đang ủy quyền) | Chỉ Trình TP, chờ TP về | Trực tiếp (thay TP) | Trực tiếp | Được |
| NV | Không | Không | Không | Được (việc cá nhân) |

"Giao trực tiếp" = task vào thẳng **Mới giao**, người nhận không được từ chối (chỉ xin gia hạn).

### Ủy quyền khi TP vắng
- TP tạo phiếu ủy quyền: chọn PP, thời gian từ–đến (có thể theo giờ), lý do, phạm vi quyền (tick): giao việc cho cả phòng (kể cả PP khác) / review thay TP / chấp nhận–từ chối gia hạn.
- Mọi thao tác ghi "PP A thay mặt TP B (ủy quyền số …)". Thông báo gửi TP cũng gửi PP được ủy quyền.
- Hết hạn tự thu hồi; TP có thể thu hồi sớm. Việc đã làm trong lúc ủy quyền giữ nguyên.
- TP quay lại → báo cáo bàn giao (việc PP đã giao, đã duyệt, việc Trình TP đang chờ).
- Ràng buộc: mỗi lúc chỉ **một** ủy quyền hiệu lực; không ủy quyền lại; PP không tự duyệt việc của chính mình. TP vắng đột xuất → HR/Admin tạo phiếu thay.

### Task Trình TP (PP → TP)
- Chỉ cho: ký duyệt văn bản/tờ trình, quyết định phương án/ý kiến chỉ đạo, chủ trì/dự họp với cấp trên–đơn vị khác, việc phát sinh vượt phạm vi ủy quyền.
- Bắt buộc ghi nội dung cần TP làm (+ hồ sơ đính kèm nếu có). Bắt đầu ở **Chờ chấp nhận**.
- TP: Chấp nhận → Mới giao; Từ chối (bắt buộc lý do) → trả PP; Giao lại người khác (PP vẫn theo dõi).
- Quá 48h chưa phản hồi → nhắc TP (không tự chấp nhận).
- TP bấm Hoàn thành → **đóng luôn, không review**; PP nhận thông báo.
- Sau khi TP chấp nhận, PP không được sửa hạn, ưu tiên hoặc hủy.

## Vòng đời task (7 trạng thái)

| Trạng thái | Ai chuyển tiếp |
|---|---|
| Chờ chấp nhận | TP: chấp nhận / từ chối / giao lại |
| Bị từ chối | Người giao: sửa và gửi lại, hoặc hủy |
| Mới giao | Người thực hiện: bắt đầu |
| Đang thực hiện | Người thực hiện: nộp kết quả |
| Chờ review | Người review: duyệt / yêu cầu làm lại |
| Cần làm lại | Người thực hiện: sửa, nộp lại |
| Hoàn thành | Trạng thái cuối |

Chỉ task Trình TP bắt đầu ở Chờ chấp nhận; còn lại vào thẳng Mới giao. Bấm "Hoàn thành" chỉ chuyển sang **Chờ review**; chỉ thao tác **Duyệt** mới sang Hoàn thành (trừ Trình TP và task tự giao của TP). "Trễ hạn" là **cờ**, không phải trạng thái.

## Review

Người review:
- Mặc định: người giao (NV → PP review; PP → TP review).
- TP đang ủy quyền có quyền review: PP được ủy quyền (trừ việc của chính PP đó → chờ TP).
- Người giao chỉ định reviewer khác (TP hoặc PP cùng phòng).
- Người giao nghỉ việc/chuyển phòng → TP.
- Task tự giao của NV → PP quản lý trực tiếp, không có thì TP.
- Task Trình TP, task tự giao của TP → không cần review.

Các bước: NV nộp (bắt buộc mô tả kết quả, tùy chọn file/link) → Chờ review, NV không sửa được. Reviewer **Duyệt** → Hoàn thành, ngày hoàn thành = **ngày nộp** (không tính trễ do reviewer chậm); hoặc **Yêu cầu làm lại** (bắt buộc nhận xét) → Cần làm lại. Mỗi lần nộp là một phiên bản kết quả (lần 1, 2…) kèm nhận xét. Quá 48h chưa review → nhắc reviewer; quá 72h → báo TP.

## Business rules

- **BR-01** Luồng chuẩn TP → PP → NV; NV chỉ tạo task cho chính mình.
- **BR-02** PP chỉ giao TP task Trình TP; bắt đầu ở Chờ chấp nhận, bắt buộc ghi nội dung.
- **BR-03** PP không giao PP khác, trừ khi đang ủy quyền có quyền "Giao việc cho cả phòng".
- **BR-04** Ủy quyền phải có thời gian bắt đầu–kết thúc và phạm vi; mỗi lúc một ủy quyền; không ủy quyền lại.
- **BR-05** Hết hạn ủy quyền tự thu hồi; thao tác trong lúc ủy quyền ghi rõ "thay mặt TP".
- **BR-06** Từ chối task / yêu cầu làm lại → bắt buộc lý do.
- **BR-07** Reviewer ≠ assignee, kể cả khi đang ủy quyền.
- **BR-08** Chỉ sang Hoàn thành qua Duyệt (trừ Trình TP và task tự giao của TP).
- **BR-09** Đang Chờ review thì assignee không sửa nội dung/kết quả.
- **BR-10** Chỉ người giao (hoặc TP) được hủy; task Hoàn thành không hủy được.
- **BR-11** Reviewer rời phòng → task Chờ review chuyển TP; assignee rời phòng → trả về người giao.
- **BR-12** Quá hạn chưa nộp → gắn cờ Trễ hạn, task vẫn làm tiếp.

## Thông báo & lịch sử

| Sự kiện | Người nhận |
|---|---|
| Task mới giao / chờ chấp nhận | Người thực hiện |
| TP chấp nhận / từ chối / hoàn thành Trình TP | PP (người giao) |
| Tạo / thu hồi / hết hạn ủy quyền | TP, PP được ủy quyền, cả phòng |
| Thông báo gửi TP trong lúc ủy quyền | TP và PP được ủy quyền |
| Nộp kết quả | Người review |
| Duyệt / yêu cầu làm lại | Người thực hiện, người giao (nếu khác reviewer) |
| Sắp đến hạn (trước 24h) / trễ hạn | Người thực hiện, người giao |
| Review quá 72h | TP |

Mọi thay đổi trạng thái, assignee, reviewer, hạn đều ghi lịch sử (ai, lúc nào, cũ → mới, lý do). Lịch sử **chỉ đọc, không xóa**.

## KPI (mô phỏng NĐ 335/2025)

Mỗi tháng mỗi người 100 điểm = **30 điểm tiêu chí chung** (TP chấm tay) + **70 điểm nhiệm vụ** (tự tính từ task).

| Chỉ số | Cách tính |
|---|---|
| a – Số lượng | Số task được duyệt / số task được giao có hạn trong kỳ |
| b – Chất lượng | Mỗi task duyệt bắt đầu 100%, mỗi lần làm lại trừ 25%; lấy trung bình |
| c – Tiến độ | Nộp đúng hạn 100%, trễ 75%; trễ có lý do khách quan được TP xác nhận vẫn 100% |

`Điểm nhiệm vụ = (a + b + c) / 3 × 70`

TP và PP thêm 3 chỉ số (chia 6): d – kết quả phòng (100% nếu mọi NV đạt từ Hoàn thành trở lên, ngược lại 50%), đ – khả năng tổ chức, e – đoàn kết nội bộ (đ, e cấp trên chấm tay).

Ví dụ: 10 task, 9 duyệt, 1 task làm lại 1 lần, 2 task trễ → a = 90%, b = 97,2%, c = 94,4% → 65,7 + 27 = 92,7 → Xuất sắc.

Xếp loại: ≥ 90 Hoàn thành xuất sắc; 70–<90 Hoàn thành tốt; 50–<70 Hoàn thành; < 50 hoặc bị kỷ luật → Không hoàn thành. Số Xuất sắc ≤ 20% số Tốt trong phòng (cảnh báo khi vượt). Xếp loại TP không cao hơn xếp loại phòng.

Chốt điểm hằng tháng: ngày 1 tháng sau hệ thống tính điểm nháp → NV xem, tự đánh giá, ghi ý kiến → TP xử lý ý kiến, chấm 30 điểm, chốt phòng → HR khóa kỳ (sau khóa không đổi điểm). Điểm năm = trung bình 12 tháng.

Quy tắc chi tiết (tài liệu nghiệp vụ mục 10.5–10.10):
- **Task được tính:** task được giao (kể cả task cha, Trình TP), có hạn, không bị hủy. Task tự giao **không** tính. Tính cho người thực hiện cuối cùng.
- **Kỳ của task** = tháng chứa hạn hiện hành (sau gia hạn), giờ VN. Một task chỉ thuộc một kỳ.
- b, c chỉ tính trên task đã duyệt. c so **ngày nộp phiên bản được duyệt** với hạn. Trình TP: b = 100%, c so ngày TP bấm Hoàn thành.
- Có task nhưng không task nào duyệt → điểm nhiệm vụ 0. Không có task → TP nhập tay điểm nhiệm vụ, bắt buộc lý do.
- d tính sau khi mọi NV có xếp loại. TP chấm 30 điểm chung cho NV, PP và chấm đ, e cho PP; HR nhập thay cấp trên cho TP. PP được ủy quyền không chấm thay. Không ai chấm hoặc xử lý ý kiến KPI của chính mình.
- Ý kiến: xin xác nhận trễ có lý do / khiếu nại số liệu (gắn task) / ý kiến chung. Chấp nhận trễ có lý do → c của task = 100%.
- Kỳ theo phòng–tháng: **Đang đánh giá** (tự tính lại) → TP chốt → **Đã chốt** → HR khóa → **Đã khóa** (HR có thể trả lại TP khi đã chốt). Chốt khi mọi người đã có điểm chấm tay và mọi ý kiến đã xử lý.
- Vượt 20% Xuất sắc chỉ cảnh báo. Xếp loại phòng do HR nhập; TP cao hơn phòng thì hạ xuống bằng. HR đánh dấu kỷ luật → Không hoàn thành.
- Mã quy tắc KR-01…KR-11 (tài liệu nghiệp vụ mục 10.10).

> Công thức lấy từ bài phân tích báo chí, chưa đối chiếu văn bản gốc NĐ 335/2025.

## Module chức năng

Thứ tự làm: 1 → 2 → 3 → 4 → 5 → 6 → 7 (KPI cần dữ liệu giao việc và review).

| # | Module | Chức năng chính | Ưu tiên |
|---|---|---|---|
| 1 | Tài khoản & phân quyền | Đăng nhập, đổi mật khẩu, role Admin/HR/Member | Phải có |
| 2 | Tổ chức | CRUD phòng ban, gán chức vụ TP/PP/NV, danh mục vị trí việc làm | Phải có |
| 3 | Giao việc | Tạo task (tiêu đề, mô tả, hạn, ưu tiên, sản phẩm đầu ra, file); ma trận giao việc; task cha–con; Trình TP; ủy quyền + báo cáo bàn giao; xin gia hạn | Phải có |
| 4 | Thực hiện & review | Cập nhật tiến độ (%), bình luận, nộp nhiều phiên bản, duyệt/làm lại, lịch sử | Phải có |
| 5 | Nhắc việc & thông báo | In-app + email; sắp đến hạn, trễ hạn, chờ review lâu | Phải có |
| 6 | KPI & xếp loại | Tính a/b/c, tự đánh giá, TP chấm tiêu chí chung, chốt/khóa kỳ, xếp loại tháng/năm | Phải có |
| 7 | Dashboard & báo cáo | Việc của tôi, tổng quan phòng, bảng xếp hạng KPI, xuất Excel/PDF | Nên có |
| 8 | Mở rộng | Kanban, việc định kỳ, giao việc liên phòng, công khai KPI | Có thể bỏ |

## Câu hỏi mở (chưa chốt)

- Danh sách loại việc Trình TP đã đủ chưa, hay cho HR cấu hình?
- TP có được ủy quyền cho nhiều PP cùng lúc không? (Hiện tại: chỉ một.)
- PP được ủy quyền có chấm KPI thay TP không? (Hiện tại: không.)
- Thời gian nhắc 48h/72h có cho HR cấu hình không?
- Có giao việc liên phòng trong bản đầu không?
- KPI: kỳ của task theo tháng của hạn hay tháng hoàn thành? Nộp lại sau hạn do làm lại có tính trễ? Task tự giao có tính? Có trọng số theo độ ưu tiên? Ai chấm cho TP? (Hiện tại: tháng của hạn / có / không / không / HR nhập thay.)
