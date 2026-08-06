#!/usr/bin/env python3
"""
Health and proxy E2E tests.
Validates the proxy serves health endpoints, static files, and handles auth.
"""
import subprocess, json, sys, time
from test_config import CONFIG
PROXY = CONFIG.proxy_url

PASS = 0; FAIL = 0
def check(label, ok, detail=''):
    global PASS, FAIL
    if ok: PASS+=1; print(f"  ✅ {label}")
    else: FAIL+=1; print(f"  ❌ {label}" + (f": {detail}" if detail else ""))

def curl(url, headers=None, method='GET', data=None):
    cmd = ['curl', '-s', '--max-time', '5']
    if method != 'GET': cmd += ['-X', method]
    if data is not None: cmd += ['-d', json.dumps(data)]
    if headers:
        for k,v in headers.items(): cmd += ['-H', f'{k}: {v}']
    cmd.append(url)
    return subprocess.run(cmd, capture_output=True, text=True).stdout.strip()

proxy = None
if CONFIG.manages_local_proxy:
    subprocess.run(
        ['fuser', '-k', f'{CONFIG.proxy_port}/tcp'], capture_output=True
    )
    time.sleep(1)
    proxy = subprocess.Popen(
        ['python3', 'tools/robust_proxy.py'],
        stdout=subprocess.DEVNULL,
        stderr=subprocess.DEVNULL,
        env=CONFIG.proxy_environment(),
    )
    time.sleep(3)

try:
    print("=" * 60)
    print("  Health & Proxy E2E Tests")
    print("=" * 60)
    print()
    
    h = curl(f'{PROXY}/health')
    health = json.loads(h)
    check("Health endpoint works", 'status' in health)
    check(f"Backend: {health.get('status')}", health.get('status') == 'ok')
    
    for path in ['/', '/admin', '/admin/health', '/admin/clients']:
        r = curl(f'{PROXY}{path}')
        check(f"SPA serves {path}", 'html' in r.lower(), f"got {len(r)} bytes")
    
    for ep in ['/health', '/api/v1/admin/health/storage', '/api/v1/admin/health/federation']:
        r = curl(f'{PROXY}{ep}')
        d = json.loads(r)
        check(f"API {ep}", len(d) > 0)
    
    r = curl(f'{PROXY}/api/v1/admin/clients')
    d = json.loads(r)
    check("Unauthenticated returns error", 'error' in d)
    
    ok_count = sum(1 for i in range(10) if 'html' in curl(f'{PROXY}/admin/clients').lower())
    check(f"10 rapid requests ({ok_count}/10)", ok_count >= 9)
    
    print(f"\nTests: {PASS+FAIL}  Pass: {PASS}  Fail: {FAIL}")
except Exception as e:
    print(f"Error: {e}")
finally:
    if proxy is not None:
        proxy.terminate()
        proxy.wait(timeout=3)

sys.exit(0 if FAIL == 0 else 1)
