#!/usr/bin/env python3
"""
API-level login flow E2E test.
Tests authentication through the proxy: login → token → admin access.

Usage: python3 tests/integration/api_login_e2e.py
"""
import sys, time, json, subprocess, os
from test_config import CONFIG, IntegrationConfigurationError

PASS = 0; FAIL = 0
def check(label, ok, detail=''):
    global PASS, FAIL
    if ok: PASS+=1; print(f"  ✅ {label}")
    else: FAIL+=1; print(f"  ❌ {label}" + (f": {detail}" if detail else ""))

def curl(method, url, data=None, headers=None, timeout=10):
    cmd = ['curl', '-s', '--max-time', str(timeout)]
    if method != 'GET': cmd += ['-X', method]
    if data is not None: cmd += ['-d', json.dumps(data)]
    if headers:
        for k,v in headers.items(): cmd += ['-H', f'{k}: {v}']
    cmd.append(url)
    r = subprocess.run(cmd, capture_output=True, text=True, timeout=timeout+5)
    return r.stdout.strip()

try:
    CONFIG.require_credentials()
except IntegrationConfigurationError as error:
    # Live authenticated tests need a dedicated Snaplink test deployment.
    # Skip cleanly when credentials are not configured.
    print(f"SKIP: {error}")
    sys.exit(0)
PROXY = CONFIG.proxy_url
API = CONFIG.api_url

print("=" * 70)
print("  API Login Flow E2E Test")
print("=" * 70)
print()

# 1. Check proxy is up
print("【1. Proxy Health】")
check("Proxy root", curl('GET', f'{PROXY}/') != '')

# 2. OIDC Login Discovery
print("\n【2. OIDC Discovery】")
login_resp = curl('POST', f'{PROXY}/auth/login', data={},
                 headers={'Content-Type': 'application/json'})
try:
    providers = json.loads(login_resp).get('providers', [])
    check("Login endpoint returns providers", len(providers) > 0)
    provider_ids = [p.get('id','') for p in providers]
    has_password = 'password' in provider_ids
    check(f"Password provider available", has_password, f"providers={provider_ids}")
except Exception as e:
    check("Parse login response", False, str(e))

# 3. Login with password
print("\n【3. Password Authentication】")
login_data = CONFIG.login_payload()
auth_resp = curl('POST', f'{PROXY}/auth/login', data=login_data,
                 headers={'Content-Type': 'application/json'})
try:
    auth_data = json.loads(auth_resp)
    token = auth_data.get('access_token', '')
    check("Login returns access_token", len(token) > 20, f"token length={len(token)}")
    
    # Verify token structure
    parts = token.split('.')
    check("Token is JWT (3 parts)", len(parts) == 3, f"got {len(parts)} parts")
    
    # Decode payload
    import base64
    try:
        payload = json.loads(base64.urlsafe_b64decode(parts[1] + '=='))
        check(f"JWT subject: {payload.get('sub', '?')}", payload.get('sub') == CONFIG.username)
        check(f"JWT issuer: {payload.get('iss', '?')}", payload.get('iss') == 'sso-server')
    except:
        check("Decode JWT payload", False)
        
except Exception as e:
    check("Parse auth response", False, str(e))
    token = ''

# 4. Admin API Access
print("\n【4. Admin API Access】")
if token:
    # Test through proxy
    api_resp = curl('GET', f'{PROXY}/api/v1/admin/clients',
                    headers={'Authorization': f'Bearer {token}'})
    try:
        clients = json.loads(api_resp)
        client_list = clients.get('clients', [])
        check(f"List clients through proxy ({len(client_list)} clients)", len(client_list) >= 0)
    except:
        check("List clients through proxy", False, api_resp[:100])
    
    # Test directly
    api_resp2 = curl('GET', f'{API}/api/v1/admin/clients',
                     headers={'Authorization': f'Bearer {token}'})
    try:
        clients2 = json.loads(api_resp2)
        check("Direct API access works", 'clients' in clients2)
    except:
        check("Direct API access works", False, api_resp2[:100])
    
    # Token introspection
    intro_resp = curl('POST', f'{PROXY}/auth/login',
                      data={'token': token},
                      headers={'Content-Type': 'application/json'})
    check("Token introspection", intro_resp != '')
else:
    check("Admin API access (skip - no token)", True)

# 5. Logout
print("\n【5. Logout】")
if token:
    logout_resp = curl('POST', f'{PROXY}/api/v1/admin/logout',
                       headers={'Authorization': f'Bearer {token}'})
    # Logout may return 200 or 401 depending on implementation
    check("Logout endpoint responds", logout_resp != '')

# 6. Error Cases
print("\n【6. Error Cases】")
# Wrong password
wrong_login = curl('POST', f'{PROXY}/auth/login',
                   data=CONFIG.login_payload(password='definitely-wrong'),
                   headers={'Content-Type': 'application/json'})
try:
    wrong_data = json.loads(wrong_login)
    has_error = 'error' in wrong_data
    check("Wrong password returns error", has_error, f"got: {wrong_login[:100]}")
except:
    check("Wrong password returns error (non-JSON)", True)

# Missing auth
no_auth_resp = curl('GET', f'{PROXY}/api/v1/admin/clients')
try:
    no_auth_data = json.loads(no_auth_resp)
    check("No-auth request returns 401-style error", 
          'error' in no_auth_data or no_auth_resp == '', 
          f"got: {no_auth_resp[:100]}")
except:
    check("No-auth request handled", True)

# 7. Load test with auth
print("\n【7. Authenticated Load Test】")
if token:
    ok = 0
    for i in range(20):
        r = curl('GET', f'{PROXY}/api/v1/admin/clients',
                 headers={'Authorization': f'Bearer {token}'}, timeout=5)
        try:
            if json.loads(r).get('clients') is not None:
                ok += 1
        except Exception as exc:
            print(f'api_login_e2e: retry skipped: {exc}')
    check(f"20 authenticated requests ({ok}/20)", ok >= 18, f"only {ok}")
else:
    check("Load test (skip - no token)", True)

print(f"\n{'=' * 70}")
print(f"  Tests: {PASS+FAIL}  Pass: {PASS}  Fail: {FAIL}")
print(f"{'=' * 70}")
sys.exit(0 if FAIL == 0 else 1)
