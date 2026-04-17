#!/usr/bin/env bash
# AutoDeploy — Teacher Demo & Test Script
# Run this to prove everything works: ./demo-test.sh

set -euo pipefail

GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
BOLD='\033[1m'
NC='\033[0m'

pass() { echo -e "${GREEN}  PASS${NC}  $1"; }
fail() { echo -e "${RED}  FAIL${NC}  $1"; FAILED=$((FAILED+1)); }
info() { echo -e "${BLUE}  ....${NC}  $1"; }
head() { echo -e "\n${BOLD}${YELLOW}$1${NC}"; echo "  $(printf '─%.0s' {1..50})"; }

FAILED=0
BASE="http://localhost:3000"

clear
echo -e "${BOLD}"
cat << 'BANNER'
  ╔══════════════════════════════════════════════════╗
  ║       AutoDeploy — Live Demo Test Suite          ║
  ║       CI/CD with Docker & Jenkins                ║
  ╚══════════════════════════════════════════════════╝
BANNER
echo -e "${NC}"

# ── 1. Docker checks ──────────────────────────────────────────
head "1. Docker environment"

if docker info &>/dev/null; then
  pass "Docker is running"
else
  fail "Docker is NOT running — start Docker Desktop first"
  exit 1
fi

if docker ps --format '{{.Names}}' | grep -q "autodeploy-web"; then
  pass "autodeploy-web container is running"
else
  fail "App container not running — run: docker-compose up --build"
  exit 1
fi

IMG=$(docker images autodeploy-app --format "{{.Repository}}:{{.Tag}}" | head -1)
if [ -n "$IMG" ]; then
  pass "Docker image found: $IMG"
else
  fail "No autodeploy-app image found"
fi

# ── 2. Health endpoint ────────────────────────────────────────
head "2. /health endpoint"
sleep 1

HTTP_CODE=$(curl -s -o /tmp/ad_health.json -w "%{http_code}" "$BASE/health" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  pass "GET /health → 200 OK"
else
  fail "GET /health → $HTTP_CODE (expected 200)"
fi

STATUS=$(cat /tmp/ad_health.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('status','?'))" 2>/dev/null || echo "?")
if [ "$STATUS" = "healthy" ]; then
  pass "Health status = \"healthy\""
else
  fail "Health status = \"$STATUS\" (expected \"healthy\")"
fi

UPTIME=$(cat /tmp/ad_health.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(round(d.get('uptime',0)))" 2>/dev/null || echo "0")
pass "Server uptime = ${UPTIME}s"

VERSION=$(cat /tmp/ad_health.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('version','?'))" 2>/dev/null || echo "?")
BUILD=$(cat /tmp/ad_health.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('build','?'))" 2>/dev/null || echo "?")
info "Version: $VERSION  |  Build: $BUILD"

# ── 3. API message endpoint ───────────────────────────────────
head "3. /api/message endpoint"

HTTP_CODE=$(curl -s -o /tmp/ad_msg.json -w "%{http_code}" "$BASE/api/message" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  pass "GET /api/message → 200 OK"
else
  fail "GET /api/message → $HTTP_CODE"
fi

MSG=$(cat /tmp/ad_msg.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('message','?')[:60])" 2>/dev/null || echo "?")
pass "Message: \"$MSG\""

ENV=$(cat /tmp/ad_msg.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('environment','?'))" 2>/dev/null || echo "?")
pass "Environment: $ENV"

# ── 4. API status endpoint ────────────────────────────────────
head "4. /api/status endpoint"

HTTP_CODE=$(curl -s -o /tmp/ad_status.json -w "%{http_code}" "$BASE/api/status" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  pass "GET /api/status → 200 OK"
else
  fail "GET /api/status → $HTTP_CODE"
fi

NODE=$(cat /tmp/ad_status.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('node','?'))" 2>/dev/null || echo "?")
PLAT=$(cat /tmp/ad_status.json 2>/dev/null | python3 -c "import sys,json; d=json.load(sys.stdin); print(d.get('platform','?'))" 2>/dev/null || echo "?")
pass "Node $NODE running on $PLAT"

# ── 5. Frontend ───────────────────────────────────────────────
head "5. Frontend (dashboard UI)"

HTTP_CODE=$(curl -s -o /tmp/ad_front.html -w "%{http_code}" "$BASE/" 2>/dev/null || echo "000")
if [ "$HTTP_CODE" = "200" ]; then
  pass "GET / → 200 OK (frontend served)"
else
  fail "GET / → $HTTP_CODE"
fi

if grep -q "AutoDeploy" /tmp/ad_front.html 2>/dev/null; then
  pass "HTML contains AutoDeploy app"
else
  fail "HTML missing expected content"
fi

# ── 6. Container health ───────────────────────────────────────
head "6. Container internals"

CONTAINER_STATUS=$(docker inspect autodeploy-web --format '{{.State.Health.Status}}' 2>/dev/null || echo "no-healthcheck")
if [ "$CONTAINER_STATUS" = "healthy" ] || [ "$CONTAINER_STATUS" = "no-healthcheck" ]; then
  pass "Container state: $CONTAINER_STATUS"
else
  fail "Container health: $CONTAINER_STATUS"
fi

RESTART_COUNT=$(docker inspect autodeploy-web --format '{{.RestartCount}}' 2>/dev/null || echo "?")
if [ "$RESTART_COUNT" = "0" ]; then
  pass "Container restart count: 0 (stable)"
else
  info "Container restart count: $RESTART_COUNT"
fi

PORT_MAP=$(docker port autodeploy-web 2>/dev/null | head -1 || echo "not mapped")
pass "Port mapping: $PORT_MAP"

# ── 7. Jenkins (optional) ─────────────────────────────────────
head "7. Jenkins (optional — skip if not set up)"

if docker ps --format '{{.Names}}' | grep -q "jenkins-autodeploy"; then
  pass "Jenkins container is running"
  J_CODE=$(curl -s -o /dev/null -w "%{http_code}" "http://localhost:8080/login" 2>/dev/null || echo "000")
  if [ "$J_CODE" = "200" ]; then
    pass "Jenkins UI reachable at http://localhost:8080"
  else
    info "Jenkins returned HTTP $J_CODE"
  fi
else
  info "Jenkins not running (optional — skipped)"
  info "To start Jenkins: docker-compose -f jenkins/docker-compose.jenkins.yml up -d"
fi

# ── Summary ───────────────────────────────────────────────────
echo ""
echo -e "${BOLD}$(printf '═%.0s' {1..54})${NC}"
if [ "$FAILED" -eq 0 ]; then
  echo -e "${GREEN}${BOLD}  ALL TESTS PASSED  —  Project is fully working!${NC}"
  echo ""
  echo -e "  ${BOLD}Show your teacher:${NC}"
  echo -e "  • Dashboard     →  http://localhost:3000"
  echo -e "  • Health check  →  http://localhost:3000/health"
  echo -e "  • API           →  http://localhost:3000/api/message"
  echo -e "  • Jenkins UI    →  http://localhost:8080"
  echo -e "  • Docker image  →  docker images autodeploy-app"
  echo -e "  • Live logs     →  docker logs autodeploy-web --follow"
else
  echo -e "${RED}${BOLD}  $FAILED TEST(S) FAILED${NC}"
  echo -e "  Check the errors above and fix before your demo."
fi
echo -e "${BOLD}$(printf '═%.0s' {1..54})${NC}"
echo ""
