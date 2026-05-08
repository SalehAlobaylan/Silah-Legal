# Flutter Integration Handoff Note

Date: 2026-05-08
Owner of this note: Flutter repo only

## Scope

This note documents cross-repo follow-up discovered while validating the Flutter app against the local backend and AI services. No code changes are requested here for the Flutter repo itself beyond the Flutter work already completed.

## What Was Validated From Flutter

The Flutter macOS app was run successfully against local services and the following flows responded successfully during smoke testing:

- Authentication and current user lookup
- Dashboard stats
- Recent activity
- Profile data and profile stats
- Regulations list/detail flows used by the app
- Alerts and notifications fetch
- Cases list, create, fetch, and update
- AI links fetch
- Case documents fetch
- AI chat sessions list/create
- AI chat streaming endpoint

## Follow-Up Needed Outside Flutter

### 1. AI chat provider API key is not configured

Observed behavior:

- Chat reports that the API key is not configured.
- Streaming infrastructure was reachable, but the model/provider configuration is still incomplete.

Needed from AI service owner:

- Configure the required LLM provider API key in the AI service environment.
- Confirm the exact required environment variable names and local setup instructions.
- Re-test the chat flow after configuration.

Impact on Flutter:

- Flutter chat UI and request flow can run, but end-user chat functionality is blocked until the AI service is configured.

### 2. Delete chat session contract mismatch

Observed behavior:

- `DELETE /api/ai/chat/sessions/:id` returned `400` during app validation.

Needed from backend or AI owner:

- Confirm whether this endpoint expects an empty body, no `Content-Type`, or a specific payload.
- Align the API contract so a normal delete from the client succeeds consistently.

Impact on Flutter:

- Session cleanup/delete in the app is unreliable until the contract is clarified and fixed server-side or explicitly documented.

### 3. Dashboard daily operations endpoint is too slow or timing out

Observed behavior:

- `/api/dashboard/daily-operations` timed out during validation.

Needed from backend owner:

- Investigate query performance and server-side latency.
- Confirm expected response time and whether pagination, caching, or query simplification is needed.

Impact on Flutter:

- Dashboard secondary data may fail to load or degrade the user experience even though the main dashboard stats endpoint works.

## Notes For Backend/AI Owners

- These findings came from real app-level validation, not just unit tests.
- Core Flutter integration appears broadly healthy.
- Remaining blockers are service configuration and server-side API behavior, not Flutter ownership issues.

## Recommended Ownership Split

- Flutter owner: keep Flutter-only changes in `GP-flutter`
- AI owner: configure chat provider key and verify chat model readiness
- Backend owner: investigate dashboard latency and confirm delete-session API contract