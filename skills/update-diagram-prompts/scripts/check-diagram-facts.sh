#!/usr/bin/env bash
# check-diagram-facts.sh — the harness for update-diagram-prompts.
#
# A diagram prompt is "correct" only if the facts it encodes still match the
# code. The generic update-docs crawler (inventory.sh) dumps EVERYTHING; this
# script instead extracts just the handful of drift-prone facts that the
# diagram catalog depends on, each with a file:line citation, in a compact,
# diffable form. Run it, then diff the output against docs/diagram-prompts.md:
# any mismatch is a diagram that lies.
#
# Usage:
#   scripts/check-diagram-facts.sh            # print the canonical facts
#   scripts/check-diagram-facts.sh --help
#
# Run from the Silah-Legal monorepo root. Read-only; never writes.

set -uo pipefail

ROOT="${SILAH_ROOT:-$(pwd)}"
BE="$ROOT/Legal-Case-Management-System"
AI="$ROOT/Legal-Case-Management-System-AI-Microservice"
WEB="$ROOT/Legal_Case_Management_Website"
MOB="$ROOT/GP-flutter"

case "${1:-}" in
  -h|--help) grep -E '^#' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
esac

hr() { printf '\n=== %s ===\n' "$1"; }
fact() { printf '  %-28s %s\n' "$1" "$2"; }

missing=0
need() { [ -e "$1" ] || { echo "  !! MISSING: ${1#$ROOT/}" >&2; missing=1; }; }
need "$BE"; need "$AI"; need "$WEB"; need "$MOB"

# ---- Diagram #1 / #5: the active service set + ports -------------------------
hr "Services & ports (diagrams #1 Architecture, #5 Stack/Deploy)"
fact "backend" "Legal-Case-Management-System  :3000  (Fastify, owns DB)"
fact "website" "Legal_Case_Management_Website :3001 prod  (Next.js client)"
fact "ai"      "Legal-Case-Management-System-AI-Microservice :8000 (FastAPI, stateless)"
fact "mobile"  "GP-flutter  (Flutter client)"
echo "  source: docs/architecture.md + per-service package.json/pubspec"

# ---- Diagram #1 / #6: backend route groups + workers + Socket.IO ------------
hr "Backend surface (diagrams #1, #6 Journey)"
groups=$(grep -oE 'register\(([a-zA-Z]+)Routes' "$BE/src/app.ts" 2>/dev/null | sort -u | wc -l | tr -d ' ')
regs=$(grep -cE 'register\([a-zA-Z]+Routes' "$BE/src/app.ts" 2>/dev/null)
fact "route groups (distinct)" "$groups   (src/app.ts register() calls: $regs)"
ws=$(grep -nE 'new SocketIOServer' "$BE/src/plugins/websocket.ts" 2>/dev/null | head -1 | cut -d: -f1)
fact "Socket.IO realtime" "src/plugins/websocket.ts:${ws:-?} (Fastify plugin, not a service)"
workers=$(ls "$BE/src/workers" 2>/dev/null | tr '\n' ' ')
fact "background workers" "${workers:-none}"

# ---- Diagram #7: Drizzle data model ----------------------------------------
hr "Data model (diagram #7 ERD)"
tables=$(grep -rh 'pgTable(' "$BE/src/db/schema"/*.ts 2>/dev/null | grep -c 'pgTable(')
fact "Drizzle tables" "$tables  (src/db/schema/*.ts)"
orgcols=$(grep -rl 'organization_id\|organizationId' "$BE/src/db/schema"/*.ts 2>/dev/null | wc -l | tr -d ' ')
fact "schema files w/ org scope" "$orgcols  (multi-tenancy — show org boundary)"

# ---- Diagram #3 / #4: AI microservice ---------------------------------------
hr "AI microservice (diagrams #3 Pipeline, #4 AI Internals)"
routers=$(grep -c 'include_router' "$AI/ai_service/app/main.py" 2>/dev/null)
fact "routers mounted" "$routers  (ai_service/app/main.py)"
rnames=$(grep -oE 'include_router\(([a-z_]+)\.' "$AI/ai_service/app/main.py" 2>/dev/null \
          | sed -E 's/include_router\(//; s/\.$//' | tr '\n' ' ')
fact "router names" "$rnames"
stages=$(sed -n '7,16p' "$AI/ai_service/app/api/routes/find_related.py" 2>/dev/null \
          | grep -cE '^[[:space:]]*[0-9]')
fact "find-related stages" "$stages  (find_related.py docstring; mark optional ones dashed)"
prov=$(grep -A1 'embeddings_provider' "$AI/ai_service/app/config.py" 2>/dev/null \
        | grep -oE 'default="[a-z]+"' | head -1)
model=$(grep -oE 'default="BAAI/[^"]+"' "$AI/ai_service/app/config.py" 2>/dev/null | head -1)
fact "embeddings provider" "${prov:-?}  <-- config.py (note: default is fake, not bge)"
fact "embeddings model" "${model:-?}  config.py"

# ---- Diagram #2: auth + roles ----------------------------------------------
hr "Auth & roles (diagram #2)"
roles=$(awk '/export const userRoleEnum/{f=1} f{print} /as const/{if(f)exit}' "$BE/src/db/schema/users.ts" 2>/dev/null \
         | grep -oE '"[a-z_]+"' | tr '\n' ' ')
fact "user roles" "${roles:-?}  (src/db/schema/users.ts)"
oauth=$(ls "$BE/src/routes/oauth" 2>/dev/null >/dev/null && echo "Google OAuth + email/password (JWT HS256)" || echo "?")
fact "auth methods" "$oauth"

# ---- Known gotchas the diagrams must LABEL, not hide ------------------------
hr "Gotchas to label (diagrams #1, #5)"
webdev=$(grep -oE '"dev":[^,]*-p [0-9]+' "$WEB/package.json" 2>/dev/null | grep -oE '[0-9]+$')
fact "website dev port" "${webdev:-?}  (collides with backend :3000 — label it)"
mob=$(grep -oE "defaultValue: 'http://localhost:[0-9]+'" "$MOB/gp/lib/core/constants/api_constants.dart" 2>/dev/null | head -1 | grep -oE '[0-9]+')
fact "mobile API base default" "${mob:-?}  (should be 3000 — backend; label drift)"

echo
[ "$missing" -eq 0 ] && echo "All four service dirs present. Facts above are the canonical inputs to docs/diagram-prompts.md." \
                     || echo "WARNING: some service dirs missing — see !! lines above."
exit 0
