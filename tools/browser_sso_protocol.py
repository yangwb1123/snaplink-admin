"""Memory-only public-client grants, strict JOSE verification and callback ownership."""

import base64
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import re
import secrets
import socket
import threading
import time
from urllib.parse import parse_qsl, urlencode, urlsplit

from tools.browser_sso_plan import Failure, callback, require, strict_json, text


def b64(raw):
    return base64.urlsafe_b64encode(raw).decode('ascii').rstrip('=')


def unb64(value, limit):
    require(text(value, limit) and re.fullmatch(r'[A-Za-z0-9_-]+', value), 'invalid_token')
    raw = base64.urlsafe_b64decode(value + '=' * (-len(value) % 4))
    require(b64(raw) == value, 'invalid_token')
    return raw


def query(raw, *, resources=False):
    require(len(raw) <= 8192 and not re.search(r'%(?![0-9A-Fa-f]{2})', raw), 'invalid_callback')
    try:
        pairs = parse_qsl(raw, keep_blank_values=True, strict_parsing=True, encoding='utf-8',
                          errors='strict', max_num_fields=32)
    except (ValueError, UnicodeError):
        raise Failure('invalid_callback') from None
    values = {}
    for key, value in pairs:
        require(text(key, 64) and text(value, 4096) and
                (key not in values or (resources and key == 'resource')), 'invalid_callback')
        values.setdefault(key, []).append(value)
    return values


class Verifier:
    def __init__(self, plan, transport):
        self.plan, self.transport, self.subject = plan, transport, None

    def keys(self):
        data = self.transport.request('jwks_uri')
        keys = data.get('keys')
        require(set(data) == {'keys'} and isinstance(keys, list) and 1 <= len(keys) <= 16, 'invalid_jwks')
        result = {}
        for key in keys:
            require(isinstance(key, dict) and set(key) <=
                    {'kty', 'crv', 'kid', 'x', 'alg', 'use', 'key_ops', 'origin'}, 'invalid_jwks')
            require(text(key.get('kid'), 128) and key['kid'] not in result and
                    key.get('alg') == 'EdDSA' and key.get('kty') == 'OKP' and
                    key.get('crv') == 'Ed25519' and key.get('use') == 'sig' and
                    key.get('key_ops', ['verify']) == ['verify'], 'invalid_jwks')
            require(len(unb64(key.get('x'), 64)) == 32, 'invalid_jwks')
            result[key['kid']] = key
        return result

    def verify(self, token, typ, audiences, keys):
        try:
            import jwt
            require(text(token, 32768) and token.count('.') == 2, 'invalid_token')
            head, body, signature = token.split('.')
            header = strict_json(unb64(head, 2048), 1536)
            claims = strict_json(unb64(body, 24576), 18432)
            require(set(header) == {'alg', 'kid', 'typ'} and header['alg'] == 'EdDSA' and
                    header['typ'] == typ and text(header['kid'], 128) and
                    header['kid'] in keys and len(unb64(signature, 128)) == 64, 'invalid_token')
            key = jwt.PyJWK.from_dict(keys[header['kid']], algorithm='EdDSA').key
            jwt.decode(token, key, algorithms=['EdDSA'], issuer=self.plan['op']['issuer'],
                       options={'require': ['iss', 'aud', 'sub', 'exp', 'iat', 'auth_time'],
                                'verify_aud': False}, leeway=0)
            audience = claims.get('aud')
            audience = [audience] if isinstance(audience, str) else audience
            require(isinstance(audience, list) and all(text(v) for v in audience) and
                    len(audience) == len(set(audience)) and set(audience) == set(audiences), 'invalid_token')
            require(claims.get('iss') == self.plan['op']['issuer'] and self.subject is not None and
                    claims.get('sub') == self.subject, 'invalid_token')
            require(all(type(claims.get(k)) is int for k in ('exp', 'iat', 'auth_time')) and
                    0 < claims['auth_time'] <= claims['iat'] <= time.time() < claims['exp'], 'invalid_token')
            expected = self.plan['expected_auth']
            require(claims.get('amr') == expected['amr'] and claims.get('acr', '') == expected['acr'], 'invalid_token')
            return claims
        except Failure:
            raise
        except Exception:
            raise Failure('invalid_token') from None

    def grant(self, tokens, rp, nonce):
        require(isinstance(tokens, dict) and tokens.get('token_type') == 'Bearer' and
                text(tokens.get('access_token'), 32768) and text(tokens.get('id_token'), 32768), 'invalid_token')
        keys = self.keys()
        access = self.verify(tokens['access_token'], 'at+jwt', rp['resources'], keys)
        identity = self.verify(tokens['id_token'], 'JWT', [rp['client_id']], keys)
        require(access.get('client_id') == rp['client_id'] and access.get('tenant_id', '') == rp['tenant_id'] and
                text(access.get('sid')) and
                identity.get('sid') == access['sid'] and identity.get('nonce') == nonce and
                identity.get('azp', rp['client_id']) == rp['client_id'], 'invalid_token')
        for claims in (access, identity):
            scope = claims.get('scope')
            require(isinstance(scope, str) and len(scope.split()) == len(rp['scopes']) and
                    set(scope.split()) == set(rp['scopes']), 'invalid_token')
        require(identity.get('_resources') == rp['resources'] and
                identity.get('at_hash') == b64(hashlib.sha512(tokens['access_token'].encode('ascii')).digest()[:32]),
                'invalid_token')
        same_context(access, identity)
        user = self.transport.request('userinfo_endpoint', token=tokens['access_token'])
        require(user.get('sub') == self.subject, 'invalid_token')
        return {'tokens': tokens, 'access': access, 'identity': identity}

    def cookie(self, value):
        claims = self.verify(value, 'snaplink-op-session+jwt', ['urn:snaplink:browser-op-session'], self.keys())
        require(claims.get('ext') == {'purpose': 'browser-op-session', 'provider': 'password'} and
                claims['exp'] <= claims['auth_time'] + 8 * 60 * 60 and text(claims.get('sid')), 'invalid_token')
        return claims


def same_context(first, second):
    require(all(first.get(k, '') == second.get(k, '') for k in ('sub', 'auth_time', 'amr', 'acr')),
            'invalid_token')


class RP:
    def __init__(self, plan, config, verifier, end):
        self.plan, self.config, self.verifier, self.end = plan, config, verifier, end
        target = callback(config['redirect_uri'])
        self.target, self.lock, self.done = target, threading.Lock(), threading.Event()
        self.closed, self.consumed, self.failure, self.grant = False, False, None, None
        self.state, self.nonce, self.verifier_value = (secrets.token_urlsafe(32) for _ in range(3))
        self.params = {'client_id': config['client_id'], 'response_type': 'code', 'response_mode': 'query',
                       'redirect_uri': config['redirect_uri'], 'scope': ' '.join(config['scopes']),
                       'resource': config['resources'], 'state': self.state, 'nonce': self.nonce,
                       'code_challenge': b64(hashlib.sha256(self.verifier_value.encode('ascii')).digest()),
                       'code_challenge_method': 'S256', 'ui_locales': plan['locale']}
        if plan['expected_auth']['acr']:
            self.params['acr_values'] = plan['expected_auth']['acr']
        self.server = None

    def authorization_url(self):
        return self.plan['op']['login_url'] + '?' + urlencode(self.params, doseq=True)

    def exchange(self, raw):
        values = query(raw)
        require(set(values) <= {'iss', 'state', 'code', 'error', 'error_description'} and
                values.get('iss') == [self.plan['op']['issuer']] and
                values.get('state') == [self.state] and
                (('code' in values) != ('error' in values)) and
                ('error_description' not in values or 'error' in values), 'invalid_callback')
        with self.lock:
            require(not self.closed and not self.consumed and time.monotonic() < self.end, 'callback_replayed')
            self.consumed = True  # Atomically before the *only* token POST, including failures.
            verifier, nonce = self.verifier_value, self.nonce
            self.verifier_value = self.nonce = None
        try:
            require('error' not in values, 'authorization_blocked')
            tokens = self.verifier.transport.request('token_endpoint', form={
                'grant_type': 'authorization_code', 'client_id': self.config['client_id'],
                'redirect_uri': self.config['redirect_uri'], 'code': values['code'][0], 'code_verifier': verifier})
            grant = self.verifier.grant(tokens, self.config, nonce)
            with self.lock:
                require(not self.closed and time.monotonic() < self.end, 'unknown_result')
                self.grant = grant
        except Failure as error:
            self.failure = error.state
            raise
        except Exception:
            self.failure = 'unknown_result'
            raise Failure('unknown_result') from None
        finally:
            self.done.set()

    def start(self):
        owner = self
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def send_error(self, *_args, **_kwargs):
                # stdlib parse errors otherwise reflect the raw request line.
                self.respond(400)
            def handle_one_request(self):
                # Bound the request line before stdlib parsing; never echo a URL.
                self.raw_requestline = self.rfile.readline(8193)
                if not self.raw_requestline or len(self.raw_requestline) > 8192:
                    return
                if self.parse_request():
                    self.do_request()
                self.close_connection = True
            def do_request(self):
                try:
                    require(self.command == 'GET' and self.headers.get_all('Host') == [owner.target.netloc] and
                            not self.headers.get('Transfer-Encoding') and
                            len(self.headers.get_all('Content-Length', [])) <= 1 and
                            self.headers.get('Content-Length', '0') == '0', 'invalid_callback')
                    if self.path == '/complete':
                        self.respond(200 if owner.grant else 400)
                        return
                    require(self.path.startswith('/callback?'), 'invalid_callback')
                    owner.exchange(self.path[len('/callback?'):])
                    self.respond(303, redirect=True)
                except Failure as error:
                    # Invalid unsolicited requests cannot overwrite an accepted grant.
                    with owner.lock:
                        if owner.grant is None:
                            owner.failure = error.state
                            owner.closed = True
                            owner.done.set()
                    self.respond(303, redirect=True)
                except Exception:
                    self.respond(400)
            def respond(self, status, redirect=False):
                self.send_response(status)
                self.send_header('Cache-Control', 'no-store')
                self.send_header('Referrer-Policy', 'no-referrer')
                self.send_header('Content-Security-Policy', "default-src 'none'; frame-ancestors 'none'")
                if redirect:
                    self.send_header('Location', '/complete')
                self.send_header('Content-Type', 'text/plain; charset=utf-8')
                self.send_header('Content-Length', '23')
                self.end_headers()
                self.wfile.write(b'SSO acceptance finished')
        class Server(ThreadingHTTPServer):
            daemon_threads, allow_reuse_address, request_queue_size = True, False, 4
            slots = threading.BoundedSemaphore(4)
            def handle_error(self, *_):
                pass
            def process_request(self, request, address):
                if self.slots.acquire(blocking=False):
                    super().process_request(request, address)
                else:
                    self.shutdown_request(request)
            def process_request_thread(self, request, address):
                def interrupt():
                    try:
                        request.shutdown(socket.SHUT_RDWR)
                    except OSError:
                        pass
                seconds = max(0.01, min(owner.plan['limits']['request_seconds'], owner.end - time.monotonic()))
                request.settimeout(seconds)
                timer = threading.Timer(seconds, interrupt)
                timer.daemon = True
                timer.start()
                try:
                    super().process_request_thread(request, address)
                finally:
                    timer.cancel()
                    self.slots.release()
        try:
            self.server = Server((self.target.hostname, self.target.port), Handler)
            self.thread = threading.Thread(target=self.server.serve_forever, kwargs={'poll_interval': 0.05}, daemon=True)
            self.thread.start()
        except OSError:
            raise Failure('callback_unavailable') from None
        return self

    def close(self):
        with self.lock:
            self.closed = True
            self.verifier_value = self.nonce = None
        if self.server:
            self.server.shutdown()
            self.server.server_close()
            self.thread.join(timeout=1)
            self.server = None
