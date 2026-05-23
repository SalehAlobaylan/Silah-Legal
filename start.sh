#!/bin/bash

# ─────────────────────────────────────────────
#  Silah-Legal — Start All Services
# ─────────────────────────────────────────────

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BOLD='\033[1m'
NC='\033[0m'

ROOT_DIR="$(cd "$(dirname "$0")" && pwd)"
LOGS_DIR="$ROOT_DIR/.logs"
mkdir -p "$LOGS_DIR"

PIDS=()

# ── Cleanup on Ctrl+C ──────────────────────────
cleanup() {
  echo -e "\n${YELLOW}Shutting down all services...${NC}"
  for pid in "${PIDS[@]}"; do
    kill "$pid" 2>/dev/null
  done
  echo -e "${GREEN}All services stopped.${NC}"
  exit 0
}
trap cleanup SIGINT SIGTERM

# ── Helpers ────────────────────────────────────
wait_for_port() {
  local port=$1
  local service=$2
  # Default 30s; callers can pass a longer timeout. The AI service's first boot
  # has to load the BGE-M3 model (~50s cold, much faster once cached).
  local retries="${3:-30}"
  echo -ne "  Waiting for ${service} on port ${port}..."
  while ! nc -z localhost "$port" 2>/dev/null; do
    sleep 1
    retries=$((retries - 1))
    if [ "$retries" -eq 0 ]; then
      echo -e " ${RED}timed out${NC}"
      return 1
    fi
  done
  echo -e " ${GREEN}ready${NC}"
}

# ── Backend API ────────────────────────────────
start_backend() {
  echo -e "${BLUE}▶  Starting Backend API (port 3001)...${NC}"
  (
    cd "$ROOT_DIR/Legal-Case-Management-System" || exit 1
    npm install --silent
    npm run dev
  ) > "$LOGS_DIR/backend.log" 2>&1 &
  PIDS+=($!)
  wait_for_port 3001 "Backend"
}

# ── Background Worker ──────────────────────────
start_worker() {
  echo -e "${BLUE}▶  Starting Background Worker (combined: scheduler + extraction)...${NC}"
  (
    cd "$ROOT_DIR/Legal-Case-Management-System" || exit 1
    npm run worker
  ) > "$LOGS_DIR/worker.log" 2>&1 &
  PIDS+=($!)
  echo -e "  Worker started ${GREEN}(PID: ${PIDS[$((${#PIDS[@]}-1))]})${NC}"
}

# ── AI Microservice ────────────────────────────
start_ai() {
  echo -e "${BLUE}▶  Starting AI Microservice (port 8000)...${NC}"
  (
    cd "$ROOT_DIR/Legal-Case-Management-System-AI-Microservice" || exit 1
    # Pin to python3.13 — `python3` on this machine resolves to 3.14, which
    # numpy 2.x supports but torch's prebuilt wheels do not (yet). 3.13 has
    # wheels for everything in requirements.txt.
    PYTHON_BIN="${PYTHON_BIN:-python3.13}"
    if [ ! -d "venv" ]; then
      "$PYTHON_BIN" -m venv venv
    fi
    # shellcheck disable=SC1091
    source venv/bin/activate
    pip install -r requirements.txt -q
    cd ai_service || exit 1
    uvicorn app.main:app --port 8000
  ) > "$LOGS_DIR/ai.log" 2>&1 &
  PIDS+=($!)
  # 120s — first boot loads the BGE-M3 model (~50s cold). Subsequent boots are faster.
  wait_for_port 8000 "AI Service" 120
}

# ── Frontend ───────────────────────────────────
start_frontend() {
  echo -e "${BLUE}▶  Starting Frontend (port 3000)...${NC}"
  (
    cd "$ROOT_DIR/Legal_Case_Management_Website" || exit 1
    npm install --silent
    npm run dev
  ) > "$LOGS_DIR/frontend.log" 2>&1 &
  PIDS+=($!)
  wait_for_port 3000 "Frontend"
}

# ── Main ───────────────────────────────────────
echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
echo -e "${BOLD}${GREEN}   Silah-Legal — Starting All Services  ${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
echo ""

start_backend
start_worker
start_ai
start_frontend

echo ""
echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
echo -e "${BOLD}  All services are up!${NC}"
echo -e "${BOLD}${GREEN}════════════════════════════════════════${NC}"
echo ""
echo -e "  ${BLUE}Frontend:${NC}        http://localhost:3000"
echo -e "  ${BLUE}Backend API:${NC}     http://localhost:3001"
echo -e "  ${BLUE}API Docs:${NC}        http://localhost:3001/docs"
echo -e "  ${BLUE}AI Microservice:${NC} http://localhost:8000"
echo -e "  ${BLUE}AI Docs:${NC}         http://localhost:8000/docs"
echo ""
echo -e "  Logs → ${YELLOW}.logs/${NC}"
echo -e "    backend.log  |  worker.log  |  ai.log  |  frontend.log"
echo ""
echo -e "  Press ${BOLD}Ctrl+C${NC} to stop all services."
echo ""

# Keep script alive and stream a combined tail of all logs
tail -f "$LOGS_DIR/backend.log" "$LOGS_DIR/worker.log" "$LOGS_DIR/ai.log" "$LOGS_DIR/frontend.log" &
TAIL_PID=$!
PIDS+=($TAIL_PID)

wait
