#!/bin/bash
# sso-console development server
# Usage: ./start.sh [--build] [--prod]
#   --build  Force rebuild the Flutter web app
#   --prod   Kill existing proxy and restart fresh

set -e

cd "$(dirname "$0")"

if [ "$1" = "--prod" ] || [ "$2" = "--prod" ]; then
  echo "🔄 Killing existing proxy on :4444..."
  fuser -k 4444/tcp 2>/dev/null || true
  sleep 1
fi

if [ "$1" = "--build" ] || [ "$2" = "--build" ] || [ ! -d "build/web" ]; then
  echo "⚙️  Building Flutter web app..."
  flutter build web --release 2>&1 | tail -3
  echo "✅ Build complete"
  echo ""
fi

echo "🚀 Starting proxy on http://localhost:4444"
echo "   API backend: http://localhost:8080"
echo "   Login: admin / admin"
echo ""

# Check if snaplink is running
if ! curl -s --max-time 2 http://localhost:8080/health > /dev/null 2>&1; then
  echo "⚠️  snaplink backend not running on :8080"
  echo "   Start it first: cd ../snaplink && /tmp/sso-srv -config ./cmd/sso-server/config.yaml &"
  echo ""
fi

# Clean up old proxy output
touch /tmp/sso-console-proxy.log

# Start proxy in background with auto-restart
python3 tools/robust_proxy.py &
PID=$!
echo "📋 Proxy PID: $PID"
echo "    Logs: /tmp/sso-console-proxy.log"
wait $PID
