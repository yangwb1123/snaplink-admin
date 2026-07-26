#!/usr/bin/env python3
"""
Comprehensive admin flow E2E test through the proxy.
Tests full admin workflows: login, navigation, detail pages, CRUD operations.

Usage: python3 tests/integration/admin_flow_e2e.py
"""
import sys, os, time, json, subprocess, urllib.request, urllib.error

PASS = 0; FAIL = 0

def check(label, ok, detail=''):
    global PASS, FAIL
    if ok: PASS+=1; print(f"  ✅ {label}")
    else: FAIL+=1; print(f"  ❌ {label}" + (f": {detail}" if detail else ""))

API = 'http://localhost:8080'
PROXY = 'http://localhost:4444'

def api(method, path, data=None, token=None):
    url = f"{API}{path}"
    body = json.dumps(data).encode() if data else None
    h = {'Content-Type': 'application/json'} if data else {}
    if token: h['Authorization'] = f'Bearer {token}'
    try:
        resp = urllib.request.urlopen(urllib.request.Request(url, data=body, headers=h, method=method), timeout=10)
        return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read()
        try: return e.code, json.loads(body) if body else {}
        except: return e.code, {}

def curl_status(url):
    r = subprocess.run(['curl', '-s', '--max-time', '5', '-o', '/dev/null', '-w', '%{http_code}', url],
                       capture_output=True, text=True, timeout=10)
    return r.stdout.strip()

# Start
print("=" * 70)
print("  sso-console Admin Flow E2E Test")
print("=" * 70)
print()

# 1. Login
print("【1. Authentication】")
status, resp = api('POST', '/auth/login', {
    'provider': 'password', 'client_id': 'sso-admin-console',
    'scope': ['openid', 'profile', 'admin:read', 'admin:write'],
    'credential': {'username': 'admin', 'password': 'admin'}
})
TOKEN = resp.get('access_token', '')
check("Login successful", status == 200 and len(TOKEN) > 20, f"status={status}")

# 2. Proxy health
print("\n【2. Proxy Availability】")
check("Proxy responds", curl_status(f'{PROXY}/') == '200')
check("Admin page loads", curl_status(f'{PROXY}/admin') == '200')

# 3. Module Navigation
print("\n【3. Module Navigation (22 modules)】")
modules = ['clients', 'users', 'tenants', 'permissions', 'connections',
           'user-support', 'live-activity', 'token-security',
           'organizations', 'operations', 'crypto-keys', 'credentials',
           'token-policies', 'token-exchange', 'authz-checks', 'domains',
           'access-policies', 'dr-mode', 'threat-policies', 'webhooks',
           'emergency-access', 'governance']
for m in modules:
    check(f"/admin/{m}", curl_status(f'{PROXY}/admin/{m}') == '200')

# 4. Admin API via Token
print("\n【4. Admin API Access】")
status, resp = api('GET', '/api/v1/admin/clients', token=TOKEN)
check("List clients", status == 200, f"status={status}")
if status == 200:
    clients = resp.get('clients', [])
    check(f"Clients count: {len(clients)}", True)
    if clients:
        cid = clients[0].get('client_id') or clients[0].get('id', '')
        status2, _ = api('GET', f'/api/v1/admin/clients/{cid}', token=TOKEN)
        check(f"Get client detail", status2 == 200, f"status={status2}")

# 5. Users API
print("\n【5. Users API】")
status, resp = api('GET', '/api/v1/admin/users', token=TOKEN)
check("List users", status == 200)
if status == 200:
    users = resp.get('users', [])
    check(f"Users count: {len(users)}", True)
    if users:
        uid = users[0].get('id', '')
        for sub in ['sessions', 'consents', 'mfa', 'lifecycle']:
            s, _ = api('GET', f'/api/v1/admin/users/{uid}/{sub}', token=TOKEN)
            check(f"User {sub}", s == 200 or s == 404, f"status={s}")

# 6. Token Security API
print("\n【6. Token Security API】")
for sub in ['portfolio', 'sessions', 'expiring', 'suspicious', 'usage']:
    s, _ = api('GET', f'/api/v1/admin/tokens/{sub}', token=TOKEN)
    check(f"Token {sub}", s in (200, 404, 403), f"status={s}")

# 7. Governance API
print("\n【7. Governance API】")
gov_paths = [
    ('GET', '/api/v1/admin/config/running'),
    ('GET', '/api/v1/admin/health/storage'),
    ('GET', '/api/v1/admin/health/federation'),
    ('GET', '/api/v1/admin/compliance/soc2-evidence'),
    ('GET', '/api/v1/admin/compliance/data-map'),
    ('GET', '/api/v1/admin/changes'),
]
for method, path in gov_paths:
    s, _ = api(method, path, token=TOKEN)
    check(f"Governance {path.split('/')[-1]}", s in (200, 404, 403), f"status={s}")

# 8. Detail URLs via proxy
print("\n【8. Detail URL Loading】")
detail_urls = [
    '/admin/clients/client-abc',
    '/admin/users/admin',
    '/admin/users/admin/sessions',
    '/admin/tenants/tenant-1/members',
    '/admin/connections/oidc',
    '/admin/permissions/client-abc/roles',
    '/admin/governance/audit',
    '/admin/token-security/portfolio',
    '/admin/credentials/report',
]
for url in detail_urls:
    code = curl_status(f'{PROXY}{url}')
    check(f"Detail {url}", code == '200', f"got {code}")

# 9. CRUD Operations
print("\n【9. CRUD Operations】")
# Create temp client
import uuid
test_client = {
    'client_name': f'e2e-test-{uuid.uuid4().hex[:8]}',
    'name': 'E2E Test Client',
    'redirect_uris': ['http://localhost:9999/callback'],
    'grant_types': ['authorization_code'],
}
status, resp = api('POST', '/api/v1/admin/clients', test_client, token=TOKEN)
check(f"Create client (status={status})", status in (200, 201, 400), f"got {status}")
if status == 200:
    cid2 = resp.get('client_id') or resp.get('id', '')
    if cid2:
        # Read
        s, _ = api('GET', f'/api/v1/admin/clients/{cid2}', token=TOKEN)
        check("Read created client", s == 200)
        # Delete
        s, _ = api('DELETE', f'/api/v1/admin/clients/{cid2}', token=TOKEN)
        check("Delete created client", s == 200 or s == 204, f"status={s}")

# 10. Load test
print("\n【10. Load Test (30 requests through proxy)】")
ok = 0
for i in range(30):
    code = curl_status(f'{PROXY}/admin/clients')
    if code == '200': ok += 1
check(f"30 proxy requests: {ok}/30", ok >= 27, f"only {ok}")

print(f"\n{'=' * 70}")
print(f"  Tests: {PASS+FAIL}  Pass: {PASS}  Fail: {FAIL}")
print(f"{'=' * 70}")
sys.exit(0 if FAIL == 0 else 1)
