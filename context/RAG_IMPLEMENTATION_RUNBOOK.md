# RAG Implementation Runbook (Silah-Legal)

This document summarizes the current Retrieval-Augmented Generation (RAG) implementation for document insights, how to run it, expected behavior, and common troubleshooting.

## 1) What Was Implemented

## Scope
- OCR/text extraction is the input to RAG.
- Vector store is PostgreSQL + pgvector.
- Primary storage table is `document_chunks`.
- Insights remain backward-compatible for frontend.

## Backend Changes (`Legal-Case-Management-System`)
- Added pgvector migration:
  - `src/db/migrations/0012_document_chunks_pgvector.sql`
  - `CREATE EXTENSION IF NOT EXISTS vector;`
  - `document_chunks` table with:
    - `id`
    - `organization_id`
    - `document_id`
    - `chunk_index`
    - `content`
    - `content_lang`
    - `token_count`
    - `embedding vector(1024)`
    - `metadata jsonb`
    - `created_at`, `updated_at`
  - Indexes:
    - unique `(document_id, chunk_index)`
    - org/document lookup index
    - HNSW cosine index on `embedding`
- Added insights RAG metadata migration:
  - `src/db/migrations/0013_document_insights_rag_metadata.sql`
  - Adds:
    - `insights_citations_json`
    - `insights_retrieval_meta_json`
- Added RAG services:
  - `src/services/document-chunk.service.ts`
  - `src/services/document-rag.service.ts`
- Wired ingestion + retrieval into extraction/insights flow:
  - `src/services/document-extraction.service.ts`
  - `src/services/ai-client.service.ts`

## AI Service Changes (`Legal-Case-Management-System-AI-Microservice`)
- Embedding provider wiring hardened in:
  - `ai_service/app/config.py`
- Real BGE embeddings support in:
  - `ai_service/app/core/embeddings.py`
- Runtime import compatibility helper:
  - `ai_service/app/__init__.py`

## API Compatibility Guarantee
- Existing document insights endpoints are unchanged:
  - `GET /api/documents/:docId/insights`
  - `POST /api/documents/:docId/insights/refresh`
- Existing required response fields are preserved:
  - `summary`
  - `highlights`
- Optional RAG fields may appear:
  - `citations`
  - `retrievalMeta`

## 2) Runtime Flow

1. User uploads a document.
2. Backend extraction queue processes OCR/parser extraction.
3. Extracted text is chunked and embedded.
4. Chunks are stored in `document_chunks` (organization-scoped).
5. Insights generation retrieves top-k relevant chunks by vector similarity.
6. AI insights are generated with retrieved context.
7. Insights response returns:
   - required: `summary`, `highlights`
   - optional: `citations`, `retrievalMeta`

## 3) How To Run (PowerShell)

Run these in your active local clone root (for example `C:\Users\...\Silah-Legal`).

## Backend API
```powershell
cd ".\Legal-Case-Management-System"
npm run db:migrate
npm run dev
```

## Backend Worker (separate terminal)
```powershell
cd ".\Legal-Case-Management-System"
npm run worker:reg-monitor
```

## AI Service (separate terminal)
```powershell
cd ".\Legal-Case-Management-System-AI-Microservice"
.\.venv\Scripts\python.exe -m uvicorn ai_service.app.main:app --host 127.0.0.1 --port 8000
```

## Required env values

## Backend `.env`
```env
AI_SERVICE_URL=http://localhost:8000
```

## AI `.env`
```env
EMBEDDINGS_PROVIDER=bge
EMBEDDING_MODEL_NAME=BAAI/bge-m3
EMBEDDING_DEVICE=cpu
```

## 4) Quick Verification

## Health checks
```powershell
Invoke-WebRequest http://localhost:3001/health | Select-Object -Expand Content
Invoke-WebRequest http://localhost:8000/health/ | Select-Object -Expand Content
```

## Embedding dimension check (must be 1024)
```powershell
Invoke-RestMethod -Method Post `
  -Uri http://localhost:8000/embed/ `
  -ContentType "application/json" `
  -Body '{"texts":["test"],"normalize":true}'
```

Expected: `dimension` is `1024`.

## Functional check via UI
1. Open app UI.
2. Go to `Cases` -> open a case -> `Documents`.
3. Upload a `.txt` file (recommended first test), `.pdf`, or `.docx`.
4. Open document insights.
5. Confirm `summary` and `highlights` are present.
6. If available, verify optional `citations` and `retrievalMeta`.
cd "C:\Users\Omar's ZenBook\Desktop\Silah-Legal\Legal_Case_Management_Website"
$env:NEXT_PUBLIC_API_URL="http://localhost:3001"
$env:NEXT_PUBLIC_WS_URL="http://localhost:3001"
npx next dev -p 3000

## 5) Observed Effects

- Insights are now grounded using retrieved document chunks (RAG).
- First AI embed call can be slower due to model warm-up.
- `insights/refresh` may return `pending` before it becomes `ready`.
- Existing frontend contract is preserved (`summary`, `highlights` remain stable).

## 6) Troubleshooting

## `ModuleNotFoundError: No module named 'app'` (AI service)
- Run from the AI service repo root.
- Use:
```powershell
python -m uvicorn ai_service.app.main:app --host 127.0.0.1 --port 8000
```

## `/embed/` returns dimension `4`
- You are on fake embeddings.
- Ensure AI `.env` has:
  - `EMBEDDINGS_PROVIDER=bge`
  - `EMBEDDING_MODEL_NAME=BAAI/bge-m3`
- Restart AI service.

## Document extraction becomes `file_missing`
- Usually worker started from wrong working directory.
- Restart worker from `Legal-Case-Management-System` root:
```powershell
npm run worker:reg-monitor
```

## Port conflict between backend and frontend
- Backend uses `3001` in this setup.
- Run frontend on a different port (commonly `3000`).

## 7) Current Limits / Next Steps

- Hybrid lexical ranking (BM25) is not implemented yet.
- Retrieval currently uses pgvector cosine similarity and document/org scoping.
- Future improvements can add hybrid retrieval, reranking, and richer citations.
