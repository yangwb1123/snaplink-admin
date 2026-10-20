"""Verified TLS, proxy isolation, strict JSON, deadlines and no write replay."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import os
import socket
import ssl
import threading
import time
import unittest
from unittest.mock import patch

from sso_acceptance_https import HTTPSFixture, reply
from sso_acceptance_support import plan
from tools.browser_sso_plan import Failure
from tools.browser_sso_transport import Transport, preflight, tls_context


class TransportSafetyTest(unittest.TestCase):
    def fixture(self, respond):
        fixture = HTTPSFixture(respond)
        self.addCleanup(fixture.close)
        return fixture

    def transport(self, fixture, *, trusted=True, seconds=2, limit=65536, wrong_host=False):
        data = plan()
        origin = fixture.origin.replace('127.0.0.1', 'localhost') if wrong_host else fixture.origin
        op = {key: value.replace(data['op']['origin'], origin) for key, value in data['op'].items()}
        limits = {'request_seconds': seconds, 'body_bytes': limit}
        return Transport(op, limits, time.monotonic() + 5,
                         context=tls_context(str(fixture.cert) if trusted else None))

    def test_owned_tls_listener_is_not_blocked_by_a_silent_client(self):
        fixture = self.fixture(lambda h: reply(h))
        with socket.create_connection(fixture.server.server_address, timeout=1):
            start = time.monotonic()
            self.transport(fixture, seconds=0.5).request('discovery_url')
            self.assertLess(time.monotonic() - start, 1)

    def test_explicit_private_ca_verifies_owned_https(self):
        fixture = self.fixture(lambda h: reply(h))
        self.assertEqual(self.transport(fixture).request('discovery_url'), {'ok': True})
        self.assertEqual(fixture.counts, {'GET': 1, 'POST': 0})

    def test_explicit_ca_cannot_be_replaced_by_another_user(self):
        fixture = self.fixture(lambda h: reply(h))
        fixture.cert.chmod(0o666)
        with self.assertRaises(Failure):
            tls_context(str(fixture.cert))
        self.assertEqual(fixture.counts, {'GET': 0, 'POST': 0})

    def test_context_verification_cannot_be_disabled_after_construction(self):
        fixture = self.fixture(lambda h: reply(h))
        transport = self.transport(fixture)
        transport.context.check_hostname = False
        transport.context.verify_mode = ssl.CERT_NONE
        with self.assertRaises(Failure):
            transport.request('discovery_url')
        self.assertEqual(fixture.counts, {'GET': 0, 'POST': 0})

    def test_untrusted_and_wrong_hostname_fail_before_http(self):
        fixture = self.fixture(lambda h: reply(h))
        transport = self.transport(fixture, trusted=False)
        with self.assertRaises(Failure) as untrusted:
            transport.request('discovery_url')
        self.assertEqual(untrusted.exception.state, 'tls_error')
        # Keep the actual connection on our owned IPv4 listener while checking
        # the distinct TLS hostname. A refused ::1 socket is not hostname proof.
        transport = self.transport(fixture, wrong_host=True)
        address = (socket.AF_INET, socket.SOCK_STREAM, socket.IPPROTO_TCP, '', fixture.server.server_address)
        with patch('tools.browser_sso_transport.resolve', return_value=address), self.assertRaises(Failure) as wrong:
            transport.request('discovery_url')
        self.assertEqual(wrong.exception.state, 'tls_error')
        self.assertEqual(fixture.counts, {'GET': 0, 'POST': 0})

    def test_insecure_supplied_tls_context_is_never_accepted(self):
        context = ssl._create_unverified_context()
        with self.assertRaises(Failure):
            Transport(plan()['op'], plan()['limits'], time.monotonic() + 5, context=context)

    def test_proxy_and_ca_environment_are_not_inherited(self):
        hits = []
        class Trap(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_CONNECT(self):
                hits.append(True)  # Presence only, never proxy headers/target/body.
                self.send_error(403)
        trap = ThreadingHTTPServer(('127.0.0.1', 0), Trap)
        thread = threading.Thread(target=trap.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(thread.join, 2)
        self.addCleanup(trap.server_close)
        self.addCleanup(trap.shutdown)
        target = self.fixture(lambda h: reply(h))
        proxy = 'http://127.0.0.1:' + str(trap.server_port)
        with patch.dict(os.environ, {'HTTPS_PROXY': proxy, 'https_proxy': proxy, 'ALL_PROXY': proxy,
                                     'HTTP_PROXY': proxy, 'NO_PROXY': '', 'SSL_CERT_FILE': str(target.cert)}):
            self.transport(target).request('discovery_url')
            with self.assertRaises(Failure):
                self.transport(target, trusted=False).request('discovery_url')
        self.assertEqual(hits, [])
        self.assertEqual(target.counts['GET'], 1)

    def test_all_backchannel_redirects_rejected_including_same_origin(self):
        destination = self.fixture(lambda h: reply(h))
        for status in (301, 302, 303, 307, 308):
            for same_origin in (False, True):
                holder = {}
                def redirect(h):
                    reply(h, status=status, headers={'Location': holder['location']})
                target = self.fixture(redirect)
                holder['location'] = (target.origin if same_origin else destination.origin) + '/token'
                transport = self.transport(target)
                with self.subTest(status=status, same_origin=same_origin), self.assertRaises(Failure) as raised:
                    transport.request('token_endpoint', form={'code': 'synthetic-code'})
                self.assertEqual(raised.exception.state, 'redirect_rejected')
                self.assertEqual(target.counts['POST'], 1)
        self.assertEqual(destination.counts, {'GET': 0, 'POST': 0})

    def test_wrong_origin_rejected_before_connect(self):
        fixture = self.fixture(lambda h: reply(h))
        transport = self.transport(fixture)
        transport.op['token_endpoint'] = 'https://outside.invalid/token'
        with patch('socket.socket') as network, self.assertRaises(Failure):
            transport.request('token_endpoint', form={'code': 'synthetic-code'})
        network.assert_not_called()

    def test_bounded_duplicate_malformed_compressed_and_html_responses(self):
        for body, headers in [(b'{"key":1,"key":2}', {}), (b'{"n":NaN}', {}),
                              (b'{"nested":{"x":1,"x":2}}', {}), (b'[1]', {}),
                              (b'not json', {}), (b' ' * 65537, {}),
                              (b'{"ok":true}', {'Content-Encoding': 'gzip'}),
                              (b'{}', {'Content-Type': 'text/html'})]:
            fixture = self.fixture(lambda h, b=body, hdr=headers: reply(h, b, headers=hdr))
            with self.subTest(size=len(body), headers=list(headers)), self.assertRaises(Failure) as raised:
                self.transport(fixture).request('discovery_url')
            self.assertNotIn('nested', str(raised.exception))

    def test_slow_body_and_headers_obey_total_request_deadline(self):
        for headers in (False, True):
            stopped = threading.Event()
            self.addCleanup(stopped.set)
            def drip(h):
                if headers:
                    h.connection.sendall(b'HTTP/1.0 200 OK\r\nX-Drip: ')
                else:
                    h.send_response(200)
                    h.send_header('Content-Type', 'application/json')
                    h.send_header('Content-Length', '100')
                    h.end_headers()
                while not stopped.wait(0.08):
                    try:
                        h.connection.sendall(b' ')
                    except OSError:
                        break
            fixture = self.fixture(drip)
            start = time.monotonic()
            with self.subTest(headers=headers), self.assertRaises(Failure):
                self.transport(fixture, seconds=0.3).request('discovery_url')
            self.assertLess(time.monotonic() - start, 1.5)
            stopped.set()

    def test_stuck_dns_is_bounded_and_never_later_sends(self):
        release = threading.Event()
        self.addCleanup(release.set)
        fixture = self.fixture(lambda h: reply(h))
        original = socket.getaddrinfo
        def blocked(*args, **kwargs):
            release.wait(2)
            return original(*args, **kwargs)
        start = time.monotonic()
        with patch('socket.getaddrinfo', side_effect=blocked), self.assertRaises(Failure):
            self.transport(fixture, seconds=0.1).request('discovery_url')
        self.assertLess(time.monotonic() - start, 1)
        release.set()
        self.assertEqual(fixture.counts['GET'], 0)

    def test_lost_write_response_is_unknown_with_exactly_one_post(self):
        def lost(h):
            h.rfile.read(int(h.headers.get('Content-Length', 0)))
            h.connection.shutdown(socket.SHUT_RDWR)
        fixture = self.fixture(lost)
        with self.assertRaises(Failure) as raised:
            self.transport(fixture).request('token_endpoint', form={'code': 'synthetic-code'})
        self.assertEqual(raised.exception.state, 'unknown_result')
        self.assertEqual(fixture.counts['POST'], 1)

    def test_preflight_requires_pinned_discovery_and_both_clients(self):
        data = plan()
        from unittest.mock import Mock
        good = {'issuer': data['op']['issuer'], **{key: data['op'][key] for key in
                ('authorization_endpoint', 'token_endpoint', 'jwks_uri', 'userinfo_endpoint')},
                'response_types_supported': ['code'], 'grant_types_supported': ['authorization_code'],
                'code_challenge_methods_supported': ['S256'], 'token_endpoint_auth_methods_supported': ['none'],
                'id_token_signing_alg_values_supported': ['EdDSA']}
        provider = {'iss': data['op']['issuer'], 'op_session_supported': True,
                    'op_session_available': False, 'providers': ['password']}
        transport = Mock()
        transport.request.side_effect = [good, provider, provider]
        preflight(data, transport)
        self.assertEqual(transport.request.call_count, 3)
        for bad in ({**good, 'token_endpoint': 'https://outside.invalid/token'},
                    {**good, 'code_challenge_methods_supported': []}):
            transport.request.side_effect = [bad]
            with self.assertRaises(Failure):
                preflight(data, transport)


if __name__ == '__main__':
    unittest.main()
