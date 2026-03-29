# Phase 3 — Advanced Retrieval Architecture

**Parent plan**: [`ai-improvement-overview.md`](ai-improvement-overview.md)
**Depends on**: Phase 1 (Gemini integration), Phase 2 (reranking pipeline)

---

## 1. Late Interaction (ColBERT-style)

**Priority**: Medium
**Effort**: High
**Impact**: High — much better for long legal texts

**Current state**: Not implemented. Uses standard pooled embeddings.

### What to build

- Instead of compressing each text into a single vector, keep per-token embeddings
- Use MaxSim matching: for each query token, find its maximum similarity to any document token
- Sum these MaxSim scores for the final relevance score
- This captures fine-grained token-level matches that pooled embeddings miss

### Why it matters for legal text

A regulation may have 50 articles, but only article 74 is relevant. Pooled embeddings average over all articles, diluting the signal. ColBERT's per-token approach catches the specific matching article.

### Consideration

This is a significant architectural change. Consider using an existing library like `RAGatouille` or `pylate` for ColBERT integration rather than building from scratch.

### Files to modify

- `ai_service/app/core/` — new `colbert_retriever.py` module
- `ai_service/app/api/routes/find_related.py` — alternative retrieval path
- `ai_service/requirements.txt` — add `ragatouille` or `colbert-ai`

---

## 2. Agentic Retrieval

**Priority**: Low
**Effort**: Medium
**Impact**: Medium — iterative search for complex cases

**Current state**: Not implemented. Single-pass retrieval only.

### What to build

- For complex cases, let Gemini 3.1 Flash iteratively refine the search
- Step 1: Initial retrieval with BGE-M3
- Step 2: LLM reviews results, identifies gaps, generates new queries
- Step 3: Additional retrieval rounds with refined queries
- Step 4: LLM consolidates all results into final ranking

### Use case

Complex cases that touch multiple legal domains (e.g., a labor dispute with criminal elements) where a single query misses relevant regulations from secondary domains.

### Architecture

```
Case Text → BGE-M3 → Initial Results
                          │
                          ▼
                  Gemini reviews results
                  "Are there gaps? Which legal domains are missing?"
                          │
                          ▼
                  Generate refined queries
                  "Search for regulations about X, Y"
                          │
                          ▼
                  BGE-M3 → Additional Results
                          │
                          ▼
                  Gemini consolidates all results → Final Ranking
```

### Files to modify

- New: `ai_service/app/core/agentic_retriever.py`
- `ai_service/app/api/routes/find_related.py` — optional agentic mode flag

---

## 3. Legal Knowledge Graph

**Priority**: Low-Medium
**Effort**: High
**Impact**: Medium — improves recall through regulation relationships

**Current state**: Not implemented. No relationship mapping between regulations.

### What to build

- Map cross-references between Saudi regulations (e.g., نظام العمل Article 74 references Article 80)
- When one regulation matches a case, boost its referenced regulations in the ranking
- Can be built incrementally:
  1. Start with explicit cross-references extracted from regulation text (regex + LLM)
  2. Expand with LLM-identified semantic relationships
  3. Add lawyer-curated relationships over time

### Data model

```sql
CREATE TABLE regulation_relationships (
  id SERIAL PRIMARY KEY,
  source_regulation_id INTEGER REFERENCES regulations(id),
  target_regulation_id INTEGER REFERENCES regulations(id),
  relationship_type VARCHAR(50),  -- 'references', 'amends', 'supersedes', 'related'
  source_article VARCHAR(50),     -- e.g., 'Article 74'
  target_article VARCHAR(50),     -- e.g., 'Article 80'
  confidence FLOAT,               -- extraction confidence
  created_at TIMESTAMP DEFAULT NOW()
);
```

### Files to modify

- New database table: `regulation_relationships` (Drizzle schema in backend)
- `ai_service/app/api/routes/find_related.py` — boost related regulations in scoring
- New: `ai_service/scripts/extract_regulation_relationships.py` — LLM-powered extraction script
