"""Disposable loopback RPs. Grants stay server-side; never in browser storage."""

import base64
import hashlib
import ipaddress
import json
import secrets
import threading
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


def json_request(url, *, form=None, token=None, tls_context=None):
    body = urllib.parse.urlencode(form).encode() if form is not None else None
    headers = {'Accept': 'application/json'}
    if form is not None:
        headers['Content-Type'] = 'application/x-www-form-urlencoded'
    if token is not None:
        headers['Authorization'] = 'Bearer ' + token
    request = urllib.request.Request(url, data=body, headers=headers)
    with urllib.request.urlopen(request, timeout=15, context=tls_context) as response:
        require(response.status == 200, 'OP request failed')
        return json.load(response)


class RelyingParty:
    def __init__(self, client_id, name, skip_consent, *, host='127.0.0.1'):
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

        self.server = ThreadingHTTPServer((host, 0), Handler)
        self.origin = f'http://{host}:{self.server.server_port}'
        self.redirect = self.origin + '/callback'
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

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
        with self.lock:
            self.grants.append({'tokens': tokens, 'access': access, 'identity': identity})

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
