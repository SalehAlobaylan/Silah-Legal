# Silah (صلة) — Architecture & Documentation Index

> Single-source docs for all 4 services, generated from source by `/update-docs`. Product intent lives in [PRD.md](PRD.md); per-service detail is linked below. These docs are self-contained — they do not depend on `/context/`.

## What Silah Is

Silah is an AI-powered, Arabic-first legal case-management platform for Saudi legal practitioners. Law firms and legal departments manage cases, clients, and documents through a web dashboard and a mobile app, over a Fastify REST API. A stateless Python microservice runs the AI: it links each case to the Saudi regulations that govern it (with verifiable evidence), powers a legal chat assistant, and extracts/analyzes documents and regulations. The platform is multi-tenant, role-based, bilingual (AR/EN, RTL), and real-time.

## System Architecture

Four services compose into one product. The **backend owns the database**; everything else is a client or a stateless dependency.

- **Auth flow** — backend issues a JWT (email/password or Google OAuth) → web + mobile attach `Authorization: Bearer`.
- **Case → regulation suggestion** — web/mobile create a case → backend `/api/ai-links` assembles the case + candidate regulations → calls the AI service `/similarity/find-related` → AI runs the RAG pipeline (embed → composite score → optional HyDE / agentic / ColBERT / rerank → optional Gemini verification) → backend stores ranked `case_regulation_links` → lawyer verifies in the UI.
- **Document intelligence** — upload → backend stores in S3/MinIO, chunks → AI service extracts (incl. Arabic OCR) → case insights.
- **Regulation monitoring** — backend workers poll trusted Saudi sources → detect new/amended regulations → AI amendment-impact → subscription alerts.
- **Real-time** — backend Socket.IO pushes notifications → web (`socket.io-client`) + mobile (`socket_io_client`).

```
GP-flutter ─────────────────→ backend (REST + Socket.IO, :3000)
Legal_Case_Management_Website → backend (REST + Socket.IO, :3000)
backend ────────────────────→ AI microservice (:8000)  [find-related, extract, insights, chat]
backend ────────────────────→ PostgreSQL (Drizzle; backend is the only writer)
backend ────────────────────→ Redis (workers/queues), S3/MinIO (files), Tavily, Gemini*, Google OAuth
web / mobile ────────────────→ AI service ONLY via the backend (never direct)
```
\* Gemini/HF are called by the AI microservice, not the backend.

## Services

| Service | Role (one line) | Stack | Port |
|---------|-----------------|-------|------|
| [Legal-Case-Management-System](Legal-Case-Management-System.md) | REST API, auth/RBAC, cases/clients/regulations/docs/billing, Socket.IO, **owns DB** | Node.js · Fastify 5 · Drizzle · PostgreSQL | 3000 |
| [Legal_Case_Management_Website](Legal_Case_Management_Website.md) | Web dashboard for lawyers & admins + client portal | Next.js 16 · React 19 · shadcn · TanStack Query | 3001 (prod) |
| [Legal-Case-Management-System-AI-Microservice](Legal-Case-Management-System-AI-Microservice.md) | Stateless RAG/LLM: case↔regulation matching, assistant, extraction, insights | Python · FastAPI · BGE-M3 · Gemini | 8000 |
| [GP-flutter](GP-flutter.md) | Flutter app + client portal (early development) | Flutter · Dart · Provider · GoRouter · Dio | — |

## Shared Data Model (verify each sync)

- **PostgreSQL**, owned by the backend via Drizzle — **51 tables** in `Legal-Case-Management-System/src/db/schema/*.ts`.
- **Multi-tenant:** nearly every table carries `organization_id`; clients only see their own org.
- **Roles:** `admin`, `senior_lawyer`, `lawyer`, `paralegal`, `clerk`, `client` (`users.ts:13`).
- **Case types:** `criminal`, `civil`, `commercial`, `labor`, `family`, `administrative` (`cases.ts:17`).
- **Case status:** `open → in_progress → pending_hearing → closed → archived` (`cases.ts:26`).
- **Embeddings:** BAAI/bge-m3 multilingual (AR/EN) — but the AI service defaults to a `fake` provider; set `EMBEDDINGS_PROVIDER=bge` for real retrieval (`ai_service/app/config.py:32`).

## Running Everything

Each service has its own setup (see its doc). Quick path:
```bash
# 1. Backend (:3000) — owns DB, must be up first
cd Legal-Case-Management-System && npm install && npm run db:migrate && npm run db:seed && npm run dev
# 2. AI service (:8000)
cd Legal-Case-Management-System-AI-Microservice && source .venv/bin/activate && cd ai_service && uvicorn app.main:app --port 8000
# 3. Website — run on 3001 to avoid colliding with backend's 3000
cd Legal_Case_Management_Website && npm install && npx next dev -p 3001
# 4. Mobile
cd GP-flutter/gp && flutter run --dart-define=API_BASE_URL=http://localhost:3000
```
There is also a repo-root `start.sh` that orchestrates services.

## Known Cross-Service Gotchas

These are real and tracked in [PRD.md §9](PRD.md#9-implementation-status--known-gaps):
1. **Port collision in dev** — the website's `npm run dev` uses `-p 3000`, the same port as the backend. Run the web dev server on 3001.
2. **Mobile default API base is wrong** — defaults to `:3001` (the website), not the backend's `:3000`. Pass `--dart-define=API_BASE_URL=http://localhost:3000`.
3. **AI embeddings default to `fake`** — real case↔regulation matching needs `EMBEDDINGS_PROVIDER=bge` (or an HF token).

---

*Generated by `/update-docs` from source code. Regenerate after structural changes; update [PRD.md](PRD.md) §9 as code and intent converge or diverge.*
