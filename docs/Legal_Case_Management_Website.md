# Legal_Case_Management_Website (Web Dashboard)

> The web dashboard for lawyers and admins (and a client-portal surface). A Next.js App Router app that is a **pure client** of the backend API — it has no API routes or database of its own; all data comes from the backend over HTTP + Socket.IO.

**Port:** 3001 (production `start`) — see drift below  **Stack:** Next.js 16 · React 19 · TypeScript · Tailwind · shadcn/ui · TanStack Query · Zustand  **Directory:** `Legal_Case_Management_Website/`

---

## Overview

This is the primary human interface for staff users. It renders three route groups — authentication, the main dashboard, and the external client portal — and talks exclusively to the backend (`NEXT_PUBLIC_API_URL`), the AI service URL is exposed for reference (`NEXT_PUBLIC_AI_SERVICE_URL`), and real-time updates arrive over `socket.io-client` (`NEXT_PUBLIC_WS_URL`). State is split: TanStack Query for server data, Zustand for client state. There are **no** `route.ts` API handlers — confirmed by the crawler — so there is no server-side data layer here.

## Features

### Authentication surface
`/(auth)/login`, `/(auth)/register`, plus `/auth/callback` for the Google OAuth round-trip. Tokens from the backend are attached to subsequent requests (via `axios`).
- **Product basis:** PRD §2, §7 (auth).

### Case workspace
Routes under `/(dashboard)/cases`: list, `new`, `[id]` detail, `[id]/edit`, `[id]/linking` (review AI regulation suggestions), and `[id]/prepare`. The `linking` page is the UI for the case→regulation verification flow.
- **Product basis:** PRD §4.1, §4.2.

### Client management & client portal
`/(dashboard)/clients` (list, `new`, `[id]`, `automations`, `intake`) for staff, and a separate `/(client-portal)/portal/*` area (`overview`, `documents`, `billing`) for external `client` users.
- **Product basis:** PRD §3, §4.1.

### Regulations, dashboard, alerts, admin
`/(dashboard)/regulations` (+ `[id]`), `/(dashboard)/dashboard`, `/(dashboard)/alerts` (live notifications), `/(dashboard)/profile`, `/(dashboard)/settings`, and admin pages `/(dashboard)/admin/dashboard`, `/admin/monitoring`, `/admin/lawyers/[id]`. Charts via `recharts`; drag-and-drop via `@dnd-kit`.
- **Product basis:** PRD §4.5, §4.6, §4.10.

### Public intake
`/intake/[formId]` renders a public intake form (no auth) that submits to the backend's public-intake endpoint.
- **Product basis:** PRD §4.7.

## Architecture

- **Internal structure (`src/`):** `app/` (App Router — route groups `(auth)`, `(dashboard)`, `(client-portal)`), `components/` (UI, shadcn/ui-based), `lib/` (API client, helpers, error codes), `context/` + `providers/` (React context, query/socket providers), `__tests__/`.
- **Routing:** App Router; route-group folders in parentheses don't appear in the URL. 28 `page.tsx` routes total (incl. the root landing page `src/app/page.tsx`).
- **Data flow:** components → TanStack Query hooks → `axios` → backend `/api/*`; live updates → `socket.io-client` → query invalidation. No server actions, no `route.ts`.
- **Forms/validation:** `react-hook-form` + `zod` (`@hookform/resolvers`).
- **i18n/RTL:** Arabic-first, RTL-aware (PRD §5).
- **Integration — Calls:** backend REST (`NEXT_PUBLIC_API_URL`) + Socket.IO (`NEXT_PUBLIC_WS_URL`). **Cannot:** touch the database or call the AI service directly (goes through the backend).

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Framework | Next.js 16 (App Router), React 19 |
| Language | TypeScript |
| Styling/UI | Tailwind, shadcn/ui, `lucide-react` |
| Server state | TanStack Query |
| Client state | Zustand |
| HTTP / realtime | axios · socket.io-client |
| Forms | react-hook-form + zod |
| Charts / DnD / docs | recharts · @dnd-kit · react-doc-viewer |
| Testing | Jest · Playwright (`e2e/`) |

## Running
```bash
cd Legal_Case_Management_Website
npm install
cp .env.example .env             # NEXT_PUBLIC_API_URL, NEXT_PUBLIC_WS_URL, NEXT_PUBLIC_AI_SERVICE_URL
npm run dev                      # next dev -p 3000  (see drift)
# Production:
npm run build && npm run start   # next start -p 3001
# Tests:
npm run test                     # jest
npm run test:e2e                 # playwright
```

**Drift / gotcha:** `dev` runs on **port 3000**, which collides with the backend's dev port; only `start` (production) uses **3001**. Run the web dev server on a different port (e.g. `next dev -p 3001`) or run the backend elsewhere to avoid the clash. (`package.json` scripts.)

## Configuration
| Variable | Purpose |
|----------|---------|
| `NEXT_PUBLIC_API_URL` | Backend REST base URL |
| `NEXT_PUBLIC_WS_URL` | Socket.IO URL for live updates |
| `NEXT_PUBLIC_AI_SERVICE_URL` | AI service URL (reference; calls normally route via backend) |

`.env.e2e` holds Playwright test config.

## Sources
- `src/app/**/page.tsx` (routes), `src/{components,lib,context,providers}/`
- `package.json` (Next 16 / React 19, scripts, deps), `.env.example`, `e2e/`
