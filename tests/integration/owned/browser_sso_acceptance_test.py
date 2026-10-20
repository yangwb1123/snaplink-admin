#!/usr/bin/env python3
"""Owned-loopback Chrome TLS rejection only; no password/target/stock acceptance."""

import argparse
import json
import os
from pathlib import Path
import socket
import sys
import time
import unittest
from unittest.mock import patch

from cryptography.hazmat.primitives.asymmetric.ed25519 import Ed25519PrivateKey
from cryptography.hazmat.primitives.serialization import Encoding, PublicFormat

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / 'tests/unit'))
from sso_acceptance_https import HTTPSFixture, reply
from sso_acceptance_support import plan
from tools import browser_sso_acceptance as cli
from tools import browser_sso_browser as driver
from tools.browser_sso_plan import Failure, validate_plan
from tools.browser_sso_protocol import b64


class ChromeTLSBoundaryTest(unittest.TestCase):
    def test_private_ca_backchannel_success_does_not_disable_chrome_tls_before_credentials(self):
        data = plan()
        # Fresh public verification key only on the wire; no login UI,
        # cookie/token signing or mutation endpoint exists in this test.
        public_key = {'kid': 'owned-key', 'kty': 'OKP', 'crv': 'Ed25519', 'alg': 'EdDSA',
                      'use': 'sig', 'x': b64(Ed25519PrivateKey.generate().public_key().public_bytes(
                          Encoding.Raw, PublicFormat.Raw))}
        def respond(handler):
            if handler.path == '/.well-known/openid-configuration':
                op = data['op']
                body = {'issuer': op['issuer'], **{k: op[k] for k in
                        ('authorization_endpoint', 'token_endpoint', 'jwks_uri', 'userinfo_endpoint')},
                        'response_types_supported': ['code'], 'grant_types_supported': ['authorization_code'],
                        'code_challenge_methods_supported': ['S256'], 'token_endpoint_auth_methods_supported': ['none'],
                        'id_token_signing_alg_values_supported': ['EdDSA']}
            elif handler.path.startswith('/auth/login?'):
                body = {'iss': data['op']['issuer'], 'providers': ['password'],
                        'op_session_supported': True, 'op_session_available': False}
            elif handler.path == '/.well-known/jwks.json':
                body = {'keys': [public_key]}
            else:
                reply(handler, b'{}', status=404)
                return
            reply(handler, json.dumps(body).encode())
        fixture = HTTPSFixture(respond)
        self.addCleanup(fixture.close)
        old = data['op']['origin']
        data['op'] = {k: v.replace(old, fixture.origin) for k, v in data['op'].items()}
        data['ca_file'] = str(fixture.cert)
        data['credential_file'] = str(fixture.root / 'intentionally-absent-credentials.json')
        for i, rp in enumerate(data['rps']):
            with socket.socket() as reserve:
                reserve.bind((f'127.0.0.{i + 2}', 0))
                rp['redirect_uri'] = f'http://127.0.0.{i + 2}:{reserve.getsockname()[1]}/callback'
        validate_plan(data)
        with patch.dict(os.environ, {'HOME': str(fixture.root)}), cli.clean_environment(), \
                patch.object(driver, 'load_credentials') as credential:
            with self.assertRaises(Failure) as raised:
                driver.run(data, time.monotonic() + 30)
        credential.assert_not_called()
        self.assertEqual(raised.exception.state, 'browser_tls_or_navigation')
        self.assertEqual(fixture.counts['POST'], 0)
        self.assertEqual(fixture.counts['GET'], 4)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browser-channel', choices=('chrome',), required=True)
    parser.parse_args()
    unittest.main(argv=[sys.argv[0]], verbosity=2)
