# Phase 2 — Reranking & Embedding Improvements

**Parent plan**: [`ai-improvement-overview.md`](ai-improvement-overview.md)
**Depends on**: Phase 1 (Gemini integration must be in place for HyDE)

---

## 1. Cross-Encoder Reranking

**Priority**: High
**Effort**: Low
**Impact**: High — significantly better relevance scoring than bi-encoder cosine similarity

**Current state**: Not implemented. Only bi-encoder (BGE-M3) embeddings with cosine similarity.

### What to build

- Add a cross-encoder model (e.g., `BAAI/bge-reranker-v2-m3`) as a reranking step
- After BGE-M3 returns top 20-30 candidates, pass (case_text, regulation_text) pairs through cross-encoder
- Cross-encoder scores each pair jointly (much more accurate than comparing independent embeddings)
- Re-rank candidates by cross-encoder score before passing to Gemini LLM judge

### Why it matters

Bi-encoders encode query and document independently — they can miss nuanced relationships. Cross-encoders process both texts together, capturing token-level interactions. For legal texts where a single keyword difference changes applicability, this is critical.

### Target pipeline position

```
BGE-M3 (top 30) → Cross-Encoder Reranker (top 15) → Gemini LLM Judge (final ranking)
```

### Files to modify

- `ai_service/app/core/` — new `reranker.py` module
- `ai_service/app/api/routes/find_related.py` — insert reranking step after BGE-M3 scoring
- `ai_service/requirements.txt` — may need `sentence-transformers` update

---

## 2. HyDE (Hypothetical Document Embeddings)

**Priority**: Medium
**Effort**: Low
**Impact**: Medium — improves recall for cases with unusual wording

**Current state**: Not implemented.

### What to build

- Before embedding the case text, send it to Gemini 3.1 Flash with a prompt: "What Saudi regulation would govern this case? Write a hypothetical regulation article."
- Embed the hypothetical regulation text instead of (or alongside) the raw case text
- Search for real regulations similar to the hypothetical one
- This bridges the vocabulary gap between how lawyers describe cases and how regulations are written

### Why it helps

A case might say "the employee was terminated without notice" but the regulation says "إنهاء عقد العمل" (termination of employment contract). HyDE generates the regulation-style text, making embedding search more effective.

### Files to modify

- `ai_service/app/api/routes/find_related.py` — add HyDE query generation before embedding
- Uses existing Gemini integration from Phase 1

---

## 3. Fine-Tuning BGE-M3 on Saudi Legal Data

**Priority**: High
**Effort**: Medium
**Impact**: High — domain-adapted embeddings for Saudi legal terminology

**Current state**: Not implemented. Uses pre-trained BGE-M3 out of the box.

### What to build

- Export verified links from the database as training pairs (case_text, regulation_text, relevant: yes/no)
- Fine-tune BGE-M3 using contrastive learning on this labeled data
- The model learns Saudi legal terminology, regulation structure, and domain-specific semantics
- Deploy fine-tuned model as a replacement for the base BGE-M3

### Prerequisites

Sufficient verified links in the database (ideally 500+ positive pairs). The tuning script (`tune-case-link-scoring.ts`) already loads this data — extend it to export training pairs.

### Steps

1. **Export training data**: Script to pull verified links and format as (anchor, positive, negative) triplets
2. **Negative sampling**: For each positive (case, regulation) pair, sample hard negatives — regulations that scored high by BGE-M3 but were rejected by lawyers
3. **Fine-tune**: Use `sentence-transformers` MultipleNegativesRankingLoss or similar
4. **Evaluate**: Compare retrieval metrics (recall@10, MRR) before and after fine-tuning
5. **Deploy**: Swap model weights in config, keep base model as fallback

### Files to modify

- New: `ai_service/scripts/export_training_data.py`
- New: `ai_service/scripts/fine_tune_bge.py`
- `ai_service/app/core/embeddings.py` — load fine-tuned model weights
- `ai_service/app/config.py` — model path configuration
