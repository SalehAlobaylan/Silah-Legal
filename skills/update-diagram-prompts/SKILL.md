---
name: update-diagram-prompts
description: Build, generate, update, and sync the code-backed diagram-generation prompts in docs/diagram-prompts.md for the Silah-Legal meta-monorepo. Use this skill whenever the user wants to: generate or refresh diagram prompts, update the system/architecture/auth/AI-pipeline/data-model diagrams, regenerate diagram-prompts.md, check whether the diagram prompts have drifted from code, add a new diagram prompt, or keep the Gemini/LLM diagram prompts current with the 4 services (Legal-Case-Management-System backend, Legal_Case_Management_Website frontend, Legal-Case-Management-System-AI-Microservice, GP-flutter mobile). This is the diagram counterpart to the update-docs skill: same code-as-source-of-truth methodology, but the artifact is diagram prompts, not prose docs. Also use when the user says the diagrams are out of date or a new service/flow needs to appear in the diagrams.
---

# update-diagram-prompts

Maintains `docs/diagram-prompts.md` — a catalog of **code-backed prompts** that, when fed to a diagram-capable LLM (Gemini, etc.), produce current-state diagrams of the Silah system. This is the diagram sibling of the `update-docs` skill. The discipline is identical: **read the source code, treat it as the source of truth, and flag where the prompts have drifted.** A prompt that describes a system that no longer exists generates a diagram that lies.

The deliverable is not a diagram — it's the *prompt that generates the diagram*. Each prompt is a self-contained spec an LLM can render without seeing the repo: product context, code-backed components, data flows, boundary rules, and visual requirements. All paths below are **relative to the monorepo root** (`Silah-Legal/`).

## Why This Skill Exists (the drift problem)

Diagrams rot faster than code and silently — nobody notices until a diagram is wrong in a review. Silah's current diagram assets are the proof: `docs/diagrams/` holds four static PNGs (`Arch.png`, `arch1.png`, `UML.png`, `DB-ERD.png`) that are **images with no link to source** — they predate most of the current system and cannot be diffed against code. This skill replaces "a PNG someone exported once" with "a prompt regenerated from code." When you generate `docs/diagram-prompts.md`, make sure these code facts (which the old images get wrong or omit) are correct:

- **It is 4 services, not a vague box-of-boxes.** Backend (`Legal-Case-Management-System`, Node/Fastify, :3000, **owns the DB**), website (`Legal_Case_Management_Website`, Next.js, :3001), AI microservice (`Legal-Case-Management-System-AI-Microservice`, FastAPI, :8000, **stateless**), mobile (`GP-flutter`, Flutter). Derive the set from the repo + `docs/architecture.md`, not from the old PNGs.
- **The AI service is rich, not "one endpoint."** It mounts **11 routers** (`ai_service/app/main.py:50-60`): health, embeddings, similarity, find_related, find_related_multi_source, regulation_extract, regulation_insights, document_extract, document_insights, assistant, admin_insights. Any diagram that shows a single "AI: find related" box is stale.
- **The case→regulation linking is a 7-stage RAG pipeline**, not a single hop: HyDE → embed/unit-build → composite score → agentic retrieval → ColBERT late-interaction → cross-encoder rerank → Gemini LLM verification (`ai_service/app/api/routes/find_related.py:1-15`). Most stages are optional and gated per request.
- **Embeddings: BGE-M3 multilingual — but the default provider is `fake`.** Real retrieval needs `EMBEDDINGS_PROVIDER=bge` (`ai_service/app/config.py:32`, model `BAAI/bge-m3` at `:37`). Don't draw "the AI box embeds with BGE-M3" without noting it's off by default.
- **The backend is the only DB writer; clients never call the AI service directly.** Web/mobile → backend → AI. The AI service owns no database. This boundary must be visible in the architecture and journey diagrams.
- **Realtime is Socket.IO** registered as a Fastify plugin (`src/plugins/websocket.ts:65`), not a separate service.
- **Data model is large:** 51 Drizzle tables in `src/db/schema/*.ts`, nearly all carrying `organization_id` (multi-tenancy). The ERD prompt must show org-scoping, not just table boxes.
- **Port gotchas to label, not hide:** the website `dev` script runs on `:3000` (collides with the backend); mobile's `API_BASE_URL` defaults to `:3001` (should be `:3000`). See `docs/PRD.md` §9.

## Scope: Which Services Appear in Diagrams

All four are active — draw all of them.

| Service | Dir | Port | Role in diagrams |
|---------|-----|------|------------------|
| Backend API | `Legal-Case-Management-System` | 3000 | REST + Socket.IO, **owns PostgreSQL**, calls AI service, runs workers |
| Web dashboard | `Legal_Case_Management_Website` | 3001 | Next.js client for lawyers/admins + client portal |
| AI microservice | `Legal-Case-Management-System-AI-Microservice` | 8000 | stateless RAG/LLM: find-related, assistant, extraction/OCR, insights |
| Mobile app | `GP-flutter` | — | Flutter client + client portal (early development) |

**Infra/externals to show where relevant:** PostgreSQL (backend-owned), Redis (worker queues), S3/MinIO (file storage), and external calls made *by the AI service* — Gemini (verification/assistant), Hugging Face (embeddings), ALAPI (OCR) — plus backend externals Google OAuth, Tavily (web search), Twilio/nodemailer (notifications).

## Source of Truth Priority

- **Facts** (services, ports, routes, routers, pipeline stages, tables, models, providers): **code wins.** Use the crawler + read the cited files. Do **not** copy facts from the old PNGs or from `/context/` (stale, being removed).
- **Product context** (what each diagram is *explaining* — the case→regulation value, the verification workflow, multi-tenancy, bilingual/RTL): **the PRD (`docs/PRD.md`) wins.** The Product Context block in each prompt comes from the PRD.
- When code and a prior prompt/PNG/PRD disagree, that's drift — fix the prompt to match code and note it in your report.

## The Harness — run this first

This skill ships its own harness plus the shared crawler. **Always run the harness before writing or reviewing any prompt** — it is how you drive the skill's core job (keeping prompts code-accurate).

### 1. `scripts/check-diagram-facts.sh` — the focused drift-checker (primary)

Prints exactly the handful of drift-prone facts the diagram catalog encodes — service set + ports, backend route-group count, Socket.IO line, worker list, table count, the 11 AI routers, the 7 find-related stages, embeddings provider/model, the 6 roles, and the port gotchas — each with a `file:line` source. Diff its output against `docs/diagram-prompts.md`: any mismatch is a diagram that lies.

```bash
# From the monorepo root:
./skills/update-diagram-prompts/scripts/check-diagram-facts.sh
```

Read-only, exits 0 on success. This is the **review-mode harness** and the pre-write checklist for full regenerate.

### 2. `../update-docs/scripts/inventory.sh` — the broad crawler (for detail)

When you need more than the headline facts (exact route paths, schema fields, every Flutter route), reuse the `update-docs` crawler:

```bash
./skills/update-docs/scripts/inventory.sh all       # everything
./skills/update-docs/scripts/inventory.sh ai        # AI routers + RAG core modules (pipeline diagram)
./skills/update-docs/scripts/inventory.sh backend   # route groups + 51 tables + workers (architecture/ERD)
```

Service keys: `backend`, `website`, `ai`, `mobile`. The crawler is shared with `update-docs`; if it ever drifts from the code layout, fix it there and both skills benefit.

### 3. `examples/` — a proven prompt→diagram loop

`examples/architecture.prompt.md` is catalog prompt #1 fully filled in from the harness output; `examples/architecture.mmd` is a valid rendering of it; `examples/architecture.png`/`.svg` are that diagram **actually rendered** (verified during authoring). Use it as the template for what a finished, code-accurate prompt looks like, and to confirm the render path works:

```bash
cd skills/update-diagram-prompts/examples
npx -y @mermaid-js/mermaid-cli -i architecture.mmd -o architecture.svg   # needs node/npx (+chromium once)
```

## The Diagram Catalog

`docs/diagram-prompts.md` opens with a short header (date, purpose, the 4-service list, a note that `docs/diagrams/*.png` are legacy exports superseded by these prompts) and then contains one prompt per diagram. Keep these and update them; add new ones as the system grows.

1. **Overall System Architecture** — all 4 services + infra (PostgreSQL, Redis, S3/MinIO) + external APIs. Show clients→backend→AI, the backend as sole DB writer, and user-JWT auth vs internal service calls drawn distinctly.
2. **Auth & RBAC Flow** — email/password + Google OAuth → backend JWT issuance (HS256) → web/mobile bearer tokens; the 6 roles, `organization_id` multi-tenant scoping, and `client`-role confinement to the client portal. Sequence/swimlane.
3. **Case → Regulation AI Linking Pipeline** — the headline flow. Lawyer/case → backend `/api/ai-links` assembles case + candidate regulations → AI `/similarity/find-related` → the **7 RAG stages** (HyDE, embed, composite score, agentic, ColBERT, rerank, Gemini verify) → ranked `case_regulation_links` → lawyer verification UI. Mark optional stages as dashed.
4. **AI Microservice Internals** — the 11 routers grouped by capability (embeddings · similarity/find-related · assistant chat+stream+analyze+summarize · extraction+OCR · insights: document/regulation/admin), the `ai_service/app/core/*` engine modules, the **stateless** boundary (no DB), and external LLM/OCR calls.
5. **Tech Stack, File Structure & Deployment** — per-service stack, ports, env groups, and startup order (backend first → AI service → website → mobile). Must label the dev port collision and the mobile default-URL gotcha.
6. **End-to-End Case Journey** — lawyer creates case → upload documents → backend stores in S3/MinIO + chunks → AI extraction/OCR → AI find-related → suggestions stored → lawyer verifies → regulation monitoring raises alerts → Socket.IO notifications to web/mobile.
7. **Data Model / ERD** — the 51 Drizzle tables grouped (identity/tenant, cases/clients, regulations, documents, AI ops, engagement, billing), every group scoped by `organization_id`. Supersedes the static `DB-ERD.png`.

## Prompt Anatomy

Every prompt uses this skeleton so diagrams come out consistent and code-grounded:

```
You are a technical diagram designer. Create a <diagram type> for the current Silah platform.

Use the repository code and structure as the source of truth. Draw the 4 active
services (backend, web, AI microservice, mobile). The backend is the only writer
of the database; web and mobile never call the AI service directly.

### Product Context
<2–4 lines from docs/PRD.md: Arabic-first legal case management, the case→regulation
 AI-suggestion + verification model, multi-tenancy — what this diagram explains for product>

### Code-Backed Components
<one block per component the diagram shows — from the crawler/source:
 name, path, type, stack, port, the routes/routers/tables/workers it owns, and its
 "must not" boundary. Cite real route prefixes (e.g. /api/ai-links) and router/path names
 (e.g. /similarity/find-related).>

### Key Data Flows
<numbered, directional, protocol-labeled:
 "Website → backend GET /api/cases (JWT)",
 "backend → AI POST /similarity/find-related (internal)",
 "backend → PostgreSQL (Drizzle, sole writer)",
 "backend → web/mobile Socket.IO notifications">

### Boundary Rules
<the hard service boundaries to visualize — backend owns DB; AI is stateless;
 clients reach AI only via backend; client-role users confined to the portal>

### Visual Requirements
<layout, color groups per service, solid vs dashed (optional/on-demand) vs red (failure)
 arrows, user-JWT vs internal-call distinction, icons for queue/db/storage, exclusions>

Generate a complete current-state <diagram type>.
```

Keep prompts **self-contained** (the LLM never sees the repo), **code-accurate** (every route/router/port/table/dimension matches source), and **diagram-tool-agnostic** (describe the picture, not a specific tool's syntax).

## Workflows

### Full regenerate (all prompts)
1. Run `./skills/update-diagram-prompts/scripts/check-diagram-facts.sh` for the canonical facts, and `./skills/update-docs/scripts/inventory.sh all` when you need finer detail.
2. Read `docs/PRD.md` for the Product Context blocks (do not read `/context/` — stale, being removed).
3. If `docs/diagram-prompts.md` exists, read it to preserve structure, intent, and any deliberate visual conventions. (First run: it doesn't exist yet — create it from the catalog above; use `examples/architecture.prompt.md` as the shape of a finished prompt.)
4. Write each prompt against the harness facts — the 4 services, the 11 AI routers, the 7-stage pipeline, 51 tables, correct ports/providers.
5. Write the header (date, 4-service list, the note that `docs/diagrams/*.png` are legacy/superseded).
6. Report: per prompt, what it shows, and **call out every code↔(old-PNG/prior-prompt) drift you corrected** — that's the point of the run.

### Targeted update (one diagram, or "a service changed")
Update only the affected prompt(s). Use the map below to decide which. Still fix the header if the service set changed.

### Review mode ("are the diagrams out of date?")
Read-only. Run `./skills/update-diagram-prompts/scripts/check-diagram-facts.sh`, diff its output against each prompt (and the old PNGs), and produce a drift table with `file:line` evidence:

| Prompt | Element | Status | Evidence |
|--------|---------|--------|----------|
| #3 AI pipeline | stages | **outdated** | old `Arch.png` shows one AI hop; `find_related.py:1-15` = 7 gated stages |
| #4 AI internals | endpoints | **outdated** | prompt says 1 endpoint; `main.py:50-60` mounts 11 routers |
| #1 Architecture | embeddings | **caveat** | BGE-M3 but provider defaults to `fake` (`config.py:32`) |

**Stop and ask which diagrams to regenerate before writing anything.** Don't rewrite the whole file unasked.

## Code Change → Which Prompts to Update

| What changed | Prompts to update |
|--------------|-------------------|
| New/removed service | #1, #5, #6 (and #4 if it's the AI service) |
| Backend route group added/changed | #1 (if architectural), #5 API matrix, #6 if it's in the journey |
| AI router / RAG stage change | #3, #4, #6 |
| Embedding/model/provider change | #3, #4, and any "BGE-M3 / provider" mention |
| Drizzle table / schema change | #7 ERD, #6 if it's a journey entity |
| Auth/JWT/role/OAuth change | #2, #1 (auth arrows) |
| Worker/queue change | #6 (journey), #1 if drawn |
| Port/env/startup change | #5 |
| Case/verification/feed product change | #6, and the Product Context block wherever it appears |

## Done When
- `scripts/check-diagram-facts.sh` runs clean and every fact it prints is reflected in `docs/diagram-prompts.md` (no drift).
- `docs/diagram-prompts.md` reflects the 4 active services, the 11 AI routers, the 7-stage find-related pipeline, 51 tables, correct ports/providers, and the backend-owns-DB / AI-stateless boundary.
- The header notes that `docs/diagrams/*.png` are legacy exports superseded by these prompts.
- Each prompt is self-contained and code-accurate.
- Your report lists the drift you fixed.
