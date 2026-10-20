"""Owned canonical-ingress browser scenarios; no production acceptance or HA."""

import json
import urllib.parse

from app_sso_entry_fixture import EntryFixture, LiveReplicaFixture, authorization_endpoint, raw_entry_observation
from app_sso_entry_transport import LIMIT, get_document, get_json, provider_contract
from browser_sso_rp import (accepted, approve, assert_original_context, check_live_grants, json_request,
                            later_issuance, password_once, require, run_normal_case, unchanged_cookie)


def navigation_contract(request):
    headers = request.all_headers()
    require(request.method == 'GET' and request.is_navigation_request() and
            'text/html' in headers.get('accept', '') and
            headers.get('sec-fetch-mode') == 'navigate' and headers.get('sec-fetch-dest') == 'document',
            'Generic RP was not exercised by a native HTML-capable browser navigation')


def blocker_contract(data, issuer, authenticated, party, before_grants, before, after, has_ui):
    require(isinstance(data, dict) and isinstance(data.get('providers'), list) and data.get('iss') == issuer and
            data.get('op_session_supported') is True and data.get('op_session_available') is authenticated and
            'op_session_error' not in data, 'Generic navigation did not expose the expected identity discovery state')
    require(not has_ui and not party.failure and len(party.grants) == before_grants and before == after,
            'Generic entry unexpectedly rendered UI, reached a grant, or submitted authentication')


def generic_navigation(context, fixture, party, counts, *, authenticated):
    before, grants = dict(counts), len(party.grants)
    ingress_before = fixture.ingress.counts.get(('POST', '/auth/login'), 0)
    page = context.new_page()
    try:
        response = page.goto(party.origin + '/start-discovery', wait_until='load', timeout=30000)
        require(response is not None and response.url == page.url, 'Generic RP lost its document response')
        navigation_contract(response.request)
        target = urllib.parse.urlsplit(page.url)
        require(target.scheme + '://' + target.netloc == fixture.issuer and target.path == '/auth/login',
                'Generic RP did not navigate to the actual advertised endpoint')
        provider_contract(response.status, response.all_headers())
        raw = response.body()
        require(len(raw) <= LIMIT, 'Browser provider response exceeded its budget')
        has_ui = page.locator('flt-glass-pane, flt-semantics-placeholder, input[type=password]').count() != 0
        blocker_contract(json.loads(raw), fixture.issuer, authenticated, party, grants, before, dict(counts), has_ui)
        require(fixture.ingress.counts.get(('POST', '/auth/login'), 0) == ingress_before,
                'Generic navigation made an identity POST outside the browser observer')
        require(len(party.pending) == 1, 'Generic entry did not own exactly one abandoned RP state')
        party.discard(page.url)  # Abandon locally, never replay or convert to a hosted request.
        require(not party.pending, 'Generic entry retained abandoned RP state')
        if not authenticated:
            require(not context.cookies(fixture.issuer), 'Fresh generic entry issued an identity cookie')
    finally:
        page.close()
    return {'document': 'provider_json', 'ui': False, 'callback': False, 'authentication_posts': 0,
            'op_session_available': authenticated, 'abandoned_state_discarded': True}


def entry_controls(fixture):
    from browser_sso_test import check_fixture_preflight
    b = fixture.rps[1]
    path = '/auth/login?' + urllib.parse.urlencode({'client_id': b.client_id})
    _, metadata = get_json(fixture.issuer + '/.well-known/openid-configuration', b.tls_context)
    raw_observation = raw_entry_observation(metadata, fixture.issuer)
    require(raw_observation['issuer_matches'] and raw_observation['path_matches'],
            'Raw gateway discovery lost its issuer or identity entry path')
    status, headers, original = get_document(fixture.issuer + path, b.tls_context)
    provider_contract(status, headers)
    status, headers, direct = get_document(fixture.backend + path, None)
    provider_contract(status, headers)
    require(original == direct, 'Raw gateway altered client-only provider JSON bytes')
    check_fixture_preflight(fixture)  # Existing tool, exact four anonymous GETs per RP.
    control = b.authorization_url('')
    query = urllib.parse.urlsplit(control).query
    try:
        status, headers, html_control = get_document(fixture.backend + '/auth/login?' + query,
                                                   None, accept='text/html')
        provider_contract(status, headers)
        require(html_control == direct, 'Stock HTML-acceptance control differed from provider JSON')
    finally:
        b.discard(fixture.issuer + '/auth/login?' + query)
    fixture.ingress.canonicalize(fixture.issuer)
    _, metadata = get_json(fixture.issuer + '/.well-known/openid-configuration', b.tls_context)
    authorization_endpoint(metadata, fixture.issuer)  # Require returned value; never repair it.
    status, headers, canonical = get_document(fixture.issuer + path, b.tls_context)
    provider_contract(status, headers)
    require(canonical == original, 'Canonical fixture ingress altered client-only provider JSON bytes')
    check_fixture_preflight(fixture)
    return {'raw_gateway': raw_observation, 'canonical_endpoint_exact': True,
            'client_only_json_byte_identical': True, 'stock_html_accept_returns_json': True}


def run_entry_browser(browser, fixture):
    from browser_sso_test import (assert_grants, browser_context, cookie_for, enable_semantics,
                                  login_form, observe)
    network = {'external_requests': 0}
    context = browser_context(browser, fixture, network=network)
    diagnostics = {}
    counts = observe(context, fixture.issuer, diagnostics)
    a, b = fixture.rps
    phase = 'generic_fresh'
    try:
        fresh = generic_navigation(context, fixture, b, counts, authenticated=False)
        phase = 'hosted_primary_form'
        primary = context.new_page()
        primary.goto(a.origin + '/start')
        login_form(primary).wait_for(timeout=30000)
        phase = 'hosted_primary_consent'
        password_once(primary)
        primary.get_by_text(a.name + ' wants access', exact=True).wait_for(timeout=30000)
        require(not context.cookies(fixture.issuer) and not a.grants and not b.grants,
                'Primary hosted consent was bypassed')
        approve(primary, a)
        phase = 'hosted_primary_callback'
        accepted(primary, a)
        require(diagnostics.get('credential_complete') is True and
                counts == {'password': 1, 'resume': 0, 'continuation': 1, 'unexpected': 0},
                'Hosted primary did not submit exactly one password and its own consent')
        original = cookie_for(context, fixture.issuer)
        require(original['httpOnly'] and original['secure'] and original['sameSite'] == 'Lax' and
                original['domain'] == '127.0.0.1' and original['path'] == '/', 'Unsafe hosted OP cookie attributes')
        claims = assert_original_context(a.grants, original)
        phase = 'generic_authenticated'
        authenticated = generic_navigation(context, fixture, b, counts, authenticated=True)
        unchanged_cookie(context, fixture, original)
        later_issuance(claims)
        phase = 'hosted_secondary_consent'
        second = context.new_page()
        second.goto(b.origin + '/start')  # NEW request; never reuse the abandoned generic request.
        enable_semantics(second)
        second.get_by_text(b.name + ' wants access', exact=True).wait_for(timeout=30000)
        require(not b.grants and len(a.grants) == 1 and
                counts == {'password': 1, 'resume': 1, 'continuation': 1, 'unexpected': 0},
                'Hosted B did not require its own consent after identity-only resume')
        unchanged_cookie(context, fixture, original)
        approve(second, b)
        phase = 'hosted_secondary_callback'
        accepted(second, b)
        assert_grants(fixture, original)
        require(counts == {'password': 1, 'resume': 1, 'continuation': 2, 'unexpected': 0},
                'Hosted B replayed authentication or consent')
        require(all(b.grants[0][token]['iat'] > claims['auth_time'] for token in ('access', 'identity')),
                'Hosted B issuance did not cross the original authentication second')
        unchanged_cookie(context, fixture, original)
        check_live_grants(fixture)
        require(not fixture.ingress.failed and network['external_requests'] == 0,
                'Entry fixture used an external resource or failed its identity ingress')
        return {'generic_fresh': fresh, 'generic_authenticated': authenticated,
                'hosted_counts': dict(counts), 'completed_grants': 2, 'exact_auth_time': True,
                'cookie_unchanged': True, **network}
    except Exception:
        print('Entry failure phase:', phase, '; counts:', counts, '; safe OP diagnostics:', diagnostics, flush=True)
        raise
    finally:
        context.close()


def run_entry_case(playwright, backend, web, gateway, channel):
    with EntryFixture(backend, web, gateway, consent_skips=(False, False)) as fixture:
        controls = entry_controls(fixture)
        browser = playwright.chromium.launch(headless=True, channel=channel)
        try:
            print('Case: rp-entry; gateway:', gateway, '; Chromium:', browser.version, flush=True)
            evidence = run_entry_browser(browser, fixture)
        finally:
            browser.close()
    # Published by the parent only AFTER independent descendant/resource checks.
    return {'case': 'rp-entry', 'gateway': gateway, 'cleanup_verified': True, **controls, **evidence}


def separate_context_login(browser, context, fixture, original, first_claims):
    """Same user/remembered B consent does not imply a shared browser identity."""
    from browser_sso_test import browser_context, cookie_for, login_form, observe
    b = fixture.rps[1]
    before = len(b.grants)
    network = {'external_requests': 0}
    isolated = browser_context(browser, fixture, network=network)
    diagnostics = {}
    counts = observe(isolated, fixture.issuer, diagnostics)
    try:
        page = isolated.new_page()
        page.goto(b.origin + '/start')
        login_form(page).wait_for(timeout=30000)
        require(not isolated.cookies(fixture.issuer), 'Separate browser inherited OP cookies')
        require(counts == {'password': 0, 'resume': 0, 'continuation': 0, 'unexpected': 0},
                'Separate browser attempted automatic authorization')
        require(len(b.grants) == before, 'Separate browser obtained a grant before authentication')
        password_once(page)
        # Per-user/client consent is remembered across jars, not authentication.
        accepted(page, b)
        require(diagnostics.get('credential_complete') is True, 'Separate form lost fixture credentials')
        require(counts == {'password': 1, 'resume': 0, 'continuation': 0, 'unexpected': 0},
                'Separate-browser authentication or saved consent was replayed')
        require(len(b.grants) == before + 1, 'Separate-browser code exchange did not complete once')
        independent = cookie_for(isolated, fixture.issuer)
        claims = assert_original_context([b.grants[-1]], independent)
        require(claims['auth_time'] > first_claims['auth_time'], 'Separate login reused the old authentication time')
        require(independent['value'] != original['value'] and claims['sid'] != first_claims['sid'],
                'Separate authentication reused the old canonical anchor')
        unchanged_cookie(context, fixture, original)
        require(network['external_requests'] == 0, 'Separate browser used an external resource')
    finally:
        isolated.close()
    print('PASS: separate jar needs its own password/canonical anchor, despite remembered B consent')
    return dict(counts)


def cross_process_verification(fixture):
    # Each original token is sent only to its own OP, not to the other RP.
    # Read fresh JWKS through the opposite live process; no cached key equality
    # or readiness check can stand in for signature/claims or bearer validation.
    for party, replica in zip(fixture.rps, (2, 1)):
        fixture.select_replica(replica)
        before = dict(fixture.ingress.replica_counts)
        grant = party.grants[0]
        identity = party.verify_identity(grant['tokens']['id_token'], grant['identity']['nonce'])
        require(identity == grant['identity'], 'Opposite-process JWKS verification changed ID-token claims')
        user = json_request(fixture.issuer + '/userinfo', token=grant['tokens']['access_token'],
                            tls_context=party.tls_context)
        require(user.get('sub') == grant['identity']['sub'], 'Opposite-process access-token verification failed')
        expected = dict(before)
        for path in ('/.well-known/jwks.json', '/userinfo'):
            key = (replica, 'GET', path)
            expected[key] = expected.get(key, 0) + 1
        require(fixture.ingress.replica_counts == expected,
                'Opposite-process verification did not traverse the selected live replica')
        fixture.assert_live()
    return {'opposite_jwks_verifications': 2, 'opposite_userinfo_verifications': 2}


def run_live_case(playwright, backend, web, gateway, channel):
    with LiveReplicaFixture(backend, web, gateway, consent_skips=(False, False)) as fixture:
        fixture.assert_live()  # Both original processes before A starts.
        print('Phase: launch owned Chrome', flush=True)
        browser = playwright.chromium.launch(headless=True, channel=channel)
        try:
            print('Case: live-replicas; gateway:', gateway, '; Chromium:', browser.version, flush=True)
            evidence = run_normal_case(browser, fixture, after_primary=fixture.after_primary)
            fixture.assert_routing()
            verification = cross_process_verification(fixture)
            fixture.assert_routing()  # Same originals after B, repeats and both cross-checks.
            live = {'original_processes': 2, 'distinct_pids': True, 'both_live_before_a_and_after_b': True,
                    'replica_1_code_exchanges': 1, 'replica_2_code_exchanges': 3,
                    'replica_1_login_posts': 3, 'replica_2_login_posts': 7,
                    'op_cookie_issuances': 1, 'op_cookie_reissues': 0, 'store': 'redis',
                    'fixed_shared_signing_key': True, **verification}
        finally:
            browser.close()
    return {'case': 'live-replicas', 'gateway': gateway, 'cleanup_verified': True, **live, **evidence}
