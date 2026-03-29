# Phase 1 — Gemini LLM Integration & Quick Wins

**Parent plan**: [`ai-improvement-overview.md`](ai-improvement-overview.md)

---

## 1. LLM Verification & Reranking with Gemini 3.1 Flash

**Priority**: Critical
**Effort**: Medium
**Impact**: High — eliminates false positives, adds legal reasoning

**Current state**: RAG with LLM is partially implemented — LLM is used in `regulation_insights.py` for generating regulation summaries and impact analysis, but NOT for verifying or reranking match results.

### What to build

- Add Gemini 3.1 Flash as a post-retrieval verification layer
- After BGE-M3 returns top 15-20 candidates, send them to Gemini with the case text
- Gemini determines:
  1. Is this regulation legally applicable to this case? (yes/no)
  2. Which specific articles are most relevant?
  3. Confidence level (high/medium/low)
  4. Brief Arabic explanation of why it applies
- Re-rank results based on LLM judgment
- Filter out false positives that BGE-M3 scored highly but are not actually relevant

### Why Gemini 3.1 Flash

- Strong Arabic language support (MSA — Modern Standard Arabic)
- Very fast inference for a reranker use case
- Cost-effective (~fractions of a cent per case)
- Good structured output (JSON) capabilities

### Architecture

```python
# After existing scoring pipeline returns top candidates...
async def verify_with_llm(case_text: str, candidates: list[ScoredRegulation]) -> list[VerifiedMatch]:
    prompt = f"""You are a Saudi legal expert. Given this case:
    {case_text}

    For each regulation below, determine:
    1. Is it legally applicable? (yes/no)
    2. Which specific articles are relevant?
    3. Confidence level (high/medium/low)
    4. Brief explanation in Arabic

    Regulations:
    {format_candidates(candidates)}"""

    response = await gemini_client.generate_content(...)
    # Filter out non-applicable, re-rank by LLM confidence
```

### LLM as Judge (combined)

This technique overlaps with a standalone "LLM as Judge" approach. We combine them into a single Gemini call that both:

- **Validates** each match (binary: applicable or not)
- **Reranks** by legal reasoning quality
- **Explains** why each regulation applies (value-add for lawyers)

### Files to modify

- `ai_service/app/api/routes/find_related.py` — add LLM verification step after scoring
- `ai_service/app/config.py` — add Gemini API key and config
- `ai_service/app/core/` — new `llm_verifier.py` module
- `ai_service/requirements.txt` — add `google-generativeai` package

---

## 2. Chunk Overlap / Sliding Window

**Priority**: Medium
**Effort**: Low
**Impact**: Medium — prevents losing context at chunk boundaries

**Current state**: Regulations are split into chunks, but chunks have no overlap. Context at chunk boundaries is lost.

### What to build

- When splitting regulation text into chunks, add 10-20% overlap between adjacent chunks
- Example: if chunks are 512 tokens, each chunk shares ~50-100 tokens with the next
- This ensures that articles or concepts spanning chunk boundaries are captured in at least one chunk

### Files to modify

- `ai_service/app/api/routes/find_related.py` — modify `_build_regulation_units()` to add overlap

---

## 3. Instruction-Tuned Embedding Queries

**Priority**: Low
**Effort**: Low
**Impact**: Low — minor improvement since BGE-M3 supports it but isn't using it

**Current state**: BGE-M3 supports task instructions but no instructions are passed during embedding.

### What to build

- Pass task-specific instructions when encoding queries: "Find the Saudi regulation that governs this legal dispute"
- BGE-M3 uses these instructions to produce more task-aware embeddings
- Separate instructions for Arabic and English queries

### Files to modify

- `ai_service/app/core/embeddings.py` — add instruction prefix to query encoding
