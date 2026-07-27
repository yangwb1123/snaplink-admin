.PHONY: build test analyze serve clean watch verify benchmark full-stack integration

# ═══════════════════════════════════════════
# sso-console 开发命令
# ═══════════════════════════════════════════

# 构建 Flutter Web 应用
build:
	flutter build web --release

# 运行所有单元测试
test:
	flutter test

# 静态分析
analyze:
	flutter analyze

# 启动开发代理服务器
serve:
	@echo "Starting proxy on http://localhost:4444..."
	@fuser -k 4444/tcp 2>/dev/null || true
	@sleep 1
	@python3 tools/robust_proxy.py

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
verify: analyze build test
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
