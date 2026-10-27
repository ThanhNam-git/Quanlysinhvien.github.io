# CLAUDE.md — Backend

REST API cho hệ thống quản lý công việc. Nghiệp vụ chung (vai trò, vòng đời task, BR-xx, KPI) xem `../CLAUDE.md`.

## Stack

- Spring Boot 4.1, Java 21, Maven wrapper
- Web MVC (REST, JSON), Spring Security, Data JPA + PostgreSQL, Flyway, Validation, Mail, Lombok
- Package gốc `vn.qlcv`

## Chạy

```bash
./mvnw spring-boot:run     # cổng 8080, cần JDK 21 + PostgreSQL
./mvnw test
```

Cấu hình trong `src/main/resources/application.properties`, ghi đè bằng biến môi trường: `DB_URL`, `DB_USERNAME`, `DB_PASSWORD`, `MAIL_HOST`, `MAIL_PORT`, `MAIL_USERNAME`, `MAIL_PASSWORD`.

- Schema DB chỉ thay đổi qua migration Flyway trong `src/main/resources/db/migration` (`V1__init.sql`, `V2__...`). Hibernate để `ddl-auto=validate`, không tự tạo bảng. Không sửa migration đã chạy, luôn tạo file mới.
- Múi giờ nghiệp vụ: `Asia/Ho_Chi_Minh`.
- Thiết kế CSDL (bảng, ràng buộc, RBAC, quy ước đặt tên): `instruction/database.md`. Thêm/sửa bảng thì cập nhật file này cùng migration.

## Kiến trúc

**Bắt buộc theo `instruction/architecture.md`** (Feature-Based Clean Architecture + quy ước REST API):

@instruction/architecture.md
