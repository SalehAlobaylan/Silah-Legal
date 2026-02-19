# Complete Regulation Monitoring & Versioning Plan

## Summary
This plan delivers a full regulation monitoring/versioning feature across:
- AI microservice (`Legal-Case-Management-System-AI-Microservice`)
- Backend API + worker (`Legal-Case-Management-System`)
- Next.js frontend (`Legal_Case_Management_Website`)

Key locked decisions:
- Monitoring runs as a **separate runtime worker process** (same repo/image, separate command).
- OCR provider is **alAPI** (`https://alapi.deep.sa/docs`) as primary.
- OCR fallback chain: **secondary OCR provider -> parser-only fallback**.
- Version creation trigger: **content hash changed only**.
- Existing high-score subscription dialog flow remains.

---

## Current-State Findings (Compatibility Gaps)

1. AI links request contract mismatch
- Backend client in `Legal-Case-Management-System/src/services/ai-client.service.ts` sends only `case_text`.
- AI route `Legal-Case-Management-System-AI-Microservice/ai_service/app/api/routes/find_related.py` expects `case_text + regulations[]`.

2. Monitoring runtime missing
- No worker scheduler/loop exists in backend runtime (`src/server.ts`, `src/app.ts`).

3. Alerts API shape mismatch
- Frontend alerts client expects `{ alerts, unreadCount }`.
- Backend notifications route currently returns `{ notifications }`.

4. Regulation detail/version page missing
- Frontend has regulations list page but no `regulations/[id]` detail page to show version timeline.

---

## Target End-to-End Flow

1. User generates AI suggestions for a case.
2. High-score suggestions (`>= 0.80`) appear in dialog, preselected, user can uncheck.
3. Bulk subscription endpoint persists selected user-level subscriptions.
4. Worker polls due subscriptions and groups checks by `(regulation_id, source_url)`.
5. Worker calls AI microservice extraction endpoint.
6. AI microservice fetches source and extracts text using parser + OCR fallback chain.
7. Backend compares normalized hash with latest version hash.
8. If changed, backend creates new `regulation_versions` row and updates regulation metadata.
9. Backend creates `regulation_update` notifications for subscribers and emits websocket event.
10. Frontend refreshes regulations/alerts/versions through query invalidation.

---

## Backend Plan (`Legal-Case-Management-System`)

### 1) Fix AI Link Generation Contract

Files:
- `src/services/ai-client.service.ts`
- `src/routes/ai-links/index.ts`

Changes:
- Update `findRelatedRegulations` request to send:
  - `case_text`
  - `regulations: { id, title, category, content_text }[]`
  - `top_k`, `threshold`
- In `POST /api/ai-links/:caseId/generate`, fetch candidate regulations from DB and pass them to AI service.
- Keep existing `isSubscribed` decoration in `GET /api/ai-links/:caseId`.

### 2) Add Monitoring Worker Runtime

Files:
- New: `src/workers/regulation-monitor.worker.ts`
- New: `src/services/regulation-monitor.service.ts`
- Update: `package.json`
- Update: `src/config/env.ts`

Changes:
- Add npm script:
  - `worker:reg-monitor` -> `tsx src/workers/regulation-monitor.worker.ts`
- Worker loop behavior:
  - Poll interval via env (`REG_MONITOR_POLL_SECONDS`, default 60)
  - Acquire advisory lock to avoid duplicate processing across replicas
  - Fetch due rows from `regulation_subscriptions` where:
    - `is_active = true`
    - `next_check_at <= now`
  - Group rows by `(regulation_id, source_url)` for one fetch per group
  - Process each group with bounded concurrency (`REG_MONITOR_MAX_CONCURRENCY`, default 5)

### 3) Integrate AI Extraction Call from Worker

Files:
- `src/services/ai-client.service.ts`
- `src/services/regulation-monitor.service.ts`

Changes:
- Add extraction client method:
  - calls AI microservice `POST /regulations/extract`
  - passes `source_url`, `if_none_match`, `if_modified_since`
- Handle extraction statuses:
  - `ok`: evaluate hash/versioning
  - `not_modified`: update schedule/check metadata only
  - `error`: schedule retry/backoff

### 4) Versioning and State Updates

Files:
- `src/services/regulation-monitor.service.ts`
- optionally shared helper in `src/services/regulation.service.ts`

Changes:
- Normalize extracted text consistently before hash comparison.
- Use SHA-256 for normalized content hash.
- On hash change:
  - compute next `version_number`
  - insert row in `regulation_versions` with:
    - `regulation_id`, `version_number`, `content`, `content_hash`
    - `raw_html` (if available)
    - `artifact_uri` (if available)
    - `changes_summary` (optional)
    - `created_by = 'system'`
  - update regulation `updated_at` and status if applicable
- On no change:
  - no new version row

### 5) Subscription Metadata Updates per Run

Files:
- `src/services/regulation-monitor.service.ts`

Changes:
- Update for all subscriptions in processed group:
  - `last_checked_at`
  - `last_etag`
  - `last_modified`
  - `last_content_hash`
  - `next_check_at = now + check_interval_hours`
  - `updated_at`
- On failure:
  - set `next_check_at` with exponential backoff cap

### 6) Notifications + WebSocket Broadcast

Files:
- `src/services/notification.service.ts`
- `src/services/regulation-monitor.service.ts`
- `src/plugins/websocket.ts` (event contract docs only if needed)

Changes:
- Create `notifications` rows (`type = regulation_update`) for active subscribers.
- Broadcast org-scoped websocket event:
  - `regulation-updated`
  - payload: `{ regulationId, versionId, versionNumber, detectedAt }`

### 7) Alerts Contract Compatibility

Files:
- `src/routes/notifications/index.ts`

Changes:
- For `/api/alerts` compatibility, return response shape frontend can consume:
  - `alerts` mapped from notifications
  - `unreadCount`
- Keep existing `/api/notifications` routes working.

### 8) Optional Manual Trigger Endpoint (Operational)

Files:
- `src/routes/regulations/index.ts`

Changes:
- Add `POST /api/regulations/monitor/run` (admin/internal usage).
- Request optional:
  - `regulationId?: number`
  - `dryRun?: boolean`
- Response:
  - `scanned`, `changed`, `versionsCreated`, `failed`

---

## AI Microservice Plan (`Legal-Case-Management-System-AI-Microservice`)

### 1) New Regulation Extraction Endpoint

Files:
- New route: `ai_service/app/api/routes/regulation_extract.py`
- Update router registration in `ai_service/app/main.py`
- Update schemas:
  - `ai_service/app/api/schemas/requests.py`
  - `ai_service/app/api/schemas/responses.py`

Endpoint:
- `POST /regulations/extract`

Request:
- `source_url: string`
- `if_none_match?: string`
- `if_modified_since?: string`
- `max_chars?: number`

Response:
- `status: ok | not_modified | error`
- `source_url`, `final_url`
- `etag?`, `last_modified?`, `content_type?`
- `extracted_text`
- `normalized_text_hash`
- `raw_html?`
- `extraction_method`
- `ocr_provider_used: alapi | secondary | none`
- `fallback_stage: none | secondary | parser_only`
- `warnings: string[]`
- `error_code?`

### 2) Provider-Switchable OCR Architecture

Files:
- New: `ai_service/app/core/ocr/providers/base.py`
- New: `ai_service/app/core/ocr/providers/alapi.py`
- New: `ai_service/app/core/ocr/providers/<secondary>.py`
- New: `ai_service/app/core/ocr/factory.py`

Behavior:
- Primary provider selected from env: `OCR_PRIMARY_PROVIDER=alapi`
- Secondary provider from env: `OCR_SECONDARY_PROVIDER=...`
- Runtime switch by env only (no code changes)

### 3) Extraction Pipeline with Locked Fallback Chain

1. Fetch source safely (timeouts, limits, whitelist, SSRF protection).
2. If HTML: parse/extract text.
3. If PDF/image or low parser text quality: call OCR providers.
4. OCR fallback chain:
- `alAPI` primary
- if fail -> secondary OCR provider
- if fail -> parser-only fallback
5. Normalize text and compute hash.
6. Return status + metadata.

### 4) alAPI Integration

Config in `ai_service/app/config.py`:
- `ALAPI_BASE_URL=https://alapi.deep.sa`
- `ALAPI_API_KEY`
- `ALAPI_OCR_PATH`
- `OCR_TIMEOUT_SECONDS`
- `OCR_MAX_PAGES`
- `OCR_PRIMARY_PROVIDER=alapi`
- `OCR_SECONDARY_PROVIDER=<value>`

Implementation details:
- Add provider timeout + retry strategy.
- Map alAPI response fields into internal canonical OCR result.
- Emit warning when OCR confidence/quality is low.

### 5) Dependencies and Container

Files:
- `requirements.txt`
- `Dockerfile`

Changes:
- Add HTTP client and parsing/OCR dependencies needed for hybrid extraction.
- If secondary provider is local OCR, add required system packages in Dockerfile.

---

## Frontend Plan (`Legal_Case_Management_Website`)

### 1) Keep Existing High-Score Subscription UX

File:
- `src/app/(dashboard)/cases/[id]/page.tsx`

Status:
- Already includes high-score selection dialog and bulk subscribe integration.

Enhancements:
- Show specific failure reason labels for failed items if backend returns per-item reasons.

### 2) Add Regulation Detail + Version Timeline UI

Files:
- New page: `src/app/(dashboard)/regulations/[id]/page.tsx`
- Reuse hooks from `src/lib/hooks/use-regulations.ts`

Behavior:
- Fetch regulation detail.
- Fetch version list (`/api/regulations/:id/versions`).
- Render version timeline (version number, created/fetched time, summary, content excerpt).

### 3) Alerts and Realtime Invalidation

Files:
- `src/lib/api/alerts.ts`
- `src/lib/hooks/use-alerts.ts`
- `src/lib/hooks/use-websocket.ts`

Changes:
- Align alerts parsing with backend compatibility shape.
- On `regulation-updated`, invalidate:
  - `['regulations']`
  - `['regulation', regulationId]`
  - `['regulation-versions', regulationId]`
  - `['alerts']`
  - `['ai-links']`

### 4) Endpoint + Type Cleanup

Files:
- `src/lib/api/endpoints.ts`
- `src/lib/types/alert.ts`
- `src/lib/types/regulation.ts`

Changes:
- Add endpoint constants for monitoring/admin route if used.
- Ensure alert/regulation types match actual backend payloads.

---

## Public APIs / Interfaces Added or Changed

1. AI microservice:
- New `POST /regulations/extract`

2. Backend:
- `POST /api/ai-links/:caseId/generate` request-to-AI payload fixed (includes regulations list)
- Optional new `POST /api/regulations/monitor/run`
- `/api/alerts` response shape made frontend-compatible

3. Internal OCR provider interface:
- Pluggable provider contract with `alAPI` primary and runtime provider selection

---

## Deployment Plan (DigitalOcean)

Keep same repo/image; deploy as separate runtime processes:

1. API component
- Command: existing web start command

2. Worker component
- Command: `npm run worker:reg-monitor`

Notes:
- This is separate runtime, not separate codebase.
- Both components share same DB and env source (with worker-specific env vars enabled only where needed).

---

## Testing Plan

### Backend Tests

1. AI link generation contract
- Verify backend sends `regulations[]` and handles AI response correctly.

2. Worker scheduling
- Picks only due active subscriptions.
- Honors lock and avoids duplicate processing.

3. Versioning
- No version on unchanged hash.
- New version exactly once on changed hash.

4. Notifications
- Creates `regulation_update` notifications for subscribers.
- Emits websocket event once per changed regulation.

5. Failure handling
- Extraction failure triggers retry scheduling with backoff.

### AI Microservice Tests

1. Extraction format handling
- HTML parse path
- PDF parse path
- OCR path

2. OCR fallback chain
- alAPI success
- alAPI fail -> secondary success
- both fail -> parser-only fallback

3. Safety
- whitelist enforcement
- SSRF/private-network blocking
- timeout behavior

4. Contract
- Response fields and enums match backend expectations.

### Frontend Tests

1. Subscription suggestion dialog
- Opens after generation with eligible rows
- Preselection/uncheck works
- Disabled rows for non-subscribable/already subscribed

2. Alerts
- Regulation update appears and links correctly.

3. Version UI
- Regulation detail page shows versions and refreshes on websocket updates.

4. Query invalidation
- `regulation-updated` invalidates alerts/regulations/versions/ai-links.

### End-to-End Scenarios

1. Generate AI links -> subscribe selected high-score regs.
2. Worker run detects source change -> new version created.
3. User receives alert and sees updated version timeline.

---

## Rollout / Monitoring

1. Rollout phases
- Phase 1: contract fixes + alerts shape + frontend type alignment
- Phase 2: AI extraction endpoint + alAPI integration + fallback chain
- Phase 3: worker + versioning + notifications + regulation detail UI

2. Operational metrics
- `subscriptions_scanned_total`
- `source_fetch_failures_total`
- `ocr_alapi_failures_total`
- `ocr_secondary_failures_total`
- `parser_only_fallback_total`
- `versions_created_total`
- `notifications_created_total`
- loop duration and queue depth

3. Feature flags / kill switch
- `REG_MONITOR_ENABLED=false` to disable worker safely.

---

## Assumptions and Defaults

1. High-score threshold stays `0.80`.
2. Default check interval stays `24h`.
3. Subscription scope remains user-level + org-scoped.
4. Versioning trigger is content-hash only.
5. OCR happens only in AI microservice (never in backend).
6. Primary OCR provider is alAPI; fallback chain is fixed as agreed.

