"""Offline/credential boundaries. Synthetic files; zero target requests."""

from contextlib import redirect_stderr, redirect_stdout
from io import StringIO
import json
import os
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from sso_acceptance_support import plan, write_json
from tools import browser_sso_acceptance as cli
from tools.browser_sso_plan import Failure, load_credentials, load_plan, validate_plan


class PlanSafetyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'plan.json'
        write_json(self.path, plan())

    def invoke(self, args):
        output, errors = StringIO(), StringIO()
        with redirect_stdout(output), redirect_stderr(errors), \
                patch.object(cli, 'execute') as execution, \
                patch('socket.socket') as socket, patch.object(cli, 'load_credentials') as credential:
            code = cli.main(args)
        self.assertEqual(errors.getvalue(), '')
        execution.assert_not_called()
        socket.assert_not_called()
        credential.assert_not_called()
        return code, json.loads(output.getvalue())

    def test_no_plan_is_missing_not_pass(self):
        code, report = self.invoke([])
        self.assertNotEqual(code, 0)
        self.assertEqual(report['browser_acceptance'], 'not_run')
        self.assertEqual(report['state'], 'missing_inputs')
        self.assertEqual(report['missing'], ['plan'])

    def test_complete_plan_is_only_offline_validation(self):
        code, report = self.invoke(['--plan', str(self.path)])
        self.assertEqual(code, 0)
        self.assertEqual(report['state'], 'valid_plan')
        self.assertEqual(report['browser_acceptance'], 'not_run')
        self.assertNotIn('example.invalid', json.dumps(report))
        self.assertNotIn('rp-a', json.dumps(report))

    def test_either_execution_flag_alone_never_starts_execution(self):
        for flag in ('--execute', '--allow-authentication'):
            with self.subTest(flag=flag):
                code, report = self.invoke(['--plan', str(self.path), flag])
                self.assertNotEqual(code, 0)
                self.assertEqual(report['state'], 'authentication_consent_required')
                self.assertEqual(report['browser_acceptance'], 'not_run')

    def test_unknown_duplicate_and_inline_cli_are_sanitized(self):
        for tail in (['--execute', '--execute'], ['--plan', 'canary-inline'],
                     ['--password', 'canary-inline'], ['--plan=' + str(self.path)],
                     ['--allow-authentication=true'], ['--pl', str(self.path)]):
            with self.subTest(tail=tail[:1]):
                code, report = self.invoke(['--plan', str(self.path), *tail])
                self.assertNotEqual(code, 0)
                self.assertEqual(report['state'], 'invalid_arguments')
                self.assertNotIn('canary', json.dumps(report))

    def test_complete_plan_and_both_flags_dispatch_once_without_env_credentials(self):
        output = StringIO()
        result = cli.report('unknown_result', 'execute', acceptance='unknown_result')
        with redirect_stdout(output), patch.dict(os.environ, {'SNAPLINK_TEST_PASSWORD': 'not-used'}), \
                patch.object(cli, 'execute', return_value=result) as execution:
            code = cli.main(['--plan', str(self.path), '--execute', '--allow-authentication'])
        self.assertEqual(code, 1)
        execution.assert_called_once()
        self.assertEqual(json.loads(output.getvalue())['browser_acceptance'], 'unknown_result')

    def test_missing_nested_inputs_are_fixed_names(self):
        data = plan()
        del data['op']['issuer']
        del data['rps'][1]['resources']
        write_json(self.path, data)
        code, report = self.invoke(['--plan', str(self.path), '--execute', '--allow-authentication'])
        self.assertNotEqual(code, 0)
        self.assertEqual(report['missing'], ['op.issuer', 'rps.1.resources'])
        self.assertEqual(report['browser_acceptance'], 'not_run')

    def test_operator_plan_is_not_writable_by_other_users(self):
        self.path.chmod(0o666)
        with self.assertRaises(Failure):
            load_plan(str(self.path))

    def test_duplicate_keys_unknown_fields_inline_secrets_and_limits_fail(self):
        invalid = [b'{"version":1,"version":1}', b'{"secret":"canary-inline"}',
                   b'[]', b'{"version":NaN}', b' ' * 32769]
        for value in invalid:
            self.path.write_bytes(value)
            with self.subTest(size=len(value)), self.assertRaises(Failure):
                load_plan(str(self.path))
        for field, value in [('password', 'canary-inline'), ('request', 'opaque'),
                             ('limits', {'total_seconds': 301, 'request_seconds': 3, 'body_bytes': 65536}),
                             ('registration_confirmed', False), ('policy_confirmed', False)]:
            data = plan()
            data[field] = value
            with self.subTest(field=field), self.assertRaises(Failure):
                validate_plan(data)

    def test_exact_https_endpoints_no_suffix_userinfo_query_or_fragment(self):
        for field, value in [('origin', 'http://op.example.invalid'),
                             ('issuer', 'https://op.example.invalid.evil'),
                             ('token_endpoint', 'https://op.example.invalid.evil/token'),
                             ('jwks_uri', 'https://op.example.invalid/.well-known/jwks.json?secret=x'),
                             ('login_url', 'https://op.example.invalid/login/#x'),
                             ('origin', 'https://user@op.example.invalid'),
                             ('origin', 'https://OP.example.invalid'),
                             ('origin', 'https://op.example.invalid\\@evil.invalid')]:
            data = plan()
            data['op'][field] = value
            with self.subTest(field=field, value=value), self.assertRaises(Failure):
                validate_plan(data)

    def test_callback_requires_distinct_numeric_loopback_exact_path_and_port(self):
        for uri in ('http://localhost:42000/callback', 'http://127.0.0.2/callback',
                    'http://127.0.0.2:42000/callback?x=1', 'http://127.0.0.2:42000/callback#x',
                    'https://remote.invalid/callback', 'http://127.0.0.2:42000/%63allback',
                    'http://127.0.0.3:42001/callback'):
            data = plan()
            data['rps'][0]['redirect_uri'] = uri
            with self.subTest(uri=uri), self.assertRaises(Failure):
                validate_plan(data)
        data = plan()
        data['op'] = {k: v.replace('op.example.invalid', '127.0.0.2') if isinstance(v, str) else v
                      for k, v in data['op'].items()}
        with self.assertRaises(Failure):
            validate_plan(data)

    def test_unsupported_flows_never_relax_policy(self):
        for field, value in [('provider', 'oidc'), ('pkce', 'plain'), ('response_mode', 'form_post'),
                             ('token_endpoint_auth_method', 'client_secret_basic')]:
            data = plan()
            data['rps'][0][field] = value
            with self.subTest(field=field), self.assertRaises(Failure) as raised:
                validate_plan(data)
            self.assertEqual(raised.exception.state, 'unsupported_by_tool')


class CredentialFileSafetyTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.path = Path(self.tmp.name) / 'credential.json'
        self.value = {'username': 'owned-user', 'password': 'synthetic-only', 'expected_subject': 'owned-subject'}
        write_json(self.path, self.value)

    def test_explicit_owner_only_regular_file_is_read_once_without_environment_fallback(self):
        with patch.dict(os.environ, {'SNAPLINK_TEST_PASSWORD': 'not-used'}):
            value = load_credentials(str(self.path))
        self.assertTrue(value == self.value, 'Credential reference changed')

    def test_unsafe_modes_symlink_hardlink_fifo_directory_and_size_fail(self):
        for mode in (0o644, 0o640, 0o666, 0o700):
            self.path.chmod(mode)
            with self.subTest(mode=mode), self.assertRaises(Failure):
                load_credentials(str(self.path))
        self.path.chmod(0o600)
        for kind in ('symlink', 'hardlink', 'fifo', 'directory', 'oversized', 'parent_symlink'):
            other = Path(self.tmp.name) / kind
            if kind == 'symlink':
                other.symlink_to(self.path)
            elif kind == 'hardlink':
                other.hardlink_to(self.path)
            elif kind == 'fifo':
                os.mkfifo(other, 0o600)
            elif kind == 'directory':
                other.mkdir()
            elif kind == 'parent_symlink':
                other.symlink_to(Path(self.tmp.name), target_is_directory=True)
                other = other / self.path.name
            else:
                other.write_bytes(b' ' * 8193)
                other.chmod(0o600)
            with self.subTest(kind=kind), self.assertRaises(Failure):
                load_credentials(str(other))
            if kind == 'hardlink':
                other.unlink()

    def test_wrong_file_owner_is_rejected_before_read(self):
        actual = os.fstat
        def wrong_owner(fd):
            from types import SimpleNamespace
            info = actual(fd)
            return SimpleNamespace(st_uid=os.getuid() + 1, st_mode=info.st_mode,
                                   st_nlink=info.st_nlink, st_size=info.st_size)
        with patch('os.fstat', side_effect=wrong_owner), patch('os.read') as read, self.assertRaises(Failure):
            load_credentials(str(self.path))
        read.assert_not_called()

    def test_duplicate_extra_and_non_password_secret_types_fail_without_echo(self):
        for raw in ('{"username":"x","username":"y"}',
                    '{"username":"x","password":"synthetic-only","token":"canary"}',
                    '{"username":"x","password":1,"expected_subject":"x"}'):
            self.path.write_text(raw)
            with self.subTest(raw_type='json'), self.assertRaises(Failure) as raised:
                load_credentials(str(self.path))
            self.assertNotIn('canary', str(raised.exception))
            self.assertNotIn('synthetic-only', str(raised.exception))


if __name__ == '__main__':
    unittest.main()
