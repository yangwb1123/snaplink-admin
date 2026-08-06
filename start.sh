#!/bin/bash
# sso-console development server
# Usage: ./start.sh [--build] [--prod]
#   --build  Force rebuild the Flutter web app
#   --prod   Kill existing proxy and restart fresh

set -e

cd "$(dirname "$0")"

SNAPLINK_PROXY_PORT="${SNAPLINK_PROXY_PORT:-4444}"
SNAPLINK_API_URL="${SNAPLINK_API_URL:-http://localhost:8080}"
case "$SNAPLINK_PROXY_PORT" in
  *[!0-9]*|'')
    echo "SNAPLINK_PROXY_PORT must be a numeric TCP port" >&2
    exit 2
    ;;
esac

if [ "$1" = "--prod" ] || [ "$2" = "--prod" ]; then
  echo "🔄 Killing existing proxy on :${SNAPLINK_PROXY_PORT}..."
  fuser -k "${SNAPLINK_PROXY_PORT}/tcp" 2>/dev/null || true
  sleep 1
fi

if [ "$1" = "--build" ] || [ "$2" = "--build" ] || [ ! -d "build/web" ]; then
  echo "⚙️  Building Flutter web app..."
  flutter build web --release 2>&1 | tail -3
  echo "✅ Build complete"
  echo ""
fi

echo "🚀 Starting proxy on http://localhost:${SNAPLINK_PROXY_PORT}"
echo "   API backend: ${SNAPLINK_API_URL}"
echo ""

# Check if snaplink is running
if ! curl -s --max-time 2 "${SNAPLINK_API_URL}/health" > /dev/null 2>&1; then
  echo "⚠️  snaplink backend is not reachable at ${SNAPLINK_API_URL}"
  echo "   Start it first: cd ../snaplink && /tmp/sso-srv -config ./cmd/sso-server/config.yaml &"
  echo ""
fi

# Clean up old proxy output
touch /tmp/sso-console-proxy.log

# Start proxy in background with auto-restart
PORT="$SNAPLINK_PROXY_PORT" BACKEND="$SNAPLINK_API_URL" \
  python3 tools/robust_proxy.py &
PID=$!
echo "📋 Proxy PID: $PID"
echo "    Logs: /tmp/sso-console-proxy.log"
wait $PID
