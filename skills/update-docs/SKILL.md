---
name: update-docs
description: Build, generate, update, and sync documentation for the Silah-Legal meta-monorepo. Use this skill whenever the user wants to: update docs, regenerate documentation, document features or architecture, document recent changes, review what's outdated, check whether code has drifted from the PRD, refresh service docs, or do a documentation pass across any or all of the 4 services (Legal-Case-Management-System backend, Legal_Case_Management_Website frontend, Legal-Case-Management-System-AI-Microservice, GP-flutter mobile app). Docs lead with features and architecture and are anchored to the product PRD (docs/PRD.md), flagging PRD-vs-code drift. The skill maintains /docs/ at the repo root as the single authoritative documentation source — a self-contained set (PRD + index + one file per service) that does NOT depend on the legacy /context/ folder.
---

# update-docs

Maintains `/docs/` at the Silah-Legal monorepo root as the single authoritative documentation source for all 4 services. It replaces the older `/context/` flat-file structure, which is **stale and slated for deletion** — do NOT read or depend on `/context/`. Each service gets one comprehensive file, and `docs/PRD.md` is the self-contained product source of truth. When invoked, read source code — don't paraphrase what README or context files say.

Silah (صلة) is an AI-powered legal case-management platform for Saudi legal practitioners (Arabic-first, bilingual, multi-tenant). All paths below are **relative to the monorepo root** (`Silah-Legal/`), not to this skill directory.

## Output Structure

Each service doc is named **after its repository directory** (not a generic alias like `backend.md`):

```
/docs/
├── PRD.md                                            # Product source of truth (self-contained, lives here)
├── architecture.md                                          # System architecture overview + links
├── Legal-Case-Management-System.md                   # backend (Node/Fastify API)
├── Legal_Case_Management_Website.md                  # website (Next.js dashboard)
├── Legal-Case-Management-System-AI-Microservice.md   # ai (Python/FastAPI)
└── GP-flutter.md                                     # mobile (Flutter app)
```

The crawler service **keys** (`backend`, `website`, `ai`, `mobile`) are CLI shorthands only; the **doc filenames are the repository names** above.

`docs/PRD.md` is the single product source of truth and lives inside `/docs/` (it was reconstructed from code and is intentionally self-contained, so nothing breaks when `/context/` is deleted). It is **maintained in place** — corrected and gap-tracked, not regenerated from scratch on every run (see below).

## The PRD Is the Product Source of Truth

`docs/PRD.md` defines *why* the product exists: the Arabic-first legal workspace, the case→regulation AI-suggestion + verification workflow, the regulation library/versioning/monitoring model, real-time UX, and the hard constraints (multi-tenancy, RBAC, bilingual RTL). It outranks every other doc on product intent. Its `§9 Implementation Status — Known Gaps` table is the canonical place for code-vs-intent divergence. Jobs:

1. **Ground features in it.** Every feature you document in a service doc should connect to the product requirement it serves. A feature with no PRD/context basis is worth a flag ("not in PRD — verify intent").
2. **Maintain the PRD when code and spec diverge — but mind the direction:**
   - **Factual drift** (a port, default, endpoint, type name that the PRD merely *describes*): code wins. Update the PRD text in place to match code, citing the file.
   - **Intent conflict** (code contradicts a product *requirement* or *constraint*): do **not** silently overwrite the requirement. Record it in the PRD's `§9 Implementation Status — Known Gaps` table so the requirement stays visible as the goal. Whether to change the requirement or fix the code is the user's call, not yours.

   Example of factual drift this repo actually has: the Flutter app defaults its API base to `http://localhost:3001` (`GP-flutter/gp/lib/core/constants/api_constants.dart:4`), but the backend runs on **3000** — 3001 is the website. That's a fact to correct/flag, not a product requirement.

## Agent Instruction Files (CLAUDE.md / AGENTS.md)

The repo has agent-facing instruction files — root `CLAUDE.md` and `AGENTS.md` (there are **no** nested per-service ones; everything funnels through the root). They are themselves a kind of documentation, and they overlap with what you're writing. Use them **only where they add something code and the PRD don't express** — don't copy them wholesale, and don't treat them as authoritative:

- **Useful to pull from:** run commands, service-boundary rules, multi-tenancy/RBAC discipline, the bilingual/RTL requirement, and hard-won gotchas. These are human knowledge that isn't in the code. Fold the relevant bits into a service's Architecture/Running sections.
- **Not authoritative on facts:** they drift. Root `CLAUDE.md` under-describes the backend (it lists ~7 route groups; the code registers **27+** in `Legal-Case-Management-System/src/app.ts`) and the AI service (it lists one endpoint; the code mounts 11 routers). Code wins; add their drift to the same drift log as the PRD's.
- **Do not rewrite them.** These are hand-maintained operator instructions, not generated docs. The skill reads them and *flags* their drift in its report; it does not overwrite `CLAUDE.md`/`AGENTS.md`.

If an agent file and the code agree and the file adds nothing new, skip it — "needed and useful" is the bar, not "exists."

## What These Docs Are For

The priority is **features and architecture** — what each service *does* for the product, and *how it's built* — not a route dump. A new engineer should read a service doc and understand the capabilities and the design before they ever see an endpoint table. Routes, env vars, and schema are reference material that *supports* that understanding; they come after it, not first.

Concretely, when you read the code, keep asking: *What capability does this serve? Why does it exist? How does data flow through it?* — not just *what's the function signature*. The backend's `/api/ai-links` + `/api/case-sources` + the AI service's `find_related` pipeline are not 30 endpoints; they're the **case→regulation AI-suggestion feature** with a verification workflow. The AI service's `ai_service/app/core/` modules (`agentic_retriever`, `colbert_retriever`, `hyde`, `reranker`, `llm_verifier`) are not files; they're the **RAG retrieval pipeline**. Document the feature, then list the endpoints under it.

## Per-Service Doc Template

Every service doc uses this structure. Lead with Overview → Features → Architecture; keep API/config reference below. Write "none" or "n/a" if a section is genuinely empty.

```markdown
# <Service Name>

> <One-line: what this service does AND what it cannot do.>

**Port:** <port>  **Stack:** <tech>  **Directory:** <dir>/

---

## Overview
2–4 sentences in plain language: the service's role in the product, the problem
it solves, and where it sits in the system. No jargon dump — the paragraph a new
engineer reads first.

## Features
The headline section. Each feature is what the service actually *does* — a
product capability or a meaningful internal capability — explained in prose, not
a table. For each: what it does, why it exists, and (briefly) how it works. Name
the feature the way the team talks about it.

### <Feature name, e.g. "Case → regulation AI suggestions">
What it does and why it matters. The mechanism in 2–4 sentences. Point at the
route group / router / worker / module that implements it, with `file:line`.
Note key tunables and their defaults.
- **Product basis:** the PRD/context requirement this serves, or "not in PRD —
  verify intent" if there's no basis.
- **Drift:** flag any divergence from the PRD/context (e.g. port mismatch, an
  endpoint the docs call "future" that is live). Omit the line if it matches.

### <Feature name>
…repeat for each real capability. Derive the list from route groups, AI routers,
Drizzle tables, workers, and Flutter feature modules — each cluster is usually
one feature.

## Architecture
How the service is built and how it fits the wider system.
- **Internal structure** — the key modules/layers and what each is responsible for
- **Key flows** — trace the important paths end to end (e.g. case create →
  AI find-related → suggestion stored → lawyer verifies). ASCII diagram welcome.
- **Design decisions** — the non-obvious choices and why
- **Integration** — who it calls and who calls it, and for what:
  **Calls / Called by / Shares DB with.**
- **Cannot** — the hard boundaries it must not cross (e.g. AI service is stateless,
  owns no DB; frontend never writes the DB directly)

## Tech Stack
| Layer | Technology |
|-------|-----------|

## Running
```bash
# Dev
<exact command>
# Worker / migrations (if any)
<exact command>
```

## Data Model (if DB-owning service)
Key tables/structs. Focus on fields the product surfaces or other services consume.

## API Reference
Supporting detail. Group endpoints under the feature they serve where it helps.

### Public / Authenticated
| Method | Path | Auth | Description |
|--------|------|------|-------------|

### Internal / service-to-service
| Method | Path | Auth | Description |
|--------|------|------|-------------|

## Configuration
| Variable | Required | Default | Purpose |
|----------|----------|---------|---------|

## Sources
Files this doc was generated from, so the next sync can verify:
- `src/routes/...`, `src/db/schema/...`, `.env.example`, ...
```

---

## How to Read Each Service

**Start with the crawler — don't hand-grep.** A bundled script does the deterministic part (enumerate routes, route prefixes, Drizzle tables, Pydantic schemas, Flutter features, env vars) for you, with `file:line` citations. Run it first, then read the cited files only where you need detail. This is faster, cheaper, and keeps every service doc consistent.

```bash
# From the monorepo root:
./skills/update-docs/scripts/inventory.sh backend   # one service
./skills/update-docs/scripts/inventory.sh all       # every service
./skills/update-docs/scripts/inventory.sh --list    # known service names
```

Service keys: `backend`, `website`, `ai`, `mobile`.

What the crawler prints, per service:

- **backend** — route prefixes from `src/app.ts` (group → URL prefix), `fastify.<verb>(` handler registrations with `file:line`, the list of route groups, Drizzle `pgTable` definitions in `src/db/schema/`, workers, and env vars (`.env.example` + `process.env.*` refs in code).
- **website** — App Router pages (`src/app/**/page.tsx` → URL, route-group folders like `(dashboard)` stripped to real paths), a check for API route handlers (expected: none — pure client), top-level `src/` dirs, and `NEXT_PUBLIC_*` env vars.
- **ai** — FastAPI `@router/@app` decorators with `file:line`, `include_router` mounts in `main.py`, Pydantic schemas in `ai_service/app/api/schemas/`, the `ai_service/app/core/` RAG modules, and env vars.
- **mobile** — feature modules (`gp/lib/features/*`), GoRouter `path:` entries in `gp/lib/app/routes.dart`, the `gp/lib/core/*` layers, and the backend/AI base-URL wiring.

Read the cited source files when you need request/response shapes or field-level notes the inventory doesn't capture.

If the crawler ever returns "(none found)" for a service that clearly has routes, the layout moved — fall back to the source paths below and **update `inventory.sh`** so the next run works.

### Verified source layouts (fallback + where to read detail)

| Service | Routes | Models / Schemas | Env |
|---------|--------|------------------|-----|
| **backend** (`Legal-Case-Management-System/`) | handlers in `src/routes/<group>/index.ts` (`fastify.<verb>(`); URL prefixes in `src/app.ts` (`app.register(xRoutes, { prefix })`) | Drizzle tables in `src/db/schema/*.ts` (`pgTable`) | `.env.example` |
| **website** (`Legal_Case_Management_Website/`) | App Router pages `src/app/**/page.tsx`; no API routes (pure client of the backend) | — (UI; types in `src/lib`) | `.env.example` (`NEXT_PUBLIC_*`) |
| **ai** (`Legal-Case-Management-System-AI-Microservice/`) | `ai_service/app/api/routes/*.py` (`@router.<verb>`); mounts in `ai_service/app/main.py` | `ai_service/app/api/schemas/*.py` (Pydantic); settings in `ai_service/app/config.py` | `.env.example` |
| **mobile** (`GP-flutter/`) | GoRouter in `gp/lib/app/routes.dart`; features in `gp/lib/features/*` | Dart models per feature | `gp/lib/core/constants/api_constants.dart` (compile-time `String.fromEnvironment`) |

### Cite your sources

Every service doc ends with a `## Sources` footer listing the files the inventory drew from. When a fact is non-obvious or likely to drift (a default value, a port, a hard-coded threshold), inline the `file:line` next to it. This lets the next person — or the next sync — trace any claim back to code in seconds, and makes review mode (below) far faster.

---

## Workflows

### Full sync (all services)

1. Check if `/docs/` has the per-service files. If not, this is a migration run — say so (see Migration below). `/docs/` currently holds only `QANONIAH_FEATURE_CASE_STUDY.md`, so the first real run is a migration.
2. **Read `docs/PRD.md` first.** It frames the product intent every feature doc connects back to. Keep it open as you write. (Do not read `/context/` — it is stale and being removed.)
3. Run `./skills/update-docs/scripts/inventory.sh all` once up front to get the full code inventory.
4. For each of the 4 services, in this order: backend → website → ai → mobile:
   - Use that service's inventory section; read the cited source files where you need request/response detail or field notes
   - Pull run commands, boundary rules, and gotchas from root `CLAUDE.md`/`AGENTS.md` only where code doesn't express them, and only fold in what's genuinely useful
   - Write or update `/docs/<RepositoryName>.md` (the file named after the service's repo dir) using the template — Features cite their PRD/context basis and flag drift; end with a `## Sources` footer
5. Maintain `docs/PRD.md` in place: correct factual drift you found in step 4 (update the text, cite the file), and record any intent conflicts in its `§9 Implementation Status — Known Gaps` table. Do not regenerate it from scratch; do not overwrite product requirements.
6. Regenerate `/docs/architecture.md` last (it references all other files).
7. Report: list each file written, a one-line summary of what changed, and **call out every drift you found — PRD↔code first, then CLAUDE.md/AGENTS.md↔code.** That's the product-critical finding. Do not edit the agent files; just report their drift.

### Targeted update (one or few services)

Same as full sync but only for the named service(s). Read the relevant PRD/context section to ground that service's features. If you found PRD drift, maintain the PRD in place (factual fixes inline; intent conflicts into its gap section), and update `architecture.md` at the end.

### Review mode ("what's outdated?")

Review mode is **read-only**. The user wants to see drift before committing to a rewrite — so the deliverable is a gap report and a decision, not new docs. Do not write or overwrite any doc in this mode.

1. Run the crawler for the relevant service(s) to get the current code inventory
2. Read both the current `/docs/<RepositoryName>.md` AND the cited source files
3. Produce a gap table — cite the source `file:line` for each drift so the user can verify without re-reading:

| Service | Section | Status | Source evidence |
|---------|---------|--------|-----------------|
| backend | Route groups | **outdated** | CLAUDE.md lists ~7; `src/app.ts:133-162` registers 27+ |
| mobile | API base URL | **outdated** | defaults to `:3001`; backend is `:3000` (`api_constants.dart:4`) |
| ai | Endpoints | **outdated** | docs say 1 endpoint; `main.py:50-60` mounts 11 routers |

4. **Stop and ask which gaps to fix before writing anything.** End with an explicit question — e.g. "Want me to fix all the route drift, just the backend doc, or the whole set?" The user may only care about a subset. Wait for their answer, then switch to targeted-update mode for the agreed scope.

### First-run generation (clean slate)

The initial `/docs/` set (PRD + index + 4 service files) was already generated from source. `/context/` is stale and being deleted, so a regeneration is **code-first**, not a context migration:
1. Run the crawler (`inventory.sh all`) and read the cited source files.
2. Read source code for each service. Source code wins on facts; `docs/PRD.md` carries product intent — flag drift between them.
3. Write/refresh the per-service `/docs/` files and `architecture.md`; maintain `docs/PRD.md` in place.
4. Do NOT reintroduce a dependency on `/context/`. The `/docs/` set must stand alone.

---

## Source of Truth Priority

- **Facts** (routes, ports, defaults, schema): **source code wins** over README, context files, and the PRD. Document what the code does; cite the file.
- **Product intent** (what a feature is *for*, success metrics, hard constraints): **the PRD (`docs/PRD.md`) wins.** Code shows what is; the PRD shows what should be.
- When the two disagree, that's drift — **document both and flag it.** Don't silently pick one; the gap is the finding. If something is genuinely ambiguous, note the file path rather than guessing.

---

## Maintaining the PRD

`docs/PRD.md` is the product source of truth — maintained in place. The skill does **not** regenerate it from scratch on a normal sync. When syncing, the only edits you make to it are:

- **Factual corrections** where the PRD merely *describes* something the code defines (a port, a default, an endpoint name). Update the prose to match code, cite the file.
- **Gap tracking** in its `§9 Implementation Status — Known Gaps` table when code contradicts a product *requirement*. Record it; never overwrite the requirement to match code.

If asked to do larger PRD edits (rewriting requirements, adding features), that's a product authoring task driven by the user, not an automated sync — make exactly the change requested and nothing more.

---

## architecture.md Template

`architecture.md` is the **system architecture document** — the big picture that no single service doc covers. It explains what the product is, how the major flows cross services, and links out to the per-service detail. Treat the cross-service flows as the main content, not the table.

Verify the facts (ports, model, endpoints) against code every sync — these drift.

```markdown
# Silah-Legal — Architecture & Documentation Index

> Single-source docs for all 4 services. Auto-maintained by `/update-docs`.

## What Silah Is
2–3 sentences: AI-powered, Arabic-first legal case-management platform for Saudi
legal practitioners. Web dashboard + mobile app over a Fastify API, with a Python
RAG microservice that links cases to Saudi regulations. Multi-tenant, bilingual,
real-time.

## System Architecture
Prose + diagram of how the services compose. Cover the major flows end to end:

- **Case → regulation suggestion** — frontend/mobile create a case → backend
  (`/api/ai-links`, `/api/cases`) calls the AI service `find-related` → AI runs the
  RAG pipeline (embed → retrieve → rerank → verify) → suggestions stored → lawyer
  verifies in the UI.
- **Auth flow** — backend issues JWTs (RBAC roles) → website + mobile attach
  `Authorization: Bearer`.
- **Real-time** — backend Socket.IO pushes notifications → website + mobile clients.

```
GP-flutter ───────────────→ backend (REST, :3000)
Legal_Case_Management_Website → backend (REST, :3000) + Socket.IO
backend ──────────────────→ AI microservice (:8000, find-related / extract / insights)
backend ──────────────────→ PostgreSQL (Drizzle ORM; owns the schema)
website/mobile ───────────→ AI microservice (only via backend; not direct)
```

## Services
| Service | Role (one line) | Stack | Port |
|---------|-----------------|-------|------|
| [Legal-Case-Management-System](Legal-Case-Management-System.md) | REST API, auth/RBAC, cases/clients/regulations, Socket.IO, owns DB | Node.js / Fastify / Drizzle / PostgreSQL | 3000 |
| [Legal_Case_Management_Website](Legal_Case_Management_Website.md) | Web dashboard for lawyers/admins | Next.js 16 / React 19 / shadcn | 3001 |
| [Legal-Case-Management-System-AI-Microservice](Legal-Case-Management-System-AI-Microservice.md) | RAG pipeline: case↔regulation matching, extraction, insights | Python / FastAPI / BGE-M3 | 8000 |
| [GP-flutter](GP-flutter.md) | Mobile + client-portal app | Flutter / Dart | — |

## Shared Data Model (verify each sync)
- PostgreSQL, owned by the backend via Drizzle (`Legal-Case-Management-System/src/db/schema/*.ts`)
- Multi-tenant: nearly every table carries an organization scope
- Embeddings: BGE-M3 multilingual (Arabic/English) — verify model in AI `.env.example` / `ai_service/app/config.py`
- Case types: Criminal, Civil, Commercial, Labor, Family, Administrative
- Roles: Admin, Senior Lawyer, Lawyer, Paralegal, Clerk
```
