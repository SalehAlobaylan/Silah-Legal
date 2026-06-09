# Silah (صلة) — Product Requirements Document

**Product:** Silah — AI-powered legal case-management platform for Saudi legal practitioners
**Doc type:** Product Requirements Document (system-wide, self-contained)
**Status:** Reconstructed from source code — this is the authoritative product spec; it does not depend on `/context/`.
**Primary market:** Saudi Arabia (Arabic-first, bilingual AR/EN, RTL)

> This PRD was regenerated directly from the codebase by `/update-docs`. Where it states a *fact* (a port, model, enum), code wins and the file is cited. Where it states *intent* (what a capability is for), it is the product goal — when code contradicts intent, that is tracked in **§9 Implementation Status — Known Gaps**, not silently rewritten.

---

## 1. Purpose & Vision

Silah is a multi-tenant SaaS platform that gives Saudi law firms, legal departments, and consultants a single workspace to manage cases, clients, and documents — and uses AI to connect each case to the Saudi laws and regulations that govern it. The differentiator is the **case → regulation linking engine**: a retrieval pipeline that surfaces relevant regulations for a case, with verifiable evidence, so a lawyer reviews suggestions rather than searching manually.

The product is **Arabic-first** (Arabic primary, English secondary, full RTL) because its users and its legal corpus are Arabic.

## 2. Users & Roles

Six roles, enforced by RBAC (`Legal-Case-Management-System/src/db/schema/users.ts:13`):

| Role | Intent |
|------|--------|
| `admin` | Full org administration, billing, member management, AI/analytics dashboards |
| `senior_lawyer` | Case management + team oversight |
| `lawyer` | Full case management (default role on signup) |
| `paralegal` | Limited case access |
| `clerk` | Administrative tasks |
| `client` | External client-portal access only (their own cases/documents/billing) |

Every user belongs to exactly one **organization** (tenant). All data is scoped by `organization_id`; users only ever see their own org's data.

## 3. Core Domain

- **Cases** — typed `criminal | civil | commercial | labor | family | administrative`; status `open → in_progress → pending_hearing → closed → archived` (`src/db/schema/cases.ts:17,26`). A case has a client, an assigned lawyer, jurisdiction, filing date, and next-hearing date.
- **Clients** — client records, client activities, client documents, plus an external **client portal** (separate portal accounts + messaging).
- **Regulations / legal sources** — Saudi laws stored with versions, chunks (for retrieval), insights, amendment-impact analysis, and monitoring of upstream sources.
- **Documents** — case documents and client documents, uploaded to object storage, chunked and extracted for RAG.

## 4. Product Capabilities (the "what")

1. **Case & client management** — CRUD for cases, clients, and the relationships between them, with dashboards, search, and activity tracking.
2. **AI regulation linking + verification** — for a case, the system finds the most relevant regulations and presents them as **suggestions a lawyer accepts or rejects** (`case_regulation_links`). Suggestions carry similarity scores and matched-evidence so the lawyer can verify, not just trust.
3. **AI legal assistant** — chat (with streaming), case analysis, and document summarization grounded in the org's own case/document/regulation context.
4. **Document intelligence** — upload → extract text (incl. OCR for scanned Arabic) → chunk → derive case insights from documents.
5. **Regulation monitoring** — poll trusted Saudi sources (e.g. MoJ, open-data publishers), detect new/amended regulations, and raise subscription-based alerts with amendment-impact analysis.
6. **Admin intelligence** — org-level AI summaries, case-risk profiles, and review-prioritization for administrators.
7. **Intake** — public intake forms that turn external submissions into cases/clients.
8. **Automations & integrations** — org automation rules, third-party integrations, and outbound webhooks.
9. **Billing** — plans, subscriptions, invoices (PDF), and payments.
10. **Real-time** — live notifications and updates over Socket.IO.
11. **Multi-channel access** — a web dashboard (lawyers/admins) and a Flutter mobile app (incl. a client-portal experience).

## 5. Hard Constraints (non-negotiable product rules)

- **Multi-tenancy:** every query is scoped by `organization_id`. Cross-org data leakage is a Sev-1 defect.
- **RBAC:** privileged actions check role; `client` users are confined to the client portal.
- **Bilingual / RTL:** all user-facing surfaces support Arabic (primary) and English, RTL-aware.
- **AI is advisory:** AI never auto-decides a legal outcome. Regulation links and insights are suggestions a human verifies.
- **Service boundaries:** the AI microservice is **stateless** — it owns no database and receives all case/regulation data in the request. Only the backend owns and writes the database. The web and mobile clients never talk to the database directly and reach the AI service only through the backend.

## 6. Architecture (one line each)

| Service | Role | Stack | Port |
|---------|------|-------|------|
| `Legal-Case-Management-System` | REST API, auth/RBAC, domain logic, Socket.IO, owns the DB | Node.js / Fastify 5 / Drizzle / PostgreSQL | 3000 |
| `Legal_Case_Management_Website` | Web dashboard for lawyers & admins | Next.js 16 / React 19 / shadcn / TanStack Query | 3001 (prod) |
| `Legal-Case-Management-System-AI-Microservice` | Stateless RAG / LLM pipeline | Python / FastAPI / BGE-M3 | 8000 |
| `GP-flutter` | Mobile app + client portal | Flutter / Dart | — |

See [architecture.md](architecture.md) for the cross-service flows and [per-service docs](architecture.md#services) for detail.

## 7. Key Flows

- **Case → regulation suggestion:** lawyer creates/opens a case → backend `/api/ai-links` gathers the case + candidate regulations and calls the AI service `/similarity/find-related` → AI runs the pipeline (embed → composite score → optional HyDE/agentic/ColBERT/rerank → optional LLM verification) → backend stores ranked `case_regulation_links` → lawyer verifies in the UI.
- **Auth:** backend issues a JWT (HS256) on login/register or Google OAuth → web & mobile send `Authorization: Bearer <token>`.
- **Real-time:** backend emits notifications/updates over Socket.IO → web (`socket.io-client`) and mobile (`socket_io_client`) subscribe.

## 8. Success Signals (intent)

- A lawyer can go from "new case" to "reviewed regulation suggestions" without manually searching the corpus.
- Regulation suggestions are explainable (every suggestion has evidence/score).
- New or amended regulations reach subscribed users as actionable alerts.
- The whole experience works in Arabic, RTL, on web and mobile.

## 9. Implementation Status — Known Gaps

This table tracks places where **code diverges from product intent**. Maintained by `/update-docs`; never delete an intent line to "match" the code — record the gap.

| Area | Intent | Code reality | Evidence |
|------|--------|--------------|----------|
| AI embeddings | Use the multilingual BGE-M3 model for real Arabic/English retrieval | Default provider is `"fake"`; real embeddings require `EMBEDDINGS_PROVIDER=bge` (or HF serverless/endpoint) via env | `ai_service/app/config.py:32` (default `"fake"`), `:37` (model `BAAI/bge-m3`) |
| Mobile API base | Mobile talks to the backend (`:3000`) | `API_BASE_URL` defaults to `http://localhost:3001` (the website's port) | `GP-flutter/gp/lib/core/constants/api_constants.dart:4` |
| Web dev port | Web runs on 3001 | `dev` script uses `-p 3000`, colliding with the backend's dev port; only `start` uses 3001 | `Legal_Case_Management_Website/package.json` (`"dev":"next dev -p 3000"`) |
| Mobile maturity | Full mobile parity (per roadmap) | Early development; 10 feature modules scaffolded, GoRouter wired | `GP-flutter/gp/lib/features/`, `gp/lib/app/routes.dart` |

## 10. Out of Scope (v1, from code signals)

- Direct DB access from clients; clients are API-only.
- AI making binding legal decisions.
- Any single-tenant assumption — multi-tenancy is mandatory everywhere.

---

*Generated by `/update-docs` from source. To refresh, run the skill and update §9 as code and intent converge or diverge.*
