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

def _probe(full_url: str, threshold_ms: int) -> tuple:
    """Measure one URL; returns (url, elapsed_ms, code, ok, slow_alert)."""
    start = time.time()
    try:
        r = subprocess.run(
            ['curl', '-s', '-o', '/dev/null', '-w', '%{http_code}', '--max-time', '10', full_url],
            capture_output=True, text=True, timeout=15
        )
        elapsed_ms = (time.time() - start) * 1000
        code = r.stdout.strip()
        ok = code == '200'
        slow_alert = elapsed_ms > threshold_ms
        status = '✅' if ok else f'❌{code}'
        speed = '🐢' if slow_alert else ''
        print(f"  {status}{speed} {elapsed_ms:7.1f}ms {full_url.split('://', 1)[-1]}")
        return (full_url, elapsed_ms, code, ok, slow_alert)
    except Exception as e:
        print(f"  ❌ERR {full_url}: {e}")
        return (full_url, 0, 'ERR', False, False)


def _report(results: list, threshold_ms: int, csv: str) -> int:
    """Print the summary and optional CSV; return the exit code."""
    total_urls = len(results)
    passed = sum(1 for r in results if r[3])
    failed = total_urls - passed
    slow = sum(1 for r in results if r[4])
    avg = sum(r[1] for r in results) / total_urls if results else 0
    max_t = max(r[1] for r in results) if results else 0

    print(f"\n{'=' * 50}")
    print(f"  Total:  {total_urls}")
    print(f"  Passed: {passed}")
    print(f"  Failed: {failed}")
    print(f"  Slow:   {slow} (>{threshold_ms}ms)")
    print(f"  Avg:    {avg:.0f}ms")
    print(f"  Max:    {max_t:.0f}ms")
    grade = '🚀 Excellent' if avg < 100 else '👍 Good' if avg < 200 else '⚠️ Acceptable' if avg < 500 else '🐌 Slow'
    print(f"  Grade:  {grade}")
    print(f"{'=' * 50}")

    if csv:
        with open(csv, 'w') as f:
            f.write('url,time_ms,status,passed\n')
            for url, tm, code, ok, _ in results:
                f.write(f'{url},{tm:.1f},{code},{ok}\n')
        print(f"CSV saved: {csv}")

    return 0 if failed == 0 else 1


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--threshold-ms', type=int, default=500, help='Response time threshold in ms')
    parser.add_argument('--proxy', default=CONFIG.proxy_url)
    parser.add_argument('--csv', help='Output CSV file path')
    args = parser.parse_args()
    
    BASE = args.proxy.rstrip('/')
    print(f"Proxy: {BASE}")
    print(f"URLs: {len(URLS)}")
    print(f"Threshold: {args.threshold_ms}ms")
    print()
    
    results = [_probe(f"{BASE}{url}", args.threshold_ms) for url in URLS]
    sys.exit(_report(results, args.threshold_ms, args.csv))

if __name__ == '__main__':
    main()
