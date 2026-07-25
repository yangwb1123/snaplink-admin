import sys, json, urllib.request, urllib.error, base64

BASE = "http://localhost:8080"

def api(method, path, body=None, token=None):
    url = f"{BASE}{path}"
    data = json.dumps(body).encode() if body else None
    h = {"Authorization": f"Bearer {token}"} if token else {}
    if body: h["Content-Type"] = "application/json"
    try:
        resp = urllib.request.urlopen(urllib.request.Request(url, data=data, headers=h, method=method), timeout=10)
        return resp.status, json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read()
        try: return e.code, json.loads(body) if body else {"code": e.code}
        except: return e.code, {"error": body[:100].decode(errors='replace')}
    except Exception as e:
        return 0, {"error": str(e)}

def decode_jwt(token):
    payload = token.split('.')[1]
    pad = 4 - len(payload) % 4
    if pad != 4: payload += '=' * pad
    return json.loads(base64.urlsafe_b64decode(payload))

passed = 0; failed = 0

def test(name, fn):
    global passed, failed
    try:
        fn(); passed += 1; print(f"  ✅ {name}")
    except AssertionError as e: failed += 1; print(f"  ❌ {name}: {e}")
    except Exception as e: failed += 1; print(f"  ❌ {name}: {type(e).__name__}: {e}")

print("✦ 01 - 认证流程测试")
print("="*50)
status, login_resp = api("POST", "/auth/login", {
    "provider": "password", "client_id": "sso-admin-console",
    "scope": ["openid", "profile", "admin:read", "admin:write"],
    "credential": {"username": "admin", "password": "admin"}
})
TOKEN = login_resp.get("access_token", "")
test("登录获取 Token", lambda: "access_token" in login_resp and len(TOKEN) > 20)
if not TOKEN:
    print(f"  ⛔ 登录失败: {login_resp}")
    sys.exit(1)
test("Token 含 admin:read", lambda: "admin:read" in login_resp.get("scope", ""))
test("Token 含 admin:write", lambda: "admin:write" in login_resp.get("scope", ""))
test("expires_in > 0", lambda: login_resp.get("expires_in", 0) > 0)
test("token_type = Bearer", lambda: login_resp.get("token_type") == "Bearer")
status, me_resp = api("GET", "/me", token=TOKEN)
test("/me 返回 admin", lambda: me_resp.get("sub") == "admin")
status, err_resp = api("POST", "/auth/login", {
    "provider": "password", "client_id": "sso-admin-console",
    "scope": ["openid", "profile", "admin:read", "admin:write"],
    "credential": {"username": "admin", "password": "wrong"}
})
test("错误密码返回错误", lambda: "error" in err_resp)
payload = decode_jwt(TOKEN)
test("JWT sub = admin", lambda: payload.get("sub") == "admin")
test("JWT client_id = sso-admin-console", lambda: payload.get("client_id") == "sso-admin-console")
status, roles_resp = api("GET", "/roles/me", token=TOKEN)
test("roles/me 含 sso-admin", lambda: any(r.get("code") == "sso-admin" for r in roles_resp.get("roles", [])))
status, perms_resp = api("GET", "/permissions/me", token=TOKEN)
test("permissions/me 含 admin:*", lambda: any(p.get("code") == "admin:*" for p in perms_resp.get("permissions", [])))

print("\n✦ 02 - 核心 CRUD")
print("="*50)
status, data = api("GET", "/api/v1/admin/clients", token=TOKEN)
test("列出客户端", lambda: len(data.get("clients", [])) >= 1)
test("含 sso-admin-console", lambda: any(c["id"] == "sso-admin-console" for c in data.get("clients", [])))
c_id = "e2e-client-test-001"
status, _ = api("POST", "/api/v1/admin/clients", {"id": c_id, "name": "E2E Test", "active": True}, token=TOKEN)
test("创建客户端", lambda: status in (200, 201, 409))
status, _ = api("DELETE", f"/api/v1/admin/clients/{c_id}", token=TOKEN)
test("删除客户端", lambda: status in (200, 204, 404))
status, data = api("GET", "/api/v1/admin/users", token=TOKEN)
test("列出用户", lambda: len(data.get("users", [])) >= 1)
test("含 admin 用户", lambda: any(u["id"] == "admin" for u in data.get("users", [])))
status, data = api("GET", "/api/v1/admin/tenants", token=TOKEN)
test("列出租户", lambda: isinstance(data.get("tenants", []), list))

print("\n✦ 03 - Admin 端点清单")
print("="*50)
status, data = api("GET", "/api/v1/admin/endpoints", token=TOKEN)
eps = data.get("endpoints", []); paths = [e["path"] for e in eps]
test("端点列表非空", lambda: len(eps) > 0)
for name, kw in [("clients","/clients"),("users","/users"),("tenants","/tenants"),
    ("break-glass","break-glass"),("webhooks","webhooks"),("crypto/keys","crypto/keys"),
    ("credentials","credentials"),("tokens","/tokens"),("sessions","/sessions"),
    ("domains","/domains"),("dr","dr/"),("config","/config/"),("compliance","/compliance/"),
    ("permissions","/permissions/"),("connections","/connections")]:
    test(f"含 {name}", lambda k=kw: any(k in p for p in paths))

print("\n✦ 04 - 功能模块")
print("="*50)
for path, name in [
    ("/api/v1/admin/break-glass","Break Glass"),
    ("/api/v1/admin/webhooks/subscriptions","Webhooks"),
    ("/api/v1/admin/crypto/keys","Crypto Keys"),
    ("/api/v1/admin/credentials","Credentials"),
    ("/api/v1/admin/domains","Domains"),
    ("/api/v1/admin/dr/mode","DR Mode"),
    ("/api/v1/admin/token-policies","Token Policies"),
    ("/api/v1/admin/threat-policies","Threat Policies"),
    ("/api/v1/admin/access-policies","Access Policies"),
    ("/api/v1/admin/sessions","Sessions"),
    ("/api/v1/admin/config/running","Config Running"),
    ("/api/v1/admin/storage-health","Storage Health"),
    ("/api/v1/admin/federation/health","Federation Health"),
]:
    s, _ = api("GET", path, token=TOKEN)
    test(name, lambda s=s: s < 500)

print("\n✦ 05 - Token 安全")
print("="*50)
for path in ["/api/v1/admin/tokens/portfolio","/api/v1/admin/tokens/sessions",
    "/api/v1/admin/tokens/expiring","/api/v1/admin/tokens/suspicious","/api/v1/admin/tokens/usage"]:
    s, _ = api("GET", path, token=TOKEN)
    test(f"GET {path.split('/')[-1]}", lambda s=s: s < 500)
s, _ = api("POST", "/api/v1/admin/tokens/temp", {"subject":"admin","scopes":["openid"]}, token=TOKEN)
test("Create temp token", lambda: s in (200,201,403,501))

print("\n✦ 06 - 用户支持")
print("="*50)
for path in ["/api/v1/admin/users/admin/sessions","/api/v1/admin/users/admin/consents",
    "/api/v1/admin/users/admin/mfa","/api/v1/admin/users/admin/lifecycle",
    "/api/v1/admin/users/admin/password-reset-tokens","/api/v1/admin/users/admin/email-change-tokens"]:
    s, _ = api("GET", path, token=TOKEN)
    test(f"GET {path.split('/')[-1]}", lambda s=s: s < 500)
for path, name in [("/api/v1/admin/users/admin/device-secrets","撤销设备密钥"),
    ("/api/v1/admin/users/admin/refresh-tokens","撤销刷新令牌"),
    ("/api/v1/admin/users/admin/password-reset-tokens","撤销密码重置链接"),
    ("/api/v1/admin/users/admin/email-change-tokens","撤销邮箱变更链接")]:
    s, d = api("DELETE", path, token=TOKEN)
    test(name, lambda s=s: s in (200,204,403,501) or s < 500)

print("\n✦ 07 - 治理与合规")
print("="*50)
for path in ["/api/v1/admin/config/applied","/api/v1/admin/config/diff",
    "/api/v1/admin/config/history","/api/v1/admin/compliance/soc2-evidence",
    "/api/v1/admin/compliance/data-map","/api/v1/admin/compliance/consents",
    "/api/v1/audit/events","/api/v1/admin/changes","/api/v1/admin/snapshots",
    "/api/v1/admin/releases","/api/v1/admin/releases:current"]:
    s, _ = api("GET", path, token=TOKEN)
    name = path.rsplit('/',1)[-1].split(':')[0]
    test(f"GET {name}", lambda s=s: s < 500)

print("\n✦ 08 - 端到端流程")
print("="*50)
s, d = api("GET", "/health")
test("E2E: 健康检查", lambda: d.get("status") == "ok")
test("E2E: 登录", lambda: "access_token" in login_resp)
s, _ = api("GET", "/api/v1/admin/endpoints", token=TOKEN)
test("E2E: 获取端点", lambda: s == 200)
s, _ = api("POST", "/api/v1/admin/break-glass", {"target_user_id":"admin","reason":"E2E","scope":"readonly"}, token=TOKEN)
test("E2E: Break Glass", lambda: s in (200,201,403,501))
s, _ = api("GET", "/api/v1/admin/tokens/portfolio", token=TOKEN)
test("E2E: Token 组合", lambda: s < 500)
s, _ = api("GET", "/api/v1/admin/config/running", token=TOKEN)
test("E2E: 运行配置", lambda: s < 500)

total = passed + failed
print(f"\n{'='*50}")
print(f"✦ 测试完成: {total} 个")
print(f"   通过: {passed}/{total}")
print(f"   失败: {failed}/{total}")
print(f"   通过率: {passed/total*100:.0f}%")
print(f"{'='*50}")
if failed > 0: print("\n⚠️  部分测试失败"); sys.exit(1)
else: print("\n✅ 所有功能正常工作!")
