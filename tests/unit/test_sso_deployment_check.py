import contextlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import os
from pathlib import Path
import socket
import ssl
import subprocess
import sys
import tempfile
import threading
import unittest
from unittest.mock import MagicMock, patch
import urllib.error
import urllib.parse

from tools import check_browser_sso_deployment as checker

ROOT = Path(__file__).resolve().parents[2]
ISSUER = 'https://op.example.test'


class DeploymentCheckTest(unittest.TestCase):
    def setUp(self):
        self.requests = []
        self.responses = {
            '/health': (200, 'application/json', {'status': 'ok'}),
            '/readyz': (200, 'application/json', {'status': 'ready'}),
            '/.well-known/openid-configuration': (200, 'application/json', {
                'issuer': ISSUER, 'response_types_supported': ['code'],
                'grant_types_supported': ['authorization_code'],
                'code_challenge_methods_supported': ['S256'],
            }),
            '/auth/login': (200, 'application/json', {
                'iss': ISSUER, 'providers': [], 'op_session_supported': True,
                'op_session_available': False,
            }),
        }
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                owner.requests.append((self.command, self.path, dict(self.headers)))
                status, content_type, body = owner.responses[urllib.parse.urlsplit(self.path).path]
                self.send_response(status)
                self.send_header('Content-Type', content_type)
                if 300 <= status < 400:
                    self.send_header('Location', owner.origin + '/must-not-follow')
                # Must not persist/forward cookies from a probe response.
                self.send_header('Set-Cookie', 'snaplink_op_session=fixture-only; Path=/')
                self.end_headers()
                self.wfile.write(body if isinstance(body, bytes) else json.dumps(body).encode())

        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.origin = f'http://127.0.0.1:{self.server.server_port}'
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.addCleanup(self.close)

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=3)

    def inspect(self):
        return checker.inspect_deployment(self.origin, ISSUER, 'rp/a+ b&c', timeout=1)

    def test_requests_are_read_only_exact_and_credential_free(self):
        report = self.inspect()
        self.assertFalse(report['passed'])  # Plain HTTP is diagnostic, never release-ready.
        self.assertEqual(report['checks']['https']['state'], 'required')
        self.assertTrue(all(check['state'] == 'ok' for name, check in report['checks'].items()
                            if name != 'https'))
        self.assertEqual(len(self.requests), 4)
        self.assertEqual([path for _, path, _ in self.requests[:3]],
                         ['/health', '/readyz', '/.well-known/openid-configuration'])
        for method, _, headers in self.requests:
            self.assertEqual(method, 'GET')
            self.assertNotIn('Authorization', headers)
            self.assertNotIn('Cookie', headers)
            self.assertNotIn('Content-Length', headers)
        query = urllib.parse.parse_qs(urllib.parse.urlsplit(self.requests[-1][1]).query)
        self.assertEqual(query, {'client_id': ['rp/a+ b&c']})
        self.assertEqual(report['browser_acceptance'], 'not_run')
        self.assertEqual(report['shared_sessions_and_keys'], 'not_verified')
        self.assertEqual(report['per_client_authorization'], 'not_verified')

    def test_advertised_https_success_still_is_not_browser_or_ha_acceptance(self):
        def fetch(opener, origin, path, timeout):
            handlers = [handler for handler in opener.handlers
                        if isinstance(handler, checker.urllib.request.HTTPSHandler)]
            self.assertEqual(len(handlers), 1)
            self.assertEqual(handlers[0]._context.verify_mode, ssl.CERT_REQUIRED)
            self.assertTrue(handlers[0]._context.check_hostname)
            body = self.responses[urllib.parse.urlsplit(path).path][2]
            return {'state': 'ok', 'http_status': 200}, body

        with patch.object(checker, 'fetch_json', side_effect=fetch):
            report = checker.inspect_deployment(ISSUER, ISSUER, 'rp')
        self.assertTrue(report['passed'])
        self.assertEqual(report['browser_acceptance'], 'not_run')
        self.assertEqual(report['shared_sessions_and_keys'], 'not_verified')
        self.assertEqual(report['per_client_authorization'], 'not_verified')

    def test_health_only_does_not_probe_authorization(self):
        with contextlib.redirect_stdout(io.StringIO()) as output:
            status = checker.main(['--origin', self.origin, '--health-only'])
        report = json.loads(output.getvalue())
        self.assertEqual(status, 0)
        self.assertEqual(report['mode'], 'health_only')
        self.assertEqual(list(report['checks']), ['health'])
        self.assertEqual(len(self.requests), 1)

    def test_http_errors_redirects_and_bad_bodies_never_mean_healthy(self):
        cases = [(401, 'application/json', {}, 'unauthorized'),
                 (403, 'application/json', {}, 'forbidden'),
                 (502, 'application/json', {}, 'http_error'),
                 (302, 'application/json', {}, 'redirect_rejected'),
                 (200, 'text/html', b'<html>SPA</html>', 'invalid_response'),
                 (200, 'application/json', [], 'invalid_response'),
                 (200, 'application/json', {'status': 'down'}, 'invalid_response'),
                 (200, 'application/json', b'{"status":"down","status":"ok"}', 'invalid_response'),
                 (200, 'application/json', b'x' * (checker.MAX_RESPONSE_BYTES + 1), 'response_too_large')]
        for status, content_type, body, expected in cases:
            with self.subTest(status=status, expected=expected):
                self.responses['/health'] = status, content_type, body
                report = checker.inspect_deployment(self.origin, health_only=True, timeout=1)
                self.assertFalse(report['passed'])
                self.assertEqual(report['checks']['health']['state'], expected)
        self.assertEqual(len(self.requests), len(cases))

    def test_probe_failure_and_omitted_capability_are_not_disabled(self):
        self.responses['/auth/login'] = 503, 'application/json', {}
        report = self.inspect()
        self.assertEqual(report['checks']['providers']['state'], 'http_error')
        self.assertEqual(report['checks']['browser_sso']['state'], 'unknown')
        self.responses['/auth/login'] = 200, 'application/json', {'iss': ISSUER, 'providers': []}
        self.assertEqual(self.inspect()['checks']['browser_sso']['state'], 'unknown')

    def test_explicit_disabled_unavailable_and_bad_capability_are_distinct(self):
        for updates, state in [({'op_session_supported': False}, 'disabled'),
                               ({'op_session_error': 'temporarily_unavailable'}, 'unavailable'),
                               ({'op_session_supported': 'true'}, 'unknown'),
                               ({'op_session_available': 0}, 'invalid_response')]:
            with self.subTest(state=state):
                body = {'iss': ISSUER, 'providers': [], 'op_session_supported': True,
                        'op_session_available': False, **updates}
                self.responses['/auth/login'] = 200, 'application/json', body
                self.assertEqual(self.inspect()['checks']['browser_sso']['state'], state)

    def test_issuer_and_advertised_grants_are_checked_independently(self):
        self.responses['/.well-known/openid-configuration'][2].update({
            'issuer': 'https://foreign.example', 'response_types_supported': ['token'],
            'grant_types_supported': [], 'code_challenge_methods_supported': 'S256',
        })
        self.responses['/auth/login'][2]['iss'] = 'https://foreign.example'
        checks = self.inspect()['checks']
        self.assertEqual(checks['issuer']['state'], 'mismatch')
        self.assertEqual(checks['provider_issuer']['state'], 'mismatch')
        self.assertEqual(checks['code_response']['state'], 'not_advertised')
        self.assertEqual(checks['code_grant']['state'], 'not_advertised')
        self.assertEqual(checks['pkce_s256']['state'], 'unknown')
        self.assertEqual(checks['health']['state'], 'ok')

    def test_report_never_contains_response_secrets_or_identifiers(self):
        self.responses['/auth/login'][2].update({'access_token': 'secret-access-fixture',
                                               'client_context': {'secret': 'secret-client-fixture'}})
        report = json.dumps(self.inspect())
        for forbidden in ('secret-access-fixture', 'secret-client-fixture', ISSUER, 'rp/a', 'fixture-only'):
            self.assertNotIn(forbidden, report)

    def test_connection_failure_does_not_claim_feature_off(self):
        with socket.socket() as reserved:
            reserved.bind(('127.0.0.1', 0))
            origin = f'http://127.0.0.1:{reserved.getsockname()[1]}'
            report = checker.inspect_deployment(origin, ISSUER, 'rp', timeout=1)
        self.assertEqual(report['checks']['health']['state'], 'unreachable')
        self.assertEqual(report['checks']['browser_sso']['state'], 'unknown')
        self.assertFalse(report['passed'])

    def test_tls_errors_are_sanitized_and_not_configuration_disabled(self):
        opener = MagicMock()
        opener.open.side_effect = urllib.error.URLError(ssl.SSLError('secret-network-fixture'))
        result, data = checker.fetch_json(opener, ISSUER, '/health', 1)
        self.assertEqual(result, {'state': 'tls_error'})
        self.assertIsNone(data)
        self.assertNotIn('secret-network-fixture', json.dumps(result))
        self.assertEqual(opener.open.call_count, 1)

    def test_invalid_explicit_targets_fail_before_network_without_echoing_secret(self):
        for value in ('https://user:secret-input-fixture@op.example', 'https://op.example/api',
                      'https://op.example?token=secret-input-fixture', ''):
            with self.subTest(value=value), patch.object(checker, 'inspect_deployment') as inspect, \
                    contextlib.redirect_stderr(io.StringIO()) as error:
                with self.assertRaises(SystemExit) as failure:
                    checker.main(['--origin', value, '--health-only'])
                self.assertEqual(failure.exception.code, 2)
                inspect.assert_not_called()
                self.assertNotIn('secret-input-fixture', error.getvalue())
        with contextlib.redirect_stderr(io.StringIO()), self.assertRaises(SystemExit):
            checker.main(['--origin', self.origin])


class DevelopmentStartupTest(unittest.TestCase):
    def test_launchers_never_kill_a_listener_and_exec_the_owned_proxy(self):
        make = subprocess.run(['make', '-n', 'serve'], cwd=ROOT, capture_output=True,
                              text=True, timeout=10, check=True)
        script = (ROOT / 'dev.sh').read_text()
        for text in (make.stdout, script):
            self.assertNotIn('fuser', text)
            self.assertNotIn('lsof', text)
            self.assertNotIn('kill ', text)
        self.assertIn('exec python3 tools/robust_proxy.py', script)
        self.assertIn('pipefail', script)

    def test_occupied_port_fails_without_disturbing_its_owner(self):
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            listener.listen()
            environment = {**os.environ, 'PORT': str(listener.getsockname()[1]),
                           'BACKEND': 'http://127.0.0.1:1'}
            result = subprocess.run([sys.executable, 'tools/robust_proxy.py'], cwd=ROOT,
                                    env=environment, capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 1)
            self.assertIn('port is already in use', result.stderr)
            self.assertNotIn('Traceback', result.stderr)
            with socket.create_connection(listener.getsockname(), timeout=1):
                connection, _ = listener.accept()
                connection.close()

    def test_development_script_uses_configured_identity_origin_and_port(self):
        with tempfile.TemporaryDirectory(prefix='snaplink-startup-unit-') as directory:
            bin_path = Path(directory)
            log = bin_path / 'arguments.jsonl'
            python = bin_path / 'python3'
            python.write_text(f'#!{sys.executable}\nimport json, os, sys\n'
                              'with open(os.environ["STARTUP_ARGUMENT_LOG"], "a") as stream:\n'
                              ' stream.write(json.dumps([sys.argv[1:], os.environ.get("BACKEND"), '
                              'os.environ.get("PORT")]) + "\\n")\n')
            python.chmod(0o700)
            flutter = bin_path / 'flutter'
            flutter.write_text('#!/bin/sh\nexit 99\n')
            flutter.chmod(0o700)
            environment = {**os.environ, 'PATH': str(bin_path) + os.pathsep + os.environ['PATH'],
                           'STARTUP_ARGUMENT_LOG': str(log), 'BACKEND': 'https://explicit-op.example',
                           'SNAPLINK_API_URL': 'https://must-not-select.example', 'PORT': '42424',
                           'SNAPLINK_PROXY_PORT': '43434'}
            result = subprocess.run(['bash', 'dev.sh', '--quick'], cwd=ROOT, env=environment,
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 0)
            calls = [json.loads(line) for line in log.read_text().splitlines()]
            self.assertEqual(calls[0][0], ['tools/check_browser_sso_deployment.py', '--origin',
                                          'https://explicit-op.example', '--health-only'])
            self.assertEqual(calls[1], [['tools/robust_proxy.py'], 'https://explicit-op.example', '42424'])
            self.assertNotIn('Proxy is ready', result.stdout)

    def test_development_build_failure_is_not_hidden_by_tail(self):
        with tempfile.TemporaryDirectory(prefix='snaplink-startup-unit-') as directory:
            bin_path = Path(directory)
            for name, content in {
                'flutter': '#!/bin/sh\necho "fixture build failure"\nexit 17\n',
                'python3': '#!/bin/sh\nexit 0\n',
            }.items():
                program = bin_path / name
                program.write_text(content)
                program.chmod(0o700)
            environment = {**os.environ, 'PATH': str(bin_path) + os.pathsep + os.environ['PATH']}
            result = subprocess.run(['bash', 'dev.sh', '--build'], cwd=ROOT, env=environment,
                                    capture_output=True, text=True, timeout=5)
            self.assertEqual(result.returncode, 17)
            self.assertNotIn('Build complete', result.stdout)
            self.assertNotIn('Starting proxy', result.stdout)


if __name__ == '__main__':
    unittest.main()
