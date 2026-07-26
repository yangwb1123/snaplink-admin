#!/bin/bash
# sso-console 一键开发启动脚本
#
# Usage:
#   ./dev.sh             启动后端 + 构建 + 代理
#   ./dev.sh --quick     跳过构建，直接启动代理
#   ./dev.sh --build     强制重建 Flutter 并启动代理
#   ./dev.sh --test      运行测试套件
#   ./dev.sh --clean     清理构建产物

set -e

cd "$(dirname "$0")"

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

info()  { echo -e "${GREEN}[INFO]${NC} $1"; }
warn()  { echo -e "${YELLOW}[WARN]${NC} $1"; }
error() { echo -e "${RED}[ERROR]${NC} $1"; }

case "${1:-}" in
  --clean)
    info "Cleaning build artifacts..."
    rm -rf build/web
    info "Done."
    exit 0
    ;;
  --test)
    info "Running test suite..."
    make test
    info "Tests complete."
    exit 0
    ;;
  --quick)
    WARN_SKIP_BUILD=true
    ;;
  --build)
    FORCE_BUILD=true
    ;;
  *)
    # Default: check if build exists
    if [ ! -d "build/web" ]; then
      FORCE_BUILD=true
    fi
    ;;
esac

# Check prerequisites
command -v flutter >/dev/null 2>&1 || { error "Flutter is required but not installed."; exit 1; }
command -v python3 >/dev/null 2>&1 || { error "Python 3 is required but not installed."; exit 1; }

# Check if snaplink backend is running
if curl -s --max-time 2 http://localhost:8080/health > /dev/null 2>&1; then
  info "snaplink backend is running on :8080"
else
  warn "snaplink backend is NOT running on :8080"
  warn "Start it first or some features will be unavailable."
  echo ""
fi

# Build Flutter if needed
if [ "${FORCE_BUILD:-false}" = "true" ] || [ "${WARN_SKIP_BUILD:-false}" != "true" ]; then
  info "Building Flutter web app..."
  flutter build web --release 2>&1 | tail -3
  info "Build complete."
  echo ""
fi

# Kill existing proxy
kill $(lsof -ti:4444) 2>/dev/null || true
sleep 1

# Start proxy
info "Starting proxy on http://localhost:4444"
python3 tools/robust_proxy.py &
PID=$!
sleep 2

# Verify proxy
if curl -s --max-time 3 -o /dev/null -w '%{http_code}' http://localhost:4444/ 2>/dev/null | grep -q 200; then
  info "Proxy is ready: http://localhost:4444"
  info "Login: admin / admin"
  echo ""
  info "Press Ctrl+C to stop."
else
  warn "Proxy may not have started correctly. Check tools/robust_proxy.py"
fi

# Wait for proxy to exit
wait $PID 2>/dev/null
