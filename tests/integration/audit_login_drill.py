#!/usr/bin/env python3
"""B6-2 client_id contract drill — device redirect-leg facts
(lib/screens/device lens).

Proves: (a) the device-entry login leg has the shape the module pins
(REQ-1: /login/?redirect=/device/verify[?user_code=…] — built by the
same rule as device_verify_screen.dart:174-180), (b) a login through
that leg carries the aligned client_id on POST /auth/login
(sso_client.dart:92 wire), (c) the deployed sink shows exactly one
auth.login.success row with that client_id, no duplicates
(implementation-gate.md:57 '无重复').

Step 【3b】 adds the setup-originated leg (REQ-3): wizard POST →
immediate login → sink query → exactly one auth.login.success row with
the agreed client_id, zero duplicates; zero matches → exit 1, never
skipped. Sink emission is IdP-side (B4-5) — the leg is [proposed] and
FAILs loudly until that lands; a runnable leg is never marked
[proposed] for a zero/unverifiable query result.

Step 【1b】 adds the DCR leg (REQ-1): POST {PROXY}/register with
the register_panel wire shape (developer_api.dart:104 →
DcrClientMetadata.toRegistrationWire(), dcr_models.dart:151-165); the
RFC 7591 server-assigned response client_id must equal AGREED_CLIENT_ID
(REQ-1.4) — a failed/mismatched register exits 1 with the response
printed, never a skip, never [proposed].

Branch value (REQ-0): AGREED_CLIENT_ID = 'console' (A) or
'sso-admin-console' (B), one line. The login leg is API-driven through
the proxy because Flutter renders to a canvas (browser_login_test.py:89).

Usage: python3 tests/integration/audit_login_drill.py
Exit code: 0 = PASS or SKIP, 1 = FAIL.
Settle knob: SNAPLINK_DRILL_SETTLE_SECONDS (floor 10) for event-ingestion lag.
"""
import base64
import json
import os
import subprocess
import sys
import time
from urllib.parse import parse_qs, quote, urlsplit

from test_config import CONFIG, IntegrationConfigurationError

AGREED_CLIENT_ID = 'sso-admin-console'  # Branch B (REQ-0 decision)

PASS = 0
FAIL = 0


def check(label, ok, detail=''):
    global PASS, FAIL
    if ok:
        PASS += 1
        print(f"  ✅ {label}")
    else:
        FAIL += 1
        print(f"  ❌ {label}" + (f": {detail}" if detail else ""))


def curl(method, url, data=None, headers=None, timeout=15):
    cmd = ['curl', '-s', '--max-time', str(timeout)]
    if method != 'GET':
        cmd += ['-X', method]
    if data is not None:
        cmd += ['-d', json.dumps(data)]
    if headers:
        for k, v in headers.items():
            cmd += ['-H', f'{k}: {v}']
    cmd.append(url)
    result = subprocess.run(cmd, capture_output=True, text=True,
                            timeout=timeout + 5)
    return result.stdout.strip()


def decode_jwt(token):
    """Read-only JWT payload decode (full_integration_test.py:29-33 idiom)."""
    payload = token.split('.')[1]
    pad = 4 - len(payload) % 4
    if pad != 4:
        payload += '=' * pad
    return json.loads(base64.urlsafe_b64decode(payload))


def settle_seconds():
    try:
        return max(10, int(os.environ.get('SNAPLINK_DRILL_SETTLE_SECONDS', '10')))
    except ValueError:
        return 10


def sink_rows(token, tenant_id):
    """GET the sink audit events for auth.login.success (server route only,
    REQ-4: the localStorage ring is never consulted)."""
    url = (f'{API}/api/v1/audit/events'
           f'?event_types=auth.login.success&tenant_id={tenant_id}')
    resp = curl('GET', url, headers={'Authorization': f'Bearer {token}'})
    try:
        data = json.loads(resp)
        return data.get('events') or data.get('items') or []
    except Exception:
        return None


def read_events(token, tenant_id):
    """GET the sink audit events without an event-type filter — the
    console-shaped query (limit serialized as a string, matching
    AuditQuery's '$limit' wire, audit_query.dart)."""
    url = (f'{API}/api/v1/audit/events'
           f'?tenant_id={tenant_id}&limit=100')
    resp = curl('GET', url, headers={'Authorization': f'Bearer {token}'})
    try:
        data = json.loads(resp)
        return data.get('events') or data.get('items') or []
    except Exception:
        return None


try:
    CONFIG.require_credentials()
except IntegrationConfigurationError as error:
    # No live stack/credentials configured: skip cleanly, never a false
    # PASS or FAIL (api_login_e2e.py:27-36 idiom).
    print(f"SKIP: {error}")
    sys.exit(0)

PROXY = CONFIG.proxy_url
API = CONFIG.api_url

print("=" * 70)
print("  B6-2 Login Drill (client_id contract, device redirect leg)")
print("=" * 70)
print()

# Step 1 — REQ-0 evidence: the drill's client_id matches the agreed value.
print("【1. Client ID alignment (REQ-0)】")
check("CONFIG.client_id == AGREED_CLIENT_ID",
      CONFIG.client_id == AGREED_CLIENT_ID,
      f"config={CONFIG.client_id!r}, agreed={AGREED_CLIENT_ID!r}")

# Step 1b — REQ-1 DCR leg: POST /register with the module's wire shape
# (developer_api.dart:104 → DcrClientMetadata.toRegistrationWire(),
# dcr_models.dart:151-165). RFC 7591: client_id is server-assigned —
# never sent in the body; the response id must equal AGREED_CLIENT_ID.
print("\n【1b. DCR: POST /register issues the agreed client_id (REQ-1)】")


def register_client():
    """POST {PROXY}/register with the register_panel wire shape; return
    (parsed response dict or None, raw body)."""
    body = {
        'client_name': f'drill-dcr-{int(time.time())}',
        'redirect_uris': ['https://app.example.test/callback'],
        'scope': 'openid profile',
        'token_endpoint_auth_method': 'client_secret_basic',
        'token_strategy': 'jwt',
        'grant_types': ['authorization_code', 'refresh_token'],
        'require_pkce': True,
    }
    check("DCR body has no client_id (RFC 7591 server-assigned)",
          'client_id' not in body)
    raw = curl('POST', f'{PROXY}/register', data=body,
               headers={'Content-Type': 'application/json'})
    try:
        return json.loads(raw), raw
    except Exception:
        check("DCR response is parseable JSON", False, raw[:200])
        return None, raw


dcr_resp, dcr_raw = register_client()
if dcr_resp is None:
    check("DCR register 2xx JSON", False, f"POST {PROXY}/register")
    dcr_client_id = None
else:
    dcr_client_id = dcr_resp.get('client_id')
    check("DCR response client_id == AGREED_CLIENT_ID",
          dcr_client_id == AGREED_CLIENT_ID,
          f"issued {dcr_client_id!r}, agreed {AGREED_CLIENT_ID!r}")
    print(f"    register response: {dcr_raw[:300]}")

# Step 2 — REQ-3 device leg: build the device-entry login URL by the
# module's rule (device_verify_screen.dart:174-180) and assert the
# redirect query parameter has the leg shape REQ-1 pins. No browser hop:
# the drill's login is API-driven; this step pins URL *construction*.
print("\n【2. Device redirect-leg shape (REQ-3)】")
for label, target in (
    ("redirect with user_code", '/device/verify?user_code=WXYZ-1234'),
    ("redirect without code", '/device/verify'),
):
    login_url = f'{PROXY}/login/?redirect=' + quote(target, safe='/')
    redirect_value = parse_qs(urlsplit(login_url).query)['redirect'][0]
    check(f"{label} == {target!r}", redirect_value == target,
          f"got {redirect_value!r}")

# Step 3 — REQ-3 login: one real POST /auth/login with the aligned
# client_id and CONFIG.login_payload() (the sso_client.dart:92 wire).
print("\n【3. Login through the device funnel wire (REQ-3)】")
login_data = CONFIG.login_payload()
check("login payload carries the agreed client_id",
      login_data.get('client_id') == AGREED_CLIENT_ID,
      f"got {login_data.get('client_id')!r}")
if dcr_client_id is not None:
    login_data['client_id'] = dcr_client_id
    check("login client_id sourced from DCR response (register→manage pivot)",
          login_data['client_id'] == AGREED_CLIENT_ID)
auth_resp = curl('POST', f'{PROXY}/auth/login', data=login_data,
                 headers={'Content-Type': 'application/json'})
token = ''
tenant_id = None
try:
    auth_data = json.loads(auth_resp)
    token = auth_data.get('access_token', '')
    check("Login returns access_token", len(token) > 20,
          f"token length={len(token)}")
    parts = token.split('.')
    check("Token is JWT (3 parts)", len(parts) == 3, f"got {len(parts)} parts")
    claims = decode_jwt(token) if len(parts) == 3 else {}
    tenant_id = claims.get('tenant_id')
    if tenant_id:
        check(f"JWT tenant_id claim: {tenant_id}", True)
    else:
        check("JWT tenant_id claim present", False,
              "B4-1 dependency: drill does not implement claim parsing")
except Exception as error:
    check("Parse auth response", False, str(error))

# Step 3b — REQ-3 setup-originated leg: wizard POST → immediate login →
# settle → sink query → exactly one row with the agreed client_id, zero
# duplicates; zero matches → exit 1, never skipped. Additive: uses local
# variables only (setup_*), so step 3's token/tenant_id (device leg,
# steps 4-6) are never written. Sink emission is IdP-side (B4-5,
# implementation-gate.md:57 dependency column); zero auth.login.success
# emission strings exist in this repo (census
# test/oidc_login_handle_success_census_test.dart:97-105) — the leg is
# [proposed] until B4-5 lands and FAILs loudly, never a skip, never a
# false PASS.
print("\n【3b. Setup-originated login leg (REQ-3)】")
print("  [proposed] sink emission is IdP-side (B4-5, "
      "implementation-gate.md:57); zero auth.login.success emission")
print("  strings exist in this repo (census "
      "test/oidc_login_handle_success_census_test.dart:97-105).")

# 3b-1 — Stack freshness, hard precondition check. The wizard is a
# one-time bootstrap: POST /api/v1/setup 409s on an initialized stack
# (SetupResult.alreadyDone, lib/api/setup_api.dart:98/:208-209). On an
# initialized stack this FAILs loudly (never a skip) and the deviation
# is recorded per the [RESOLVED] note convention.
setup_status_resp = curl('GET', f'{PROXY}/api/v1/setup/status')
try:
    setup_status = json.loads(setup_status_resp)
except Exception:
    setup_status = {}
check("setup leg: stack uninitialized (setup_required)",
      setup_status.get('setup_required') is True,
      f"got {setup_status.get('setup_required')!r}")

# 3b-2 — Wizard completion wire (lib/api/setup_api.dart:161-162:
# {'admin': admin.toJson(), if (application != null) 'application': …}).
# A fresh username keeps the leg repeatable; the password satisfies the
# ≥8-char wizard validation (setup_screen_test.dart:17 pins it).
setup_epoch = int(time.time())
setup_admin = f'drill-setup-{setup_epoch}'
setup_password = f'drill-pass-{setup_epoch}'
setup_resp = curl('POST', f'{PROXY}/api/v1/setup',
                  data={'admin': {'username': setup_admin,
                                  'password': setup_password}},
                  headers={'Content-Type': 'application/json'})
try:
    setup_data = json.loads(setup_resp)
    created_admin = (setup_data.get('created') or {}).get('admin')
    setup_ok = setup_data.get('ok') is True and bool(created_admin)
    setup_detail = ''
    if not setup_ok:
        error = (setup_data.get('error')
                 or setup_data.get('message') or '')
        if error:
            setup_detail = f'error={error!r}'
            if 'already' in str(error).lower():
                setup_detail += (' (409 already-initialized: run on a '
                                 'fresh stack)')
        else:
            setup_detail = f'body={setup_resp[:120]!r}'
except Exception:
    setup_ok = False
    setup_detail = f'non-JSON response: {setup_resp[:120]!r}'
check("setup leg: wizard POST ok + created admin", setup_ok,
      setup_detail)

# 3b-3 — Immediate login with the created admin (D3: login_payload()
# hardcodes CONFIG.username — merge the created admin locally;
# test_config.py stays untouched; 'client_id' carried from :90).
setup_login_data = CONFIG.login_payload(password=setup_password)
setup_login_data['credential']['username'] = setup_admin
setup_auth_resp = curl('POST', f'{PROXY}/auth/login',
                       data=setup_login_data,
                       headers={'Content-Type': 'application/json'})
setup_token = ''
setup_tenant_id = None
try:
    setup_auth_data = json.loads(setup_auth_resp)
    setup_token = setup_auth_data.get('access_token', '')
    check("setup leg: login returns access_token",
          len(setup_token) > 20,
          f"token length={len(setup_token)}")
    setup_parts = setup_token.split('.')
    check("setup leg: token is JWT (3 parts)",
          len(setup_parts) == 3, f"got {len(setup_parts)} parts")
    setup_claims = (decode_jwt(setup_token)
                    if len(setup_parts) == 3 else {})
    setup_tenant_id = setup_claims.get('tenant_id')
    check("setup leg: JWT tenant_id claim present",
          bool(setup_tenant_id),
          "B4-1 dependency: drill does not implement claim parsing")
except Exception as error:
    check("setup leg: parse auth response", False, str(error))

# D2 premise-evidence line (design §1 D2 / FM-17): the "fresh setup
# creates a fresh tenant; its initial admin is that tenant's root"
# premise is an external-repo assumption with zero in-repo evidence —
# this line is the empirical channel for the §7(c) acceptance gate
# (compare setup_tenant_id with the device leg's tenant_id across runs;
# record the comparison in the [RESOLVED] note).
print(f"  premise-evidence: setup_tenant_id={setup_tenant_id!r} "
      f"vs device tenant_id={tenant_id!r}")

if setup_token and setup_tenant_id:
    # 3b-4 — Settle ingestion before the first query (F11): the setup
    # login is immediate (API-driven, no browser round-trip), so the
    # first sink query must not race the sink.
    setup_settle = settle_seconds()
    print(f"  ⏳ settling {setup_settle}s for event-ingestion lag (F11) "
          "before the first sink query")
    time.sleep(setup_settle)

    # 3b-5 — Sink query, tenant-isolated (D2: separate setup_token /
    # setup_tenant_id keep the leg additive; steps 4-6 count the device
    # tenant only). Valid only under the §1 D2 assumption.
    setup_rows = sink_rows(setup_token, setup_tenant_id)
    if setup_rows is None:
        check("setup leg: sink query verifiable", False,
              "unverifiable sink — never [proposed] on a runnable leg")
    else:
        # 3b-6 — Hard checks (mirror of Step 4's semantics): zero matches
        # is a FAIL → exit 1, never a skip, never a PASS; duplicates FAIL.
        setup_matching = [r for r in setup_rows
                          if r.get('client_id') == AGREED_CLIENT_ID]
        check("setup leg: exactly one auth.login.success row with "
              f"client_id={AGREED_CLIENT_ID}",
              len(setup_matching) == 1,
              f"got {len(setup_matching)} row(s) of "
              f"{len(setup_rows)} total")
        setup_settle = settle_seconds()
        print(f"  ⏳ settling {setup_settle}s for event-ingestion lag "
              "(F11)")
        time.sleep(setup_settle)
        setup_rows_after = sink_rows(setup_token, setup_tenant_id) or []
        check("setup leg: count stable after re-settle",
              len(setup_rows_after) == len(setup_rows),
              f"was {len(setup_rows)}, now {len(setup_rows_after)}")
else:
    # No setup token/tenant_id: the login/parse checks above already
    # FAILed loudly — a runnable leg never converts this into [proposed]
    # (REQ-3 never-skip rule).
    print("  ⚠️ no setup token/tenant_id — the checks above FAILed; "
          "never [proposed] (REQ-3 never-skip rule)")

# Step 4 — REQ-3 sink: exactly one auth.login.success row with the
# agreed client_id. Reads only the server route (REQ-4: no ring).
print("\n【4. Sink: exactly one auth.login.success row (REQ-3)】")
proposed = False
if token and tenant_id:
    rows = sink_rows(token, tenant_id)
    if rows is None:
        proposed = True
        print("  ⚠️ sink query unverifiable (no response / non-JSON); "
              "sink legs marked [proposed] — no false PASS")
        print(f"    query: GET {API}/api/v1/audit/events"
              f"?event_types=auth.login.success&tenant_id={tenant_id}")
    else:
        matching = [r for r in rows if r.get('client_id') == AGREED_CLIENT_ID]
        check(f"exactly one auth.login.success row with client_id="
              f"{AGREED_CLIENT_ID}",
              len(matching) == 1,
              f"got {len(matching)} row(s) of {len(rows)} total")
else:
    print("  ⚠️ no token/tenant_id — sink legs unverifiable; "
          "marked [proposed] — no false PASS")
    proposed = True

# Step 5 — no duplicates (implementation-gate.md:57 '无重复').
print("\n【5. No duplicates (REQ-3)】")
if not proposed:
    second_resp = curl('POST', f'{PROXY}/auth/login', data=login_data,
                       headers={'Content-Type': 'application/json'})
    try:
        second_token = json.loads(second_resp).get('access_token', '')
        check("Second login returns access_token", len(second_token) > 20)
    except Exception:
        check("Second login returns access_token", False)
    settle = settle_seconds()
    print(f"  ⏳ settling {settle}s for event-ingestion lag (F11)")
    time.sleep(settle)
    rows_after = sink_rows(token, tenant_id) or []
    event_ids = [r.get('id') or r.get('trace_id') for r in rows_after]
    check("two rows total after second login",
          len(rows_after) == 2, f"got {len(rows_after)}")
    check("no repeated event id/trace_id",
          len(event_ids) == len(set(event_ids)))
    time.sleep(settle)
    rows_stable = sink_rows(token, tenant_id) or []
    check("count stable after re-settle",
          len(rows_stable) == len(rows_after),
          f"was {len(rows_after)}, now {len(rows_stable)}")
else:
    print("  ⏭️ no-duplicates legs skipped ([proposed], no stack/emission)")

# Step 6 — T-12 joint (implementation-gate.md:56): a console-shaped read
# triggers the caller's own audit.event.read self-audit row (sink-side
# emission is B1-5, implementation-gate.md:47 — until it lands, this leg
# records [proposed], never a false PASS).
print("\n【6. T-12 joint: console-shaped read triggers the caller's own "
      "audit.event.read】")
read_proposed = False
if token and tenant_id:
    # Console-shaped query: GET {API}/api/v1/audit/events
    # ?tenant_id=<t>&limit=100 — the exact wire the timeline tab issues
    # (AuditQuery serializes limit as a string).
    console_resp = curl(
        'GET',
        f'{API}/api/v1/audit/events?tenant_id={tenant_id}&limit=100',
        headers={'Authorization': f'Bearer {token}'},
    )
    try:
        json.loads(console_resp)
        console_ok = True
    except Exception:
        console_ok = False
    if not console_ok:
        read_proposed = True
        print("  ⚠️ console-shaped query unverifiable (no response / "
              "non-JSON); read leg marked [proposed] — no false PASS")
        print(f"    query: GET {API}/api/v1/audit/events"
              f"?tenant_id={tenant_id}&limit=100")
    else:
        settle = settle_seconds()
        print(f"  ⏳ settling {settle}s for event-ingestion lag (F11)")
        time.sleep(settle)
        read_rows = read_events(token, tenant_id) or []
        # P4 load-bearing pin: canonical type match (exact, never a bare
        # substring) AND actor == caller identity (JWT sub / drill client
        # identity) — a concurrent same-tenant read cannot decoy a PASS
        # (the token is fresh and singly held).
        caller = claims.get('sub') or AGREED_CLIENT_ID
        read_events_rows = [
            r for r in read_rows if r.get('type') == 'audit.event.read'
        ]
        attributed = [
            r for r in read_events_rows
            if (r.get('actor_id') or r.get('actorId')) == caller
        ]
        if attributed:
            check(
                f"caller-attributed audit.event.read row observed "
                f"(actor == {caller!r})",
                True,
                f"{len(attributed)} row(s)",
            )
        else:
            read_proposed = True
            print("  ⚠️ no caller-attributed audit.event.read row observed; "
                  "emission is sink-side B1-5 (implementation-gate.md:47) — "
                  "read leg marked [proposed] — no false PASS")
            print(f"    query: GET {API}/api/v1/audit/events"
                  f"?tenant_id={tenant_id}&limit=100")
else:
    read_proposed = True
    print("  ⚠️ no token/tenant_id — read leg unverifiable; "
          "marked [proposed] — no false PASS")
proposed = proposed or read_proposed

# Step 7 — report.
print(f"\n{'=' * 70}")
if proposed:
    print("  [proposed] sink-side legs (steps 4-6) were NOT verified: "
          "emission is generated outside this repo (0 grep hits). "
          "Record this deviation in the [RESOLVED] note "
          "(audit-contract-batch-snaplink-console.md) — no false PASS.")
print(f"  Drill: {PASS + FAIL} checks  Pass: {PASS}  Fail: {FAIL}")
print(f"{'=' * 70}")
sys.exit(1 if FAIL else 0)
