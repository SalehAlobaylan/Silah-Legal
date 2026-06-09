# Legal-Case-Management-System-AI-Microservice (AI Microservice)

> A stateless Python/FastAPI service that does all the heavy AI work for Silah: embeddings, the case→regulation retrieval pipeline, the legal chat assistant, document/regulation extraction, OCR, and admin intelligence. It owns no database — every request carries the case/regulation/document data it needs, and only the backend ever calls it.

**Port:** 8000  **Stack:** Python 3.12+ · FastAPI · BGE-M3 (BAAI/bge-m3) · optional Gemini LLM  **Directory:** `Legal-Case-Management-System-AI-Microservice/` (app under `ai_service/app/`)

---

## Overview

The backend delegates anything model-shaped to this service. It exposes 11 routers (`ai_service/app/main.py:50-60`) covering embeddings, similarity, the full `find-related` pipeline, extraction (regulations & documents incl. OCR), insights (documents, regulations, admin), and a chat assistant. It is deliberately **stateless and DB-free**: the backend passes candidate regulations, case text, and document chunks in the request body; the service returns scored/structured results. Error responses use the same envelope shape as the Node backend (`register_exception_handlers`, `main.py:38`).

## Features

### Embeddings
`POST /embed/` returns dense embeddings for input text. The provider is pluggable (`EMBEDDINGS_PROVIDER`): `fake` (deterministic, for tests — the **default**), `bge` (local BAAI/bge-m3), or Hugging Face serverless/endpoint, tried in `HF_EMBED_PROVIDER_ORDER`. Multilingual (Arabic/English) by model choice.
- **Product basis:** PRD §4.2 (semantic retrieval foundation).
- **Drift:** default provider is `"fake"` (`config.py:32`); real retrieval needs `EMBEDDINGS_PROVIDER=bge` or an HF token. See PRD §9.

### Case → regulation find-related (the headline pipeline)
`POST /similarity/find-related` (`api/routes/find_related.py:455`) is the endpoint the backend calls to rank regulations for a case. Documented pipeline stages (`find_related.py:1-16`):

1. **HyDE query expansion** — optional (`hyde.py`), when enabled + opted-in per request
2. **Embedding & unit build** — always
3. **Composite scoring** — always (semantic + lexical + category + support signals)
4. **Agentic retrieval expansion** — optional (`agentic_retriever.py`)
5. **ColBERT late-interaction** — optional (`colbert_retriever.py`)
6. **Cross-encoder reranking** — optional (`reranker.py`)
7. **LLM verification** — optional, via Gemini (`llm_verifier.py`, when `GEMINI_ENABLED`)

Each stage is gated by both a service-level toggle and a per-request opt-in, so the backend controls cost/latency per call. Results carry score breakdowns, matched evidence, and verification details (`schemas/responses.py`). A multi-source variant exists at `find_related_multi_source.py`.
- **Product basis:** PRD §4.2, §7.

### Legal assistant
`api/routes/assistant.py`: `POST /chat`, `POST /chat/stream` (streaming), `POST /analyze-case`, `POST /summarize-document`. Grounded in org context (case summaries, regulation chunks, document chunks) passed by the backend; returns answers with citations (`chat_engine.py`).
- **Product basis:** PRD §4.3.

### Extraction & OCR
`POST /regulations/extract` and `POST /documents/extract` (`extraction.py`) pull structured content from regulation/document text. OCR for scanned/Arabic documents is configurable (`OCR_*`, `ALAPI_*` for the ALAPI OCR provider; primary/secondary provider + strict mode), under `app/core/ocr/`.
- **Product basis:** PRD §4.4.

### Insights (document / regulation / admin)
- `POST /documents/case-insights` — highlights from documents relevant to a case.
- `POST /regulations/...` (regulation insights & amendment-impact analysis).
- `POST /admin/case-risk-profile`, `POST /admin/org-intelligence-summary`, `POST /admin/review-prioritization` (`admin_insights.py`) — org-level intelligence for administrators.
- **Product basis:** PRD §4.5, §4.6.

## Architecture

- **Internal structure:** `ai_service/app/main.py` (FastAPI app, CORS, router mounts), `app/config.py` (Pydantic `BaseSettings`), `app/api/routes/*.py` (endpoints), `app/api/schemas/{requests,responses}.py` (Pydantic contracts), `app/api/deps.py` (DI, e.g. `get_embedding_service`), `app/core/*` (the engine), `app/errors/*` (canonical error envelope), `app/utils/`.
- **Core engine (`app/core/`):** `embeddings.py`, `similarity.py`, `agentic_retriever.py`, `colbert_retriever.py`, `hyde.py`, `reranker.py`, `llm_verifier.py`, `llm_json.py`, `chat_engine.py`, `extraction.py`, `models.py`, `ocr/`.
- **Key flow (find-related):** request → embed case + candidates → composite score → optional expansions/rerank → optional LLM verify → ranked `RelatedRegulation[]` with evidence.
- **Determinism:** `random.seed(42)` at startup (`main.py:22`) for reproducible scoring/tests.
- **Integration — Called by:** the backend only (`AI_SERVICE_URL`). **Calls:** optionally Hugging Face inference, Gemini, ALAPI OCR. **Owns:** no database — fully stateless.
- **Cannot:** persist anything, talk to the DB, or be called directly by web/mobile clients.

## Tech Stack
| Layer | Technology |
|-------|-----------|
| Framework | FastAPI (Python 3.12+) |
| Settings | `pydantic-settings` `BaseSettings` |
| Embeddings | BAAI/bge-m3 (local) or HF serverless/endpoint; `fake` for tests |
| Rerank/retrieval | cross-encoder reranker, ColBERT, agentic expansion, HyDE |
| LLM | Google Gemini (optional, for verification & assistant) |
| OCR | ALAPI provider + configurable fallback |

## Running
```bash
cd Legal-Case-Management-System-AI-Microservice
python -m venv .venv && source .venv/bin/activate
pip install -r requirements.txt
cp .env.example .env            # set EMBEDDINGS_PROVIDER=bge for real embeddings; GEMINI_* to enable LLM
cd ai_service
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```
OpenAPI docs at `http://localhost:8000/docs`. Health: `GET /` and `GET /embeddings` (under the health router).

## API Reference

Routers mounted in `main.py:50-60` (no global prefix; paths are as declared on each router):

| Method | Path | Router | Purpose |
|--------|------|--------|---------|
| GET | `/` | health/root | service + version |
| GET | `/embeddings` | health | embedding-backend health |
| POST | `/embed/` | embeddings | embed text |
| POST | `/similarity/` | similarity | pairwise similarity |
| POST | `/similarity/find-related` | find_related | **rank regulations for a case** |
| POST | (multi-source) | find_related_multi_source | multi-source variant |
| POST | `/regulations/extract` | regulation_extract | structure a regulation |
| POST | `/documents/extract` | document_extract | extract document text (+OCR) |
| POST | `/documents/case-insights` | document_insights | doc highlights for a case |
| POST | (regulation insights / amendment impact) | regulation_insights | regulation analysis |
| POST | `/chat`, `/chat/stream` | assistant | legal chat (+ streaming) |
| POST | `/analyze-case`, `/summarize-document` | assistant | case analysis, doc summary |
| POST | `/admin/case-risk-profile` | admin_insights | case risk |
| POST | `/admin/org-intelligence-summary` | admin_insights | org summary |
| POST | `/admin/review-prioritization` | admin_insights | review queue ranking |

Request/response shapes: `ai_service/app/api/schemas/requests.py` and `responses.py`.

## Configuration

Env in `.env.example` (`config.py`). Key vars:

| Variable | Default | Purpose |
|----------|---------|---------|
| `EMBEDDINGS_PROVIDER` | `fake` | `fake` / `bge` / HF |
| `EMBEDDING_MODEL_NAME` | `BAAI/bge-m3` | embedding model |
| `EMBEDDING_DEVICE` | `cpu` | `cpu` / `cuda` |
| `HF_EMBED_PROVIDER_ORDER` | `serverless,endpoint,bge` | fallback order |
| `HF_SERVERLESS_*`, `HF_ENDPOINT_*` | — | HF inference creds |
| `GEMINI_ENABLED`, `GEMINI_API_KEY`, `GEMINI_MODEL` | — | LLM verification/assistant |
| `OCR_PRIMARY_PROVIDER`, `OCR_*`, `ALAPI_*` | — | OCR |
| `HOST`, `PORT` (8000), `CORS_ORIGINS` | — | server/CORS |
| `INSIGHTS_*`, `EXTRACTION_*`, `SOURCE_WHITELIST_DOMAINS` | — | tuning |

## Sources
- `ai_service/app/main.py` (routers, CORS, seed), `ai_service/app/config.py` (settings/model defaults)
- `ai_service/app/api/routes/*.py` (endpoints), `ai_service/app/api/schemas/{requests,responses}.py`
- `ai_service/app/core/*` (RAG engine), `.env.example`
