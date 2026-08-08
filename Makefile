.PHONY: build build-prod test test-browser guard-count-pin analyze k8s-render serve clean watch verify benchmark full-stack integration

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

# B6-1b artifact gate: the old ring-scoped copy, the audit-ring storage
# key, and its base64/base64Url masks must be absent from the release web
# bundle (run after build-prod in CI). Fail-closed: the explicit `test -d`
# guard is the mechanism — a grep failure inside $() is swallowed by the
# command substitution either way, so a missing artifact must be caught
# before any needle runs; the bundle is searched recursively (grep -r) so
# a chunked build cannot silently widen the surface.
#
# Count semantics: `grep -oF | wc -l` counts OCCURRENCES, not lines
# (W-3/W-4) — dart2js may emit several occurrences on one line. The
# sso_audit_log pre-seam baseline is exactly 2 occurrences (one const
# per use site: setItem/getItem); the gate requires 0, so it is red
# until the storage seam lands (W-1/W-2 — the gate must not be green
# independent of the seam).
#
# En needles and the key-mask encodings are the stable pins; escaped-zh
# variants are advisory (dart2js escaping may change with the toolchain).
release-artifact-check:
	@set -eu; \
	test -d build/web || { echo 'FAIL: build/web missing — run `make build-prod` first'; exit 1; }; \
	test "$$(grep -rI -oF 'Clear audit log?' build/web/ | wc -l)" = "0" || { echo 'FAIL: "Clear audit log?" still in release bundle'; exit 1; }; \
	test "$$(grep -rI -oF 'local audit entries' build/web/ | wc -l)" = "0" || { echo 'FAIL: "local audit entries" still in release bundle'; exit 1; }; \
	test "$$(grep -rI -oF 'Clear log' build/web/ | wc -l)" = "0" || { echo 'FAIL: "Clear log" still in release bundle'; exit 1; }; \
	test "$$(grep -rI -oF 'sso_audit_log' build/web/ | wc -l)" = "0" || { echo 'FAIL: "sso_audit_log" still in release bundle (storage seam not landed?)'; exit 1; }; \
	test "$$(grep -rI -oF 'c3NvX2F1ZGl0X2xvZw==' build/web/ | wc -l)" = "0" || { echo 'FAIL: base64(sso_audit_log) mask still in release bundle'; exit 1; }; \
	test "$$(grep -rI -oF 'c3NvX2F1ZGl0X2xvZw' build/web/ | wc -l)" = "0" || { echo 'FAIL: base64Url(sso_audit_log) mask still in release bundle'; exit 1; }; \
	test "$$(grep -rI -oF '\u6e05\u7a7a\u5ba1\u8ba1' build/web/ | wc -l)" = "0" || { echo 'FAIL: escaped-zh 清空审计 still in release bundle'; exit 1; }; \
	test "$$(grep -rI -oF '\u672c\u5730\u5ba1\u8ba1' build/web/ | wc -l)" = "0" || { echo 'FAIL: escaped-zh 本地审计 still in release bundle'; exit 1; }; \
	test "$$(grep -rI -oF '\u6e05\u9664\u65e5\u5fd7' build/web/ | wc -l)" = "0" || { echo 'FAIL: escaped-zh 清除日志 still in release bundle'; exit 1; }; \
	echo "release artifact check: OK (ring-scoped copy, storage key and masks absent from the release bundle)"

# 运行所有单元测试
test:
	flutter test
	python3 -m unittest discover -s tests/unit -p 'test_*.py'

# ── G7 (B6-1) executable count pin — closes the F8 silent-regression class ──
# The four-file guard suite must report EXACTLY +$(GUARD_PIN_COUNT) on the
# VM platform, per implementation-gate.md G7 row (`flutter test … -r
# expanded`; breakdown guard 38 + mutation 42 + developer guard 1 + oidc
# guard 1 = 82, 2026-08-08 re-measured — the mutation-gap work landed its
# 3 rows: guard probe 4 (mid-identifier canary), the _scanWith
# second-consumer dispatch-branch pin, and the scan 6/6b residual row).
# Fail-closed: numeric equality on the expanded reporter's summary line
# reds on (a) a deleted guard test, (b) a @TestOn platform-mismatch
# silently dropping a file (green exit code — exit code alone cannot
# catch it, gate doc M5), and (c) any added test that forgets to re-pin
# the G7 row together with this target.
# Platform caveat: the command MUST run on the default VM platform (no
# --platform chrome) — the developer/oidc guards and the scans helper are
# @TestOn('vm')/dart:io and silently skip or fail to compile off-VM.
# Any future change to the four files must re-measure with `-r expanded`
# and bump GUARD_PIN_COUNT and the implementation-gate.md G7 row TOGETHER.
GUARD_PIN_FILES = test/audit_contract_guard_test.dart test/audit_contract_guard_mutation_test.dart test/developer_audit_visibility_guard_test.dart test/oidc_login_audit_visibility_guard_test.dart
GUARD_PIN_COUNT ?= 82
guard-count-pin:
	@set -eu; \
	out="$$(flutter test $(GUARD_PIN_FILES) -r expanded 2>&1)"; \
	count="$$(printf '%s\n' "$$out" | sed -nE 's/^.*\+([0-9]+): All tests passed!$$/\1/p' | tail -1)"; \
	if [ -z "$$count" ]; then printf '%s\n' "$$out" >&2; echo 'FAIL: guard suite did not report "All tests passed!" (compile error or test failure)' >&2; exit 1; fi; \
	if [ "$$count" -ne "$(GUARD_PIN_COUNT)" ]; then printf '%s\n' "$$out" >&2; echo "FAIL: guard suite count +$$count != +$(GUARD_PIN_COUNT) (G7 pin — implementation-gate.md G7 row; re-measure with -r expanded and re-pin the G7 row and this target together)" >&2; exit 1; fi; \
	echo "guard count pin: OK (+$$count: All tests passed!)"

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
	PYENV_VERSION=3.12.9 python3 tools/ai-dev-gates/check-ui-spec.py --dir lib --all --json -o /tmp/snap-ui-report.json
	@echo "UI spec gate: OK (see /tmp/snap-ui-report.json)"

# 前端工程质量门禁：console.log/any/吞异常/测试跳过（恒失败项）
ui-quality:
	PYENV_VERSION=3.12.9 python3 tools/ai-dev-gates/check-frontend-quality.py --dir lib --json -o /tmp/snap-quality.json
	@echo "UI quality gate: OK (see /tmp/snap-quality.json)"

# 深度工程审计（上帝文件/复杂度/嵌套——需人工评审后逐步清零）
ui-quality-strict:
	PYENV_VERSION=3.12.9 python3 tools/ai-dev-gates/check-frontend-quality.py --dir lib --strict --json -o /tmp/snap-quality-strict.json
	@echo "Strict audit: see /tmp/snap-quality-strict.json"

# 一键规范自检（接入 ci 前可手工运行）
spec-check: ui-check ui-quality
	@echo "Spec gates passed"
