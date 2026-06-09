# GP-flutter (Mobile App)

> The Flutter mobile app for Silah, including a client-portal experience. A pure client of the backend API (REST + Socket.IO). In **early development** — feature modules and navigation are scaffolded; not yet at parity with the web dashboard.

**Platform:** Flutter / Dart (Android, iOS, Web, Desktop)  **State:** Provider  **Nav:** GoRouter  **HTTP:** Dio  **Directory:** `GP-flutter/` (app under `gp/`)

---

## Overview

A multi-platform Flutter app that targets the same backend as the web dashboard. Architecture is feature-first: each capability is a folder under `gp/lib/features/`, with shared infrastructure (network, storage, errors, constants) under `gp/lib/core/`. Navigation is centralized in `gp/lib/app/routes.dart` (GoRouter). Auth and realtime mirror the web client: JWT bearer tokens over Dio, live updates over `socket_io_client`.

## Features

Feature modules present (`gp/lib/features/`): `auth`, `dashboard`, `cases`, `clients`, `client_portal`, `regulations`, `assistant`, `notifications`, `profile`, `settings`.

GoRouter routes (`gp/lib/app/routes.dart`):

| Route | Feature |
|-------|---------|
| `/login`, `/register` | auth |
| `/dashboard` | dashboard |
| `/cases`, `/cases/create`, `/cases/:id`, `/cases/:id/edit` | cases |
| `/clients`, `/clients/:id` | clients |
| `/regulations`, `/regulations/:id` | regulations |
| `/portal/overview`, `/portal/documents`, `/portal/billing` | client portal |
| `/assistant` | AI assistant |
| `/notifications` | notifications |
| `/profile`, `/settings` | profile / settings |

- **Product basis:** PRD §4.11 (multi-channel access), §11 (mobile is roadmap-stage). The route set mirrors the core web flows (cases, clients, regulations, assistant, client portal).

## Architecture

- **Internal structure:** `gp/lib/app/` (app shell, `routes.dart` GoRouter config), `gp/lib/features/<feature>/` (per-feature screens/widgets/state), `gp/lib/core/` (`network`, `storage`, `errors`, `constants`, `utils`, `demo`).
- **Networking:** `core/network/api_client.dart` wraps Dio with `baseUrl: ApiConstants.baseUrl`; `core/network/websocket_service.dart` connects Socket.IO to the same base. Endpoint paths are centralized in `core/constants/api_constants.dart` (e.g. `/api/auth/login`, `/api/cases`, `/api/regulations`).
- **Config:** base URLs are **compile-time** via `String.fromEnvironment` (`--dart-define`), not a `.env` file: `API_BASE_URL` and `AI_SERVICE_URL`.
- **Storage:** `shared_preferences` + `flutter_secure_storage` (tokens).
- **Integration — Calls:** backend REST + Socket.IO. **Cannot:** touch the DB or call the AI service directly (via backend).
- **Drift:** `API_BASE_URL` defaults to `http://localhost:3001` (`core/constants/api_constants.dart:4`), but the backend runs on **3000** (3001 is the website). Pass the correct base at build time, e.g. `--dart-define=API_BASE_URL=http://localhost:3000`. See PRD §9.

## Tech Stack
| Concern | Package |
|---------|---------|
| State management | `provider` |
| Navigation | `go_router` |
| HTTP | `dio` |
| Realtime | `socket_io_client` |
| Storage | `shared_preferences`, `flutter_secure_storage` |
| Forms | `flutter_form_builder`, `form_builder_validators` |
| Files | `file_picker`, `open_filex`, `path_provider` |
| UX | `cached_network_image`, `shimmer`, `pull_to_refresh`, `timeago` |
| i18n | `flutter_localizations`, `intl` (Arabic-first, RTL) |

## Running
```bash
cd GP-flutter/gp
flutter pub get
# Point at the backend (default is :3001 which is wrong — backend is :3000):
flutter run --dart-define=API_BASE_URL=http://localhost:3000 \
            --dart-define=AI_SERVICE_URL=http://localhost:8000
flutter test
```
SDK: Dart `^3.9.2` (`pubspec.yaml`).

## Configuration (compile-time `--dart-define`)
| Define | Default | Purpose |
|--------|---------|---------|
| `API_BASE_URL` | `http://localhost:3001` (should be `:3000`) | backend base URL |
| `AI_SERVICE_URL` | `http://localhost:8000` | AI service (reference) |

## Sources
- `gp/lib/app/routes.dart` (navigation), `gp/lib/features/*` (feature modules)
- `gp/lib/core/network/{api_client,websocket_service}.dart`, `gp/lib/core/constants/api_constants.dart`
- `gp/pubspec.yaml` (deps, SDK)
