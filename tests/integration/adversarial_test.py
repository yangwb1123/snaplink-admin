#!/usr/bin/env python3
"""
Adversarial integration tests for sso-console URL routing.
Tests the proxy + backend stack with edge cases, error conditions,
and cross-module navigation scenarios.

Usage: python3 tests/integration/adversarial_test.py [--proxy-url http://localhost:4444] [--api-url http://localhost:8080]
"""
import sys, os, json, time, http.client, urllib.request, urllib.error, argparse

parser = argparse.ArgumentParser()
parser.add_argument('--proxy-url', default='http://localhost:4444')
parser.add_argument('--api-url', default='http://localhost:8080')
args = parser.parse_args()

PROXY_HOST = 'localhost'
PROXY_PORT = 4444
API_HOST = 'localhost'
API_PORT = 8080

PASS = 0
FAIL = 0
ERRORS = []

def check(label, condition, detail=''):
    global PASS, FAIL
    if condition:
        PASS += 1
        print(f"  ✅ {label}")
    else:
        FAIL += 1
        msg = f"  ❌ {label}: {detail}" if detail else f"  ❌ {label}"
        print(msg)
        ERRORS.append(msg)

def http_get(host, port, path, expect_status=200, timeout=5):
    try:
        conn = http.client.HTTPConnection(host, port, timeout=timeout)
        conn.request('GET', path)
        resp = conn.getresponse()
        status = resp.status
        body = resp.read().decode('utf-8', errors='replace')
        conn.close()
        return status, body
    except Exception as e:
        return 0, str(e)

def http_post(host, port, path, data=None, timeout=5):
    try:
        conn = http.client.HTTPConnection(host, port, timeout=timeout)
        body = json.dumps(data).encode() if data else b''
        headers = {'Content-Type': 'application/json'} if data else {}
        conn.request('POST', path, body=body, headers=headers)
        resp = conn.getresponse()
        status = resp.status
        data = resp.read().decode('utf-8', errors='replace')
        conn.close()
        return status, data
    except Exception as e:
        return 0, str(e)

print("=" * 70)
print("  sso-console 对抗式集成测试")
print("=" * 70)
print()

# ──────────────────────────────────────────────
# 1. PROXY HEALTH
# ──────────────────────────────────────────────
print("【1. Proxy 健康检查】")
s, b = http_get(PROXY_HOST, PROXY_PORT, '/')
check("首页返回 200", s == 200, f"got {s}")

s, b = http_get(PROXY_HOST, PROXY_PORT, '/admin')
check("管理后台返回 200", s == 200, f"got {s}")

s, b = http_get(PROXY_HOST, PROXY_PORT, '/login')
check("登录页返回 200 (SPA fallback)", s == 200, f"got {s}")

# ──────────────────────────────────────────────
# 2. ALL 22 MODULE ROUTES
# ──────────────────────────────────────────────
print("\n【2. 所有 22 个模块路由可达性】")
modules = [
    'clients', 'users', 'permissions', 'connections',
    'user-support', 'live-activity', 'token-security', 'tenants',
    'organizations', 'operations', 'crypto-keys', 'credentials',
    'token-policies', 'token-exchange', 'authz-checks', 'domains',
    'access-policies', 'dr-mode', 'threat-policies', 'webhooks',
    'emergency-access', 'governance'
]
all_ok = True
for m in modules:
    s, _ = http_get(PROXY_HOST, PROXY_PORT, f'/admin/{m}')
    ok = s == 200
    if not ok: all_ok = False
    check(f"/admin/{m:25s} → {s}", ok, f"expected 200, got {s}")
check("所有 22 个模块路由返回 200", all_ok, "some modules failed")

# ──────────────────────────────────────────────
# 3. DETAIL URLS (Level 2-3 routes)
# ──────────────────────────────────────────────
print("\n【3. 深层 URL 路由 (Level 2-3)】")
detail_urls = [
    '/admin/clients/client-abc',
    '/admin/clients/client-abc/edit',
    '/admin/users/admin',
    '/admin/users/admin/sessions',
    '/admin/users/admin/consents',
    '/admin/users/admin/mfa',
    '/admin/users/admin/lifecycle',
    '/admin/tenants/tenant-1',
    '/admin/tenants/tenant-1/members',
    '/admin/tenants/tenant-1/invitations',
    '/admin/tenants/tenant-1/usage',
    '/admin/connections/oidc',
    '/admin/permissions/client-abc',
    '/admin/permissions/client-abc/roles',
    '/admin/permissions/client-abc/assignments',
    '/admin/webhooks/sub-1',
    '/admin/emergency-access/test-session',
    '/admin/credentials/report',
    '/admin/crypto-keys/rotate',
    '/admin/governance/audit',
    '/admin/governance/compliance',
    '/admin/governance/write',
    '/admin/token-security/portfolio',
    '/admin/token-security/suspicious',
    '/admin/token-security/temp',
    '/admin/token-security/revoke',
    '/admin/domains/new',
    '/admin/threat-policies/new',
]
all_detail_ok = True
for url in detail_urls:
    s, _ = http_get(PROXY_HOST, PROXY_PORT, url)
    ok = s == 200
    if not ok: all_detail_ok = False
    check(f"{url:55s} → {s}", ok, f"expected 200, got {s}")
check(f"所有 {len(detail_urls)} 个深层 URL 返回 200", all_detail_ok, "some failed")

# ──────────────────────────────────────────────
# 4. EDGE CASES
# ──────────────────────────────────────────────
print("\n【4. 边界情况测试】")

s, b = http_get(PROXY_HOST, PROXY_PORT, '/admin/clients/nonexistent-client-xyz')
check("不存在的客户端 ID 返回 200 (SPA 渲染)", s == 200, f"got {s}")

s, b = http_get(PROXY_HOST, PROXY_PORT, '/admin/this-module-does-not-exist')
check("不存在的模块名返回 200 (SPA 兜底)", s == 200, f"got {s}")

s, b = http_get(PROXY_HOST, PROXY_PORT, '/admin/clients/a/b/c/d/e/f/g')
check("深层 URL (7 段) 返回 200", s == 200, f"got {s}")

s, b = http_get(PROXY_HOST, PROXY_PORT, '/admin/clients/client%20123%2Ftest')
check("URL 编码的特殊字符", s == 200, f"got {s}")

s, b = http_get(PROXY_HOST, PROXY_PORT, '/admin/users/550e8400-e29b-41d4-a716-446655440000')
check("UUID 格式的 ID", s == 200, f"got {s}")

s, b = http_get(PROXY_HOST, PROXY_PORT, '/admin/clients/')
check("尾部斜杠", s == 200, f"got {s}")

s, b = http_get(PROXY_HOST, PROXY_PORT, '/admin/clients?page=1&filter=active')
check("带查询参数的 URL", s == 200, f"got {s}")

# ──────────────────────────────────────────────
# 5. API PROXY FUNCTIONALITY
# ──────────────────────────────────────────────
print("\n【5. API 代理功能】")

s, b = http_post(PROXY_HOST, PROXY_PORT, '/auth/login', {'username': 'admin', 'password': 'admin'})
token = None
if s == 200:
    try: token = json.loads(b).get('access_token')
    except: pass
check("通过代理登录成功 (POST /auth/login)", s == 200 and token is not None, f"status={s}")

if token:
    conn = http.client.HTTPConnection(PROXY_HOST, PROXY_PORT, timeout=5)
    conn.request('GET', '/api/v1/admin/clients', headers={'Authorization': f'Bearer {token}'})
    resp = conn.getresponse()
    s2 = resp.status
    resp.read()
    conn.close()
    check("通过代理调用 API 成功 (GET /api/v1/admin/clients)", s2 == 200, f"got {s2}")
else:
    check("通过代理调用 API (跳过, 未登录)", True)

# ──────────────────────────────────────────────
# 6. BACKEND DIRECT TESTS
# ──────────────────────────────────────────────
print("\n【6. 后端直接测试】")

s, b = http_get(API_HOST, API_PORT, '/health')
check("后端健康检查", s == 200, f"got {s}")

s, b = http_post(API_HOST, API_PORT, '/auth/login', {'username': 'admin', 'password': 'admin'})
check("后端直接登录", s == 200, f"got {s}")

s, b = http_post(API_HOST, API_PORT, '/auth/login', {'username': 'admin', 'password': 'wrong'})
check("错误密码返回 401", s in (401, 403), f"got {s}")

# ──────────────────────────────────────────────
# 7. LOAD TEST (rapid requests)
# ──────────────────────────────────────────────
print("\n【7. 快速连续请求测试】")
ok_count = 0
for i in range(20):
    s, _ = http_get(PROXY_HOST, PROXY_PORT, '/admin/clients', timeout=3)
    if s == 200: ok_count += 1
check(f"20 次快速连续请求 ({ok_count}/20 成功)", ok_count >= 18, f"only {ok_count}/20")

# ──────────────────────────────────────────────
# 8. URL ROUTING CONSISTENCY
# ──────────────────────────────────────────────
print("\n【8. URL 路由一致性检查】")
# Verify same URL returns 200 consistently
url = '/admin/users/admin/sessions'
results = []
for i in range(5):
    s, _ = http_get(PROXY_HOST, PROXY_PORT, url, timeout=3)
    results.append(s)
consistent = all(r == 200 for r in results)
check(f"URL {url} 5 次请求一致性", consistent, f"results={results}")

# Cross-module: navigate from users to clients
urls = ['/admin/users', '/admin/users/admin', '/admin/clients', '/admin/clients/client-abc']
all_cross_ok = True
for url in urls:
    s, _ = http_get(PROXY_HOST, PROXY_PORT, url, timeout=3)
    if s != 200:
        all_cross_ok = False
        break
check("跨模块导航路径全部可达", all_cross_ok, f"failed at {url}")

# ──────────────────────────────────────────────
# 9. RESPONSE BODY VALIDATION
# ──────────────────────────────────────────────
print("\n【9. 响应体验证】")
s, b = http_get(PROXY_HOST, PROXY_PORT, '/admin/clients')
if s == 200:
    check("返回 HTML 内容", '<!DOCTYPE html>' in b or '<html' in b, "not HTML")
    check("包含 Flutter 入口", 'main.dart.js' in b, "flutter entry missing")
else:
    check("响应体验证 (跳过, 非 200)", True)

# Admin page should also return HTML
s, b = http_get(PROXY_HOST, PROXY_PORT, '/admin/users/admin/sessions')
if s == 200:
    check("深层 URL 返回 HTML", '<!DOCTYPE html>' in b or '<html' in b, "not HTML")

# ──────────────────────────────────────────────
# SUMMARY
# ──────────────────────────────────────────────
print("\n" + "=" * 70)
print(f"  测试完成: {PASS + FAIL} 个")
print(f"  通过: {PASS}")
print(f"  失败: {FAIL}")
print("=" * 70)

if ERRORS:
    print("\n失败详情:")
    for e in ERRORS[:15]:
        print(f"  {e}")
    if len(ERRORS) > 15:
        print(f"  ... 还有 {len(ERRORS) - 15} 个错误")

sys.exit(0 if FAIL == 0 else 1)
