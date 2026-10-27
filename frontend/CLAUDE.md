# CLAUDE.md — Frontend

Giao diện web cho hệ thống quản lý công việc, gọi REST API của `../backend`. Nghiệp vụ chung (vai trò, vòng đời task, BR-xx, KPI) xem `../CLAUDE.md`.

## Stack

- Next.js 16 (App Router, Turbopack), React 19, TypeScript, thư mục `src/`, alias `@/*` → `src/*`
- Tailwind CSS 4, shadcn/ui (style `base-nova`, Base UI, icon lucide), toast `sonner`

## Chạy

```bash
npm run dev      # http://localhost:3000
npm run build
npm run lint
```

Biến môi trường: copy `.env.example` → `.env.local`. `NEXT_PUBLIC_API_URL` = URL gốc của API backend (mặc định `http://localhost:8080/api/v1`).

## Kiến trúc

**Bắt buộc theo `instruction/architecture.md`** (Feature-Based, quy ước gọi API, UI):

@instruction/architecture.md

@AGENTS.md
