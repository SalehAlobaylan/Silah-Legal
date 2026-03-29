# AI Accuracy Improvement — Overview & Roadmap

## Current Architecture

**Embedding Model**: BAAI/bge-m3 (multilingual, runs locally)
**LLM Layer**: Gemini 3.1 Flash (planned — external API)

### Current Pipeline

```
Case Text + Documents
        │
        ▼
  BGE-M3 Embeddings (Stage 1 — fast retrieval)
        │
        ▼
  Composite Scoring (4 weighted signals):
    ├── Semantic similarity   (55%) — cosine similarity between embeddings
    ├── Support coverage      (20%) — % of case fragments with matches
    ├── Lexical overlap       (15%) — Jaccard token overlap
    └── Category prior        (10%) — case type → regulation category boost
        │
        ▼
  Threshold Filtering (min score: 0.45, min pair score: 0.40)
        │
        ▼
  Ranked Results → Frontend
```

### Target Pipeline

```
Case Text + Documents
        │
        ▼
  BGE-M3 Embeddings (Stage 1 — fast candidate retrieval)
        │
        ▼
  Composite Scoring → Top 20-30 candidates
        │
        ▼
  Cross-Encoder Reranker → Top 15 candidates
        │
        ▼
  Gemini 3.1 Flash (Stage 2 — LLM verification & reranking)
        │
        ▼
  Verified, explained, and re-ranked results → Frontend
```

---

## Key Decision: BGE-M3 + Gemini 3.1 Flash

We keep BGE-M3 as the first-stage retriever because:

- It runs locally (free, fast, no API dependency)
- It's multilingual (Arabic/English) out of the box
- It's good enough for candidate retrieval — the LLM handles precision

We add Gemini 3.1 Flash as the second-stage verifier because:

- Strong Arabic language understanding (MSA)
- Fast inference suitable for a reranker role
- Cost-effective for processing 15-20 candidates per case
- Good structured JSON output for integration

The two models complement each other: BGE-M3 handles **recall** (finding all possible matches quickly), Gemini handles **precision** (filtering to only truly relevant matches with legal reasoning).

---

## Implementation Roadmap

**Execution harness**: [`ai-improvement-execution-harness.md`](ai-improvement-execution-harness.md)

### Phase 1 — Gemini LLM Integration & Quick Wins
**Plan**: [`ai-improvement-phase1-gemini-quickwins.md`](ai-improvement-phase1-gemini-quickwins.md)

| Technique | Effort | Impact |
|-----------|--------|--------|
| Gemini 3.1 Flash LLM verification + reranking + judge | Medium | Critical |
| Chunk overlap / sliding window | Low | Medium |
| Instruction-tuned embedding queries | Low | Low |

### Phase 2 — Reranking & Embedding Improvements
**Plan**: [`ai-improvement-phase2-reranking-embeddings.md`](ai-improvement-phase2-reranking-embeddings.md)

| Technique | Effort | Impact |
|-----------|--------|--------|
| Cross-encoder reranking (BGE-reranker-v2-m3) | Low | High |
| HyDE (Hypothetical Document Embeddings) | Low | Medium |
| Fine-tune BGE-M3 on Saudi legal data | Medium | High |

### Phase 3 — Advanced Retrieval Architecture
**Plan**: [`ai-improvement-phase3-advanced-retrieval.md`](ai-improvement-phase3-advanced-retrieval.md)

| Technique | Effort | Impact |
|-----------|--------|--------|
| Late interaction / ColBERT-style retrieval | High | High |
| Agentic retrieval with Gemini | Medium | Medium |
| Legal knowledge graph | High | Medium |
