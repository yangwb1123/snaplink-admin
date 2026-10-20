"""Owned HTTPS OAuth transport + callback simulation, NOT browser/stock/target proof."""

import hashlib
import http.client
import json
import secrets
import socket
import time
import unittest
from urllib.parse import parse_qs, urlencode

import jwt
from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

from sso_acceptance_https import HTTPSFixture, reply
from sso_acceptance_support import plan
from tools.browser_sso_plan import Failure, validate_plan
from tools.browser_sso_protocol import RP, Verifier, b64, same_context
from tools.browser_sso_transport import Transport, preflight, tls_context


class OwnedSimulationTest(unittest.TestCase):
    def setUp(self):
        self.plan = plan()
        self.codes, self.tokens, self.clients = {}, {}, {}
        self.key = Ed25519PrivateKey.generate()
        self.jwk = {'kid': 'owned', 'kty': 'OKP', 'crv': 'Ed25519', 'alg': 'EdDSA', 'use': 'sig',
                    'x': b64(self.key.public_key().public_bytes(Encoding.Raw, PublicFormat.Raw))}
        self.auth_time = int(time.time()) - 3
        self.fixture = HTTPSFixture(self.respond)
        self.addCleanup(self.fixture.close)
        original = self.plan['op']['origin']
        self.plan['op'] = {k: v.replace(original, self.fixture.origin) for k, v in self.plan['op'].items()}
        self.plan['ca_file'] = str(self.fixture.cert)
        for i, rp in enumerate(self.plan['rps']):
            with socket.socket() as reserve:
                reserve.bind((f'127.0.0.{i + 2}', 0))
                rp['redirect_uri'] = f'http://127.0.0.{i + 2}:{reserve.getsockname()[1]}/callback'
        validate_plan(self.plan)
        self.transport = Transport(self.plan['op'], self.plan['limits'], time.monotonic() + 10,
                                   context=tls_context(str(self.fixture.cert)))
        self.verifier = Verifier(self.plan, self.transport)
        self.verifier.subject = 'owned-subject'
        self.rps = [RP(self.plan, cfg, self.verifier, time.monotonic() + 10) for cfg in self.plan['rps']]
        for rp in self.rps:
            self.clients[rp.config['client_id']] = rp
            code = secrets.token_urlsafe(24)
            self.codes[code] = rp
            rp.synthetic_code = code

    def sign(self, claims, typ):
        return jwt.encode(claims, self.key, algorithm='EdDSA', headers={'kid': 'owned', 'typ': typ})

    def respond(self, handler):
        op = self.plan['op']
        if handler.path == '/.well-known/openid-configuration':
            data = {'issuer': op['issuer'], **{key: op[key] for key in
                    ('authorization_endpoint', 'token_endpoint', 'jwks_uri', 'userinfo_endpoint')},
                    'response_types_supported': ['code'], 'grant_types_supported': ['authorization_code'],
                    'code_challenge_methods_supported': ['S256'], 'token_endpoint_auth_methods_supported': ['none'],
                    'id_token_signing_alg_values_supported': ['EdDSA']}
        elif handler.path.startswith('/auth/login?'):
            data = {'iss': op['issuer'], 'providers': ['password'], 'op_session_supported': True,
                    'op_session_available': False}
        elif handler.path == '/.well-known/jwks.json':
            data = {'keys': [self.jwk]}
        elif handler.path == '/token':
            raw = handler.rfile.read(int(handler.headers['Content-Length']))
            form = parse_qs(raw.decode(), strict_parsing=True)
            rp = self.codes.pop(form.get('code', [''])[0], None)
            valid = rp is not None and form.get('grant_type') == ['authorization_code'] and (
                form.get('client_id') == [rp.config['client_id']] and
                form.get('redirect_uri') == [rp.config['redirect_uri']] and
                b64(hashlib.sha256(form.get('code_verifier', [''])[0].encode()).digest()) == rp.params['code_challenge'])
            if not valid:
                reply(handler, b'{"error":"invalid_grant"}', status=400)
                return
            now = int(time.time())
            claims = {'iss': op['issuer'], 'sub': 'owned-subject', 'iat': now, 'exp': now + 90,
                      'auth_time': self.auth_time, 'amr': ['password'], 'scope': ' '.join(rp.config['scopes']),
                      'sid': secrets.token_urlsafe(16)}
            access = self.sign({**claims, 'aud': rp.config['resources'], 'client_id': rp.config['client_id']}, 'at+jwt')
            identity = self.sign({**claims, 'aud': rp.config['client_id'], 'nonce': rp.params['nonce'],
                                  '_resources': rp.config['resources'],
                                  'at_hash': b64(hashlib.sha512(access.encode()).digest()[:32])}, 'JWT')
            data = {'access_token': access, 'id_token': identity, 'token_type': 'Bearer'}
            self.tokens[access] = 'owned-subject'
        elif handler.path == '/userinfo':
            data = {'sub': self.tokens.get(handler.headers.get('Authorization', '')[7:])}
        else:
            reply(handler, b'{}', status=404)
            return
        reply(handler, json.dumps(data).encode())

    def callback_query(self, rp):
        return urlencode({'code': rp.synthetic_code, 'state': rp.state, 'iss': self.plan['op']['issuer']})

    def test_two_independent_signed_pkce_grants_over_owned_verified_tls_and_callbacks(self):
        preflight(self.plan, self.transport)
        for rp in self.rps:
            rp.start()
            self.addCleanup(rp.close)
            connection = http.client.HTTPConnection(rp.target.hostname, rp.target.port, timeout=3)
            connection.request('GET', '/callback?' + self.callback_query(rp))
            response = connection.getresponse()
            self.assertEqual(response.status, 303)
            self.assertEqual(response.getheader('Location'), '/complete')
            self.assertFalse(b'token' in response.read(), 'Callback leaked a token')
            connection.close()
            self.assertIsNone(rp.failure)
            self.assertIsNotNone(rp.grant)
        first, second = (rp.grant for rp in self.rps)
        same_context(first['access'], second['access'])
        self.assertTrue(first['access']['sid'] != second['access']['sid'], 'RP sessions were shared')
        self.assertTrue(first['tokens']['access_token'] != second['tokens']['access_token'], 'Grants were shared')
        self.assertEqual(self.fixture.counts['POST'], 2)
        for rp in self.rps:
            with self.assertRaises(Failure):
                rp.exchange(self.callback_query(rp))
        self.assertEqual(self.fixture.counts['POST'], 2)

    def test_cross_client_codes_each_post_once_without_replay(self):
        first, second = self.rps
        second.synthetic_code = first.synthetic_code
        # Use an independent code for the cross-client test, not an already
        # consumed one, so this actually exercises client binding.
        original_second = next(code for code, rp in self.codes.items() if rp is second)
        first_code = first.synthetic_code
        first.synthetic_code = original_second
        second.synthetic_code = first_code
        for rp in self.rps:
            with self.assertRaises(Failure):
                rp.exchange(self.callback_query(rp))
            with self.assertRaises(Failure):
                rp.exchange(self.callback_query(rp))
            self.assertIsNone(rp.grant)
        self.assertEqual(self.fixture.counts['POST'], 2)

    def test_correct_client_wrong_pkce_is_rejected_without_exchange_retry(self):
        rp = self.rps[0]
        rp.verifier_value = secrets.token_urlsafe(32)
        with self.assertRaises(Failure):
            rp.exchange(self.callback_query(rp))
        with self.assertRaises(Failure):
            rp.exchange(self.callback_query(rp))
        self.assertEqual(self.fixture.counts['POST'], 1)
        self.assertIsNone(rp.grant)


if __name__ == '__main__':
    unittest.main()
