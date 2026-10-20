"""Browser policy tests use synthetic request objects, never a target/browser profile."""

from contextlib import redirect_stdout
from io import StringIO
import json
import multiprocessing
import os
from pathlib import Path
import select
import subprocess
import tempfile
import time
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, Mock, patch

from sso_acceptance_support import plan, write_json
from tools import browser_sso_acceptance as cli
from tools import browser_sso_browser as browser
from tools.browser_sso_guard import Guard
from tools.browser_sso_plan import Failure
from tools.browser_sso_protocol import RP


class BrowserBoundaryTest(unittest.TestCase):
    def setUp(self):
        self.plan = plan()
        self.rps = [RP(self.plan, rp, Mock(), time.monotonic() + 20) for rp in self.plan['rps']]
        self.guard = Guard(self.plan, self.rps)

    def request(self, url, method='GET', payload=None, headers=None):
        route = Mock()
        route.request = SimpleNamespace(url=url, method=method, post_data=payload,
                                        all_headers=lambda: headers or {})
        self.guard.route(route)
        return route

    def test_exact_origins_login_parameters_static_and_callback_boundaries(self):
        for url, allowed in [(self.rps[0].authorization_url(), True),
                             (self.plan['op']['origin'] + '/app/main.dart.js', True),
                             (self.plan['op']['discovery_url'], True),
                             ('https://op.example.invalid.evil/app/main.dart.js', False),
                             (self.plan['op']['origin'] + '/login/?client_id=rp-b', False),
                             (self.plan['op']['origin'] + '/api/v1/admin/local-users', False),
                             (self.plan['op']['origin'] + '/auth/mfa', False),
                             (self.plan['op']['origin'] + '/app/main.dart.js?secret=x', False),
                             (self.plan['op']['origin'] + '/login/#fragment', False)]:
            self.guard.failure = None
            with self.subTest(allowed=allowed):
                route = self.request(url)
                self.assertEqual(route.continue_.called, allowed)
                self.assertEqual(route.abort.called, not allowed)
        self.guard.failure = None
        callback = self.rps[0].config['redirect_uri'] + '?iss=' + self.plan['op']['issuer'] + '&state=' + self.rps[0].state
        self.assertTrue(self.request(callback).continue_.called)
        self.assertTrue(self.request(callback, headers={'cookie': 'synthetic-cookie'}).abort.called)

    def test_single_password_then_no_second_password_even_if_armed(self):
        self.guard.credential = {'username': 'owned-user', 'password': 'synthetic-only'}
        self.guard.armed = 'primary'
        payload = {**self.guard.payload(), 'provider': 'password', 'credential': self.guard.credential}
        url = self.plan['op']['authorization_endpoint']
        self.assertTrue(self.request(url, 'POST', json.dumps(payload)).continue_.called)
        self.assertEqual(self.guard.primary, 1)
        self.assertIsNone(self.guard.credential)
        self.assertTrue(self.request(url, 'POST', json.dumps(payload)).abort.called)
        self.guard.failure, self.guard.phase, self.guard.armed = None, 1, 'primary'
        self.guard.credential = payload['credential']
        self.assertTrue(self.request(url, 'POST', json.dumps({**self.guard.payload(),
                        'provider': 'password', 'credential': payload['credential']})).abort.called)
        self.assertEqual(self.guard.primary, 1)

    def test_context_changes_and_duplicate_json_fail_before_write(self):
        self.guard.phase = 1
        payload = {**self.guard.payload(), 'resume_session': True}
        for field, value in [('client_id', 'rp-a'), ('redirect_uri', 'https://other.invalid'),
                             ('resource', ['rp-a-api']), ('scope', ['openid', 'rp-a:read']),
                             ('nonce', 'wrong'), ('prompt', 'login'), ('request_uri', 'opaque'),
                             ('id_token_hint', 'synthetic-other-rp-token')]:
            self.guard.failure = None
            with self.subTest(field=field):
                route = self.request(self.plan['op']['authorization_endpoint'], 'POST', json.dumps({**payload, field: value}))
                self.assertTrue(route.abort.called)
        self.guard.failure = None
        route = self.request(self.plan['op']['authorization_endpoint'], 'POST', '{"client_id":"rp-b","client_id":"rp-b"}')
        self.assertTrue(route.abort.called)
        self.assertEqual(self.guard.resume, 0)

    def test_resume_and_consent_are_one_shot_even_when_result_unknown(self):
        self.guard.phase = 1
        body = json.dumps({**self.guard.payload(), 'resume_session': True})
        url = self.plan['op']['authorization_endpoint']
        self.assertTrue(self.request(url, 'POST', body).continue_.called)
        self.assertTrue(self.request(url, 'POST', body).abort.called)
        self.guard.failure = None
        challenge = {'consent_challenge_id': 'synthetic-challenge', 'login_transaction_id': 'synthetic-continuation'}
        self.guard.challenge, self.guard.armed = challenge, 'consent'
        body = json.dumps({'client_id': 'rp-b', **challenge, 'consent_decision': 'allow'})
        self.assertTrue(self.request(url, 'POST', body).continue_.called)
        self.assertIsNone(self.guard.challenge)
        self.assertTrue(self.request(url, 'POST', body).abort.called)
        self.assertEqual(self.guard.consent, [0, 1])

    def response(self, data, *, length=None):
        response = Mock()
        response.url = self.plan['op']['authorization_endpoint']
        response.status = 200
        body = json.dumps(data).encode()
        response.body.return_value = body
        response.all_headers.return_value = {'content-length': str(len(body)) if length is None else length,
                                             'content-type': 'application/json'}
        self.guard.response(response)
        return response

    def test_consent_is_server_bound_not_automatic_approval_or_policy_bypass(self):
        data = {'iss': self.plan['op']['issuer'], 'error': 'consent_required',
                'client_name': self.rps[0].config['display_name'],
                'scopes': [{'scope': scope, 'description': ''} for scope in self.rps[0].config['scopes']],
                'consent_challenge_id': 'synthetic-challenge', 'login_transaction_id': 'synthetic-transaction'}
        self.response(data)
        self.assertIsNotNone(self.guard.challenge)
        self.assertIsNone(self.guard.armed)
        for change in ({'client_name': 'other'}, {'scopes': [{'scope': 'admin:write'}]},
                       {'scopes': [{'name': scope} for scope in self.rps[0].config['scopes']]},
                       {'scopes': [{'name': scope, 'scope': 'unexpected:write', 'description': ''}
                                   for scope in self.rps[0].config['scopes']]},
                       {'scopes': [{'scope': scope} for scope in self.rps[0].config['scopes'][:-1]]},
                       {'scopes': [{'scope': self.rps[0].config['scopes'][0]}] * len(self.rps[0].config['scopes'])},
                       {'error': 'mfa_required'}, {'iss': 'https://other.invalid'},
                       {'access_token': 'synthetic-token'}, {'authorization_details': [{'type': 'unknown'}]}):
            self.guard.failure, self.guard.challenge = None, None
            with self.subTest(fields=list(change)):
                self.response({**data, **change})
                self.assertIsNotNone(self.guard.failure)

    def test_browser_protocol_bodies_reject_unbounded_or_oversized_without_body_read(self):
        for length in ('', '65537', '1\n1'):
            self.guard.failure = None
            response = self.response({}, length=length)
            response.body.assert_not_called()
            self.assertIsNotNone(self.guard.failure)

    def test_fresh_context_blocks_service_workers_popups_websockets_downloads_and_dialogs(self):
        launched = Mock()
        launched.new_browser_cdp_session.return_value.send.return_value = {
            'arguments': list(browser.WORKER_ISOLATION_ARGS)}
        launched.new_context.return_value.new_page.return_value.evaluate.return_value = False
        context, page = browser.browser_context(launched, self.plan, self.guard)
        kwargs = launched.new_context.call_args.kwargs
        self.assertFalse(kwargs['ignore_https_errors'])
        self.assertFalse(kwargs['accept_downloads'])
        self.assertEqual(kwargs['service_workers'], 'block')
        self.assertFalse(any(key in kwargs for key in ('record_har_path', 'record_video_dir', 'storage_state')))
        self.assertIn("CredentialsContainer.prototype, 'store'", context.add_init_script.call_args.args[0])
        callbacks = {call.args[0]: call.args[1] for call in context.on.call_args_list}
        popup = Mock()
        callbacks['page'](popup)
        popup.close.assert_called_once()
        ws = Mock()
        context.route_web_socket.call_args.args[1](ws)
        ws.close.assert_called_once()
        events = {call.args[0]: call.args[1] for call in page.on.call_args_list}
        download, dialog = Mock(), Mock()
        events['download'](download)
        events['dialog'](dialog)
        download.cancel.assert_called_once()
        dialog.dismiss.assert_called_once()
        context.tracing.start.assert_not_called()
        context.storage_state.assert_not_called()
        page.screenshot.assert_not_called()

    def test_missing_or_unreadable_native_worker_switch_fails_before_context_or_credentials(self):
        for reply in ({}, {'arguments': []}, {'arguments': '--disable-shared-workers'},
                      {'arguments': ['--disable-blink-features=SharedWorker']}):
            launched = Mock()
            launched.new_browser_cdp_session.return_value.send.return_value = reply
            with self.subTest(reply=reply), patch.object(browser, 'load_credentials') as credential, \
                    self.assertRaises(Failure) as raised:
                browser.browser_context(launched, self.plan, self.guard)
            self.assertEqual(raised.exception.state, 'browser_boundary_violation')
            launched.new_context.assert_not_called()
            launched.new_browser_cdp_session.return_value.detach.assert_called_once()
            credential.assert_not_called()
        for method in ('send', 'detach'):
            launched = Mock()
            session = launched.new_browser_cdp_session.return_value
            session.send.return_value = {'arguments': list(browser.WORKER_ISOLATION_ARGS)}
            getattr(session, method).side_effect = RuntimeError('synthetic-secret-canary')
            with self.assertRaises(Failure) as raised:
                browser.browser_context(launched, self.plan, self.guard)
            self.assertNotIn('canary', str(raised.exception))
            launched.new_context.assert_not_called()

    def test_ignored_native_worker_switch_closes_context_before_navigation(self):
        for capability in (True, None, 'undefined'):
            launched = Mock()
            launched.new_browser_cdp_session.return_value.send.return_value = {
                'arguments': list(browser.WORKER_ISOLATION_ARGS)}
            page = launched.new_context.return_value.new_page.return_value
            page.evaluate.return_value = capability
            with self.subTest(capability=capability), self.assertRaises(Failure) as raised:
                browser.browser_context(launched, self.plan, self.guard)
            self.assertEqual(raised.exception.state, 'browser_boundary_violation')
            launched.new_context.return_value.close.assert_called_once()
            page.goto.assert_not_called()
            self.assertIsNone(self.guard.page)

    def test_subframe_requests_are_rejected_before_network(self):
        self.guard.page = Mock()
        route = Mock()
        route.request = SimpleNamespace(url=self.plan['op']['origin'] + '/app/main.dart.js', method='GET',
                                        all_headers=lambda: {}, frame=Mock())
        self.guard.route(route)
        route.abort.assert_called_once()
        route.continue_.assert_not_called()

    def test_native_response_barrier_rejects_redirects_before_continue_without_fetch_or_retry(self):
        context, page = Mock(), Mock()
        browser.redirect_barrier(context, page, self.guard)
        session = context.new_cdp_session.return_value
        session.send.assert_called_once_with('Fetch.enable', {
            'patterns': [{'urlPattern': '*', 'requestStage': 'Response'}]})
        paused = session.on.call_args.args[1]
        event = {'requestId': 'owned-request', 'request': {
            'url': self.plan['op']['authorization_endpoint'], 'method': 'POST'},
            'responseStatusCode': 307, 'responseHeaders': [{'name': 'Location', 'value': '/auth/login'}]}
        self.guard.primary = 1  # The first write may already have committed.
        session.send.reset_mock()
        paused(event)
        session.send.assert_called_once_with('Fetch.failRequest', {
            'requestId': 'owned-request', 'errorReason': 'BlockedByClient'})
        self.assertEqual(self.guard.failure, 'redirect_rejected')
        self.assertEqual(self.guard.primary, 1)
        context.request.fetch.assert_not_called()
        # Once stopped, even a later non-redirect response cannot continue.
        session.send.reset_mock()
        paused({**event, 'responseStatusCode': 200})
        self.assertEqual(session.send.call_args.args[0], 'Fetch.failRequest')

    def test_native_barrier_preserves_browser_tls_errors_and_sanitizes_interception_errors(self):
        context = Mock()
        browser.redirect_barrier(context, Mock(), self.guard)
        session = context.new_cdp_session.return_value
        paused = session.on.call_args.args[1]
        event = {'requestId': 'owned-request', 'request': {
            'url': self.plan['op']['discovery_url'], 'method': 'GET'}, 'responseErrorReason': 'CertificateError'}
        session.send.reset_mock()
        paused(event)
        session.send.assert_called_once_with('Fetch.continueRequest', {'requestId': 'owned-request'})
        self.assertIsNone(self.guard.failure)  # Chrome still delivers its original TLS failure.
        session.send.reset_mock()
        session.send.side_effect = [RuntimeError('synthetic-secret-canary'), None]
        paused(event)
        self.assertEqual([call.args[0] for call in session.send.call_args_list],
                         ['Fetch.continueRequest', 'Fetch.failRequest'])
        self.assertEqual(self.guard.failure, 'browser_boundary_violation')

    def test_only_exact_owned_callback_303_can_redirect_and_location_must_be_unique(self):
        callback = self.rps[0].config['redirect_uri'] + '?iss=' + self.plan['op']['issuer'] + '&state=' + self.rps[0].state
        headers = [{'name': 'Location', 'value': '/complete'}]
        self.guard.redirect_response(callback, 'GET', 303, headers)
        for url, method, status, values in (
                (callback, 'POST', 303, headers), (callback, 'GET', 307, headers),
                (callback, 'GET', 308, headers), (callback, 'GET', 303, headers * 2),
                (callback, 'GET', 303, [{'name': 'Location', 'value': '/complete?extra=x'}]),
                (callback + 'wrong', 'GET', 303, headers),
                (self.rps[1].config['redirect_uri'], 'GET', 303, headers),
                (self.plan['op']['authorization_endpoint'], 'POST', 308, headers)):
            with self.subTest(method=method, status=status), self.assertRaises(Failure):
                self.guard.redirect_response(url, method, status, values)

    def test_browser_trust_failure_precedes_credential_open_without_tls_bypass(self):
        page = Mock()
        page.goto.side_effect = RuntimeError('synthetic-secret-canary')
        with patch.object(browser, 'load_credentials') as credential, self.assertRaises(Failure) as raised:
            browser.browser_trust(page, self.plan, time.monotonic() + 1)
        self.assertEqual(raised.exception.state, 'browser_tls_or_navigation')
        credential.assert_not_called()
        self.assertNotIn('canary', str(raised.exception))

    def test_post_login_deadline_is_unknown_and_authorization_is_not_replayed(self):
        playwright = MagicMock()
        launched = playwright.__enter__.return_value.chromium.launch.return_value
        launched.new_browser_cdp_session.return_value.send.return_value = {
            'arguments': list(browser.WORKER_ISOLATION_ARGS)}
        launched.new_context.return_value.new_page.return_value.evaluate.return_value = False
        def lost(_page, guard, _rp, *_args, **_kwargs):
            guard.primary = 1
            guard.consent = [1, 0]
            raise Failure('deadline_exceeded')
        for rp in self.rps:
            rp.start = Mock()
        with patch.object(browser, 'tls_context'), patch.object(browser, 'Transport'), \
                patch.object(browser, 'preflight'), patch.object(browser, 'Verifier'), \
                patch.object(browser, 'RP', side_effect=self.rps), \
                patch('playwright.sync_api.sync_playwright', return_value=playwright), \
                patch.object(browser, 'browser_trust'), \
                patch.object(browser, 'authorize', side_effect=lost) as authorize, \
                self.assertRaises(Failure) as raised:
            browser.run(self.plan, time.monotonic() + 10)
        self.assertEqual(raised.exception.state, 'unknown_result')
        authorize.assert_called_once()
        launch = playwright.__enter__.return_value.chromium.launch.call_args.kwargs
        self.assertEqual(launch['channel'], 'chrome')
        self.assertIn('--no-proxy-server', launch['args'])
        self.assertTrue(set(browser.WORKER_ISOLATION_ARGS) <= set(launch['args']))
        self.assertFalse(any('ignore-certificate' in arg for arg in launch['args']))
        self.assertFalse({'DEBUG', 'PWDEBUG', 'SSLKEYLOGFILE', 'HTTPS_PROXY'} & set(launch['env']))

    def test_no_second_form_fill_when_b_requests_password(self):
        page, rp = Mock(), self.rps[1]
        self.guard.phase = 1
        page.locator.return_value.count.return_value = 1
        page.get_by_role.return_value.count.return_value = 1
        with patch.object(browser, 'load_credentials') as credential, \
                patch.object(browser, 'type_field') as fill, self.assertRaises(Failure):
            browser.authorize(page, self.guard, rp, time.monotonic() + 2, browser.LABELS['en-US'])
        credential.assert_not_called()
        fill.assert_not_called()
        page.get_by_role.return_value.click.assert_not_called()


class EntrypointIsolationTest(unittest.TestCase):
    def test_owned_chrome_check_never_imports_live_config_or_embedded_credentials(self):
        source = (Path(__file__).parents[1] / 'integration/owned/browser_sso_acceptance_test.py').read_text()
        self.assertNotIn('from test_config import CONFIG', source)
        self.assertNotIn('SNAPLINK_TEST_', source)
        self.assertIn('fixture = HTTPSFixture(respond)', source)
        self.assertIn("reserve.bind((f'127.0.0.{i + 2}', 0))", source)
        self.assertNotIn('ignore_https_errors=True', source)
        self.assertNotIn('--ignore-certificate', source)

    def test_driver_debug_proxy_and_keylog_environment_is_removed_and_restored(self):
        unsafe = {'DEBUG': 'pw:api', 'PWDEBUG': '1', 'NODE_OPTIONS': '--inspect',
                  'SSLKEYLOGFILE': '/not-written', 'HTTPS_PROXY': 'http://trap.invalid',
                  'SNAPLINK_TEST_PASSWORD': 'not-used', 'PATH': '/tools', 'HOME': '/owned'}
        with patch.dict(os.environ, unsafe, clear=True):
            with cli.clean_environment() as environment:
                self.assertEqual(environment, {'PATH': '/tools', 'HOME': '/owned'})
                self.assertEqual(dict(os.environ), environment)
            self.assertEqual(dict(os.environ), unsafe)

    def test_cli_exception_and_worker_details_never_echo_secrets(self):
        with tempfile.TemporaryDirectory() as root:
            path = write_json(Path(root) / 'plan.json', plan())
            for error in (RuntimeError('synthetic-secret-canary'), Failure('synthetic-secret-canary')):
                output = StringIO()
                with redirect_stdout(output), patch.object(cli, 'execute', side_effect=error):
                    code = cli.main(['--plan', path, '--execute', '--allow-authentication'])
                self.assertNotEqual(code, 0)
                self.assertNotIn('canary', output.getvalue())

    def test_supervisor_deadline_kills_only_owned_detached_child(self):
        shared = multiprocessing.Value('i', 0)
        sentinel = subprocess.Popen(['/bin/sleep', '30'])
        self.addCleanup(sentinel.wait, 2)
        self.addCleanup(sentinel.terminate)
        def stalled(_plan, _pipe):
            child = subprocess.Popen(['/bin/sleep', '30'], start_new_session=True)
            shared.value = child.pid
            child.wait()
        data = plan()
        data['limits']['total_seconds'] = 3
        start = time.monotonic()
        with patch.object(cli, '_worker', stalled):
            result = cli.execute(data)
        self.assertEqual(result['browser_acceptance'], 'unknown_result')
        self.assertLess(time.monotonic() - start, 4)
        self.assertGreater(shared.value, 0)
        self.assertIsNone(sentinel.poll(), 'Supervisor touched a non-descendant process')
        # A killed orphan may briefly remain a zombie until init reaps it.
        path = Path(f'/proc/{shared.value}/stat')
        try:
            state = path.read_text().rsplit(')', 1)[1].split()[0]
        except FileNotFoundError:
            return  # Already reaped between the timeout and this observation.
        self.assertEqual(state, 'Z')


if __name__ == '__main__':
    unittest.main()
