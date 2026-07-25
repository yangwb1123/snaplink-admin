#!/bin/bash
# Start snaplink backend + sso-console proxy for local development

echo "✦ sso-console 开发环境 ✦"
echo "============================================"

# Check if snaplink is running
if ! curl -s http://localhost:8080/health > /dev/null 2>&1; then
    echo "⚠️  snaplink 后端未运行!"
    echo "   请先在 snaplink 目录执行: make dev 或启动 sso-server"
    echo ""
    echo "或者直接测试后台 API (无需前端):"
    echo "  curl http://localhost:8080/health"
    exit 1
fi

echo "✅ snaplink 后端运行中 (端口 8080)"

# Check if proxy is already running
if curl -s http://localhost:4444/ > /dev/null 2>&1; then
    echo "✅ sso-console 代理运行中 (端口 4444)"
else
    echo "启动代理服务器..."
    cd "$(dirname "$0")"
    python3 /tmp/proxy_final.py &
    PROXY_PID=$!
    sleep 2
    if curl -s http://localhost:4444/ > /dev/null 2>&1; then
        echo "✅ 代理服务器已启动 (PID: $PROXY_PID)"
    else
        echo "❌ 代理服务器启动失败"
        exit 1
    fi
fi

echo ""
echo "============================================"
echo "访问地址:"
echo "  🔗 http://localhost:4444  (sso-console 管理界面)"
echo "  🔗 http://localhost:8080  (snaplink API)"
echo ""
echo "登录凭据: admin / admin"
echo "============================================"

# Run the integration test
echo ""
echo "运行集成测试..."
cd "$(dirname "$0")"
python3 tests/integration/full_integration_test.py
