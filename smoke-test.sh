#!/bin/sh
# Smoke test for plex + mcp-plex stack
# Usage: ./smoke-test.sh

set -e

# Load .env if present
if [ -f "$(dirname "$0")/.env" ]; then
    export $(grep -v '^#' "$(dirname "$0")/.env" | grep -v '^\s*$' | xargs)
fi

PLEX_URL="http://localhost:32400"
MCP_URL="http://localhost:${MCP_PLEX_PORT:-9102}"
API_KEY="${MCP_API_KEY}"
PASS=0
FAIL=0

check() {
    label="$1"
    shift
    if "$@" > /dev/null 2>&1; then
        printf "  PASS  %s\n" "$label"
        PASS=$((PASS + 1))
    else
        printf "  FAIL  %s\n" "$label"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Plex Stack Smoke Test ==="
echo ""

# --- Plex ---
echo "[plex]"
check "Plex /identity reachable" \
    curl -sf --max-time 5 "$PLEX_URL/identity"

check "Plex web UI reachable" \
    curl -sf --max-time 5 -o /dev/null "$PLEX_URL/web/index.html"

# --- mcp-plex ---
echo ""
echo "[mcp-plex]"
check "Health endpoint returns 200" \
    curl -sf --max-time 5 "$MCP_URL/health"

check "/mcp rejects unauthenticated POST (401)" \
    sh -c "code=\$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 -X POST -H 'Content-Type: application/json' -H 'Accept: application/json' -d '{}' '$MCP_URL/mcp'); [ \"\$code\" = '401' ]"

if [ -n "$API_KEY" ] && [ "$API_KEY" != "REPLACE_ME" ]; then
    check "/mcp accepts valid Bearer token" \
        curl -sf --max-time 5 -X POST \
            -H "Authorization: Bearer $API_KEY" \
            -H "Content-Type: application/json" \
            -H "Accept: application/json" \
            -d '{"jsonrpc":"2.0","id":1,"method":"initialize","params":{"protocolVersion":"2025-03-26","capabilities":{},"clientInfo":{"name":"smoke-test","version":"1.0"}}}' \
            "$MCP_URL/mcp"
else
    printf "  SKIP  /mcp auth test (MCP_API_KEY not set or placeholder)\n"
fi

# --- GPU ---
echo ""
echo "[gpu]"
check "nvidia-smi inside plex container" \
    docker exec plex nvidia-smi

# --- Docker health ---
echo ""
echo "[docker]"
check "plex container healthy" \
    sh -c "[ \"$(docker inspect --format='{{.State.Health.Status}}' plex 2>/dev/null)\" = 'healthy' ]"

check "mcp-plex container healthy" \
    sh -c "[ \"$(docker inspect --format='{{.State.Health.Status}}' mcp-plex 2>/dev/null)\" = 'healthy' ]"

# --- Network ---
echo ""
echo "[network]"
check "mcp-plex on mcp-net" \
    sh -c "docker inspect mcp-plex --format='{{json .NetworkSettings.Networks}}' | grep -q mcp-net"

check "mcp-plex on plex-internal" \
    sh -c "docker inspect mcp-plex --format='{{json .NetworkSettings.Networks}}' | grep -q plex-internal"

# --- Summary ---
echo ""
echo "=== Results: $PASS passed, $FAIL failed ==="
[ "$FAIL" -eq 0 ] && exit 0 || exit 1
