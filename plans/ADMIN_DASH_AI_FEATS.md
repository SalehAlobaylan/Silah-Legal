# Admin AI Suite Expansion Plan

## Summary
Expand the Admin Executive Command Center into an all-in AI suite with human-in-the-loop workflows. The system will combine deterministic scoring with optional LLM-generated summaries, always keeping explainable evidence and safe fallbacks. Admins will get AI risk intelligence, case triage, workload recommendations, document/regulation insight monitoring, model quality metrics, and AI-assisted action drafts.

## Key Changes
- Add `AI Intelligence` as a first-class dashboard tab replacing the lighter AI monitoring view.
- Add persisted org-scoped AI profile tables:
  - `admin_ai_case_profiles`: per-case AI risk, urgency, confidence, signals, evidence, recommended actions, model metadata.
  - `admin_ai_org_snapshots`: latest org-level AI summary, aggregate risk, workload signals, quality metrics, generated at timestamp.
  - `admin_ai_action_drafts`: human-approved workflow drafts such as assignment recommendations, announcement drafts, AI-link generation batches, and review queues.
- Add backend admin endpoints:
  - `GET /api/admin/ai-intelligence/summary`
  - `POST /api/admin/ai-intelligence/refresh`
  - `POST /api/admin/ai-intelligence/cases/:id/refresh`
  - `POST /api/admin/ai-intelligence/actions/:id/approve`
  - `POST /api/admin/ai-intelligence/actions/:id/dismiss`
  - `POST /api/admin/ai-intelligence/evaluation/run`
- Add audit actions:
  - `admin.ai_profile.refresh`
  - `admin.ai_org_snapshot.refresh`
  - `admin.ai_action.approve`
  - `admin.ai_action.dismiss`
  - `admin.ai_evaluation.run`

## AI Features
- Case risk intelligence:
  - Risk score, urgency, confidence, and top evidence per active case.
  - Signals from overdue hearings, stale activity, unassigned ownership, unverified AI links, document insight risks, failed extraction, recent regulation updates, and workload context.
  - Links to case detail, linking page, document insights, regulation impact, and lawyer profile.
- AI workload advisor:
  - Recommend reassignment candidates based on open workload, high-risk cases, upcoming hearings, leave status, and specialization when available.
  - Generate assignment drafts only; admin must approve.
- AI review queue:
  - Rank unverified regulation links by score, evidence coverage, document support, recency, and case risk.
  - Support batch “generate links”, “refresh profile”, and “open review” actions.
- Document intelligence:
  - Surface cases with high-risk clauses, missing insights, failed OCR/extraction, stale document context, and documents awaiting review.
  - Cluster risks by employment, commercial, family, criminal, administrative, or uncategorized patterns.
- Regulation impact intelligence:
  - Rank open cases affected by recent regulation versions.
  - Show impact reason, affected case count, and suggested admin action.
- Model quality and AI ops:
  - Show latest evaluation run, recall@5, precision@5, nDCG@5, failed cases, warnings, pipeline label, and trend versus previous run.
  - Show AI microservice health, fallback mode, warming state, and failed profile refreshes.

## Microservice Additions
- Add FastAPI route module `admin_insights.py`.
- Add endpoints:
  - `POST /admin/case-risk-profile`
  - `POST /admin/org-intelligence-summary`
  - `POST /admin/workload-recommendations`
  - `POST /admin/review-prioritization`
- Use deterministic scoring as the required baseline.
- Add optional LLM enrichment for executive summary, recommended actions, and rationale when configured.
- Response must always include `method`, `confidence`, `warnings`, and evidence references.
- If LLM or embedding provider is unavailable, return deterministic output with degraded warnings.

## Frontend Changes
- Add admin API client/types:
  - `AdminAIIntelligenceSummary`
  - `AdminAICaseProfile`
  - `AdminAISignal`
  - `AdminAIActionDraft`
  - `AdminAIQualitySummary`
  - `AdminAIWorkloadRecommendation`
- Add hooks:
  - `useAdminAIIntelligence`
  - `useRefreshAdminAIIntelligence`
  - `useRefreshAdminAICaseProfile`
  - `useApproveAdminAIAction`
  - `useDismissAdminAIAction`
  - `useRunAdminAIEvaluation`
- UI sections:
  - AI executive summary band.
  - Risk-ranked cases table.
  - Workload advisor card.
  - Review prioritization queue.
  - Document intelligence card.
  - Regulation impact watch card.
  - AI quality and model health card.
  - Action drafts inbox with approve/dismiss confirmation dialogs.
- Keep all generated actions human-in-the-loop; no destructive or external-facing action runs without admin confirmation.

## Test Plan
- Microservice:
  - Contract tests for each new admin endpoint.
  - Deterministic scoring tests for overdue hearings, stale cases, high unverified links, failed documents, regulation updates, and workload pressure.
  - LLM-unavailable fallback tests.
- Backend:
  - Admin-only and organization isolation tests.
  - Profile/snapshot/action-draft persistence tests.
  - Refresh single case and org batch tests.
  - Audit logging tests for refresh, approve, dismiss, and evaluation actions.
  - AI service degraded response tests.
- Frontend:
  - Component tests for AI summary, risk table, action drafts, and confirmation dialogs.
  - E2E tests for AI tab deep link, refresh org, refresh case, approve/dismiss draft, run evaluation, and Arabic RTL smoke.
- Verification:
  - Backend `npx tsc --noEmit`.
  - Microservice targeted `pytest` for admin insights.
  - Frontend targeted ESLint/TypeScript on changed files, plus admin-focused Playwright specs.

## Assumptions
- Admin-only access remains unchanged.
- AI may generate narrative summaries, but deterministic scores and evidence remain authoritative.
- Admin approval is required for all workflow actions.
- Existing AI evaluation, AI links, document insights, regulation insights, and command-center work should be reused instead of duplicated.
- The exposed Hugging Face token in `.env.local` should be rotated before relying on AI-provider calls.
