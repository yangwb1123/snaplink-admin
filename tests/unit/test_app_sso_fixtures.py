"""Normal stock-fixture declarations, evidence assertions and owned lifecycles."""

import copy
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import MagicMock, Mock, patch

from app_sso_fixture_support import cli, cookie_and_grants, entry, fixture, fixture_imports, flow, rp, runner, scenario, shared


class NormalFlowEvidenceTest(unittest.TestCase):
    def setUp(self):
        self.enterContext(fixture_imports())

    def test_cookie_access_identity_and_repeat_use_exact_original_context(self):
        cookie, grants = cookie_and_grants()
        claims = rp.assert_original_context(grants, cookie)
        self.assertEqual(claims['auth_time'], 1700000000)
        rp.assert_distinct_grants(grants)

    def test_cross_token_authentication_time_difference_is_not_tolerated(self):
        cookie, grants = cookie_and_grants()
        for token in ('access', 'identity'):
            for value in (None, 1700000001, 1699999999, True, 1700000000.0):
                with self.subTest(token=token, value=value):
                    changed = copy.deepcopy(grants)
                    changed[1][token]['auth_time'] = value
                    with self.assertRaisesRegex(rp.FixtureFailure, 'authentication times differ'):
                        rp.assert_original_context(changed, cookie)

    def test_cookie_canonical_anchor_and_both_token_subjects_and_sids_are_linked(self):
        cookie, grants = cookie_and_grants()
        for index, token, field, value in ((0, 'access', 'sid', 'another-anchor'),
                                            (1, 'identity', 'sid', 'another-session'),
                                            (1, 'access', 'sub', 'another-user'),
                                            (1, 'identity', 'sub', 'another-user')):
            with self.subTest(index=index, token=token, field=field):
                changed = copy.deepcopy(grants)
                changed[index][token][field] = value
                with self.assertRaises(rp.FixtureFailure):
                    rp.assert_original_context(changed, cookie)

    def test_repeat_preserves_amr_and_acr_not_just_authentication_time(self):
        cookie, grants = cookie_and_grants()
        for field, value in (('amr', ['other-method']), ('acr', 'other-context')):
            changed = copy.deepcopy(grants)
            for token in ('access', 'identity'):
                changed[2][token][field] = value
            with self.assertRaisesRegex(rp.FixtureFailure, 'Original authentication context changed'):
                rp.assert_original_context(changed, cookie)

    def test_each_explicit_navigation_needs_distinct_tokens_sessions_and_nonce(self):
        _, grants = cookie_and_grants()
        for token, fields in (('tokens', ('access_token', 'refresh_token', 'id_token')),
                              ('access', ('sid',)), ('identity', ('nonce',))):
            for field in fields:
                with self.subTest(token=token, field=field):
                    changed = copy.deepcopy(grants)
                    changed[2][token][field] = changed[0][token][field]
                    with self.assertRaises(rp.FixtureFailure):
                        rp.assert_distinct_grants(changed)

    def test_completed_grants_need_unique_code_state_and_pkce_evidence(self):
        _, grants = cookie_and_grants()
        for index, grant in enumerate(grants):
            grant['request'] = {field: field + str(index) for field in ('code', 'state', 'pkce')}
        rp.assert_distinct_grants(grants)
        for field in ('code', 'state', 'pkce'):
            changed = copy.deepcopy(grants)
            changed[1]['request'][field] = changed[0]['request'][field]
            with self.assertRaises(rp.FixtureFailure):
                rp.assert_distinct_grants(changed)
        grants[1].pop('request')
        with self.assertRaises(rp.FixtureFailure):
            rp.assert_distinct_grants(grants)

    def test_cookie_comparison_does_not_allow_sliding_expiry(self):
        original = {'value': 'private-fixture-cookie', 'expires': 1700000000}
        context, current_fixture = Mock(), SimpleNamespace(issuer='https://127.0.0.1:40001')
        for current in ({**original, 'expires': 1700000001}, {**original, 'value': 'new-fixture-cookie'}):
            with patch.object(cli, 'cookie_for', return_value=current):
                with self.assertRaises(rp.FixtureFailure) as raised:
                    flow.unchanged_cookie(context, current_fixture, original)
                self.assertNotIn('fixture-cookie', str(raised.exception))

    def test_newer_issuance_wait_is_bounded_and_not_an_authentication_retry(self):
        import time
        real_clock = time.time
        # Replace the fixture's dependency, never process-global stdlib clocks.
        with patch.object(flow, 'time') as clock:
            clock.time.return_value = 100.5
            flow.later_issuance({'auth_time': 100})
            clock.sleep.assert_called_once()
            self.assertAlmostEqual(clock.sleep.call_args.args[0], 0.6)
            self.assertIs(time.time, real_clock)
        with patch.object(flow, 'time') as clock:
            clock.time.return_value = 102
            flow.later_issuance({'auth_time': 100})
            clock.sleep.assert_not_called()
        with patch.object(flow, 'time') as clock:
            clock.time.return_value = 90
            with self.assertRaises(rp.FixtureFailure):
                flow.later_issuance({'auth_time': 100})
            clock.sleep.assert_not_called()

    def test_repeat_rp_navigation_owns_fresh_code_s256_state_nonce_and_verifier(self):
        party = rp.RelyingParty('normal-fixture', 'Normal fixture', False, host='127.0.0.2')
        self.addCleanup(party.close)
        party.issuer = 'https://127.0.0.1:40001'
        requests = [rp.urllib.parse.parse_qs(rp.urllib.parse.urlsplit(party.authorization_url('')).query)
                    for _ in range(2)]
        for field in ('state', 'nonce', 'code_challenge'):
            self.assertNotEqual(requests[0][field], requests[1][field])
        for request in requests:
            self.assertEqual(request['response_type'], ['code'])
            self.assertEqual(request['code_challenge_method'], ['S256'])
            self.assertEqual(request['resource'], ['normal-fixture-api'])
            self.assertEqual(request['scope'], ['openid normal-fixture:read'])
            _, verifier = party.pending[request['state'][0]]
            challenge = rp.base64.urlsafe_b64encode(rp.hashlib.sha256(verifier.encode()).digest()).decode().rstrip('=')
            self.assertEqual(request['code_challenge'], [challenge])
        self.assertEqual(len(party.pending), 2)


class NormalFixtureLifecycleTest(unittest.TestCase):
    def setUp(self):
        self.enterContext(fixture_imports())

    def test_default_policy_is_preserved_and_only_missing_pairs_are_added(self):
        standard = fixture.BrowserFixture(Path('/source'), Path('/web'), 'python')
        self.assertEqual(standard.consent_skips, (True, False))
        self.assertEqual(runner.CASES, {'inverse': (False, True), 'both-required': (False, False),
                                       'both-skipped': (True, True), 'shared-store': (False, False)})
        standard.stack.close()

    def test_shared_configuration_uses_published_owned_stores_and_persisted_key(self):
        with tempfile.TemporaryDirectory() as directory:
            owned = shared.SharedStoreFixture(Path('/source'), Path('/web'), 'python', consent_skips=(False, False))
            owned.directory, owned.issuer = Path(directory), 'https://127.0.0.1:40001'
            clients = [{'id': 'owned-a', 'skip_consent': False}, {'id': 'owned-b', 'skip_consent': False}]
            owned.rps = [Mock(), Mock()]
            for party, client in zip(owned.rps, clients):
                party.client_config.return_value = client
            config = owned.configuration(40002)
            self.assertEqual(config['identity'], {'backend': 'sqlite', 'session_backend': 'sqlite',
                                                  'sqlite': {'dsn': f'file:{directory}/identity.db'}})
            self.assertEqual(config['oauth']['backend'], 'sqlite')
            self.assertEqual(config['oauth']['sqlite']['dsn'], f'file:{directory}/oauth.db')
            self.assertEqual(config['self_service']['consent'], {
                'backend': 'sqlite', 'sqlite': {'dsn': f'file:{directory}/consent.db'}})
            self.assertEqual(config['keys']['signing'], {'alg': 'eddsa', 'key_file': directory + '/op-signing.pem'})
            self.assertEqual(config['clients'], clients)
            self.assertTrue(config['bootstrap']['disabled'])
            owned.stack.close()

    def test_replacement_stops_only_owned_process_before_starting_second_instance(self):
        with tempfile.TemporaryDirectory() as directory:
            owned = shared.SharedStoreFixture(Path('/source'), Path('/web'), 'python')
            owned.directory = Path(directory)
            (owned.directory / 'op-signing.pem').touch()  # Unit-only existence stub, never used as a key.
            first, second = Mock(pid=123), Mock(pid=456)
            first.poll.return_value = None
            owned.process = first
            events = []

            def stop(process):
                self.assertIs(process, first)
                events.append('stop-owned-first')
                first.poll.return_value = 0

            def start():
                self.assertEqual(first.poll(), 0)
                events.append('start-second')
                owned.process = second
            with patch.object(shared, 'stop_process', side_effect=stop), \
                    patch.object(owned, 'start_backend', side_effect=start):
                owned.replace_instance()
                with self.assertRaises(rp.FixtureFailure):
                    owned.replace_instance()
            self.assertEqual(events, ['stop-owned-first', 'start-second'])
            self.assertTrue(owned.replaced)
            owned.stack.close()

    def test_backend_start_refuses_to_overlap_owned_instances(self):
        owned = fixture.BrowserFixture(Path('/source'), Path('/web'), 'python')
        owned.process = Mock()
        owned.process.poll.return_value = None
        with patch.object(fixture.subprocess, 'Popen') as start:
            with self.assertRaises(rp.FixtureFailure):
                owned.start_backend()
            start.assert_not_called()
        owned.stack.close()

    def test_new_case_always_closes_browser_even_if_normal_flow_fails(self):
        current = Mock()
        factory = MagicMock()
        factory.return_value.__enter__.return_value = current
        playwright = Mock()
        with patch.object(runner, 'BrowserFixture', factory), \
                patch.object(runner, 'run_normal_case', side_effect=rp.FixtureFailure('Normal fixture failed')):
            with self.assertRaises(rp.FixtureFailure):
                runner.run_case(playwright, Path('/source'), Path('/web'), 'python', 'chrome', 'inverse')
        factory.assert_called_once_with(Path('/source'), Path('/web'), 'python', consent_skips=(False, True))
        playwright.chromium.launch.return_value.close.assert_called_once_with()
        factory.return_value.__exit__.assert_called_once()

    def test_explicit_shared_case_requires_normal_session_evidence_not_only_startup(self):
        current = SimpleNamespace(replace_instance=Mock(), replaced=False)
        factory = MagicMock()
        factory.return_value.__enter__.return_value = current
        playwright = Mock()
        with patch.object(runner, 'SharedStoreFixture', factory), patch.object(runner, 'run_normal_case') as normal:
            with self.assertRaisesRegex(rp.FixtureFailure, 'did not replace'):
                runner.run_case(playwright, Path('/source'), Path('/web'), 'nginx', 'chrome', 'shared-store')
        self.assertIs(normal.call_args.kwargs['replace_instance'], current.replace_instance)
        self.assertFalse(normal.call_args.kwargs['isolated_login'])
        playwright.chromium.launch.return_value.close.assert_called_once_with()

    def test_cli_runs_both_gateways_and_every_new_case_serially(self):
        playwright = Mock()
        manager = MagicMock()
        manager.__enter__.return_value = playwright
        api = SimpleNamespace(sync_playwright=Mock(return_value=manager))
        supervised = Mock()
        with fixture_imports({'playwright': SimpleNamespace(), 'playwright.sync_api': api,
                              'app_sso_supervisor': SimpleNamespace(run_owned_case=supervised)}), \
                patch.object(sys, 'argv', ['browser_sso_test.py', '--browser-channel', 'chrome']), \
                patch.object(cli, 'BrowserFixture'), patch.object(cli, 'run_browser') as baseline, \
                patch.object(cli, 'check_fixture_preflight'), patch.object(cli, 'run_case') as run:
            self.assertEqual(cli.main(), 0)
            self.assertEqual(baseline.call_count, 2)
        self.assertEqual([(call.args[2], call.args[3], call.args[4]) for call in supervised.call_args_list],
                         [(gateway, 'chrome', case) for gateway in ('python', 'nginx')
                          for case in ('rp-entry', 'live-replicas')])
        self.assertEqual([(call.args[3], call.args[4], call.args[5]) for call in run.call_args_list],
                         [(gateway, 'chrome', case) for gateway in ('python', 'nginx') for case in runner.CASES])

    def test_missing_browser_dependency_is_failure_not_skip_or_success(self):
        with patch.object(sys, 'argv', ['browser_sso_test.py', '--case', 'shared-store']), \
                fixture_imports({'playwright.sync_api': None}):
            self.assertEqual(cli.main(), 1)


class LiveReplicaEvidenceTest(unittest.TestCase):
    def setUp(self):
        self.enterContext(fixture_imports())

    def owned(self):
        owned = entry.LiveReplicaFixture(Path('/source'), Path('/web'), 'python', consent_skips=(False, False))
        owned.redis_port = 40004
        owned.directory, owned.issuer = Path('/owned'), 'https://127.0.0.1:40001'
        owned.backend, owned.second_backend = 'http://127.0.0.1:40002', 'http://127.0.0.1:40003'
        owned.rps = [SimpleNamespace(client_config=lambda: {}, pending={}, grants=[]) for _ in range(2)]
        return owned

    def test_live_configuration_shares_sessions_oauth_identity_consent_and_fixed_key(self):
        owned = self.owned()
        one, two = (owned.configuration(port) for port in (40002, 40003))
        self.assertEqual(one['identity']['session_backend'], 'redis')
        self.assertEqual(one['redis'], {'mode': 'single', 'addrs': ['127.0.0.1:40004'], 'db': 0})
        self.assertEqual(one['oauth']['backend'], 'redis')
        for store in (one['identity'], one['self_service']['consent']):
            self.assertEqual(store['backend'], 'sqlite')
            self.assertTrue(store['sqlite']['dsn'].startswith('file:/owned/'))
            self.assertIn('busy_timeout(5000)', store['sqlite']['dsn'])
        self.assertEqual(one['keys'], {'signing': {'alg': 'eddsa', 'key_file': '/owned/op-signing.pem'},
                                      'rotation': {'enabled': False}, 'signing_key_registry': {'backend': ''}})
        self.assertTrue(one['oidc']['browser_sso']['enabled'])
        self.assertTrue(one['bootstrap']['disabled'])
        two['server']['listen'] = one['server']['listen']
        self.assertEqual(one, two)

    def test_second_starts_only_after_first_key_ready_while_first_stays_alive(self):
        owned = self.owned()
        first, second = Mock(pid=101), Mock(pid=202)
        first.poll.return_value = second.poll.return_value = None
        with tempfile.TemporaryDirectory() as directory:
            owned.directory = Path(directory)
            owned.config_path = owned.directory / 'config.yaml'
            owned.ingress = Mock()
            calls = []
            def launch(backend, config):
                calls.append(backend)
                if len(calls) == 1:
                    (owned.directory / 'op-signing.pem').touch()
                    return first
                self.assertIs(owned.process, first)
                self.assertIsNone(first.poll())
                self.assertTrue((owned.directory / 'op-signing.pem').is_file())
                return second
            with patch.object(owned, 'launch_backend', side_effect=launch):
                owned.start_backend()
                owned.assert_live()
                with self.assertRaises(rp.FixtureFailure):
                    owned.start_backend()
            self.assertEqual(calls, [owned.backend, owned.second_backend])
            self.assertEqual(owned.original_pids, (101, 202))
            for process in (first, second):
                process.terminate.assert_not_called()
                process.kill.assert_not_called()
            second.poll.return_value = 1
            with self.assertRaises(rp.FixtureFailure):
                owned.assert_live()

    def test_live_routing_requires_primary_then_secondary_grants_and_no_cookie_reissue(self):
        owned = self.owned()
        owned.processes = [Mock(pid=101), Mock(pid=202)]
        owned.process, owned.original_pids = owned.processes[0], (101, 202)
        for process in owned.processes:
            process.poll.return_value = None
        owned.ingress = SimpleNamespace(replica_counts={(1, 'POST', '/auth/login'): 3, (1, 'POST', '/token'): 1},
                                         cookie_responses={1: 1}, failed=False, select=Mock(), wait_idle=Mock())
        owned.rps[0].grants = [{}]
        owned.rps[1].grants = [{}]
        with self.assertRaises(rp.FixtureFailure):
            owned.after_primary()
        owned.ingress.select.assert_not_called()
        owned.rps[1].grants = []
        owned.after_primary()
        owned.ingress.select.assert_called_once_with(2)
        owned.ingress.replica_counts.update({(2, 'POST', '/auth/login'): 7, (2, 'POST', '/token'): 3})
        owned.assert_routing()
        for mutate in ('cookie', 'tokens', 'process'):
            with self.subTest(mutate=mutate):
                if mutate == 'cookie':
                    owned.ingress.cookie_responses[2] = 1
                elif mutate == 'tokens':
                    owned.ingress.cookie_responses.pop(2, None)
                    owned.ingress.replica_counts[(2, 'POST', '/token')] = 0
                else:
                    owned.ingress.replica_counts[(2, 'POST', '/token')] = 3
                    owned.processes[0].poll.return_value = 0
                with self.assertRaises(rp.FixtureFailure):
                    owned.assert_routing()

    def test_cross_verification_requires_opposite_jwks_and_real_userinfo_routes(self):
        for fault in (None, 'signature', 'userinfo', 'unobserved'):
            owned = self.owned()
            owned.ingress = SimpleNamespace(replica_counts={}, replica=1)
            owned.assert_live = Mock()
            owned.select_replica = lambda replica: setattr(owned.ingress, 'replica', replica)
            def record(path):
                if fault != 'unobserved':
                    key = (owned.ingress.replica, 'GET', path)
                    owned.ingress.replica_counts[key] = owned.ingress.replica_counts.get(key, 0) + 1
            for party in owned.rps:
                party.grants = [{'identity': {'sub': 'fixture-user', 'nonce': 'fixture-nonce'},
                                 'tokens': {'id_token': 'private-id', 'access_token': 'private-access'}}]
                party.tls_context = None
                def verify(*_):
                    record('/.well-known/jwks.json')
                    if fault == 'signature':
                        raise rp.FixtureFailure('Controlled signature rejection')
                    return {'sub': 'fixture-user', 'nonce': 'fixture-nonce'}
                party.verify_identity = Mock(side_effect=verify)
            def userinfo(*_, **__):
                record('/userinfo')
                return {'sub': 'wrong' if fault == 'userinfo' else 'fixture-user'}
            with patch.object(scenario, 'json_request', side_effect=userinfo) as request:
                if fault is None:
                    self.assertEqual(scenario.cross_process_verification(owned),
                                     {'opposite_jwks_verifications': 2, 'opposite_userinfo_verifications': 2})
                    self.assertEqual(set(owned.ingress.replica_counts),
                                     {(replica, 'GET', path) for replica in (1, 2)
                                      for path in ('/.well-known/jwks.json', '/userinfo')})
                    self.assertEqual(request.call_count, 2)
                else:
                    with self.assertRaises(rp.FixtureFailure):
                        scenario.cross_process_verification(owned)

    def test_no_readiness_only_pass_and_browser_closes_on_failed_live_flow(self):
        owned, factory, playwright = Mock(assert_live=Mock()), MagicMock(), Mock()
        factory.return_value.__enter__.return_value = owned
        with patch.object(scenario, 'LiveReplicaFixture', factory), \
                patch.object(scenario, 'run_normal_case', side_effect=rp.FixtureFailure('Controlled live flow failure')) as run, \
                patch.object(scenario, 'cross_process_verification') as verify:
            with self.assertRaises(rp.FixtureFailure):
                scenario.run_live_case(playwright, Path('/source'), Path('/web'), 'nginx', 'chrome')
        self.assertIs(run.call_args.kwargs['after_primary'], owned.after_primary)
        self.assertNotIn('replace_instance', run.call_args.kwargs)
        verify.assert_not_called()
        playwright.chromium.launch.return_value.close.assert_called_once_with()
        factory.return_value.__exit__.assert_called_once()


if __name__ == '__main__':
    unittest.main()
