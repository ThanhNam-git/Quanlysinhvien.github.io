# Kiến trúc backend: Feature-Based Clean Architecture

Áp dụng cho `backend/` (Spring Boot 4.1, Java 21, package gốc `vn.qlcv`). Mọi code backend mới phải theo tài liệu này.

## 1. Khái niệm

- **Feature-Based:** chia code theo tính năng (task, delegation, kpi…) → trả lời câu hỏi *code thuộc tính năng nào?*
- **Clean Architecture:** chia code theo trách nhiệm, dependency hướng vào nghiệp vụ cốt lõi → trả lời câu hỏi *code phụ thuộc vào đâu?*

Mục tiêu: dễ bảo trì, dễ test, nghiệp vụ ít phụ thuộc framework.

## 2. Cấu trúc thư mục

```text
vn.qlcv/
├── BackendApplication.java
├── task/
│   ├── domain/
│   │   ├── Task.java                    # entity nghiệp vụ, chứa quy tắc chuyển trạng thái
│   │   └── TaskStatus.java
│   ├── application/
│   │   ├── port/
│   │   │   ├── in/
│   │   │   │   └── AssignTaskUseCase.java
│   │   │   └── out/
│   │   │       └── TaskRepository.java
│   │   └── service/
│   │       └── AssignTaskService.java
│   └── adapter/
│       ├── in/web/
│       │   ├── TaskController.java
│       │   └── dto/                     # AssignTaskRequest, TaskResponse (record)
│       └── out/persistence/
│           ├── TaskJpaEntity.java
│           ├── SpringDataTaskRepository.java
│           └── TaskRepositoryAdapter.java
├── delegation/
├── kpi/
├── ...
└── shared/
    ├── config/                          # SecurityConfig, JacksonConfig…
    └── exception/                       # exception chung + GlobalExceptionHandler
```

### Feature tương ứng module trong CLAUDE.md

| Package | Module |
|---|---|
| `account` | 1 – Tài khoản & phân quyền (đăng nhập, đổi mật khẩu, role Admin/HR/Member) |
| `organization` | 2 – Phòng ban, chức vụ TP/PP/NV, vị trí việc làm |
| `task` | 3 + 4 – Giao việc, task cha–con, Trình TP, gia hạn, tiến độ, nộp kết quả, review, lịch sử |
| `delegation` | 3 – Ủy quyền + báo cáo bàn giao |
| `notification` | 5 – Thông báo in-app + email, nhắc việc |
| `kpi` | 6 – Tính a/b/c, tự đánh giá, chấm, chốt/khóa kỳ, xếp loại |
| `report` | 7 – Dashboard, bảng xếp hạng, xuất Excel/PDF |

Nếu `task` quá lớn, có thể tách `review` riêng, nhưng chỉ khi thực sự cần.

## 3. Vai trò từng thành phần

| Thành phần | Trách nhiệm |
|---|---|
| `domain` | Entity và quy tắc nghiệp vụ (BR-xx, vòng đời 7 trạng thái, công thức KPI) |
| `application` | Use case, điều phối nghiệp vụ, transaction, kiểm tra quyền theo chức vụ |
| `port/in` | Interface định nghĩa hành động của ứng dụng (use case) |
| `port/out` | Interface ứng dụng cần từ bên ngoài (repository, gửi mail, lấy thông tin feature khác) |
| `adapter/in` | REST controller, scheduler (nhắc việc 48h/72h, chốt KPI ngày 1), nhận request |
| `adapter/out` | JPA, gửi email, gọi sang feature khác |
| `shared` | Thành phần dùng chung thực sự (config, exception, tiện ích thời gian) |

## 4. Luồng xử lý

```text
Client
  ↓
Controller (adapter/in/web)
  ↓
Use Case (application/port/in → service)
  ↓
Domain (quy tắc nghiệp vụ)
  ↓
Repository Port (application/port/out, interface)
  ↑ implements
Repository Adapter (adapter/out/persistence)
  ↓
PostgreSQL
```

Ví dụ: NV nộp kết quả → `TaskController` gọi `SubmitResultUseCase` → service tải `Task`, gọi `task.submit(...)` (domain kiểm tra trạng thái hợp lệ, chuyển sang Chờ review, tạo phiên bản kết quả) → `TaskRepository` lưu → port `NotificationSender` báo người review.

## 5. Nguyên tắc

1. Thư mục cấp cao nhất chia theo feature.
2. **Domain không phụ thuộc Spring, JPA hay database** — không `@Entity`, `@Component`, `@Autowired` trong `domain`. Lombok được phép (chỉ là công cụ compile-time).
3. Quy tắc nghiệp vụ nằm trong domain (ví dụ `task.approve(reviewer)` tự kiểm tra BR-07 reviewer ≠ assignee), không rải trong controller hay service.
4. Application phụ thuộc vào interface (port), không phụ thuộc trực tiếp implementation database. Được dùng `@Service` và `@Transactional` trong `application/service` (thỏa hiệp thực tế).
5. Adapter triển khai port và xử lý chi tiết kỹ thuật. Chuyển đổi `JpaEntity ↔ domain` và `DTO ↔ command/domain` nằm trong adapter.
6. **Các feature không truy cập tùy tiện code nội bộ của nhau.** Feature A cần dữ liệu feature B → gọi use case (`port/in`) của B, hoặc khai báo port out riêng trong A và adapter gọi sang B. Không import `adapter` hay `JpaEntity` của feature khác. Không dùng quan hệ JPA (`@ManyToOne`) xuyên feature — lưu ID.
7. Chỉ tạo abstraction khi thực sự cần. Truy vấn chỉ đọc đơn giản (danh sách, dashboard) được phép bỏ qua domain, đi thẳng từ service đọc → query port.

## 6. RESTful API

Backend chỉ cung cấp REST API trả JSON (Spring Web MVC, `@RestController`), frontend gọi qua HTTP.

### Quy ước URL

- Tiền tố `/api/v1`, danh từ số nhiều, kebab-case: `/api/v1/tasks`, `/api/v1/delegations`, `/api/v1/kpi-periods`.
- CRUD dùng HTTP method chuẩn:

| Hành động | Method + URL | Mã trả về |
|---|---|---|
| Danh sách (có phân trang, lọc) | `GET /api/v1/tasks?status=IN_PROGRESS&page=0&size=20` | 200 |
| Chi tiết | `GET /api/v1/tasks/{id}` | 200 / 404 |
| Tạo | `POST /api/v1/tasks` | 201 + header `Location` |
| Cập nhật | `PUT` (toàn bộ) / `PATCH` (một phần) `/api/v1/tasks/{id}` | 200 |
| Xóa | `DELETE /api/v1/...` | 204 |

- **Chuyển trạng thái là hành động nghiệp vụ, không phải PATCH trường `status`.** Dùng `POST` tới sub-resource động từ:

```text
POST /api/v1/tasks/{id}/accept          # TP chấp nhận Trình TP
POST /api/v1/tasks/{id}/reject          # body: { "reason": "..." }  (BR-06)
POST /api/v1/tasks/{id}/start
POST /api/v1/tasks/{id}/submissions     # nộp kết quả → tạo phiên bản mới
POST /api/v1/tasks/{id}/approve
POST /api/v1/tasks/{id}/request-rework  # body: { "comment": "..." }
POST /api/v1/tasks/{id}/cancel
POST /api/v1/delegations/{id}/revoke
```

- Tài nguyên con: `GET /api/v1/tasks/{id}/history`, `/api/v1/tasks/{id}/comments`, `/api/v1/tasks/{id}/subtasks`.
- Thông tin người dùng hiện tại: `GET /api/v1/me`, `GET /api/v1/me/tasks`.

### Request / response

- DTO là `record` trong `adapter/in/web/dto`, không bao giờ trả domain hay `JpaEntity` ra ngoài.
- Validate đầu vào bằng Bean Validation (`@Valid`, `@NotBlank`…) ở DTO; quy tắc nghiệp vụ validate trong domain.
- Ngày giờ dạng ISO-8601 (`2026-10-27T09:00:00+07:00`), enum dạng chuỗi `UPPER_SNAKE_CASE` (`PENDING_ACCEPTANCE`, `IN_REVIEW`…).
- Danh sách trả dạng phân trang: `{ "content": [...], "page": 0, "size": 20, "totalElements": 135 }`.

### Lỗi

Dùng `ProblemDetail` (RFC 9457) có sẵn trong Spring, xử lý tập trung tại `shared/exception/GlobalExceptionHandler` (`@RestControllerAdvice`):

| Tình huống | Mã |
|---|---|
| Sai định dạng / thiếu trường | 400 |
| Chưa đăng nhập | 401 |
| Không đủ quyền (sai chức vụ, không phải reviewer…) | 403 |
| Không tìm thấy | 404 |
| Vi phạm quy tắc nghiệp vụ / chuyển trạng thái không hợp lệ | 409 hoặc 422 |

```json
{
  "type": "about:blank",
  "title": "Business rule violated",
  "status": 422,
  "detail": "Người review không được trùng người thực hiện",
  "code": "BR-07"
}
```

Domain ném exception nghiệp vụ riêng (không phải exception Spring); handler map sang mã HTTP.

## 7. Test

- Domain: unit test thuần JUnit, không khởi động Spring.
- Service: unit test với port mock (Mockito).
- Controller: `@WebMvcTest`.
- Persistence: `@DataJpaTest` với PostgreSQL thật (Testcontainers) khi cần.
