# Kiến trúc frontend: Feature-Based

Áp dụng cho `frontend/` (Next.js 16 App Router, TypeScript, Tailwind CSS 4, shadcn/ui). Mọi code frontend mới phải theo tài liệu này.

> Next.js 16 khác nhiều so với các bản cũ (ví dụ `middleware.ts` đã đổi thành `proxy.ts`). Trước khi dùng API của Next, đọc tài liệu trong `node_modules/next/dist/docs/`.

## 1. Nguyên tắc

- **Chia code theo feature**, giống backend: code của tính năng nào nằm trong thư mục tính năng đó.
- **`app/` chỉ lo routing**: page/layout mỏng, lấy dữ liệu rồi render component của feature. Không viết logic hay UI lớn trong `app/`.
- **Backend là nguồn sự thật về nghiệp vụ và phân quyền.** Frontend chỉ ẩn/hiện nút cho dễ dùng, không tự quyết quy tắc BR-xx. Mọi kiểm tra cuối cùng do API trả về.
- Chỉ tạo abstraction khi thực sự cần.

## 2. Cấu trúc thư mục

```text
src/
├── app/                              # routing (App Router)
│   ├── layout.tsx                    # root layout, font, Toaster
│   ├── (auth)/
│   │   └── login/page.tsx
│   └── (main)/                       # các trang cần đăng nhập, dùng chung app shell
│       ├── layout.tsx                # sidebar + header
│       ├── page.tsx                  # dashboard "Việc của tôi"
│       ├── tasks/
│       │   ├── page.tsx
│       │   └── [id]/page.tsx
│       ├── delegations/
│       ├── kpi/
│       └── admin/                    # quản trị phòng ban, chức vụ (Admin/HR)
├── features/
│   ├── task/
│   │   ├── api.ts                    # hàm gọi REST API của feature
│   │   ├── types.ts                  # type khớp DTO backend
│   │   ├── schemas.ts                # schema validate form (nếu có)
│   │   ├── constants.ts              # nhãn tiếng Việt cho enum, màu badge…
│   │   ├── actions.ts                # Server Actions (nếu dùng)
│   │   ├── hooks/                    # hook client riêng của feature
│   │   └── components/               # TaskTable, TaskStatusBadge, SubmitResultDialog…
│   ├── account/
│   ├── organization/
│   ├── delegation/
│   ├── notification/
│   ├── kpi/
│   └── report/
├── components/
│   ├── ui/                           # shadcn/ui — sinh bằng CLI, hạn chế sửa tay
│   └── layout/                       # AppSidebar, AppHeader, PageHeader…
├── lib/
│   ├── api-client.ts                 # wrapper fetch: base URL, cookie/token, xử lý lỗi ProblemDetail
│   └── utils.ts                      # cn() và tiện ích chung
├── hooks/                            # hook dùng chung (use-mobile…)
└── proxy.ts                          # chặn truy cập trang khi chưa đăng nhập (kiểm tra lạc quan)
```

Feature trùng tên với package backend: `account`, `organization`, `task`, `delegation`, `notification`, `kpi`, `report`.

### Quy tắc import

- `app/` → được import `features/*`, `components/*`, `lib/*`.
- `features/A` → được import `components/*`, `lib/*`. Hạn chế import sang `features/B`; nếu cần, chỉ dùng component/type công khai, không import file nội bộ (ví dụ `task` dùng `UserAvatar` của `account`).
- `components/` và `lib/` **không** import `features/`.

## 3. Server và Client Component

- Mặc định là **Server Component**: page lấy dữ liệu từ API ở server rồi truyền xuống.
- Chỉ thêm `"use client"` cho phần cần tương tác (form, dialog, dropdown, state). Đặt `"use client"` ở component lá, không ở page.
- Thao tác thay đổi dữ liệu (giao việc, nộp kết quả, duyệt…) qua Server Action trong `features/<x>/actions.ts` hoặc gọi API từ client; sau khi thành công thì `revalidatePath`/`router.refresh()` và hiện toast.

## 4. Gọi API

- Tất cả request đi qua `lib/api-client.ts`, base URL lấy từ `NEXT_PUBLIC_API_URL` (`http://localhost:8080/api/v1`).
- Mỗi feature có `api.ts` bọc endpoint của mình; component không gọi `fetch` trực tiếp:

```ts
// features/task/api.ts
export function getTask(id: number) {
  return apiClient.get<TaskResponse>(`/tasks/${id}`);
}

export function approveTask(id: number) {
  return apiClient.post<void>(`/tasks/${id}/approve`);
}
```

- Endpoint theo quy ước REST của backend (`backend/instruction/architecture.md`, mục 6): chuyển trạng thái gọi `POST /tasks/{id}/<hành động>`, không PATCH `status`.
- `types.ts` khớp DTO backend. Ngày giờ nhận dạng chuỗi ISO-8601, hiển thị theo định dạng Việt Nam (`dd/MM/yyyy HH:mm`, múi giờ `Asia/Ho_Chi_Minh`).
- Lỗi backend trả `ProblemDetail` (`{ title, status, detail, code }`). `api-client` ném lỗi có kiểu; UI hiển thị `detail` bằng toast (`sonner`) hoặc lỗi dưới trường form. `401` → chuyển về `/login`; `403` → thông báo không đủ quyền.

## 5. UI

- Dùng component shadcn/ui trong `components/ui`. Thêm component bằng `npx shadcn@latest add <tên>`; không sửa tay trừ khi bắt buộc (sửa thì ghi chú lý do).
- Style `base-nova` dùng **Base UI** (`@base-ui/react`), không phải Radix: dùng prop `render` thay cho `asChild`. Xem file component để biết API.
- Gộp class bằng `cn()` từ `@/lib/utils`. Màu dùng biến theme (`bg-primary`, `text-muted-foreground`…), không hardcode mã màu.
- Icon dùng `lucide-react`.
- **Toàn bộ chữ hiển thị bằng tiếng Việt.** Enum từ backend (`PENDING_ACCEPTANCE`, `IN_REVIEW`…) đổi sang nhãn tiếng Việt qua `constants.ts` của feature, khớp tên trạng thái trong `../CLAUDE.md` (Chờ chấp nhận, Chờ review…). Cờ "Trễ hạn" hiển thị riêng, không phải trạng thái.

## 6. Đặt tên

| Loại | Quy ước | Ví dụ |
|---|---|---|
| File/thư mục | kebab-case | `task-table.tsx`, `submit-result-dialog.tsx` |
| Component | PascalCase | `TaskTable` |
| Hook | `use` + camelCase, file `use-xxx.ts` | `useTaskFilters` |
| Type DTO | hậu tố `Request`/`Response` giống backend | `AssignTaskRequest`, `TaskResponse` |
