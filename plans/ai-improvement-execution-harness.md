# AI Improvement Execution Harness

**Inputs**:
- `plans/ai-improvement-overview.md`
- `plans/ai-improvement-phase1-gemini-quickwins.md`
- `plans/ai-improvement-phase2-reranking-embeddings.md`
- `plans/ai-improvement-phase3-advanced-retrieval.md`

## Purpose

Turn the strategy docs into one implementation sequence that matches the current AI microservice codebase in `Legal-Case-Management-System-AI-Microservice/`.

This harness does three things:

1. Aligns the roadmap with the code that exists today
2. Defines the order of implementation and rollout gates
3. Translates each phase into concrete files, flags, and success criteria

---

## Repo-Aligned Baseline

The current implementation is simpler than the roadmap assumes:

- `ai_service/app/api/routes/find_related.py` performs weighted retrieval only
- `ai_service/app/core/embeddings.py` supports `fake` and `bge` embeddings, but no instruction-aware query path yet
- `ai_service/app/config.py` has generic LLM settings, but no Gemini-specific verification pipeline
- `ai_service/app/api/schemas/responses.py` does not yet expose verification or reranker metadata
- `requirements.txt` includes `sentence-transformers`, but not Gemini client dependencies

This means the roadmap should be executed as an incremental upgrade to the existing scoring pipeline, not as a patch onto already-shipped LLM verification logic.

---

## Target Delivery Sequence

Implement the roadmap in four delivery tracks:

1. **Foundation**
   - Add config, feature flags, observability, and response fields needed by all later phases
2. **Phase 1**
   - Ship Gemini verification, chunk overlap, and instruction-tuned embedding queries
3. **Phase 2**
   - Insert cross-encoder reranking, then add HyDE, then prepare fine-tuning workflow
4. **Phase 3**
   - Explore advanced retrieval behind opt-in modes only after baseline metrics improve

Do not start Phase 3 before Phase 1 and the first half of Phase 2 are benchmarked on real case/regulation examples.

---

## Foundation Work

These changes should happen before Phase 1 even if they are not called out explicitly in the original plans.

### 1. Add feature flags and settings

Update `ai_service/app/config.py` with:

- `gemini_api_key`
- `gemini_model`
- `gemini_enabled`
- `gemini_timeout_seconds`
- `gemini_top_n_candidates`
- `chunk_overlap_ratio`
- `embedding_query_instruction_ar`
- `embedding_query_instruction_en`
- `cross_encoder_enabled`
- `cross_encoder_model_name`
- `cross_encoder_top_n`
- `hyde_enabled`
- `hyde_max_query_chars`

Use defaults that keep the current behavior unchanged unless flags are enabled.

### 2. Extend response models safely

Update `ai_service/app/api/schemas/responses.py` with optional fields so the backend can adopt new features without a breaking change:

- `verification_status`
- `verification_confidence`
- `verification_explanation_ar`
- `relevant_articles`
- `reranker_score`
- `llm_score`
- `pipeline_stage`

Keep all new fields optional in the first rollout.

### 3. Add basic observability

Add structured logging in `find_related.py` for:

- retrieval candidate count
- reranker candidate count
- LLM-approved candidate count
- per-stage latency
- fallback path taken

This is required to compare old and new ranking behavior.

### 4. Create evaluation fixtures

Add a lightweight evaluation dataset under the AI microservice for repeatable checks:

- `ai_service/app/tests/fixtures/find_related_cases.json`
- `ai_service/app/tests/fixtures/find_related_expected.json`

Each fixture should contain:

- case text
- case type
- candidate regulations
- expected relevant regulation IDs
- optional expected article references

---

## Phase 1 Harness

### Deliverable 1. Gemini verification and reranking

**Goal**: Convert the existing weighted retrieval into a two-stage pipeline:

`composite scoring -> top N candidates -> Gemini verification -> final ranking`

**Files**:

- `ai_service/app/core/llm_verifier.py` new
- `ai_service/app/api/routes/find_related.py`
- `ai_service/app/config.py`
- `requirements.txt`

**Implementation shape**:

- Build top candidates using the current scoring logic
- Limit Gemini input to the highest-ranked `N` candidates
- Ask Gemini for strict structured output per candidate:
  - applicable: yes/no
  - confidence: high/medium/low
  - relevant articles
  - Arabic explanation
- Filter non-applicable candidates
- Re-rank approved candidates using a blend of:
  - current `final_score`
  - mapped LLM confidence
  - optional binary applicability bonus
- On LLM failure, return the current ranking unchanged and log fallback usage

**Non-negotiables**:

- JSON schema validation for Gemini responses
- timeout and exception fallback
- feature-flagged rollout
- no hard dependency on Gemini for the endpoint to function

**Acceptance criteria**:

- endpoint still works when Gemini is disabled
- endpoint still works when Gemini times out
- approved candidates contain explanation and article metadata
- ranking quality improves on a small hand-verified benchmark set

### Deliverable 2. Chunk overlap

**Goal**: improve article capture near chunk boundaries without changing the backend contract.

**Files**:

- `ai_service/app/api/routes/find_related.py`

**Implementation shape**:

- if `candidate_chunks` are already provided by the backend, preserve them as-is
- if the AI service must build fallback chunks from `content_text`, create overlapping windows instead of one large fallback blob
- default overlap should be conservative, e.g. `10%`

**Important note**:

The current `_build_regulation_units()` mostly trusts backend chunks. The quick win here is primarily for fallback chunk construction unless backend chunk generation is also changed upstream.

### Deliverable 3. Instruction-tuned query embeddings

**Goal**: make query embeddings more retrieval-specific while leaving document embeddings untouched.

**Files**:

- `ai_service/app/core/embeddings.py`
- `ai_service/app/config.py`

**Implementation shape**:

- add a query-preprocessing helper for BGE queries only
- detect Arabic vs non-Arabic input
- prepend an instruction string before `embed_query()`
- keep `embed_documents()` unchanged for regulation text

**Acceptance criteria**:

- fake embeddings still work for tests
- BGE query path remains deterministic for the same input
- instruction prefix is disabled for fake provider

---

## Phase 2 Harness

### Deliverable 1. Cross-encoder reranking

**Goal**: insert a stronger precision layer before Gemini.

**Pipeline**:

`composite scoring -> top 30 -> cross-encoder -> top 15 -> Gemini -> final`

**Files**:

- `ai_service/app/core/reranker.py` new
- `ai_service/app/api/routes/find_related.py`
- `ai_service/app/config.py`
- `requirements.txt` if dependency changes are required

**Implementation shape**:

- score `(case_text, regulation_unit_text)` or `(case_text, best_regulation_excerpt)` pairs
- aggregate chunk-level reranker scores to a regulation-level score
- keep the top reranked regulations only
- return reranker metadata optionally in the response

**Acceptance criteria**:

- reranking can be turned off without changing endpoint behavior
- latency increase stays within an agreed budget
- false positives drop on benchmark cases

### Deliverable 2. HyDE

**Goal**: improve recall for vocabulary-mismatched cases.

**Files**:

- `ai_service/app/api/routes/find_related.py`
- reuse `ai_service/app/core/llm_verifier.py` or create a small query-generation helper

**Implementation shape**:

- generate one hypothetical regulation-style query with Gemini
- embed both:
  - original case text
  - hypothetical regulation text
- combine their retrieval scores before reranking

Use HyDE only when Gemini is enabled and the request is below safe size thresholds.

### Deliverable 3. Fine-tuning pipeline

**Goal**: prepare domain-adapted embeddings once verified labels are available.

**Files**:

- `ai_service/scripts/export_training_data.py` new
- `ai_service/scripts/fine_tune_bge.py` new
- `ai_service/app/core/embeddings.py`
- `ai_service/app/config.py`

**Do not block runtime improvements on this**. Treat it as a parallel offline track.

**Readiness gate**:

- at least `500+` verified positive pairs
- hard negatives available from rejected suggestions or lawyer-reviewed mismatches
- evaluation script reports recall and MRR before model swap

---

## Phase 3 Harness

Phase 3 should stay experimental until the simpler architecture is saturated.

### 1. Late interaction / ColBERT-style retrieval

Use only if:

- long regulations still underperform after reranking and HyDE
- article-level recall is still weak
- infrastructure can absorb new indexing complexity

Treat this as an alternate retriever path, not an in-place replacement at first.

### 2. Agentic retrieval

Enable only for:

- long, multi-domain cases
- explicit `advanced_mode` or internal experimentation

Do not make iterative LLM search the default path for all requests.

### 3. Legal knowledge graph

This is the only Phase 3 item that crosses service boundaries.

It will require:

- backend schema changes
- extraction scripts
- scoring updates in the AI microservice

Do not begin this until the product team decides the relationship graph should live in the shared system of record.

---

## Suggested Endpoint Evolution

Keep the existing endpoint:

- `POST /similarity/find-related`

Evolve it with optional behavior instead of introducing a new API immediately.

Recommended request additions:

- `enable_llm_verification: bool | None = None`
- `enable_cross_encoder: bool | None = None`
- `enable_hyde: bool | None = None`

Recommended response additions:

- per-result verification metadata
- top-level `pipeline` descriptor such as `composite_v1`, `composite_gemini_v1`, or `composite_rerank_gemini_v1`
- top-level warnings for degraded execution paths

This lets the backend adopt advanced stages gradually.

---

## Metrics That Decide Progression

Track these before and after each phase:

- precision at `k`
- recall at `k`
- MRR
- article-level hit rate
- false-positive rate on reviewed cases
- median latency
- p95 latency
- Gemini fallback rate
- average tokens or payload size per LLM request

Do not move from Phase 1 to broad rollout without both quality and latency data.

---

## Recommended Sprint Order

### Sprint A

- add config and response model extensions
- add structured stage logging
- add evaluation fixtures

### Sprint B

- implement Gemini verifier
- add fallback behavior
- ship behind feature flag

### Sprint C

- add instruction-tuned query embedding
- improve fallback chunk construction with overlap
- benchmark against Sprint B

### Sprint D

- add cross-encoder reranking
- benchmark quality and latency

### Sprint E

- add HyDE for selected cases
- begin training-data export for fine-tuning

### Sprint F

- evaluate whether Phase 3 is still necessary after metrics review

---

## Immediate Recommendation

Start with **Foundation + Phase 1 Deliverable 1**.

That yields the highest likely accuracy gain with the least architectural disruption because the current service already produces a ranked candidate list that is ready for a verifier stage.
