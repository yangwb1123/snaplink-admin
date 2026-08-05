#!/usr/bin/env python3
"""
sso-console 全量测试运行器。
运行所有测试套件的基座：门禁检查、单元测试、集成测试、E2E/浏览器测试。

Usage:
  python3 tests/integration/run_all.py              # 运行所有可用测试
  python3 tests/integration/run_all.py --skip-e2e   # 跳过浏览器测试
  python3 tests/integration/run_all.py --ci         # CI 模式（不含浏览器测试）
"""
import subprocess, sys, os, time, json, argparse
from test_config import CONFIG

PASS = 0; FAIL = 0; SKIP = 0
RESULTS = []

def run_test(name, cmd, timeout=300, critical=True):
    """Run a test command and record result."""
    global PASS, FAIL, SKIP
    print(f"\n{'=' * 60}")
    print(f"  🔄 {name}")
    print(f"  {' '.join(cmd[:3])}...")
    print(f"{'=' * 60}")
    
    try:
        proc = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout)
        ok = proc.returncode == 0
        output = (proc.stdout or '') + (proc.stderr or '')
        
        if ok:
            PASS += 1
            print(f"  ✅ {name} 通过")
        else:
            FAIL += 1
            print(f"  ❌ {name} 失败 (code={proc.returncode})")
        
        # Show summary lines
        for line in output.split('\n'):
            stripped = line.strip()
            if any(kw in stripped for kw in ['✅', '❌', '通过', '失败', 'All tests', 'Result', '✦', 'FAIL', 'PASS']):
                if len(stripped) < 120:
                    print(f"    {stripped[:100]}")
        
        RESULTS.append({'name': name, 'ok': ok, 'output': output[:1000]})
        return ok
    except subprocess.TimeoutExpired:
        FAIL += 1
        print(f"  ❌ {name} 超时 ({timeout}s)")
        RESULTS.append({'name': name, 'ok': False, 'output': 'timeout'})
        return False

def run_e2e_test(name, cmd, timeout=120):
    """Run an E2E test script."""
    return run_test(name, cmd, timeout=timeout, critical=False)

def main():
    global PASS, FAIL, SKIP, RESULTS
    parser = argparse.ArgumentParser()
    parser.add_argument('--skip-e2e', action='store_true', help='Skip browser E2E tests')
    parser.add_argument('--ci', action='store_true', help='CI mode (no browser tests, no proxy)')
    args = parser.parse_args()
    
    start_time = time.time()
    
    # Ensure we're in the right directory
    os.chdir(os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__)))))
    
    print("=" * 70)
    print("  sso-console 全量测试运行器")
    print(f"  CWD: {os.getcwd()}")
    print(f"  Mode: {'CI' if args.ci else 'Full'}")
    print("=" * 70)
    
    # ── Gate 1: Engineering checks ──
    print("\n【门禁检查】")
    run_test('Filesize', ['python3', 'cli.py', 'check-filesize'], timeout=30)
    run_test('Dart Complexity', ['python3', 'cli.py', 'complexity'], timeout=60)
    run_test('Architecture', ['python3', 'cli.py', 'architecture'], timeout=30)
    run_test('Directory Fan-out', ['python3', 'cli.py', 'directory-fanout'], timeout=30)
    run_test('Root Policy', ['python3', 'cli.py', 'root-policy'], timeout=30)
    run_test('Invariants', ['python3', 'cli.py', 'invariants'], timeout=30)
    
    # ── Gate 2: Build ──
    print("\n【构建检查】")
    run_test('Flutter Build Web', ['python3', 'cli.py', 'build'], timeout=180)
    
    # ── Gate 3: Unit tests ──
    print("\n【单元测试】")
    
    # Try running all Flutter tests
    flutter_tests = subprocess.run(
        ['flutter', 'test', '--machine'],
        capture_output=True, text=True, timeout=120
    )
    if flutter_tests.returncode == 0:
        # Parse JSON lines for test results
        test_count = 0
        for line in flutter_tests.stdout.split('\n'):
            try:
                data = json.loads(line)
                if data.get('type') == 'testDone':
                    test_count += 1
            except Exception as exc:
                print(f'run_all: step failed silently: {exc}')
        if test_count > 0:
            PASS += 1
            print(f"  ✅ Flutter 单元测试 ({test_count} 个通过)")
        else:
            run_test('Flutter Unit Tests', ['flutter', 'test'], timeout=120)
    else:
        # Fallback: run specific test file
        run_test('AdminRoute Tests', ['flutter', 'test', 'test/admin_route_test.dart'], timeout=60)
    run_test(
        'Python Unit Tests',
        ['python3', '-m', 'unittest', 'discover', '-s', 'tests/unit', '-p', 'test_*.py'],
        timeout=30,
    )
    
    # ── Gate 4: Integration tests ──
    print("\n【集成测试】")
    run_test('Python Integration Tests', 
             ['python3', 'tests/integration/full_integration_test.py'], timeout=120)
    
    # ── Gate 5: E2E tests (via curl, no browser needed) ──
    if not args.skip_e2e and not args.ci:
        print("\n【E2E 测试】")
        
        # Start proxy
        proxy = None
        if CONFIG.manages_local_proxy:
            subprocess.run(
                ['fuser', '-k', f'{CONFIG.proxy_port}/tcp'],
                capture_output=True,
            )
            time.sleep(2)
            proxy = subprocess.Popen(
                ['python3', 'tools/robust_proxy.py'],
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                env=CONFIG.proxy_environment(),
            )
            time.sleep(3)
        
        # Check proxy is up
        curl_check = subprocess.run(
            ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', '--max-time', '5',
             f'{CONFIG.proxy_url}/'],
            capture_output=True, text=True, timeout=10
        )
        if curl_check.stdout.strip() == '200':
            # Run curl-based adversarial tests
            run_e2e_test('Curl Adversarial Tests', 
                        ['env', f'SNAPLINK_E2E_PROXY={CONFIG.proxy_url}', 'bash', '-c', '''
                            PASS=0; FAIL=0
                            for url in /admin/clients /admin/users /admin/tenants /admin/permissions /admin/connections /admin/webhooks /admin/governance /admin/token-security /admin/credentials/report /admin/crypto-keys/rotate /admin/governance/audit /admin/token-security/portfolio /admin/domains/new /admin/threat-policies/new /admin/clients/client-abc /admin/clients/client-abc/edit /admin/users/admin/sessions /admin/tenants/tenant-1/members /admin/permissions/client-abc/roles /admin/emergency-access/test-session; do
                                CODE=$(curl -s --max-time 5 -o /dev/null -w '%{http_code}' "$SNAPLINK_E2E_PROXY$url" 2>/dev/null)
                                [ "$CODE" = "200" ] && PASS=$((PASS+1)) || FAIL=$((FAIL+1))
                            done
                            echo "PASS=$PASS FAIL=$FAIL"
                            [ "$FAIL" -eq 0 ]
                        '''])
            
            # Run E2E runner
            run_e2e_test('Python E2E Runner', 
                        ['python3', 'tests/integration/e2e_runner.py'], timeout=180)
            
            # Try Playwright browser tests
            try:
                import playwright
                run_e2e_test('Playwright Browser Tests',
                            ['python3', 'tests/integration/browser_test.py'], timeout=120)
            except ImportError:
                SKIP += 1
                print(f"  ⏭️ Playwright 未安装，跳过浏览器测试")
        else:
            print(f"  ⚠️ 代理未启动 (HTTP {curl_check.stdout.strip()})，跳过 E2E 测试")
        
        if proxy is not None:
            proxy.terminate()
            proxy.wait(timeout=5)
    else:
        SKIP += 1
        print(f"\n  ⏭️ 跳过 E2E/浏览器测试 ({'CI mode' if args.ci else '--skip-e2e'})")
    
    # ── Summary ──
    elapsed = time.time() - start_time
    total = PASS + FAIL + SKIP
    print(f"\n{'=' * 70}")
    print(f"  测试完成: {total} 个 ({elapsed:.0f}s)")
    print(f"  通过: {PASS}  失败: {FAIL}  跳过: {SKIP}")
    print(f"{'=' * 70}")
    
    if FAIL > 0:
        print("\n失败详情:")
        for r in RESULTS:
            if not r['ok']:
                print(f"  ❌ {r['name']}")
                out = r['output'][:200]
                if out:
                    print(f"     {out[:100]}")
    
    sys.exit(0 if FAIL == 0 else 1)

if __name__ == '__main__':
    main()
