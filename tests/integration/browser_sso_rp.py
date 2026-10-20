"""Disposable loopback RPs. Grants stay server-side; never in browser storage."""

import base64
import hashlib
import ipaddress
import json
import secrets
import threading
import time
import urllib.parse
import urllib.request
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer


class FixtureFailure(RuntimeError):
    """Safe-to-print assertion, without credentials, codes or callback URLs."""


def require(condition, label):
    if not condition:
        raise FixtureFailure(label)


def jwt_payload(value):
    # The code exchange is with our own stock OP. This projection is only for
    # assertions; acceptance as a credential is checked by real /userinfo.
    parts = value.split('.')
    require(len(parts) == 3, 'OP did not issue a JWT')
    raw = parts[1] + '=' * (-len(parts[1]) % 4)
    return json.loads(base64.urlsafe_b64decode(raw))


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, *_):
        return None


def json_request(url, *, form=None, token=None, tls_context=None):
    body = urllib.parse.urlencode(form).encode() if form is not None else None
    headers = {'Accept': 'application/json'}
    if form is not None:
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
    if token is not None:
        headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(url, data=body, headers=headers)
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect(),
                                         urllib.request.HTTPSHandler(context=tls_context))
    try:
        response = opener.open(request, timeout=15)
    except urllib.error.HTTPError as error:
        error.close()
        raise FixtureFailure('OP request failed') from None
    with response:
        require(response.status == 200 and response.headers.get_content_type() == 'application/json', 'OP request failed')
        raw = response.read(65537)
        require(len(raw) <= 65536, 'OP response exceeded the fixture budget')
        return json.loads(raw)


def assert_original_context(grants, cookie):
    # Read-only projection of the real browser-issued cookie; never mint or
    # inject one. Actual OP-session resolution is proved by the UI resume/code
    # exchange, not by decoding this JWT or comparing public signing keys.
    original = jwt_payload(cookie['value'])
    auth_time = original.get('auth_time')
    require(type(auth_time) is int and auth_time > 0, 'Cookie authentication time is missing')
    require(grants and original.get('sid') == grants[0]['access'].get('sid'),
            'Cookie canonical anchor differs from the primary grant')
    for grant in grants:
        access, identity = grant['access'], grant['identity']
        require(access.get('sub') == identity.get('sub') == original.get('sub') and original.get('sub'),
                'Cookie and tokens identify different subjects')
        require(access.get('sid') and access['sid'] == identity.get('sid'),
                'Access and ID tokens identify different authorization sessions')
        for claims in (access, identity):
            require(type(claims.get('auth_time')) is int and claims['auth_time'] == auth_time,
                    'Cookie/access/ID-token authentication times differ')
        for field in ('amr', 'acr'):
            require(access.get(field) == identity.get(field) == grants[0]['access'].get(field),
                    'Original authentication context changed across grants or token types')
    return original


def assert_distinct_grants(grants):
    require(grants, 'No completed RP grants')
    for container, fields in (('tokens', ('access_token', 'refresh_token', 'id_token')),
                               ('request', ('code', 'state', 'pkce'))):
        for field in fields:
            values = [grant.get(container, {}).get(field) for grant in grants]
            require(all(values) and len(set(values)) == len(values),
                    'Authorization requests shared or lost tokens, codes, state or PKCE')
    sessions = [grant['access'].get('sid') for grant in grants]
    require(all(sessions) and len(set(sessions)) == len(sessions), 'Authorization requests shared sessions')
    nonces = [grant['identity'].get('nonce') for grant in grants]
    require(all(nonces) and len(set(nonces)) == len(nonces), 'Authorization requests shared nonces')


class RelyingParty:
    def __init__(self, client_id, name, skip_consent, *, host='127.0.0.1', server_type=ThreadingHTTPServer):
        require(ipaddress.ip_address(host).is_loopback, 'RP fixture must bind loopback only')
        self.client_id = client_id
        self.name = name
        self.skip_consent = skip_consent
        self.issuer = ''
        self.tls_context = None
        self.pending = {}
        self.grants = []
        self.failure = False
        self.received_identity_cookie = False
        self.lock = threading.Lock()
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass  # Callback query contains a one-use authorization code.

            def do_GET(self):
                # Retain only a presence bit, never identity-cookie values.
                if any(part.split('=', 1)[0].strip() == 'snaplink_op_session'
                       for part in self.headers.get('Cookie', '').split(';')):
                    owner.received_identity_cookie = True
                try:
                    owner.handle(self)
                except Exception:
                    owner.failure = True
                    self.send_response(500)
                    self.end_headers()
                    self.wfile.write(b'Fixture callback rejected')

        self.server = server_type((host, 0), Handler)
        self.origin = f'http://{host}:{self.server.server_port}'
        self.redirect = self.origin + '/callback'
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        try:
            self.thread.start()
        except BaseException:
            if self.thread.ident is not None:
                self.server.shutdown()
                self.thread.join(timeout=3)
            self.server.server_close()
            raise

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)

    def client_config(self):
        return {
            'id': self.client_id, 'name': self.name, 'active': True,
            'token_strategy': 'jwt', 'token_endpoint_auth_method': 'none',
            'require_pkce': True, 'allowed_authenticators': ['password'],
            'allowed_scopes': ['openid', self.client_id + ':read'],
            'allowed_resources': [self.client_id + '-api'],
            'redirect_uris': [self.redirect], 'skip_consent': self.skip_consent,
        }

    def authorization_url(self, query):
        options = urllib.parse.parse_qs(query, keep_blank_values=True)
        require(set(options) <= {'prompt', 'max_age'}, 'Unknown fixture request option')
        require(all(len(values) == 1 for values in options.values()), 'Duplicate fixture option')
        state, nonce, verifier = (secrets.token_urlsafe(32) for _ in range(3))
        with self.lock:
            self.pending[state] = (nonce, verifier)
        challenge = base64.urlsafe_b64encode(hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')
        payload = {
            'client_id': self.client_id, 'response_type': 'code',
            'redirect_uri': self.redirect, 'scope': 'openid ' + self.client_id + ':read',
            'resource': self.client_id + '-api', 'state': state, 'nonce': nonce,
            'code_challenge': challenge, 'code_challenge_method': 'S256',
            **{key: value[0] for key, value in options.items()},
        }
        return self.issuer + '/login/?' + urllib.parse.urlencode(payload)

    def handle(self, handler):
        target = urllib.parse.urlsplit(handler.path)
        if target.path == '/start':
            location = self.authorization_url(target.query)
            handler.send_response(302)
            handler.send_header('Location', location)
            handler.send_header('Cache-Control', 'no-store')
            handler.end_headers()
            return
        if target.path == '/favicon.ico':
            handler.send_response(204)
            handler.end_headers()
            return
        require(target.path == '/callback', 'Unknown RP path')
        self.exchange(urllib.parse.parse_qs(target.query))
        handler.send_response(200)
        handler.send_header('Content-Type', 'text/html; charset=utf-8')
        handler.send_header('Cache-Control', 'no-store')
        handler.end_headers()
        handler.wfile.write(b'<!doctype html><title>RP fixture</title><h1>Grant accepted</h1>')

    def exchange(self, params):
        require(all(len(value) == 1 for value in params.values()), 'Ambiguous RP callback')
        require(params.get('iss') == [self.issuer], 'RP issuer binding failed')
        require('error' not in params and 'code' in params and 'state' in params, 'RP did not receive a code')
        with self.lock:
            pending = self.pending.pop(params['state'][0], None)
        require(pending is not None, 'RP state binding failed')
        nonce, verifier = pending
        tokens = json_request(self.issuer + '/token', tls_context=self.tls_context, form={
            'grant_type': 'authorization_code', 'client_id': self.client_id,
            'redirect_uri': self.redirect, 'code': params['code'][0], 'code_verifier': verifier,
        })
        access = jwt_payload(tokens['access_token'])
        identity = self.verify_identity(tokens['id_token'], nonce)
        require(access.get('client_id') == self.client_id, 'Access-token client binding failed')
        audience = access.get('aud')
        require(audience in (self.client_id + '-api', [self.client_id + '-api']), 'Resource binding failed')
        require(set(access.get('scope', '').split()) == {'openid', self.client_id + ':read'}, 'Scope binding failed')
        require(access.get('iss') == self.issuer, 'Token issuer binding failed')
        user = json_request(self.issuer + '/userinfo', token=tokens['access_token'], tls_context=self.tls_context)
        require(user.get('sub') == identity.get('sub'), 'Resource validation failed')
        request = {name: hashlib.sha256(value.encode()).hexdigest() for name, value in
                   (('code', params['code'][0]), ('state', params['state'][0]), ('pkce', verifier))}
        with self.lock:
            self.grants.append({'tokens': tokens, 'access': access, 'identity': identity, 'request': request})

    def verify_identity(self, token, nonce):
        import jwt  # Optional browser-test dependency, not needed by unit gates.
        try:
            header = jwt.get_unverified_header(token)
            require(header.get('alg') == 'EdDSA', 'Unexpected fixture ID-token algorithm')
            jwks = json_request(self.issuer + '/.well-known/jwks.json', tls_context=self.tls_context)
            keys = [key for key in jwks['keys'] if key.get('kid') == header.get('kid')]
            require(len(keys) == 1, 'RP signing key is missing or ambiguous')
            identity = jwt.decode(token, jwt.PyJWK.from_dict(keys[0]).key, algorithms=['EdDSA'],
                                  audience=self.client_id, issuer=self.issuer,
                                  options={'require': ['iss', 'aud', 'sub', 'exp', 'iat', 'nonce']})
        except jwt.PyJWTError:
            raise FixtureFailure('RP ID-token signature or claims verification failed') from None
        require(identity['nonce'] == nonce, 'RP nonce binding failed')
        return identity


# Extra normal-flow assertions live in the existing isolated-fixture modules,
# never in scripts that read live deployment CONFIG. UI imports are lazy to
# keep the RP module usable without Playwright and avoid an import cycle.
def accepted(page, rp):
    page.wait_for_url(rp.origin + '/callback?**', timeout=30000)
    page.get_by_role('heading', name='Grant accepted').wait_for()
    require(not rp.failure, 'RP callback verification failed')
    page.close()


def approve(page, rp):
    page.get_by_text(rp.name + ' wants access', exact=True).wait_for(timeout=30000)
    require(page.get_by_role('textbox', name='Password', exact=True).count() == 0,
            'Consent demanded another password')
    page.get_by_role('button', name='Allow', exact=True).click()


def password_once(page):
    from browser_sso_fixture import FIXTURE_PASSWORD, FIXTURE_USER
    from browser_sso_test import type_primary_field
    type_primary_field(page, 'Username', FIXTURE_USER)
    type_primary_field(page, 'Password', FIXTURE_PASSWORD)
    page.get_by_role('button', name='Sign in', exact=True).click()


def unchanged_cookie(context, fixture, original):
    from browser_sso_test import cookie_for
    current = cookie_for(context, fixture.issuer)
    require(current['value'] == original['value'] and current['expires'] == original['expires'],
            'Ordinary authorization renewed the OP cookie')


def later_issuance(original_claims):
    # Cross the authentication second so equality is not an accidental same-second PASS.
    delay = original_claims['auth_time'] + 1.1 - time.time()
    require(delay < 2, 'Fixture authentication time is unexpectedly in the future')
    if delay > 0:
        time.sleep(delay)


def check_live_grants(fixture):
    grants = []
    for rp in fixture.rps:
        require(not rp.failure and not rp.received_identity_cookie, 'RP failure or OP-cookie leakage')
        require(not rp.pending, 'Completed normal requests left pending RP state')
        for grant in rp.grants:
            # Use only this RP's own token, including A's original after replacement.
            user = json_request(fixture.issuer + '/userinfo', token=grant['tokens']['access_token'],
                                tls_context=rp.tls_context)
            require(user.get('sub') == grant['identity']['sub'], 'An independent RP grant stopped working')
            grants.append(grant)
    assert_distinct_grants(grants)


def run_normal_case(browser, fixture, *, replace_instance=None, after_primary=None, isolated_login=False):
    from browser_sso_test import (assert_grants, browser_context, cookie_for,
                                  enable_semantics, login_form, observe)
    require(not (replace_instance and after_primary), 'Cannot combine sequential replacement and live selection')
    network = {'external_requests': 0}
    context = browser_context(browser, fixture, network=network)
    diagnostics = {}
    counts = observe(context, fixture.issuer, diagnostics)
    a, b = fixture.rps
    require(urllib.parse.urlsplit(a.origin).hostname != urllib.parse.urlsplit(b.origin).hostname,
            'Normal A/B case requires different RP hosts')
    try:
        primary = context.new_page()
        primary.goto(a.origin + '/start')
        login_form(primary)
        password_once(primary)
        if not a.skip_consent:
            primary.get_by_text(a.name + ' wants access', exact=True).wait_for(timeout=30000)
            require(not context.cookies(fixture.issuer), 'Fresh identity was issued before primary consent')
            require(not a.grants and not b.grants, 'Primary consent was bypassed')
            approve(primary, a)
        accepted(primary, a)
        continuations = int(not a.skip_consent)
        require(diagnostics.get('credential_complete') is True, 'Primary form lost fixture credentials')
        require(counts == {'password': 1, 'resume': 0, 'continuation': continuations, 'unexpected': 0},
                'Primary password/consent did not execute exactly once')
        original = cookie_for(context, fixture.issuer)
        first_claims = assert_original_context(a.grants, original)
        require(original['httpOnly'] and original['secure'] and original['sameSite'] == 'Lax' and
                original['path'] == '/' and original['domain'] == '127.0.0.1', 'Unsafe browser-cookie attributes')
        if replace_instance is not None:
            replace_instance()
        if after_primary is not None:
            after_primary()  # Completed A transaction only; never stop/restart a live replica.
        later_issuance(first_claims)
        second = context.new_page()
        second.goto(b.origin + '/start')
        if not b.skip_consent:
            enable_semantics(second)
            second.get_by_text(b.name + ' wants access', exact=True).wait_for(timeout=30000)
            require(len(a.grants) == 1 and not b.grants, 'A consent authorized B before B approval')
            require(counts == {'password': 1, 'resume': 1, 'continuation': continuations, 'unexpected': 0},
                    'B consent did not follow its own identity-only resume')
            unchanged_cookie(context, fixture, original)
            approve(second, b)
            continuations += 1
        accepted(second, b)
        assert_grants(fixture, original)
        require(b.grants[0]['access']['iat'] > first_claims['auth_time'], 'B issuance did not cross the original second')
        require(counts == {'password': 1, 'resume': 1, 'continuation': continuations, 'unexpected': 0},
                'B password/resume/consent counts differ from its declared fixture policy')
        unchanged_cookie(context, fixture, original)
        print('PASS: A password once -> B own code/S256 grant, per-client first-consent policy and exact auth_time')
        # Explicit navigation owns fresh state/nonce/verifier/code/tokens/SID,
        # but remembers that user's consent for that client.
        for index, rp in enumerate((a, b), start=2):
            repeat = context.new_page()
            repeat.goto(rp.origin + '/start')
            accepted(repeat, rp)
            require(len(rp.grants) == 2, 'Repeat authorization did not create exactly one new grant')
            require(counts == {'password': 1, 'resume': index, 'continuation': continuations, 'unexpected': 0},
                    'Repeat authorization asked for a password/consent or replayed a continuation')
            unchanged_cookie(context, fixture, original)
        same_jar_grants = a.grants + b.grants
        assert_original_context(same_jar_grants, original)
        assert_distinct_grants(same_jar_grants)
        require(all(grant[token]['iat'] > first_claims['auth_time']
                    for grant in same_jar_grants[1:] for token in ('access', 'identity')),
                'Repeat token issuance did not cross the original authentication second')
        print('PASS: ordinary repeat A and B navigation remembers consent, with fresh grants/tokens/SID/nonces')
        isolated_counts = None
        if isolated_login:
            from app_sso_entry import separate_context_login
            isolated_counts = separate_context_login(browser, context, fixture, original, first_claims)
        check_live_grants(fixture)
        require(network['external_requests'] == 0, 'Normal hosted flow used an external resource')
        print('PASS: all original/repeat RP grants remain independently usable; no RP receives the OP cookie')
        return {'same_jar': dict(counts), 'separate_jar': isolated_counts,
                'completed_grants_a': len(a.grants), 'completed_grants_b': len(b.grants),
                'exact_cookie_access_id_auth_time': True, 'external_requests': network['external_requests']}
    finally:
        context.close()
