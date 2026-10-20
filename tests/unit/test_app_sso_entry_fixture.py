"""Entry selection and transport controls; only owned loopback, no target helper."""

from contextlib import ExitStack
from http.server import BaseHTTPRequestHandler, HTTPServer
import json
from pathlib import Path
import socket
import subprocess
import sys
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch
import urllib.parse

from app_sso_fixture_support import entry, fixture, fixture_imports, modules, rp, scenario, transport


class FixtureImportIsolationTest(unittest.TestCase):
    def test_scoped_overrides_preserve_transitive_imports_and_nested_bindings(self):
        name, dependency = '_app_sso_unit_binding', '_app_sso_unit_dependency'
        self.assertNotIn(name, sys.modules)
        self.assertNotIn(dependency, sys.modules)
        self.addCleanup(sys.modules.pop, dependency, None)
        outer, inner, imported = SimpleNamespace(), SimpleNamespace(), SimpleNamespace()
        with fixture_imports({name: outer}):
            self.assertIs(sys.modules[name], outer)
            with fixture_imports({name: inner}):
                sys.modules[dependency] = imported
                self.assertIs(sys.modules[name], inner)
            self.assertIs(sys.modules[name], outer)
        self.assertNotIn(name, sys.modules)
        self.assertIs(sys.modules[dependency], imported)

    def test_existing_binding_is_restored_even_on_failure(self):
        name = '_app_sso_unit_original'
        self.assertNotIn(name, sys.modules)
        original, replacement = SimpleNamespace(), SimpleNamespace()
        sys.modules[name] = original
        self.addCleanup(sys.modules.pop, name, None)
        with self.assertRaisesRegex(RuntimeError, '^controlled import failure$'):
            with fixture_imports({name: replacement}):
                self.assertIs(sys.modules[name], replacement)
                raise RuntimeError('controlled import failure')
        self.assertIs(sys.modules[name], original)

    def test_fresh_interpreter_retains_real_dependency_identity_without_preloading(self):
        code = f'''import importlib, sys
sys.path.insert(0, {str(Path(__file__).parent)!r})
import app_sso_fixture_support as support
for dependency in (support.rp.urllib.request, support.fixture.yaml,
                   support.fixture.tempfile, support.cli.argparse):
    assert sys.modules.get(dependency.__name__) is dependency
    assert importlib.import_module(dependency.__name__) is dependency
assert support.entry.EntryFixture is support.scenario.EntryFixture
assert not any(name.startswith('tools.browser_sso_') for name in sys.modules)
'''
        result = subprocess.run([sys.executable, '-I', '-c', code], capture_output=True, timeout=15)
        self.assertEqual(result.returncode, 0, 'Fixture dependency identity/cache isolation failed')


class EntrySelectionTest(unittest.TestCase):
    issuer = 'https://127.0.0.1:40001'

    def metadata(self, **changes):
        return {'issuer': self.issuer, 'authorization_endpoint': self.issuer + '/auth/login', **changes}

    def test_only_actual_owned_advertised_endpoint_is_accepted(self):
        self.assertEqual(entry.authorization_endpoint(self.metadata(), self.issuer), self.issuer + '/auth/login')
        invalid = [None, [], {}, self.metadata(issuer='https://elsewhere.test'),
                   self.metadata(authorization_endpoint=17)]
        invalid += [self.metadata(authorization_endpoint=value) for value in (
            'http://127.0.0.1:40001/auth/login', 'https://127.0.0.1/auth/login',
            'https://external.test/auth/login', self.issuer + '/login/',
            'https://user:private-fixture@127.0.0.1:40001/auth/login',
            self.issuer + '/auth/login?request=private-fixture', self.issuer + '/auth/login#fragment',
            self.issuer + '/auth/%6cogin', self.issuer + '/auth/login\n')]
        for metadata in invalid:
            with self.subTest(kind=type(metadata).__name__):
                with self.assertRaises(rp.FixtureFailure) as failure:
                    entry.authorization_endpoint(metadata, self.issuer)
                self.assertNotIn('private-fixture', str(failure.exception))

    def test_discovery_is_fetched_before_fresh_request_and_not_substituted(self):
        party = entry.EntryRP('entry-rp', 'Entry RP', False, host='127.0.0.2')
        self.addCleanup(party.close)
        party.issuer = self.issuer
        with patch.object(entry, 'get_json', return_value=(b'', self.metadata())) as get:
            url = party.discovered_authorization_url('')
        get.assert_called_once_with(self.issuer + '/.well-known/openid-configuration', party.tls_context)
        self.assertTrue(url.startswith(self.issuer + '/auth/login?'))
        params = urllib.parse.parse_qs(urllib.parse.urlsplit(url).query)
        self.assertEqual(params['client_id'], ['entry-rp'])
        self.assertEqual(params['response_type'], ['code'])
        self.assertEqual(params['code_challenge_method'], ['S256'])
        self.assertEqual(params['redirect_uri'], [party.redirect])
        self.assertEqual(params['resource'], ['entry-rp-api'])
        self.assertFalse({'provider', 'request', 'request_uri', 'prompt', 'max_age'} & params.keys())
        party.discard(url)
        self.assertFalse(party.pending)
        with self.assertRaises(rp.FixtureFailure):
            party.discard(url)
        with patch.object(entry, 'get_json', return_value=(b'', self.metadata(authorization_endpoint='https://foreign.test'))):
            with self.assertRaises(rp.FixtureFailure):
                party.discovered_authorization_url('')
        self.assertFalse(party.pending)

    def test_raw_mismatch_is_classified_without_following_it(self):
        for gateway, url, expected in (
            ('python', 'http://127.0.0.1:40001/auth/login', (False, True, True)),
            ('nginx', 'https://127.0.0.1/auth/login', (True, False, True)),
        ):
            evidence = entry.raw_entry_observation(self.metadata(authorization_endpoint=url), self.issuer)
            self.assertEqual(tuple(evidence[key] for key in ('scheme_matches', 'authority_matches', 'path_matches')), expected)
            self.assertNotIn('127.0.0.1', json.dumps(evidence))
            self.assertFalse(evidence['endpoint_followed'])


class IngressTest(unittest.TestCase):
    def test_fixture_canonical_headers_only_no_response_rewrite(self):
        seen = []
        body = b'{ "providers": [], "iss": "fixture", "op_session_available": false }\n'

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_POST(self):
                seen.append((self.path, dict(self.headers), self.rfile.read(int(self.headers['Content-Length']))))
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Set-Cookie', 'fixture-only=value; HttpOnly')
                self.end_headers()
                self.wfile.write(body)

        with ExitStack() as stack:
            server = fixture.start_server(stack, HTTPServer(('127.0.0.1', 0), Handler))
            upstream = f'http://127.0.0.1:{server.server_port}'
            ingress = transport.IdentityIngress(stack, upstream)
            ingress.canonicalize('https://127.0.0.1:40001')
            import http.client
            connection = http.client.HTTPConnection('127.0.0.1', ingress.server.server_port, timeout=2)
            self.addCleanup(connection.close)
            connection.request('POST', '/auth/login?client_id=fixture', body=b'{"resume_session":true}', headers={
                'Host': 'wrong.test', 'X-Forwarded-Host': 'wrong.test', 'X-Forwarded-Proto': 'http',
                'Forwarded': 'host=wrong.test', 'Cookie': 'fixture-cookie=private-fixture',
                'Content-Type': 'application/json',
            })
            with connection.getresponse() as response:
                self.assertEqual(response.status, 200)
                self.assertEqual(response.read(), body)
                self.assertEqual(response.getheader('Set-Cookie'), 'fixture-only=value; HttpOnly')
            self.assertEqual(seen[0][0], '/auth/login?client_id=fixture')
            self.assertEqual(seen[0][1]['Host'], '127.0.0.1:40001')
            self.assertEqual(seen[0][1]['X-Forwarded-Host'], '127.0.0.1:40001')
            self.assertEqual(seen[0][1]['X-Forwarded-Proto'], 'https')
            self.assertNotIn('Forwarded', seen[0][1])
            self.assertEqual(seen[0][1]['Cookie'], 'fixture-cookie=private-fixture')
            self.assertEqual(seen[0][2], b'{"resume_session":true}')
            self.assertNotIn('private-fixture', repr(ingress.counts))
            self.assertEqual(ingress.counts, {('POST', '/auth/login'): 1})
            with ingress.lock:
                ingress.active = True
            with self.assertRaises(rp.FixtureFailure):
                ingress.canonicalize('https://127.0.0.1:40001')
            with ingress.lock:
                ingress.active = False
        self.assertFalse(server.fixture_thread.is_alive())
        self.assertFalse(ingress.server.fixture_thread.is_alive())
        self.assertEqual(ingress.server.socket.fileno(), -1)

    def test_network_controls_reject_redirect_proxy_and_oversize_without_replay(self):
        requests = []
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_GET(self):
                requests.append((self.path, dict(self.headers)))
                self.send_response(302 if self.path == '/redirect' else 200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Location', 'http://unowned.test/must-not-follow')
                self.end_headers()
                self.wfile.write(b'x' * (transport.LIMIT + 1) if self.path == '/large' else b'{}')
        with ExitStack() as stack:
            server = fixture.start_server(stack, HTTPServer(('127.0.0.1', 0), Handler))
            origin = f'http://127.0.0.1:{server.server_port}'
            with patch.dict('os.environ', {'http_proxy': 'http://unowned.test:9', 'no_proxy': ''}):
                for path in ('/redirect', '/large'):
                    with self.assertRaises(rp.FixtureFailure):
                        transport.get_json(origin + path, None)
                transport.get_json(origin + '/ok', None)
        self.assertEqual([path for path, _ in requests], ['/redirect', '/large', '/ok'])
        for _, headers in requests:
            self.assertEqual(headers['Accept'], 'application/json')
            self.assertEqual(headers['Cache-Control'], 'no-cache')
            self.assertNotIn('Cookie', headers)
            self.assertNotIn('Authorization', headers)

    def test_rp_token_helper_also_ignores_proxy_environment_and_rejects_redirects(self):
        requests = []
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_GET(self):
                requests.append(self.path)
                self.send_response(302)
                self.send_header('Location', 'http://unowned.test/must-not-follow')
                self.end_headers()
        import urllib.error
        with ExitStack() as stack:
            server = fixture.start_server(stack, HTTPServer(('127.0.0.1', 0), Handler))
            resolve = socket.getaddrinfo
            def owned_resolution(host, *args, **kwargs):
                self.assertEqual(host, '127.0.0.1', 'RP helper attempted an unowned connection')
                return resolve(host, *args, **kwargs)
            with patch.dict('os.environ', {'http_proxy': 'http://unowned.test:9', 'no_proxy': ''}), \
                    patch.object(socket, 'getaddrinfo', side_effect=owned_resolution):
                with self.assertRaisesRegex(rp.FixtureFailure, '^OP request failed$'):
                    rp.json_request(f'http://127.0.0.1:{server.server_port}/redirect')
        self.assertEqual(requests, ['/redirect'])

    def test_rp_http_error_response_is_closed_and_details_withheld(self):
        import urllib.error
        private = Mock()
        error = urllib.error.HTTPError('http://127.0.0.1/private-fixture', 500, 'private-fixture', {}, private)
        opener = Mock()
        opener.open.side_effect = error
        with patch.object(rp.urllib.request, 'build_opener', return_value=opener):
            with self.assertRaisesRegex(rp.FixtureFailure, '^OP request failed$') as raised:
                rp.json_request('http://127.0.0.1:40001/userinfo', token='private-fixture')
        private.close.assert_called_once_with()
        opener.open.assert_called_once()
        self.assertTrue(raised.exception.__suppress_context__)

    def test_json_document_contract_requires_no_redirect_cookie_or_cache(self):
        headers = {'content-type': 'application/json; charset=utf-8', 'cache-control': 'no-store', 'pragma': 'no-cache'}
        transport.provider_contract(200, headers)
        for changes in ({'location': '/login/'}, {'set-cookie': 'private-fixture'},
                        {'content-type': 'text/html'}, {'cache-control': 'public'}, {'pragma': ''}):
            with self.assertRaises(rp.FixtureFailure) as failure:
                transport.provider_contract(200, {**headers, **changes})
            self.assertNotIn('private-fixture', str(failure.exception))


class ReplicaSelectorTest(unittest.TestCase):
    def test_two_real_owned_upstreams_and_inflight_switch_refusal_without_retry(self):
        import http.client
        seen = []
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_GET(self):
                seen.append(self.server.server_port)
                self.send_response(200)
                self.send_header('Set-Cookie', 'snaplink_op_session=private-fixture; HttpOnly')
                self.end_headers()
                self.wfile.write(b'{}')
        with ExitStack() as stack:
            servers = [fixture.start_server(stack, HTTPServer(('127.0.0.1', 0), Handler)) for _ in range(2)]
            origins = [f'http://127.0.0.1:{server.server_port}' for server in servers]
            ingress = transport.IdentityIngress(stack, origins[0], secondary=origins[1])
            ingress.canonicalize('https://127.0.0.1:40001')
            for replica in (1, 2):
                ingress.wait_idle()
                ingress.select(replica)
                connection = http.client.HTTPConnection('127.0.0.1', ingress.server.server_port, timeout=2)
                try:
                    connection.request('GET', '/userinfo')
                    with connection.getresponse() as response:
                        self.assertEqual(response.status, 200)
                        self.assertEqual(response.read(), b'{}')
                finally:
                    connection.close()
            self.assertEqual(seen, [server.server_port for server in servers])
            self.assertEqual(ingress.replica_counts, {(1, 'GET', '/userinfo'): 1, (2, 'GET', '/userinfo'): 1})
            self.assertEqual(ingress.cookie_responses, {1: 1, 2: 1})
            self.assertNotIn('private-fixture', repr(vars(ingress)))
            with ingress.lock:
                ingress.active = True
            with self.assertRaises(rp.FixtureFailure):
                ingress.select(1)
            with ingress.lock:
                ingress.active = False
            for replica in (0, 3, True):
                with self.assertRaises(rp.FixtureFailure):
                    ingress.select(replica)
            ingress.failed = True
            with self.assertRaises(rp.FixtureFailure):
                ingress.select(1)
        self.assertFalse(ingress.server.fixture_thread.is_alive())

    def test_completed_transaction_drain_is_bounded_and_never_allows_inflight_switch(self):
        with ExitStack() as stack:
            ingress = transport.IdentityIngress(stack, 'http://127.0.0.1:40002')
            ingress.wait_idle()
            with ingress.lock:
                ingress.active = True
            with patch.object(ingress.idle, 'wait_for', return_value=False) as wait:
                with self.assertRaisesRegex(rp.FixtureFailure, '^Identity ingress did not drain its completed transaction$'):
                    ingress.wait_idle()
                self.assertEqual(wait.call_args.kwargs, {'timeout': 5})
            with self.assertRaises(rp.FixtureFailure):
                ingress.select(1)
            with ingress.idle:
                ingress.active = False
                ingress.idle.notify_all()
            ingress.wait_idle()
            ingress.select(1)

    def test_live_cli_does_not_run_sequential_or_entry_cases(self):
        from unittest.mock import MagicMock
        cli = modules['browser_sso_test']
        api = SimpleNamespace(sync_playwright=Mock(return_value=MagicMock()))
        run = Mock()
        with fixture_imports({'playwright': SimpleNamespace(), 'playwright.sync_api': api,
                              'app_sso_supervisor': SimpleNamespace(run_owned_case=run)}), \
                patch.object(sys, 'argv', ['browser_sso_test.py', '--case', 'live-replicas', '--browser-channel', 'chrome']), \
                patch.object(cli, 'BrowserFixture') as baseline, patch.object(cli, 'run_case') as normal:
            self.assertEqual(cli.main(), 0)
        baseline.assert_not_called()
        normal.assert_not_called()
        self.assertEqual([(call.args[2], call.args[3], call.args[4]) for call in run.call_args_list],
                         [('python', 'chrome', 'live-replicas'), ('nginx', 'chrome', 'live-replicas')])


class ChromeAssertionsTest(unittest.TestCase):
    def test_discovery_post_is_not_password_resume_or_consent(self):
        cli = modules['browser_sso_test']
        context = Mock()
        diagnostics = {}
        counts = cli.observe(context, 'https://127.0.0.1:40001', diagnostics)
        observe_request = context.on.call_args_list[0].args[1]
        observe_request(SimpleNamespace(url='https://127.0.0.1:40001/auth/login', method='POST',
                                        post_data_json={'client_id': 'owned-fixture'}))
        self.assertEqual(counts, {'password': 0, 'resume': 0, 'continuation': 0, 'unexpected': 0})
        self.assertEqual(diagnostics, {})

    def test_explicit_entry_cli_runs_only_the_entry_case_on_both_gateways(self):
        from unittest.mock import MagicMock
        cli = modules['browser_sso_test']
        manager = MagicMock()
        api = SimpleNamespace(sync_playwright=Mock(return_value=manager))
        run = Mock()
        with fixture_imports({'playwright': SimpleNamespace(), 'playwright.sync_api': api,
                              'app_sso_supervisor': SimpleNamespace(run_owned_case=run)}), \
                patch.object(sys, 'argv', ['browser_sso_test.py', '--case', 'rp-entry', '--browser-channel', 'chrome']), \
                patch.object(cli, 'BrowserFixture') as baseline, patch.object(cli, 'run_case') as normal:
            self.assertEqual(cli.main(), 0)
        baseline.assert_not_called()
        normal.assert_not_called()
        self.assertEqual([(call.args[2], call.args[3], call.args[4]) for call in run.call_args_list],
                         [('python', 'chrome', 'rp-entry'), ('nginx', 'chrome', 'rp-entry')])

    def test_browser_document_is_native_navigation_and_checks_blocker_not_success(self):
        request = Mock(method='GET')
        request.is_navigation_request.return_value = True
        request.all_headers.return_value = {'accept': 'text/html,application/xhtml+xml',
                                             'sec-fetch-mode': 'navigate', 'sec-fetch-dest': 'document'}
        scenario.navigation_contract(request)
        for key, value in (('accept', 'application/json'), ('sec-fetch-mode', 'cors'), ('sec-fetch-dest', 'empty')):
            with patch.object(request, 'all_headers', return_value={**request.all_headers(), key: value}):
                with self.assertRaises(rp.FixtureFailure):
                    scenario.navigation_contract(request)
        request.is_navigation_request.return_value = False
        with self.assertRaises(rp.FixtureFailure):
            scenario.navigation_contract(request)

    def test_generic_case_cannot_pass_with_grant_post_ui_or_missing_identity_probe(self):
        party = SimpleNamespace(grants=[], failure=False)
        body = {'providers': [], 'iss': 'fixture', 'op_session_supported': True, 'op_session_available': False}
        counts = {'password': 0, 'resume': 0, 'continuation': 0, 'unexpected': 0}
        scenario.blocker_contract(body, 'fixture', False, party, 0, counts, counts, False)
        for changed in ({'op_session_available': True}, {'op_session_supported': False}, {'iss': 'wrong'}, {'providers': None}):
            with self.assertRaises(rp.FixtureFailure):
                scenario.blocker_contract({**body, **changed}, 'fixture', False, party, 0, counts, counts, False)
        for grants, after, ui in (([{}], counts, False), ([], {**counts, 'resume': 1}, False), ([], counts, True)):
            party.grants = grants
            with self.assertRaises(rp.FixtureFailure):
                scenario.blocker_contract(body, 'fixture', False, party, 0, counts, after, ui)


if __name__ == '__main__':
    unittest.main()
