.PHONY: build build-prod test test-browser analyze k8s-render serve clean watch verify benchmark full-stack integration

SNAPLINK_API_URL ?= http://localhost:8080
SNAPLINK_PROXY_PORT ?= 4444
SNAPLINK_ADMIN_OAUTH_RESOURCES ?= billing-api,stripe-adapter-api

# ═══════════════════════════════════════════
# sso-console 开发命令
# ═══════════════════════════════════════════

# 构建 Flutter Web 应用
build:
	flutter build web --release --dart-define='SNAPLINK_ADMIN_OAUTH_RESOURCES=$(SNAPLINK_ADMIN_OAUTH_RESOURCES)'

# 构建与生产网关约定一致的 /app/ 静态资源
build-prod:
	flutter build web --release --base-href=/app/ --dart-define='SNAPLINK_ADMIN_OAUTH_RESOURCES=$(SNAPLINK_ADMIN_OAUTH_RESOURCES)'

# 运行所有单元测试
test:
	flutter test
	python3 -m unittest discover -s tests/unit -p 'test_*.py'

# 在真实浏览器运行全部 @TestOn('browser') 契约（适配层、联邦登录、
# 账户 action、门户安全与 Admin → hosted-login resource 传递）
test-browser:
	flutter test --platform chrome test/admin_gate_test.dart test/browser_navigation_web_test.dart test/federated_login_web_test.dart test/oidc_account_action_web_test.dart test/portal_security_web_test.dart test/web_adapters_test.dart

# 静态分析
analyze:
	flutter analyze

# Render both production profiles without contacting a Kubernetes API server.
k8s-render:
	kubectl kustomize k8s/minimal >/dev/null
	kubectl kustomize k8s/full >/dev/null

# 启动开发代理服务器
serve:
	@echo "Starting proxy on http://localhost:$(SNAPLINK_PROXY_PORT)..."
	@fuser -k $(SNAPLINK_PROXY_PORT)/tcp 2>/dev/null || true
	@sleep 1
	@PORT=$(SNAPLINK_PROXY_PORT) BACKEND=$(SNAPLINK_API_URL) python3 tools/robust_proxy.py

# 清理构建产物
clean:
	rm -rf build/web

# 持续构建（监听文件变化）
watch:
	flutter build web --release
	@echo "Watching for changes... (Ctrl+C to stop)"
	@while true; do \
		inotifywait -q -e modify -r lib/ 2>/dev/null || fswatch -1 lib/ 2>/dev/null || sleep 10; \
		flutter build web --release 2>&1 | tail -1; \
	done

# 运行全量验证
verify: analyze build-prod test
	@echo "\n=== Running integration tests ==="
	python3 tests/integration/full_integration_test.py
	@echo "\n=== Running E2E tests ==="
	python3 tests/integration/e2e_runner.py --ci

# 性能基准测试
benchmark:
	python3 tests/integration/perf_benchmark.py

# 集成测试（需后端运行在 :8080）
integration:
	python3 tests/integration/full_integration_test.py

# 全栈验证（需先启动后端和代理）
full-stack:
	python3 tests/integration/full_stack_verify.py --quick

# ── AI 生成规范门禁（由 ai-batch-runner 的检查器驱动，dogfooding）──
# 魔法间距/硬编码颜色/inline style：项目级扫描，违规 exit 1
ui-check:
	PYENV_VERSION=3.12.9 python3 $(HOME)/ai-batch-runner/scripts/check-ui-spec.py --dir lib --all --json -o /tmp/snap-ui-report.json
	@echo "UI spec gate: OK (see /tmp/snap-ui-report.json)"

# 前端工程质量门禁：console.log/any/吞异常/测试跳过（恒失败项）
ui-quality:
	PYENV_VERSION=3.12.9 python3 $(HOME)/ai-batch-runner/scripts/check-frontend-quality.py --dir lib --json -o /tmp/snap-quality.json
	@echo "UI quality gate: OK (see /tmp/snap-quality.json)"

# 深度工程审计（上帝文件/复杂度/嵌套——需人工评审后逐步清零）
ui-quality-strict:
	PYENV_VERSION=3.12.9 python3 $(HOME)/ai-batch-runner/scripts/check-frontend-quality.py --dir lib --strict --json -o /tmp/snap-quality-strict.json
	@echo "Strict audit: see /tmp/snap-quality-strict.json"

# 一键规范自检（接入 ci 前可手工运行）
spec-check: ui-check ui-quality
	@echo "Spec gates passed"
