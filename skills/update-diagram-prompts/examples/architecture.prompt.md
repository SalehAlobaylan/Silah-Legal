# Worked example — catalog prompt #1 (Overall System Architecture)

This is a **complete, self-contained prompt** filled in from `check-diagram-facts.sh`
output. It is the proof that the catalog + harness produce a real diagram:

```
prompt (this file) → feed to a diagram LLM → architecture.mmd → mermaid-cli → architecture.svg/png
```

`architecture.mmd` is one valid rendering of this prompt; `architecture.png` is it
rendered (see "Render" below). Every node and edge traces to a code fact.

---

## The prompt

You are a technical diagram designer. Create an **overall system architecture diagram** for the current Silah platform.

Use the repository code and structure as the source of truth. Draw the **4 active services**. The backend is the **only writer of the database**; the web and mobile clients **never call the AI service directly** — only the backend does.

### Product Context
Silah is an Arabic-first, multi-tenant legal case-management platform for Saudi practitioners. Lawyers manage cases/clients/regulations via a web dashboard and a mobile app; a stateless AI microservice links each case to the regulations that govern it (with verifiable evidence) and powers a legal assistant. This diagram explains how the pieces compose and where the trust boundaries are.

### Code-Backed Components
- **Legal-Case-Management-System** — backend REST API. Node.js · Fastify 5 · :3000. Owns PostgreSQL (Drizzle, 51 tables), issues JWTs, runs Socket.IO (`src/plugins/websocket.ts:65`) and 4 workers, calls the AI service. *Must not* run ML models.
- **Legal_Case_Management_Website** — Next.js 16 · :3001. Pure client of the backend. *Must not* touch the DB or call the AI service directly.
- **Legal-Case-Management-System-AI-Microservice** — FastAPI · :8000. **Stateless** (owns no DB). 11 routers; 7-stage find-related pipeline. Called only by the backend. *Must not* persist anything.
- **GP-flutter** — Flutter mobile client. Same boundary as the website.
- **Infrastructure (backend-owned):** PostgreSQL (51 org-scoped tables), Redis (worker queues), S3/MinIO (documents).
- **External APIs:** Gemini (verification/assistant) + Hugging Face (BGE-M3 embeddings) + ALAPI (OCR) — all called by the AI service; Google OAuth — called by the backend.

### Key Data Flows
1. Website → backend: REST + Socket.IO (JWT bearer)
2. GP-flutter → backend: REST + Socket.IO (JWT bearer)
3. backend → AI service: `POST /similarity/find-related` and other routers (internal call, dashed)
4. backend → PostgreSQL: Drizzle (sole writer)
5. backend → Redis / S3-MinIO / Google OAuth
6. AI service → Gemini / Hugging Face / ALAPI (dashed, on-demand)

### Boundary Rules
- Backend is the only DB writer.
- AI service is stateless and reachable only via the backend.
- `client`-role users are confined to the client portal (not shown here; see prompt #2).

### Visual Requirements
- Group: Clients / Application / Infrastructure / External APIs.
- Solid arrows = user-JWT traffic; dashed = internal/on-demand service calls.
- Render the AI service with a dashed border to signal "stateless."
- Cylinders for DB/queue/storage.

Generate a complete current-state architecture diagram.

---

## Render

```bash
# from this examples/ dir (needs node/npx; downloads mermaid-cli + chromium once):
npx -y @mermaid-js/mermaid-cli -i architecture.mmd -o architecture.svg     # vector
npx -y @mermaid-js/mermaid-cli -i architecture.mmd -o architecture.png -s 2 # raster
```

Verified working: `architecture.svg` (28 KB) and `architecture.png` were generated
and visually confirmed during skill authoring.
