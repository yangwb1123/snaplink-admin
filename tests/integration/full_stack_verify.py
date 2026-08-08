#!/usr/bin/env python3
"""
sso-console 全栈完整验证
从零开始：构建 → 启动代理 → 运行全部测试套件

Usage: python3 tests/integration/full_stack_verify.py [--quick]
"""
import subprocess, sys, os, time, json, argparse
from test_config import CONFIG

os.chdir(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))

PASS = 0; FAIL = 0; SKIP = 0; RESULTS = []


def step(name, cmd, timeout=300, skip_markers=()):
    """Run one verification step; record result.

    skip_markers: substrings that demote an exit-0 run to SKIP instead
    of PASS (a drill exiting 0 on [proposed] legs is not a pass)."""
    global PASS, FAIL, SKIP
    print(f"\n  🔄 {name}...")
    sys.stdout.flush()
    try:
        r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        ok = r.returncode == 0
        # Show key output
        for line in (r.stdout or '').split('\n')[-5:]:
            stripped = line.strip()
            if stripped and len(stripped) < 120:
                print(f"    {stripped}")
        if ok and skip_markers and any(m in (r.stdout or '') for m in skip_markers):
            SKIP += 1; print(f"  ⏭️ {name} (exit 0 但命中 SKIP 标记)")
        elif ok:
            PASS += 1; print(f"  ✅ {name}")
        else:
            FAIL += 1; print(f"  ❌ {name} (code={r.returncode})")
            for line in (r.stderr or '').split('\n')[-3:]:
                if line.strip():
                    print(f"    ! {line.strip()[:100]}")
        RESULTS.append({'name': name, 'ok': ok, 'skipped': ok and bool(skip_markers)})
        return ok
    except subprocess.TimeoutExpired:
        FAIL += 1; print(f"  ❌ {name} (timeout)")
        RESULTS.append({'name': name, 'ok': False, 'skipped': False})
        return False

def _gates_and_build(args) -> None:
    """Step 1-3: engineering gates, build, selected Flutter tests."""
    if args.quick:
        return
    print("\n【步骤 1/6: 工程门禁】")
    step('Filesize', ['python3', 'cli.py', 'check-filesize'], 30)
    step('Complexity', ['python3', 'cli.py', 'complexity'], 60)
    step('Architecture', ['python3', 'cli.py', 'architecture'], 30)
    step('Directory Fan-out', ['python3', 'cli.py', 'directory-fanout'], 30)
    step('Root Policy', ['python3', 'cli.py', 'root-policy'], 30)
    step('Invariants', ['python3', 'cli.py', 'invariants'], 30)

    print("\n【步骤 2/6: Flutter 构建】")
    step('Flutter Build', ['python3', 'cli.py', 'build'], 180)

    print("\n【步骤 3/6: Flutter 测试】")
    for test_file in ['test/admin_route_test.dart', 'test/shared_widgets_test.dart']:
        step(f'Flutter Test: {test_file}', ['flutter', 'test', test_file], 60)


def _start_proxy():
    """Start the local dev proxy; returns the Popen handle or None."""
    if not CONFIG.manages_local_proxy:
        return None
    subprocess.run(
        ['fuser', '-k', f'{CONFIG.proxy_port}/tcp'], capture_output=True
    )
    time.sleep(2)
    proxy = subprocess.Popen(
        ['python3', 'tools/robust_proxy.py'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=CONFIG.proxy_environment(),
    )
    time.sleep(3)
    return proxy


def _verify_proxy() -> bool:
    """Step 4: start the proxy and verify it answers 200 on /."""
    global PASS, FAIL
    print("\n【步骤 4/6: 启动代理】")
    proxy = _start_proxy()
    curl_check = subprocess.run(
        ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', '--max-time', '5',
         f'{CONFIG.proxy_url}/'],
        capture_output=True, text=True, timeout=10
    )
    if curl_check.stdout.strip() == '200':
        PASS += 1; print("  ✅ 代理启动成功")
    else:
        FAIL += 1; print(f"  ❌ 代理启动失败 ({curl_check.stdout.strip()})")
    return proxy


def _api_tests() -> None:
    """Step 5: API integration tests + the B6-2 drill (SKIP-aware)."""
    print("\n【步骤 5/6: API 集成测试】")
    step('Full Integration (80 tests)', 
         ['python3', 'tests/integration/full_integration_test.py'], 120)
    step('Detail API (28 tests)',
         ['python3', 'tests/integration/detail_api_test.py'], 60)
    # B6-2 client_id contract drill (device redirect-leg facts).
    # SKIP markers: exit-0 [proposed] legs are SKIP, never PASS (finding 3).
    step('B6-2 Login Drill (client_id contract)',
         ['python3', 'tests/integration/audit_login_drill.py'], 300,
         skip_markers=('SKIP:', 'SKIP', '[proposed]'))


def _e2e_tests(proxy) -> None:
    """Step 6: E2E tests against the live proxy."""
    global PASS, FAIL
    print("\n【步骤 6/6: 端到端测试】")

    step('Curl E2E',
         ['env', f'SNAPLINK_E2E_PROXY={CONFIG.proxy_url}', 'bash', '-c', '''
            OK=0; for i in $(seq 1 30); do
                CODE=$(curl -s --max-time 3 -o /dev/null -w '%{http_code}' "$SNAPLINK_E2E_PROXY/admin/clients" 2>/dev/null)
                [ "$CODE" = "200" ] && OK=$((OK+1))
            done
            echo "30次连续请求: $OK/30"
            [ "$OK" -ge 27 ]
         '''],
         60)

    step('URL Coverage',
         ['env', f'SNAPLINK_E2E_PROXY={CONFIG.proxy_url}', 'bash', '-c', '''
            URLS="/admin /admin/clients /admin/clients/client-abc /admin/clients/client-abc/edit /admin/users /admin/users/admin /admin/users/admin/sessions /admin/users/admin/consents /admin/users/admin/mfa /admin/users/admin/lifecycle /admin/tenants /admin/tenants/tenant-1 /admin/tenants/tenant-1/members /admin/tenants/tenant-1/invitations /admin/tenants/tenant-1/usage /admin/connections /admin/connections/oidc /admin/permissions /admin/permissions/client-abc /admin/permissions/client-abc/roles /admin/permissions/client-abc/assignments /admin/user-support /admin/live-activity /admin/token-security /admin/token-security/portfolio /admin/token-security/suspicious /admin/token-security/temp /admin/token-security/revoke /admin/organizations /admin/operations /admin/crypto-keys /admin/crypto-keys/rotate /admin/credentials /admin/credentials/report /admin/token-policies /admin/token-exchange /admin/authz-checks /admin/domains /admin/domains/new /admin/access-policies /admin/dr-mode /admin/threat-policies /admin/threat-policies/new /admin/webhooks /admin/webhooks/sub-1 /admin/emergency-access /admin/emergency-access/test-session /admin/governance /admin/governance/audit /admin/governance/compliance /admin/governance/write /admin/governance/configuration /admin/governance/lifecycle"
            FAIL=0
            for url in $URLS; do
                CODE=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' "$SNAPLINK_E2E_PROXY$url" 2>/dev/null)
                [ "$CODE" != "200" ] && echo "FAIL: $url → $CODE" && FAIL=$((FAIL+1))
            done
            echo "URL测试: 失败=$FAIL"
            [ "$FAIL" -eq 0 ]
         '''],
         120)

    try:
        import playwright
        step('Playwright Browser Tests',
             ['python3', 'tests/integration/browser_test.py'], 120)
    except ImportError:
        print("  ⏭️ Playwright 未安装，跳过浏览器测试")

    if proxy is not None:
        proxy.terminate()
        proxy.wait(timeout=5)


def _summary(start_time) -> None:
    """Print the summary; exit 0 iff no failures."""
    elapsed = time.time() - start_time
    print(f"\n{'=' * 70}")
    print(f"  全栈验证完成 ({elapsed:.0f}s)")
    print(f"  总计: {PASS+FAIL+SKIP}  通过: {PASS}  失败: {FAIL}  跳过: {SKIP}")
    print(f"{'=' * 70}")
    if FAIL > 0:
        for r in RESULTS:
            if not r['ok']:
                print(f"  ❌ {r['name']}")
    sys.exit(0 if FAIL == 0 else 1)


def main():
    global PASS, FAIL
    parser = argparse.ArgumentParser()
    parser.add_argument('--quick', action='store_true', help='Skip gates, only run key tests')
    args = parser.parse_args()
    
    start_time = time.time()
    print("=" * 70)
    print("  sso-console 全栈完整验证")
    print(f"  CWD: {os.getcwd()}")
    print(f"  Mode: {'快速' if args.quick else '完整'}")
    print("=" * 70)
    
    _gates_and_build(args)
    proxy = _verify_proxy()
    _api_tests()
    _e2e_tests(proxy)
    _summary(start_time)

if __name__ == '__main__':
    main()
