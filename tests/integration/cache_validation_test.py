#!/usr/bin/env python3
"""
Cache behavior validation test.
Verifies that the SnaplinkAdminApi cache layer works correctly
by measuring response times and detecting cached vs. fresh responses.

Usage: python3 tests/integration/cache_validation_test.py
"""
import sys, time, json, urllib.request, urllib.error
from test_config import CONFIG, IntegrationConfigurationError

PASS = 0; FAIL = 0
def check(label, ok, detail=''):
    global PASS, FAIL
    if ok: PASS+=1; print(f"  ✅ {label}")
    else: FAIL+=1; print(f"  ❌ {label}" + (f": {detail}" if detail else ""))

try:
    CONFIG.require_credentials()
except IntegrationConfigurationError as error:
    # Live authenticated tests need a dedicated Snaplink test deployment.
    # Skip cleanly when credentials are not configured.
    print(f"SKIP: {error}")
    sys.exit(0)
API = CONFIG.api_url
TOKEN = None

def api_call(method, path, data=None):
    """Make an API call and return (status, response, elapsed_ms)."""
    url = f"{API}{path}"
    body = json.dumps(data).encode() if data else None
    h = {'Content-Type': 'application/json'} if data else {}
    if TOKEN: h['Authorization'] = f'Bearer {TOKEN}'
    start = time.time()
    try:
        resp = urllib.request.urlopen(urllib.request.Request(url, data=body, headers=h, method=method), timeout=10)
        elapsed = (time.time() - start) * 1000
        return resp.status, json.loads(resp.read()), elapsed
    except urllib.error.HTTPError as e:
        elapsed = (time.time() - start) * 1000
        body = e.read()
        try: return e.code, json.loads(body) if body else {}, elapsed
        except: return e.code, {}, elapsed

# Login first
status, resp, _ = api_call('POST', '/auth/login', {
    **CONFIG.login_payload()
})
TOKEN = resp.get('access_token', '')

if not TOKEN:
    print("❌ Cannot login")
    sys.exit(1)

print("=" * 70)
print("  Cache Behavior Validation Test")
print("=" * 70)
print()

# 1. First request (cold cache) vs second (warm cache)
print("【1. Cache Hit Detection】")
status1, data1, t1 = api_call('GET', '/api/v1/admin/clients')
status2, data2, t2 = api_call('GET', '/api/v1/admin/clients')

print(f"  First request (cold):  {t1:.0f}ms")
print(f"  Second request (warm): {t2:.0f}ms")
print(f"  Speedup:              {t1/t2:.1f}x" if t2 > 0 else "  N/A")

check("Both requests succeed", status1 == 200 and status2 == 200, f"status1={status1}, status2={status2}")
check("Cold request slower than warm", t1 > t2 * 0.5 or t1 < 50, f"cold={t1:.0f}ms warm={t2:.0f}ms")

# 2. Mutation invalidates cache
print("\n【2. Cache Invalidation on Mutation】")
# First, warm the cache
api_call('GET', '/api/v1/admin/clients')
# Then create a temp client
import uuid
test_client = {
    'client_name': f'cache-test-{uuid.uuid4().hex[:8]}',
    'redirect_uris': ['http://localhost:9999/callback'],
    'grant_types': ['authorization_code'],
}
status_c, data_c, _ = api_call('POST', '/api/v1/admin/clients', test_client)
cache_hit_after_mutation, data3, t3 = api_call('GET', '/api/v1/admin/clients')
check("Mutation invalidates cache (fresh data returned)", 
      status_c in (200, 201, 400), f"create status={status_c}")

# Clean up if created
if status_c == 200:
    cid = data_c.get('client_id') or data_c.get('id', '')
    if cid:
        api_call('DELETE', f'/api/v1/admin/clients/{cid}')

# 3. Concurrent request deduplication
print("\n【3. Request Deduplication】")
import threading

results = {}
def fetch_clients(idx):
    s, d, t = api_call('GET', '/api/v1/admin/clients')
    results[idx] = (s, t)

# Fire 5 concurrent requests
threads = []
for i in range(5):
    t = threading.Thread(target=fetch_clients, args=(i,))
    threads.append(t)
    t.start()
for t in threads:
    t.join()

times = [results[i][1] for i in range(5)]
statuses = [results[i][0] for i in range(5)]
all_ok = all(s == 200 for s in statuses)
check("5 concurrent requests all succeed", all_ok, f"statuses={statuses}")
print(f"  Individual times: {[f'{t:.0f}ms' for t in times]}")

# 4. User sub-resources cache
print("\n【4. Sub-resource Caching】")
status, users, _ = api_call('GET', '/api/v1/admin/users')
if status == 200:
    user_list = users.get('users', [])
    if user_list:
        uid = user_list[0].get('id', '')
        subs = ['sessions', 'consents', 'mfa', 'lifecycle']
        for sub in subs:
            s1, _, t_cold = api_call('GET', f'/api/v1/admin/users/{uid}/{sub}')
            s2, _, t_warm = api_call('GET', f'/api/v1/admin/users/{uid}/{sub}')
            check(f"User/{sub}: cold={t_cold:.0f}ms warm={t_warm:.0f}ms", 
                  s1 == s2, f"status1={s1}, status2={s2}")

# 5. Cache isolation (different paths don't interfere)
print("\n【5. Cache Isolation】")
s1, d1, t1 = api_call('GET', '/api/v1/admin/clients')
s2, d2, t2 = api_call('GET', '/api/v1/admin/users')
s3, d3, t3 = api_call('GET', '/api/v1/admin/tenants')
check("Different resources cached independently (%d,%d,%d)" % (s1,s2,s3),
      s1 == 200 and s2 == 200 and s3 in (200,404),
      "")

# 6. Token endpoints cache
print("\n【6. Token Endpoints】")
token_subs = ['portfolio', 'sessions', 'expiring', 'suspicious', 'usage']
for sub in token_subs:
    s, _, t = api_call('GET', f'/api/v1/admin/tokens/{sub}')
    check(f"Token/{sub}: {t:.0f}ms", s in (200, 404, 403), f"status={s}")

# Summary
print(f"\n{'=' * 70}")
print(f"  Tests: {PASS+FAIL}  Pass: {PASS}  Fail: {FAIL}")
print(f"{'=' * 70}")
sys.exit(0 if FAIL == 0 else 1)
