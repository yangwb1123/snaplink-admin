"""Fixed-output privacy and zero ambient/network/browser/process I/O regressions."""

import ast
from contextlib import ExitStack
import http.client
import json
import os
from pathlib import Path
import socket
import subprocess
import sys
import tempfile
import unittest
from unittest.mock import patch
import urllib.request
import webbrowser

from app_sso_support import (app_sso, assert_unverified, check_app_sso, cli,
                             declarations, diagnose, labels)

TOOLS = Path(__file__).resolve().parents[2] / 'tools'


class NoEnvironment:
    def __getitem__(self, _):
        raise AssertionError('ambient environment read')

    def __iter__(self):
        raise AssertionError('ambient environment enumeration')

    def get(self, *_, **__):
        raise AssertionError('ambient environment read')


def deny_external_io(stack):
    for target in ('socket.socket', 'socket.create_connection', 'socket.getaddrinfo',
                   'http.client.HTTPConnection', 'http.client.HTTPSConnection',
                   'urllib.request.urlopen', 'urllib.request.build_opener',
                   'subprocess.Popen', 'os.system', 'webbrowser.open', 'webbrowser.get',
                   'os.getenv', 'os.listdir', 'os.scandir', 'os.walk', 'os.getcwd',
                   'os.stat', 'os.lstat', 'os.readlink', 'builtins.open',
                   'pathlib.Path.open', 'pathlib.Path.read_text', 'pathlib.Path.read_bytes'):
        stack.enter_context(patch(target, side_effect=AssertionError('forbidden I/O')))
    stack.enter_context(patch.object(os, 'environ', NoEnvironment()))


class AppSsoPrivacyTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='app-sso-privacy-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.path = self.root / 'private-path-synthetic-only.json'
        self.path.write_text(json.dumps(declarations()))
        self.path.chmod(0o600)

    def test_pure_schema_and_decision_modules_perform_no_io(self):
        data = json.dumps(declarations()).encode()
        expected = diagnose(declarations())
        with ExitStack() as stack:
            deny_external_io(stack)
            for target in ('os.open', 'os.read', 'os.write', 'os.fstat'):
                stack.enter_context(patch(target, side_effect=AssertionError('file I/O')))
            self.assertEqual(app_sso.diagnose(app_sso.decode_declarations(data)), expected)
            with self.assertRaises(app_sso.DeclarationError):
                app_sso.decode_declarations(b'{"version":1,"credential_file":"synthetic-only"}')

    def test_cli_only_opens_explicit_path_ancestors_and_reads_one_file(self):
        original_open, original_read, original_close = os.open, os.read, os.close
        opens, reads, closes = [], [], []

        def opened(path, flags, **kwargs):
            fd = original_open(path, flags, **kwargs)
            opens.append((path, flags, kwargs, fd))
            return fd

        def read(fd, count):
            reads.append((fd, count))
            return original_read(fd, count)

        def close(fd):
            closes.append(fd)
            return original_close(fd)

        with ExitStack() as stack:
            deny_external_io(stack)
            stack.enter_context(patch.object(os, 'open', side_effect=opened))
            stack.enter_context(patch.object(os, 'read', side_effect=read))
            stack.enter_context(patch.object(os, 'close', side_effect=close))
            stack.enter_context(patch.object(os, 'write', side_effect=AssertionError('file write')))
            code, report, out, err = cli(['--input', str(self.path)])
        self.assertEqual((code, err), (0, ''))
        self.assertEqual([item[0] for item in opens], ['/'] + str(self.path).split('/')[1:])
        for index, (_, flags, kwargs, fd) in enumerate(opens):
            self.assertTrue(flags & os.O_NOFOLLOW)
            self.assertFalse(flags & (os.O_WRONLY | os.O_RDWR | os.O_CREAT | os.O_TRUNC | os.O_APPEND))
            self.assertEqual(kwargs, {} if index == 0 else {'dir_fd': opens[index - 1][3]})
        self.assertCountEqual(closes, [item[3] for item in opens])
        self.assertTrue(reads)
        self.assertTrue(all(fd == opens[-1][3] and 0 < count <= 4096 for fd, count in reads))
        self.assertNotIn(self.path.name, out)
        self.assertNotIn(str(self.root), out)
        assert_unverified(self, report)

    def test_descriptors_are_closed_on_read_failure_without_fallback(self):
        original_open, original_close = os.open, os.close
        opened, closed = [], []

        def track_open(*args, **kwargs):
            fd = original_open(*args, **kwargs)
            opened.append(fd)
            return fd

        def track_close(fd):
            closed.append(fd)
            return original_close(fd)

        with patch.object(os, 'open', side_effect=track_open), \
                patch.object(os, 'close', side_effect=track_close), \
                patch.object(os, 'read', side_effect=OSError('private-synthetic-only')) as read:
            code, report, out, err = cli(['--input', str(self.path)])
        self.assertEqual((code, err), (2, ''))
        self.assertIn('input_file_unreadable', labels(report))
        self.assertNotIn('private-synthetic-only', out)
        self.assertEqual(read.call_count, 1)
        self.assertCountEqual(opened, closed)

    def test_all_external_identity_and_secret_inputs_have_identical_rejection(self):
        baseline = None
        for field in ('url', 'client_id', 'subject', 'state', 'nonce', 'login_hint',
                      'id_token_hint', 'access_token', 'password', 'credential_file'):
            for secret in ('synthetic-private-A', 'synthetic-private-B\n\u202e',
                           'https://synthetic-only.invalid/?token=private'):
                value = declarations()
                value['app_b'][field] = secret
                self.path.write_text(json.dumps(value))
                code, report, out, err = cli(['--input', str(self.path)])
                self.assertEqual((code, err), (2, ''))
                self.assertIn('invalid_declarations', labels(report))
                for private in (secret, self.path.name, 'synthetic-', 'https://'):
                    self.assertNotIn(private, out)
                if baseline is None:
                    baseline = out
                self.assertEqual(out, baseline)
                assert_unverified(self, report)

    def test_raw_argv_and_parser_error_bodies_never_reach_output(self):
        for args in (['--synthetic-secret-A'], ['--synthetic-secret-B'],
                     ['https://synthetic-only.invalid/?state=synthetic-private'],
                     ['--input', str(self.path), '--password', 'synthetic-private']):
            code, report, out, err = cli(args)
            self.assertEqual((code, err), (2, ''))
            self.assertEqual(report, app_sso.input_report('arguments'))
            self.assertNotIn('synthetic-', out)
            self.assertNotIn(self.path.name, out)
        for data in (b'{"version":1,synthetic-private-body}',
                     b'\xffsynthetic-private-body',
                     b'{"version":1,"version":"synthetic-private-body"}'):
            self.path.write_bytes(data)
            code, report, out, err = cli(['--input', str(self.path)])
            self.assertEqual((code, err), (2, ''))
            self.assertEqual(report, app_sso.input_report('declarations'))
            self.assertNotIn('synthetic-', out)

    def test_unexpected_failure_and_interrupt_are_unknown_not_a_login_result(self):
        for error, code, label in ((RuntimeError('synthetic-private-body'), 3, 'offline_diagnostic_failed'),
                                    (KeyboardInterrupt('synthetic-private-body'), 130, 'offline_diagnostic_interrupted')):
            with patch.object(check_app_sso, 'read_input_file', side_effect=error) as read:
                actual, report, out, err = cli(['--input', str(self.path)])
            self.assertEqual((actual, err, report['input_status']), (code, '', 'unknown'))
            self.assertIn(label, labels(report))
            self.assertNotIn('synthetic-', out)
            self.assertEqual(read.call_count, 1)
            assert_unverified(self, report)

    def test_imports_are_closed_stdlib_plus_only_the_new_pure_module(self):
        allowed = {
            'app_sso.py': {'dataclasses', 'json'},
            'check_app_sso.py': {'os', 'stat', 'sys', 'json', 'app_sso'},
        }
        for filename, modules in allowed.items():
            tree = ast.parse((TOOLS / filename).read_text())
            imports = set()
            for node in ast.walk(tree):
                if isinstance(node, ast.Import):
                    imports.update(alias.name for alias in node.names)
                elif isinstance(node, ast.ImportFrom):
                    imports.add(node.module)
            self.assertEqual(imports, modules)

    def test_script_from_unrelated_cwd_ignores_poison_environment_and_writes_no_cache(self):
        # Run disposable copies to observe every project-cache write, not existing caches.
        script_dir = self.root / 'script'
        script_dir.mkdir()
        for filename in ('app_sso.py', 'check_app_sso.py'):
            (script_dir / filename).write_bytes((TOOLS / filename).read_bytes())
        home = self.root / 'home'
        home.mkdir()
        (home / 'sso-plan.json').write_text('synthetic-private-default-not-for-reading')
        env = {'PATH': os.defpath, 'HOME': str(home),
               'SNAPLINK_TEST_USERNAME': 'synthetic-private-user',
               'SNAPLINK_TEST_PASSWORD': 'synthetic-private-password',
               'SNAPLINK_API_URL': 'https://synthetic-only.invalid',
               'HTTP_PROXY': 'https://synthetic-only.invalid',
               'HTTPS_PROXY': 'https://synthetic-only.invalid',
               'SSLKEYLOGFILE': str(self.root / 'must-not-exist')}
        before = sorted(str(path.relative_to(self.root)) for path in self.root.rglob('*'))
        result = subprocess.run([sys.executable, str(script_dir / 'check_app_sso.py'),
                                 '--input', str(self.path)], cwd=home, env=env,
                                capture_output=True, text=True, timeout=10, check=False)
        self.assertEqual((result.returncode, result.stderr), (0, ''))
        self.assertEqual(json.loads(result.stdout), diagnose(declarations()))
        self.assertNotIn('synthetic-', result.stdout)
        self.assertEqual(sorted(str(path.relative_to(self.root)) for path in self.root.rglob('*')), before)


if __name__ == '__main__':
    unittest.main()
