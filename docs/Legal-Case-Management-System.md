# Legal-Case-Management-System (Backend API)

> The REST API and system of record for Silah: auth/RBAC, all domain logic (cases, clients, regulations, documents, billing), real-time notifications, and the only service that owns and writes the database. It calls the AI microservice for retrieval/LLM work but never runs models itself.

**Port:** 3000  **Stack:** Node.js · Fastify 5 · Drizzle ORM · PostgreSQL · Socket.IO  **Directory:** `Legal-Case-Management-System/`

---

## Overview

This is the hub of the platform. The web dashboard and the Flutter app are both pure clients of this API; the AI microservice is a stateless dependency this service calls. It authenticates users (JWT + Google OAuth), enforces multi-tenancy and RBAC on every request, owns the PostgreSQL schema via Drizzle, stores files in S3/MinIO, runs background workers for long-running AI/monitoring jobs, and pushes live updates over Socket.IO. The app factory (`src/app.ts`) wires plugins + 27 unique route groups (28 `app.register(...)` calls — `notificationsRoutes` is mounted twice, once at `/api/notifications` and once at `/api/alerts`); `src/server.ts` is the runtime entrypoint and only does `listen()`.

## Features

### Authentication & RBAC
Email/password (bcrypt) and Google OAuth login, issuing JWT (HS256) bearer tokens; six roles (`admin`, `senior_lawyer`, `lawyer`, `paralegal`, `clerk`, `client`) enforced per route. Routes: `src/routes/auth/index.ts`, `src/routes/oauth/index.ts` (`/google`, `/google/callback`). Login activity is tracked (`login_activity` table).
- **Product basis:** PRD §2 (Users & Roles), §5 (RBAC, multi-tenancy).

### Case & client management
CRUD for cases (`src/routes/cases/index.ts`) and clients (`src/routes/clients/index.ts`), plus client activities, client documents, and an external **client portal** (portal accounts + `client_messages`). Cases are typed and move through a status workflow.
- **Product basis:** PRD §3, §4.1.

### AI regulation linking + verification
The headline feature. `src/routes/ai-links/index.ts` assembles a case (and its ready documents) plus candidate regulations, calls the AI service via `src/services/ai-client.service.ts`, and stores ranked results in `case_regulation_links` for a lawyer to accept/reject. Heavily tunable through `CASE_LINK_*` env vars (weights for semantic/lexical/category/support, score floors, strict mode).
- **Product basis:** PRD §4.2, §7 (case → regulation flow).
- **Drift:** real matching requires the AI service to run a real embeddings provider; it defaults to `"fake"` (see PRD §9).

### AI assistant, document & regulation intelligence
`src/routes/ai/index.ts` and supporting services (`chat-context.service.ts`, `document-rag.service.ts`, `regulation-insights.service.ts`, `admin-ai-intelligence.service.ts`) back the chat assistant, document insights, regulation insights, and admin intelligence by orchestrating calls to the AI microservice with org context. Chat sessions/messages are persisted (`chat_sessions`, `chat_messages`).
- **Product basis:** PRD §4.3, §4.6.

### Documents & storage
Upload/download/delete of case and client documents (`src/routes/documents/index.ts`), stored in S3 or MinIO (`STORAGE_PROVIDER`). Documents are chunked (`document_chunks`) and extracted (`document_extractions`) for RAG, with a dedicated extraction worker.
- **Product basis:** PRD §4.4.

### Regulation monitoring & alerts
Workers poll trusted Saudi sources (MoJ listing, open-data publishers) on an interval, detect new/amended regulations, compute amendment-impact, and raise subscription alerts. Config via `REG_MONITOR_*`, `REG_SOURCE_*`, `OPEN_DATA_*`, `REG_IMPACT_*`, `REG_INSIGHTS_*`. Web search augmentation via Tavily (`TAVILY_*`).
- **Product basis:** PRD §4.5.

### Intake, automations, integrations, billing
- **Intake:** internal intake forms (`/api/intake-forms`) + public intake (`/api/public/intake`) that converts submissions into cases/clients.
- **Automations:** org automation rules (`/api/automations`).
- **Integrations & webhooks:** third-party integrations (credentials encrypted with `INTEGRATION_CREDENTIALS_KEY`) and outbound webhooks.
- **Billing:** plans, subscriptions, invoices (PDF via `pdfkit`), payments.
- **Product basis:** PRD §4.7–4.9.

### Real-time notifications
Socket.IO server registered as a Fastify plugin (`src/plugins/websocket.ts:65`), sharing the HTTP server. Backs notifications and live updates; `/api/notifications` is also aliased as `/api/alerts` for frontend compatibility (`src/app.ts:148`).
- **Product basis:** PRD §4.10, §7 (real-time).

## Architecture

- **Internal structure:** `src/app.ts` (app factory — plugins, security, route registration), `src/server.ts` (bootstrap), `src/routes/<group>/` (each group = `index.ts` handlers + `schemas.ts` Zod + `handlers.ts`), `src/services/` (business logic, incl. all AI orchestration), `src/db/schema/*.ts` (Drizzle), `src/plugins/` (auth, db, websocket, swagger, error handler), `src/workers/` (background jobs), `src/lib/`, `src/utils/`.
- **Route registration:** every group is mounted with a URL prefix in `src/app.ts:133-162` (e.g. `casesRoutes → /api/cases`). Handlers register with `fastify.<verb>(...)` inside each group.
- **Security:** `@fastify/helmet`, `@fastify/cors`, `@fastify/rate-limit` (`RATE_LIMIT_*`), `@fastify/jwt`, bcrypt password hashing, encrypted integration credentials.
- **Workers:** `combined.worker.ts` (runs all in dev), plus dedicated `scheduler.worker.ts`, `document-extraction.worker.ts`, `regulation-monitor.worker.ts`.
- **Integration — Calls:** AI microservice (`AI_SERVICE_URL`, timeout `AI_SERVICE_TIMEOUT_MS`); PostgreSQL; Redis (workers/queues); S3/MinIO; Google OAuth; Tavily; nodemailer (email); Twilio (SMS). **Called by:** website + mobile app. **Owns:** the entire PostgreSQL schema.
- **Cannot:** run ML models (delegates to the AI service); it is the only writer of the DB.

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Runtime | Node.js (TypeScript, `tsx`) |
| Framework | Fastify 5 (`@fastify/*` plugins) |
| ORM / DB | Drizzle ORM · PostgreSQL · `postgres` driver |
| Auth | `@fastify/jwt`, `passport-google-oauth20`, bcrypt |
| Realtime | Socket.IO (`socket.io`) |
| Storage | AWS S3 / MinIO (`@aws-sdk/client-s3`) |
| Queue/jobs | Redis-backed workers |
| Validation | Zod |
| Docs | `@fastify/swagger` + swagger-ui at `/docs` |
| Other | `pdfkit` (invoices), `nodemailer`, `twilio`, `pino` logging |

## Running
```bash
cd Legal-Case-Management-System
npm install
cp .env.example .env            # set DATABASE_URL, JWT_SECRET, AI_SERVICE_URL, storage, ...
npm run db:migrate              # drizzle-kit migrate
npm run db:seed                 # tsx src/db/seed.ts
npm run dev                     # API (tsx watch src/server.ts) + combined worker, concurrently
# Individual workers:
npm run worker:scheduler
npm run worker:extraction
npm run worker:reg-monitor
# Production:
npm run build && npm run start:prod   # tsc → node dist/server.js
```
Swagger UI: `http://<HOST>:<PORT>/docs`. Default port 3000.

## Data Model (DB-owning service)

PostgreSQL via Drizzle; **51 tables** in `src/db/schema/*.ts`. Nearly all carry `organization_id` (multi-tenancy). Key groups:

- **Identity/tenant:** `organizations`, `users` (UUID PK, role enum), `organization_invitations`, `user_permission_grants`, `login_activity`.
- **Cases/clients:** `cases`, `clients`, `client_activities`, `client_documents`, `client_portal_accounts`, `client_messages`.
- **Regulations:** `regulations`, `regulation_versions`, `regulation_chunks`, `regulation_insights`, `regulation_subscriptions`, `regulation_monitor_runs`, `regulation_amendment_impacts`, `legal_sources`, `legal_source_chunks`, `case_regulation_links`, `case_source_links`.
- **Documents:** `documents`, `document_chunks`, `document_extractions`, `document_reviews`.
- **AI ops:** `ai_settings`, `chat_sessions`, `chat_messages`, `ai_evaluation_runs`, `ai_evaluation_run_cases`, `ai_evaluation_labels`, `admin_ai_case_profiles`, `admin_ai_org_snapshots`, `admin_dashboard_settings`.
- **Engagement/ops:** `notifications`, `notification_preferences`, `org_announcements`, `user_activities`, `user_achievements`, `user_daily_tasks`, `automation_rules`, `integrations`, `integration_webhook_endpoints`, `intake_forms`, `intake_submissions`.
- **Billing:** `billing_plans`, `subscriptions`, `invoices`, `payments`.

Enums: case type `criminal|civil|commercial|labor|family|administrative` (`cases.ts:17`); case status `open|in_progress|pending_hearing|closed|archived` (`cases.ts:26`); user role (`users.ts:13`).

## API Reference

27 unique route groups mounted under `/api/*` (28 `app.register(...)` calls — `notificationsRoutes` is mounted at both `/api/notifications` and `/api/alerts`; `src/app.ts:133-162`). Prefixes:

| Prefix | Group | Prefix | Group |
|--------|-------|--------|-------|
| `/api/auth` | auth + oauth | `/api/dashboard` | dashboard |
| `/api/organizations` | organizations | `/api/documents` | documents |
| `/api/cases` | cases + case-documents | `/api/clients` | clients |
| `/api/regulations` | regulations | `/api/notifications`, `/api/alerts` | notifications (alias) |
| `/api/ai-links` | AI regulation linking | `/api/profile` | profile |
| `/api/case-sources` (+ `/curator`) | case sources | `/api/settings` | settings |
| `/api/ai` | AI assistant/ops | `/api/users/me` | users |
| `/api/ai-evaluation` | AI eval harness | `/api/billing` | billing |
| `/api/search` | search | `/api/intake-forms` | intake |
| `/api/public/intake` | public intake | `/api/automations` | automations |
| `/api/webhooks` | webhooks | `/api/integrations` | integrations |
| `/api/admin` | admin + ai-intelligence | `/api/announcements` | announcements |

For exact methods/paths, read the cited `src/routes/<group>/index.ts` handlers or the live Swagger UI at `/docs`.

## Configuration

93 env vars in `.env.example`. Boot-time essentials:

| Variable | Purpose |
|----------|---------|
| `DATABASE_URL` | PostgreSQL connection |
| `JWT_SECRET`, `JWT_EXPIRES_IN` | JWT signing |
| `PORT` (3000), `HOST`, `CORS_ORIGIN`, `FRONTEND_URL` | server/CORS |
| `AI_SERVICE_URL`, `AI_SERVICE_TIMEOUT_MS` | AI microservice |
| `REDIS_HOST`, `REDIS_PORT` | workers/queues |
| `STORAGE_PROVIDER`, `S3_*` / `MINIO_*` | object storage |
| `GOOGLE_CLIENT_ID/SECRET/CALLBACK_URL` | OAuth |
| `TAVILY_*` | web-search augmentation |
| `INTEGRATION_CREDENTIALS_KEY` | encrypt integration creds |
| `RATE_LIMIT_MAX`, `RATE_LIMIT_WINDOW` | rate limiting |

Tuning knobs (algorithm behavior, not infra) — `CASE_LINK_*`, `CASE_DOC_*`, `REG_*`, `OPEN_DATA_*`, `INSIGHTS_*` — are documented in `.env.example`; treat them as code defaults that env can override.

## Sources
- `src/app.ts` (route prefixes, plugin registration), `src/server.ts` (bootstrap)
- `src/routes/*/index.ts` (handlers), `src/db/schema/*.ts` (51 tables), `src/workers/*.ts`
- `src/services/ai-client.service.ts` (AI integration), `src/plugins/websocket.ts` (Socket.IO)
- `package.json` (scripts/deps), `.env.example` (config)
