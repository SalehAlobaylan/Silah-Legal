# Addendum: High-Score Subscription Suggestion UI (Case AI Links)

## Summary
Add a guided subscription step in Case Detail AI Suggestions: after AI refresh, show a dialog with high-score regulations preselected, let user uncheck unwanted items, then subscribe selected ones in one action.

This addendum updates one prior decision:
- Previous: auto-subscribe only on `Verify`.
- Updated: subscribe can happen directly from the dialog (user confirmation in dialog is the explicit consent).

## Product Behavior (Decision Complete)
1. Trigger:
- Show prompt only after AI refresh/generation when there are newly generated, high-score, unsubscribed candidates.
- Do not auto-open on every page load.

2. Candidate pool:
- Eligible candidates are AI links for the current case with `similarity_score >= 0.80`.
- Candidates can be subscribed even if not verified.
- Exclude rows already subscribed by the current user.
- Exclude rows with missing/invalid `sourceUrl` or non-whitelisted domains.

3. Selection UX:
- All eligible candidates are pre-checked by default.
- User can uncheck any item before submit.
- Confirm button subscribes only checked items.
- Skip button closes dialog without changes.
- If zero checked, confirm button is disabled.

4. Post-submit:
- Show success toast with count of subscribed regulations.
- Show warning toast for skipped/failed rows (partial success supported).
- Refresh AI links and subscription state.
- Keep existing Verify/Dismiss flow unchanged.

## Backend/API Changes
1. Add bulk subscribe endpoint:
- `POST /api/regulations/subscriptions/bulk`
- Request:
  - `caseId: number`
  - `regulationIds: number[]`
- Behavior:
  - Validate JWT user + org.
  - Validate regulation ownership/visibility and URL whitelist.
  - Upsert user-level subscriptions idempotently.
  - Return per-item result.
- Response:
  - `created: number`
  - `alreadySubscribed: number`
  - `failed: { regulationId: number; reason: string }[]`

2. Add subscription lookup endpoint:
- `GET /api/regulations/subscriptions/me?caseId=:id` (or all, filtered client-side).
- Returns user subscriptions to mark already-subscribed items.

3. Extend AI links response shape:
- `GET /api/ai-links/:caseId` includes `isSubscribed` per link for current user.
- This avoids extra client joins and race conditions.

4. Keep existing endpoint:
- `POST /api/regulations/subscribe` remains for single-item/manual flows.
- Internally reuse same service method as bulk route.

## Frontend Changes
1. Component integration:
- Implement in `/Users/salehalobaylan/Desktop/Silah-Legal/Legal_Case_Management_Website/src/components/features/cases/ai-suggestions.tsx`.
- Use existing dialog primitive:
  `/Users/salehalobaylan/Desktop/Silah-Legal/Legal_Case_Management_Website/src/components/ui/dialog.tsx`.
- Use native checkbox inputs for row selection.

2. Dialog content:
- Title: “Highly related regulations found”.
- Subtitle: “Do you want to subscribe to updates for these regulations?”
- Row fields: regulation title, score %, reason/status badges.
- States: `already subscribed`, `not subscribable (missing trusted source)`, `selected`.

3. Open conditions:
- Open after successful AI refresh when candidate count > 0.
- Open once per generation batch (track batch key in local state from link ids + timestamps).

4. i18n:
- Add English and Arabic keys in:
  `/Users/salehalobaylan/Desktop/Silah-Legal/Legal_Case_Management_Website/src/lib/i18n/locales/en.json`
  `/Users/salehalobaylan/Desktop/Silah-Legal/Legal_Case_Management_Website/src/lib/i18n/locales/ar.json`
- Keys include dialog title, subtitle, selected count, subscribe action, skip action, partial-failure messages.

## Data/Schema Implications
1. Keep user-level subscriptions as canonical source.
2. Ensure unique constraint on `(user_id, regulation_id)` for idempotency.
3. Keep org scoping for all subscription reads/writes.
4. Keep source URL whitelist enforcement in service layer.

## Edge Cases
1. High score candidate already subscribed:
- Display disabled checked badge “Already subscribed”.
- Excluded from submit payload.

2. Missing/invalid source URL:
- Display disabled unchecked row with reason.
- Not submitted.

3. Partial API success:
- Apply successful subscriptions.
- Report failed ones with reasons.
- Keep dialog closed after submit; surface message with retry hint.

4. Concurrent updates:
- Bulk API uses upsert to avoid duplicates if user double-clicks or multi-tabs.

## Tests and Scenarios
1. Backend:
- Bulk subscribe creates rows for new ids.
- Bulk subscribe is idempotent for existing rows.
- Org isolation blocks cross-org subscriptions.
- URL whitelist rejection returns per-item failure reason.

2. Frontend:
- Dialog opens only after AI refresh with new high-score candidates.
- Preselection includes all eligible candidates.
- Unchecked items are not submitted.
- Already-subscribed and invalid-source rows are disabled.
- Success and partial-failure toasts render correct counts.

3. Integration:
- Generate AI links for case -> dialog appears -> uncheck one -> subscribe -> only checked rows persisted.
- Subsequent refresh does not re-prompt for already subscribed rows.

## Defaults and Assumptions
- High-score threshold: `0.80`.
- Prompt timing: after AI refresh for newly generated candidates.
- Consent model: dialog confirmation is sufficient; verify is independent.
- Subscription scope: user-level, always org-scoped.
- Trusted source policy: official-domain whitelist only.
