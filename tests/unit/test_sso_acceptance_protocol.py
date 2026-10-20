"""Synthetic JOSE/PKCE and owned callback sockets, not target authentication."""

import base64
import concurrent.futures
import hashlib
import http.client
import json
import socket
import threading
import time
import unittest
from unittest.mock import Mock, patch
from urllib.parse import urlencode

import jwt
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

from sso_acceptance_support import plan
from tools.browser_sso_plan import Failure
from tools.browser_sso_protocol import RP, Verifier, b64, same_context


class ProtocolSafetyTest(unittest.TestCase):
    def setUp(self):
        self.plan = plan()
        self.transport = Mock()
        self.verifier = Verifier(self.plan, self.transport)
        self.verifier.subject = 'owned-subject'
        self.key = Ed25519PrivateKey.generate()
        self.jwk = {'kty': 'OKP', 'crv': 'Ed25519', 'alg': 'EdDSA', 'use': 'sig', 'kid': 'owned-key',
                    'x': b64(self.key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw))}
        self.rp = RP(self.plan, self.plan['rps'][0], self.verifier, time.monotonic() + 10)

    def claims(self):
        now = int(time.time())
        return {'iss': self.plan['op']['issuer'], 'sub': 'owned-subject', 'aud': 'rp-a',
                'iat': now, 'exp': now + 120, 'auth_time': now - 2, 'amr': ['password'],
                'nonce': self.rp.nonce, 'sid': 'owned-session', 'scope': 'openid rp-a:read',
                '_resources': ['rp-a-api']}

    def token(self, claims=None, *, typ='JWT', headers=None, key=None):
        return jwt.encode(claims or self.claims(), key or self.key, algorithm='EdDSA',
                          headers={'typ': typ, 'kid': 'owned-key', **(headers or {})})

    def grant_tokens(self):
        claims = self.claims()
        access = self.token({**claims, 'aud': 'rp-a-api', 'client_id': 'rp-a'}, typ='at+jwt')
        identity = self.token({**claims, 'at_hash': b64(hashlib.sha512(access.encode()).digest()[:32])})
        return {'access_token': access, 'id_token': identity, 'token_type': 'Bearer'}

    def callback(self, **changes):
        return urlencode({'iss': self.plan['op']['issuer'], 'state': self.rp.state,
                          'code': 'synthetic-code', **changes})

    def test_signature_and_exact_purpose_issuer_audience_nonce_and_context(self):
        keys = {'owned-key': self.jwk}
        claims = self.verifier.verify(self.token(), 'JWT', ['rp-a'], keys)
        self.assertEqual(claims['auth_time'], self.claims()['auth_time'])
        for changes in ({'iss': 'https://other.invalid'}, {'aud': 'rp-b'}, {'aud': ['rp-a', 'rp-b']},
                        {'sub': 'another'}, {'auth_time': int(time.time()) + 1},
                        {'auth_time': True}, {'exp': int(time.time()) - 1},
                        {'amr': ['mfa']}, {'acr': 'stronger'}):
            with self.subTest(fields=list(changes)), self.assertRaises(Failure):
                self.verifier.verify(self.token({**self.claims(), **changes}), 'JWT', ['rp-a'], keys)
        for typ, headers, key in [('at+jwt', {}, None), ('JWT', {'kid': 'unknown'}, None),
                                  ('JWT', {'jku': 'https://trap.invalid/keys'}, None),
                                  ('JWT', {'crit': ['custom']}, None),
                                  ('JWT', {}, Ed25519PrivateKey.generate())]:
            with self.subTest(typ=typ, headers=list(headers)), self.assertRaises(Failure):
                self.verifier.verify(self.token(typ=typ, headers=headers, key=key), 'JWT', ['rp-a'], keys)
        unsigned = b64(b'{"alg":"none","typ":"JWT","kid":"owned-key"}') + '.' + b64(b'{}') + '.'
        with self.assertRaises(Failure):
            self.verifier.verify(unsigned, 'JWT', ['rp-a'], keys)
        self.transport.request.assert_not_called()

    def test_duplicate_jwt_header_and_payload_are_rejected_before_pyjwt(self):
        for header, payload in [(b'{"alg":"EdDSA","alg":"EdDSA","kid":"owned-key","typ":"JWT"}', b'{}'),
                                (b'{"alg":"EdDSA","kid":"owned-key","typ":"JWT"}', b'{"sub":"x","sub":"x"}')]:
            value = b64(header) + '.' + b64(payload) + '.' + b64(bytes(64))
            with patch.object(jwt, 'decode') as decode, self.assertRaises(Failure):
                self.verifier.verify(value, 'JWT', ['rp-a'], {'owned-key': self.jwk})
            decode.assert_not_called()

    def test_jwks_ambiguity_bounds_private_material_and_remote_refs_rejected(self):
        for keys in ([self.jwk, self.jwk], [], [self.jwk] * 17,
                     [{**self.jwk, 'use': 'enc'}], [{**self.jwk, 'key_ops': ['sign']}],
                     [{**self.jwk, 'd': 'synthetic-private'}], [{**self.jwk, 'x5u': 'https://trap.invalid'}],
                     [{**self.jwk, 'alg': 'HS256'}], [{**self.jwk, 'x': b64(b'bad')}],
                     [{**self.jwk, 'kid': None}]):
            self.transport.request.return_value = {'keys': keys}
            with self.subTest(key_count=len(keys)), self.assertRaises(Failure):
                self.verifier.keys()
        self.assertEqual(self.transport.request.call_count, 10)

    def test_grants_verify_both_signatures_nonce_client_scope_resource_and_at_hash(self):
        tokens = self.grant_tokens()
        self.transport.request.side_effect = [{'keys': [self.jwk]}, {'sub': 'owned-subject'}]
        result = self.verifier.grant(tokens, self.rp.config, self.rp.nonce)
        self.assertIn('identity', result)
        for change in ({'nonce': 'wrong'}, {'scope': 'openid rp-b:read'}, {'_resources': ['rp-b-api']},
                       {'azp': 'rp-b'}, {'at_hash': 'wrong'}, {'sid': 'different'}):
            identity = {**self.claims(), 'at_hash': b64(hashlib.sha512(tokens['access_token'].encode()).digest()[:32]), **change}
            self.transport.request.side_effect = None
            self.transport.request.return_value = {'keys': [self.jwk]}
            with self.subTest(fields=list(change)), self.assertRaises(Failure):
                self.verifier.grant({**tokens, 'id_token': self.token(identity)}, self.rp.config, self.rp.nonce)
        for change in ({'client_id': 'rp-b'}, {'aud': 'rp-b-api'}, {'scope': 'openid rp-b:read'},
                       {'tenant_id': 'another-tenant'}):
            access = self.token({**self.claims(), 'aud': 'rp-a-api', 'client_id': 'rp-a', **change}, typ='at+jwt')
            self.transport.request.return_value = {'keys': [self.jwk]}
            with self.subTest(fields=list(change)), self.assertRaises(Failure):
                self.verifier.grant({**tokens, 'access_token': access}, self.rp.config, self.rp.nonce)

    def test_auth_time_differs_by_one_second_is_always_rejected(self):
        claims = self.claims()
        for change in ({'auth_time': claims['auth_time'] + 1}, {'amr': ['mfa']}, {'acr': 'other'}):
            with self.subTest(fields=list(change)), self.assertRaises(Failure):
                same_context(claims, {**claims, **change})

    def test_cookie_requires_purpose_provider_subject_signature_and_same_context(self):
        claims = {**self.claims(), 'aud': 'urn:snaplink:browser-op-session',
                  'ext': {'purpose': 'browser-op-session', 'provider': 'password'}}
        self.transport.request.return_value = {'keys': [self.jwk]}
        cookie = self.verifier.cookie(self.token(claims, typ='snaplink-op-session+jwt'))
        same_context(cookie, self.claims())
        for ext in ({'purpose': 'access', 'provider': 'password'}, {'purpose': 'browser-op-session'}):
            with self.subTest(fields=list(ext)), self.assertRaises(Failure):
                self.verifier.cookie(self.token({**claims, 'ext': ext}, typ='snaplink-op-session+jwt'))

    def test_state_issuer_duplicate_blank_and_bad_percent_fail_before_exchange(self):
        for raw in (self.callback(iss='https://other.invalid'), self.callback(state='wrong'),
                    self.callback() + '&code=again', self.callback() + '&state=',
                    self.callback(code=''), self.callback() + '&x=%zz', self.callback() + '&x=value',
                    self.callback() + '&error=access_denied', 'x=' + 'a' * 8193):
            with self.subTest(length=len(raw)), self.assertRaises(Failure):
                self.rp.exchange(raw)
        self.transport.request.assert_not_called()

    def test_state_consumed_before_single_exchange_even_when_response_is_lost(self):
        self.transport.request.side_effect = Failure('unknown_result')
        with self.assertRaises(Failure):
            self.rp.exchange(self.callback())
        with self.assertRaises(Failure):
            self.rp.exchange(self.callback())
        self.assertEqual(self.transport.request.call_count, 1)
        self.assertTrue(self.rp.consumed)
        self.assertEqual(self.rp.failure, 'unknown_result')
        self.assertIsNone(self.rp.verifier_value)

    def test_concurrent_callback_can_exchange_at_most_once(self):
        barrier = threading.Barrier(2)
        self.transport.request.return_value = {}
        self.verifier.grant = Mock(return_value={'accepted': True})
        def exchange():
            barrier.wait(timeout=2)
            try:
                self.rp.exchange(self.callback())
                return True
            except Failure:
                return False
        with concurrent.futures.ThreadPoolExecutor(2) as pool:
            results = list(pool.map(lambda _: exchange(), range(2)))
        self.assertEqual(sum(results), 1)
        self.assertEqual(self.transport.request.call_count, 1)

    def test_expired_or_closed_transaction_never_exchanges_or_accepts_late_response(self):
        self.rp.end = time.monotonic() - 1
        with self.assertRaises(Failure):
            self.rp.exchange(self.callback())
        self.transport.request.assert_not_called()
        self.rp.end = time.monotonic() + 5
        self.transport.request.side_effect = lambda *_, **__: self.rp.close()
        self.verifier.grant = Mock(return_value={'accepted': True})
        with self.assertRaises(Failure):
            self.rp.exchange(self.callback())
        self.assertIsNone(self.rp.grant)

    def start_callback(self):
        # Reserve a socket owned by this test to choose a port, then fail on any
        # subsequent bind conflict. Never stop a pre-existing listener.
        with socket.socket() as reserve:
            reserve.bind(('127.0.0.2', 0))
            port = reserve.getsockname()[1]
        self.rp.config['redirect_uri'] = f'http://127.0.0.2:{port}/callback'
        self.rp = RP(self.plan, self.rp.config, self.verifier, time.monotonic() + 5).start()
        self.addCleanup(self.rp.close)
        return port

    def test_callback_exact_host_method_path_port_and_no_secret_echo(self):
        for host, method, path in [('127.0.0.2', 'GET', '/callback?'),
                                   ('127.0.0.2:{port}', 'POST', '/callback?'),
                                   ('127.0.0.2:{port}', 'GET', '/callback/extra?'),
                                   ('localhost:{port}', 'GET', '/callback?'),
                                   ('127.0.0.2:{port}', 'GET', 'http://127.0.0.2/callback?')]:
            port = self.start_callback()
            conn = http.client.HTTPConnection('127.0.0.2', port, timeout=2)
            conn.request(method, path + self.callback(), headers={'Host': host.format(port=port)})
            response = conn.getresponse()
            body = response.read()
            self.assertNotIn(b'synthetic-code', body)
            self.assertNotIn('synthetic-code', str(response.headers))
            conn.close()
            self.rp.close()
        self.transport.request.assert_not_called()

    def test_valid_owned_callback_clears_query_without_browser_tokens(self):
        port = self.start_callback()
        self.transport.request.return_value = {}
        self.verifier.grant = Mock(return_value={'tokens': {'access_token': 'synthetic-token'}})
        conn = http.client.HTTPConnection('127.0.0.2', port, timeout=2)
        conn.request('GET', '/callback?' + self.callback())
        response = conn.getresponse()
        self.assertEqual(response.status, 303)
        self.assertEqual(response.getheader('Location'), '/complete')
        self.assertNotIn(b'synthetic', response.read())
        conn.close()
        self.assertEqual(self.transport.request.call_count, 1)

    def test_bind_conflict_leaves_existing_socket_intact(self):
        with socket.socket() as owned:
            owned.bind(('127.0.0.2', 0))
            owned.listen()
            port = owned.getsockname()[1]
            self.rp.config['redirect_uri'] = f'http://127.0.0.2:{port}/callback'
            rp = RP(self.plan, self.rp.config, self.verifier, time.monotonic() + 5)
            with self.assertRaises(Failure):
                rp.start()
            self.assertEqual(owned.getsockname()[1], port)

    def test_invalid_http_syntax_does_not_echo_callback_secret(self):
        port = self.start_callback()
        with socket.create_connection(('127.0.0.2', port), timeout=2) as client:
            client.sendall(b'GET /callback?secret=synthetic-canary EXTRA HTTP/1.1\r\n\r\n')
            body = bytearray()
            while chunk := client.recv(4096):
                body.extend(chunk)
        self.assertNotIn(b'synthetic-canary', body)


if __name__ == '__main__':
    unittest.main()
