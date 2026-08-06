#!/usr/bin/env python3
"""
sso-console 性能基准测试。
测量所有 URL 路由的响应时间，生成性能报告。

Usage: python3 tests/integration/perf_benchmark.py [--threshold-ms 500]
"""
import subprocess, sys, time, argparse
from pathlib import Path
from test_config import CONFIG

URLS = [
    '/', '/admin',
    '/admin/clients', '/admin/clients/client-abc', '/admin/clients/client-abc/edit',
    '/admin/users', '/admin/users/admin', '/admin/users/admin/sessions',
    '/admin/users/admin/consents', '/admin/users/admin/mfa', '/admin/users/admin/lifecycle',
    '/admin/tenants', '/admin/tenants/tenant-1', '/admin/tenants/tenant-1/members',
    '/admin/tenants/tenant-1/invitations', '/admin/tenants/tenant-1/usage',
    '/admin/connections', '/admin/connections/oidc',
    '/admin/permissions', '/admin/permissions/client-abc', '/admin/permissions/client-abc/roles',
    '/admin/permissions/client-abc/assignments',
    '/admin/user-support', '/admin/live-activity',
    '/admin/token-security', '/admin/token-security/portfolio',
    '/admin/token-security/suspicious', '/admin/token-security/temp', '/admin/token-security/revoke',
    '/admin/organizations', '/admin/operations',
    '/admin/crypto-keys', '/admin/crypto-keys/rotate',
    '/admin/credentials', '/admin/credentials/report',
    '/admin/token-policies', '/admin/token-exchange', '/admin/authz-checks',
    '/admin/domains', '/admin/domains/new',
    '/admin/access-policies', '/admin/dr-mode',
    '/admin/threat-policies', '/admin/threat-policies/new',
    '/admin/webhooks', '/admin/webhooks/sub-1',
    '/admin/emergency-access', '/admin/emergency-access/test-session',
    '/admin/governance', '/admin/governance/audit', '/admin/governance/compliance',
    '/admin/governance/write', '/admin/governance/configuration', '/admin/governance/lifecycle',
]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--threshold-ms', type=int, default=500, help='Response time threshold in ms')
    parser.add_argument('--proxy', default=CONFIG.proxy_url)
    parser.add_argument('--csv', help='Output CSV file path')
    args = parser.parse_args()
    
    BASE = args.proxy.rstrip('/')
    total_urls = len(URLS)
    passed = 0
    failed = 0
    slow = 0
    results = []
    
    print(f"Proxy: {BASE}")
    print(f"URLs: {total_urls}")
    print(f"Threshold: {args.threshold_ms}ms")
    print()
    
    for url in URLS:
        full_url = f"{BASE}{url}"
        start = time.time()
        try:
            r = subprocess.run(
                ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', '--max-time', '10', full_url],
                capture_output=True, text=True, timeout=15
            )
            elapsed_ms = (time.time() - start) * 1000
            code = r.stdout.strip()
            ok = code == '200'
            slow_alert = elapsed_ms > args.threshold_ms
            
            if ok:
                passed += 1
            else:
                failed += 1
            if slow_alert:
                slow += 1
            
            results.append((url, elapsed_ms, code, ok, slow_alert))
            
            status = '✅' if ok else f'❌{code}'
            speed = '🐢' if slow_alert else ''
            print(f"  {status}{speed} {elapsed_ms:7.1f}ms {url}")
        except Exception as e:
            failed += 1
            results.append((url, 0, 'ERR', False, False))
            print(f"  ❌ERR {url}: {e}")
    
    # Summary
    avg = sum(r[1] for r in results) / len(results) if results else 0
    max_t = max(r[1] for r in results) if results else 0
    
    print(f"\n{'=' * 50}")
    print(f"  Total:  {total_urls}")
    print(f"  Passed: {passed}")
    print(f"  Failed: {failed}")
    print(f"  Slow:   {slow} (>{args.threshold_ms}ms)")
    print(f"  Avg:    {avg:.0f}ms")
    print(f"  Max:    {max_t:.0f}ms")
    print(f"  Grade:  {'🚀 Excellent' if avg < 100 else '👍 Good' if avg < 200 else '⚠️ Acceptable' if avg < 500 else '🐌 Slow'}")
    print(f"{'=' * 50}")
    
    # CSV output
    if args.csv:
        with open(args.csv, 'w') as f:
            f.write('url,time_ms,status,passed\n')
            for url, tm, code, ok, _ in results:
                f.write(f'{url},{tm:.1f},{code},{ok}\n')
        print(f"CSV saved: {args.csv}")
    
    sys.exit(0 if failed == 0 else 1)

if __name__ == '__main__':
    main()
