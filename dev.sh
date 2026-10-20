#!/bin/bash
# sso-console 一键开发启动脚本
#
# Usage:
#   ./dev.sh             构建 + 启动代理（不启动或替换身份后端）
#   ./dev.sh --quick     跳过构建，直接启动代理
#   ./dev.sh --build     强制重建 Flutter 并启动代理
#   ./dev.sh --test      运行测试套件
#   ./dev.sh --clean     清理构建产物

set -euo pipefail

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

# Match the proxy's environment precedence; never select another identity instance.
BACKEND="${BACKEND-${SNAPLINK_API_URL-${SNAPLINK_UPSTREAM-http://localhost:8080}}}"
PORT="${PORT-${SNAPLINK_PROXY_PORT-4444}}"
export BACKEND PORT
if python3 tools/check_browser_sso_deployment.py --origin "$BACKEND" --health-only; then
  info "Configured snaplink backend reports healthy."
else
  warn "Configured snaplink backend health is unavailable or invalid."
  warn "Continuing with the UI proxy only; this is NOT backend/SSO readiness."
  echo ""
fi

# Build Flutter if needed
if [ "${FORCE_BUILD:-false}" = "true" ] || [ "${WARN_SKIP_BUILD:-false}" != "true" ]; then
  info "Building Flutter web app for local development..."
  # Release, not debug: a debug bundle is unoptimized (much larger JS, slower
  # first frame and runtime), and dev.sh serves it statically through the
  # proxy — there is no hot reload to justify debug artifacts here. Use
  # `flutter run` directly for hot-reload iteration.
  python3 tools/web_font_assets.py
  flutter build web --release \
    --no-web-resources-cdn 2>&1 | tail -3
  info "Build complete."
  echo ""
fi

# Bind atomically in the foreground. A busy port fails without touching its owner.
info "Starting proxy; the listener will report its bound port."
info "Press Ctrl+C to stop."
exec python3 tools/robust_proxy.py
