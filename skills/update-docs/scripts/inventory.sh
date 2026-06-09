#!/usr/bin/env bash
# inventory.sh — deterministic source crawler for the Silah-Legal meta-monorepo.
#
# Emits a structured inventory (routes, env vars, data models, features) for one
# service or all of them, by grepping the actual source. The update-docs skill
# uses this so each run *verifies and describes* the code instead of re-deriving
# grep patterns from scratch — saves tokens and keeps every service doc consistent.
#
# Usage:
#   scripts/inventory.sh <service>     # one service (see names below)
#   scripts/inventory.sh all           # every service, in doc order
#   scripts/inventory.sh --list        # print known service names
#
# Service names (match the doc filenames):
#   backend | website | ai | mobile
#
# Run from the Silah-Legal monorepo root. Uses ripgrep (rg) if present, else grep.

set -uo pipefail

ROOT="${SILAH_ROOT:-$(pwd)}"
GREP="grep -rEn"
command -v rg >/dev/null 2>&1 && GREP="rg -n"

hr() { printf '\n========== %s ==========\n' "$1"; }
sub() { printf '\n--- %s ---\n' "$1"; }

# Map a service key to its directory.
dir_for() {
  case "$1" in
    backend) echo "Legal-Case-Management-System" ;;
    website) echo "Legal_Case_Management_Website" ;;
    ai)      echo "Legal-Case-Management-System-AI-Microservice" ;;
    mobile)  echo "GP-flutter" ;;
    *) return 1 ;;
  esac
}

# Print env vars from .env.example (the documented contract) plus any code
# references not in it (the drift). .env.example is the source of truth for the
# operator-facing list; code refs catch undocumented vars.
env_vars() {
  local d="$1" lang="$2" srcdir="$3"
  sub "Env vars (.env.example)"
  if [ -f "$ROOT/$d/.env.example" ]; then
    grep -E '^[A-Z][A-Z0-9_]+=' "$ROOT/$d/.env.example" | sed 's/=.*//' | sort -u
  else
    echo "(no .env.example)"
  fi
  sub "Env refs in code (may include vars missing from .env.example)"
  case "$lang" in
    py)   $GREP 'os\.getenv\(|os\.environ' "$ROOT/$d/$srcdir" 2>/dev/null | grep -oE '"[A-Z0-9_]+"' | tr -d '"' | sort -u ;;
    ts)   $GREP 'process\.env\.' "$ROOT/$d/$srcdir" 2>/dev/null | grep -oE 'process\.env\.[A-Z0-9_]+' | grep -oE '[A-Z0-9_]+$' | sort -u ;;
  esac
}

# Backend — Node.js + Fastify. Routes live in src/routes/<group>/index.ts as
# fastify.get/post(...) calls; the URL prefix for each group is assigned in
# src/app.ts via app.register(xRoutes, { prefix: "..." }). Models are Drizzle
# pgTable definitions in src/db/schema/*.ts.
crawl_backend() {
  local d="$1"
  hr "NODE/FASTIFY SERVICE (backend): $d"
  sub "Route prefixes (src/app.ts — group → URL prefix)"
  $GREP 'register\([a-zA-Z]+Routes,\s*\{\s*prefix' "$ROOT/$d/src/app.ts" 2>/dev/null || echo "(none found)"
  sub "Route handlers (fastify.get/post/put/patch/delete in src/routes)"
  $GREP 'fastify\.(get|post|put|patch|delete)\(|server\.(get|post|put|patch|delete)\(' "$ROOT/$d/src/routes" 2>/dev/null || echo "(none found)"
  sub "Route groups present (src/routes/*)"
  ls "$ROOT/$d/src/routes" 2>/dev/null || echo "(no routes dir)"
  sub "Drizzle tables (export const … = pgTable in src/db/schema)"
  $GREP 'pgTable\(' "$ROOT/$d/src/db/schema" 2>/dev/null || echo "(no schema dir)"
  sub "Background workers (src/workers)"
  ls "$ROOT/$d/src/workers" 2>/dev/null || echo "(no workers dir)"
  env_vars "$d" ts src
}

# Website — Next.js App Router. Pages are src/app/**/page.tsx (each path is a
# route). This frontend is a pure client of the backend — it has no API route
# handlers of its own; data comes from the backend over NEXT_PUBLIC_API_URL.
crawl_website() {
  local d="$1"
  hr "NEXT.JS APP (website): $d"
  sub "Page routes (src/app/**/page.tsx → each path is a URL)"
  find "$ROOT/$d/src/app" -name "page.tsx" 2>/dev/null \
    | sed "s#$ROOT/$d/src/app##; s#/page.tsx##" | sort || echo "(no app dir)"
  sub "API route handlers (src/app/api/**/route.ts — expected: none, pure client)"
  find "$ROOT/$d/src/app" -name "route.ts" 2>/dev/null \
    | sed "s#$ROOT/$d/src/app##; s#/route.ts##" | sort || echo "(none)"
  sub "Top-level src dirs"
  ls -d "$ROOT/$d/src"/*/ 2>/dev/null | sed "s#$ROOT/$d/src/##"
  env_vars "$d" ts src
}

# AI microservice — Python + FastAPI. Routers are decorated functions in
# ai_service/app/api/routes/*.py; response/request schemas are Pydantic
# BaseModels in ai_service/app/api/schemas/*.py; settings live in
# ai_service/app/config.py (BaseSettings).
crawl_ai() {
  local d="$1"
  hr "PYTHON/FASTAPI SERVICE (ai): $d"
  sub "FastAPI routes (@router/@app decorators in ai_service/app)"
  $GREP '@(router|app)\.(get|post|put|patch|delete)\(' "$ROOT/$d/ai_service/app" 2>/dev/null || echo "(none found)"
  sub "Router mounts (include_router in main.py)"
  $GREP 'include_router' "$ROOT/$d/ai_service/app" 2>/dev/null || true
  sub "Pydantic schemas (class … BaseModel)"
  $GREP 'class [A-Z][A-Za-z0-9]+\(BaseModel' "$ROOT/$d/ai_service/app/api/schemas" 2>/dev/null || echo "(none found)"
  sub "Core modules (ai_service/app/core — the retrieval/RAG pipeline)"
  ls "$ROOT/$d/ai_service/app/core" 2>/dev/null || echo "(no core dir)"
  env_vars "$d" py ai_service/app
}

# Mobile — Flutter/Dart. Code lives under gp/lib; features are feature folders
# in gp/lib/features/*; navigation is GoRouter routes in gp/lib/app/routes.dart.
crawl_mobile() {
  local d="$1"
  hr "FLUTTER APP (mobile): $d"
  sub "Feature modules (gp/lib/features/*)"
  ls "$ROOT/$d/gp/lib/features" 2>/dev/null || echo "(no features dir)"
  sub "GoRouter routes (path: in gp/lib/app)"
  $GREP "path:\s*'" "$ROOT/$d/gp/lib/app" 2>/dev/null || echo "(none found)"
  sub "Core layers (gp/lib/core/*)"
  ls "$ROOT/$d/gp/lib/core" 2>/dev/null || echo "(no core dir)"
  sub "API base / backend wiring (gp/lib/core/network, constants)"
  $GREP 'baseUrl|http://|https://|localhost' "$ROOT/$d/gp/lib/core" 2>/dev/null | head -20 || true
}

crawl_one() {
  case "$1" in
    backend) crawl_backend "$(dir_for backend)" ;;
    website) crawl_website "$(dir_for website)" ;;
    ai)      crawl_ai      "$(dir_for ai)" ;;
    mobile)  crawl_mobile  "$(dir_for mobile)" ;;
    *) echo "Unknown service: $1" >&2; return 1 ;;
  esac
  # Return success for any recognized service. Without this, the exit status is
  # whatever the last grep returned (often 1 when a "refs in code" section finds
  # nothing) — making a successful crawl look like a failure to callers/harnesses.
  return 0
}

case "${1:-}" in
  ""|-h|--help)
    grep -E '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
  --list)
    echo "backend website ai mobile"; exit 0 ;;
  all)
    for s in backend website ai mobile; do
      crawl_one "$s"
    done ;;
  *)
    crawl_one "$1" ;;
esac
