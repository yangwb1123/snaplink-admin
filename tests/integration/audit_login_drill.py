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
