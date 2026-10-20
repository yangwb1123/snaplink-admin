"""Strict schema, bounded explicit file intake, and closed CLI error states."""

import json
import os
from pathlib import Path
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from app_sso_support import (app_sso, assert_unverified, check_app_sso, cli,
                             declarations, labels)


class AppSsoSchemaTest(unittest.TestCase):
    def reject(self, value):
        with self.assertRaises(app_sso.DeclarationError) as raised:
            app_sso.decode_declarations(json.dumps(value).encode())
        self.assertEqual(str(raised.exception), 'invalid_declarations')
        self.assertTrue(raised.exception.__suppress_context__)

    def test_root_and_version_are_exact_types(self):
        for value in (None, [], '', 1, True, {}, {'version': True}, {'version': '1'},
                      {'version': 0}, {'version': 1.0}, {'version': 2}):
            with self.subTest(value=value):
                self.reject(value)

    def test_unknown_fields_and_identity_facts_are_not_accepted_at_any_level(self):
        for field in ('url', 'issuer', 'client_id', 'redirect_uri', 'state', 'nonce',
                      'login_hint', 'id_token_hint', 'token', 'password', 'credential_file',
                      'registration_confirmed', 'browser_profile', 'execute'):
            for location in ('root', 'app_a', 'app_b'):
                value = declarations()
                (value if location == 'root' else value[location])[field] = 'synthetic-only'
                with self.subTest(field=field, location=location):
                    self.reject(value)

    def test_each_present_app_is_complete_and_has_no_unknown_fields(self):
        for side in ('app_a', 'app_b'):
            for key in app_sso.APP_FIELDS:
                value = declarations()
                del value[side][key]
                self.reject(value)
            for item in ([], '', True, 1):
                value = declarations()
                value[side] = item
                self.reject(value)

    def test_relationships_and_all_enum_fields_are_closed(self):
        for field in ('op_relation', 'browser_jar_relation'):
            for item in (True, 1, [], {}, 'SAME', '', 'https://op.example.invalid'):
                value = declarations()
                value[field] = item
                self.reject(value)
        for field in ('flow', 'request_context', 'step_up', 'consent'):
            for item in (None, True, [], {}, 0, '', 'unknown ', 'UNKNOWN'):
                value = declarations()
                value['app_b'][field] = item
                self.reject(value)

    def test_prompt_duplicates_none_combinations_and_non_tokens_are_rejected(self):
        for prompt in ('login', {}, True, 0, ['login', 'login'], ['none', 'consent'],
                       ['none', 'login'], ['none', 'select_account'], ['LOGIN'], [' login'],
                       ['login select_account'], [''], [None], [{}], [1],
                       ['login', 'select_account', 'consent', 'none', 'login']):
            value = declarations()
            value['app_b']['prompt'] = prompt
            self.reject(value)

    def test_max_age_rejects_bool_float_signed_overflow_and_ambiguous_null(self):
        for age in (True, False, None, 0.0, 1.5, -1, 2147483648, '0', '', [], {}):
            value = declarations()
            value['app_b']['max_age'] = age
            self.reject(value)

    def test_direct_flow_cannot_also_declare_par_or_jar(self):
        for context in ('par', 'jar'):
            value = declarations()
            value['app_b'].update(flow='app_local_direct', request_context=context)
            self.reject(value)

    def test_duplicate_and_escaped_equivalent_json_keys_are_rejected(self):
        app = json.dumps(declarations()['app_b'])
        documents = [b'{"version":1,"version":1}', b'{"version":1,"versi\\u006fn":1}',
                     b'{"version":1,"op_relation":"same","op_relation":"different"}',
                     ('{"version":1,"app_b":' + app + ',"app_b":null}').encode(),
                     ('{"version":1,"app_b":' + app.replace('"flow":', '"flow":"unknown","flow":') + '}').encode()]
        for data in documents:
            with self.assertRaises(app_sso.DeclarationError):
                app_sso.decode_declarations(data)

    def test_malformed_non_utf8_bom_depth_numbers_and_size_are_bounded(self):
        for data in (b'', b'\xff', b'\xef\xbb\xbf{"version":1}', b'{', b'{}{}',
                     b'{"version":NaN}', b'{"version":Infinity}', b'{"version":-Infinity}',
                     b'{"version":1e100000}', b'{"version":' + b'1' * 11000 + b'}',
                     b'[' * 4000 + b']' * 4000,
                     b' ' * (app_sso.MAX_INPUT_BYTES + 1)):
            with self.assertRaises(app_sso.DeclarationError):
                app_sso.decode_declarations(data)
        for value in (None, '', bytearray(b'{}')):
            with self.assertRaises(app_sso.DeclarationError):
                app_sso.decode_declarations(value)


class AppSsoFileAndCliTest(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix='app-sso-input-')
        self.addCleanup(self.directory.cleanup)
        self.root = Path(self.directory.name)
        self.path = self.root / 'declarations.json'
        self.path.write_text(json.dumps(declarations()))
        self.path.chmod(0o600)

    def test_explicit_regular_file_and_exit_codes(self):
        code, report, _, err = cli(['--input', str(self.path)])
        self.assertEqual((code, err), (0, ''))
        self.assertEqual(report['assessment'], 'compatible_static_declarations')
        assert_unverified(self, report)
        value = declarations()
        value['browser_jar_relation'] = 'unknown'
        self.path.write_text(json.dumps(value))
        self.assertEqual(cli(['--input', str(self.path)])[0], 0)
        value['app_b'] = None
        self.path.write_text(json.dumps(value))
        code, report, _, err = cli(['--input', str(self.path)])
        self.assertEqual((code, err, report['assessment']), (2, '', 'missing_inputs'))
        self.path.write_text('{')
        code, report, _, err = cli(['--input', str(self.path)])
        self.assertEqual((code, err), (2, ''))
        self.assertIn('invalid_declarations', labels(report))

    def test_absent_inputs_invalid_arguments_and_help_never_open_a_file(self):
        cases = [([], 2, 'input_file_missing'), (['--input', ''], 2, 'input_file_missing'),
                 (['--help'], 0, 'usage_in_existing_docs'), (['-h'], 0, 'usage_in_existing_docs'),
                 (['--input'], 2, 'invalid_arguments'),
                 (['--input=' + str(self.path)], 2, 'invalid_arguments'),
                 (['--input', str(self.path), '--input', str(self.path)], 2, 'invalid_arguments'),
                 (['--execute'], 2, 'invalid_arguments'),
                 (['--help', 'extra'], 2, 'invalid_arguments')]
        with patch.object(check_app_sso, 'read_input_file', side_effect=AssertionError('not allowed')) as read:
            for args, expected_code, label in cases:
                code, report, _, err = cli(args)
                self.assertEqual((code, err), (expected_code, ''))
                self.assertIn(label, labels(report))
                assert_unverified(self, report)
        read.assert_not_called()

    def test_paths_are_absolute_normalized_and_not_expanded(self):
        paths = ['', 'relative.json', '~/declarations.json', '$HOME/declarations.json',
                 'file://' + str(self.path), '//tmp/declarations.json',
                 str(self.root) + '/./declarations.json', str(self.root) + '/../declarations.json',
                 str(self.path) + '/', str(self.path) + '\n', '/' + 'a' * 4096]
        with patch.object(check_app_sso.os, 'open', side_effect=AssertionError('not allowed')) as opened:
            for path in paths:
                with self.assertRaises(check_app_sso.InputFileError):
                    check_app_sso.read_input_file(path)
        opened.assert_not_called()

    def test_missing_file_is_unreadable_not_a_disabled_or_logged_out_state(self):
        code, report, _, err = cli(['--input', str(self.root / 'not-present')])
        self.assertEqual((code, err, report['input_status']), (2, '', 'unreadable'))
        self.assertIn('input_file_unreadable', labels(report))
        assert_unverified(self, report)

    def test_final_or_ancestor_symlinks_are_never_followed(self):
        link = self.root / 'link.json'
        link.symlink_to(self.path)
        parent = self.root / 'parent'
        parent.symlink_to(self.root, target_is_directory=True)
        for path in (link, parent / self.path.name):
            with patch.object(check_app_sso.os, 'read') as read:
                with self.assertRaises(check_app_sso.InputFileError):
                    check_app_sso.read_input_file(str(path))
            read.assert_not_called()

    def test_hardlinks_writable_files_directories_and_fifo_rejected_before_read(self):
        hard = self.root / 'hard.json'
        os.link(self.path, hard)
        fifo = self.root / 'fifo'
        os.mkfifo(fifo, 0o600)
        writable = self.root / 'writable.json'
        writable.write_text('{}')
        for mode in (0o620, 0o602, 0o666):
            writable.chmod(mode)
            for path in (self.path, hard, self.root, fifo, writable):
                with patch.object(check_app_sso.os, 'read') as read:
                    with self.assertRaises(check_app_sso.InputFileError):
                        check_app_sso.read_input_file(str(path))
                read.assert_not_called()

    def test_unowned_regular_file_is_rejected_using_descriptor_metadata(self):
        original = os.fstat

        def unowned(fd):
            info = original(fd)
            return SimpleNamespace(**{field: (os.getuid() + 100000 if field == 'st_uid' else getattr(info, field))
                                      for field in ('st_mode', 'st_nlink', 'st_uid', 'st_size')})

        with patch.object(check_app_sso.os, 'fstat', side_effect=unowned), \
                patch.object(check_app_sso.os, 'read') as read:
            with self.assertRaises(check_app_sso.InputFileError):
                check_app_sso.read_input_file(str(self.path))
        read.assert_not_called()

    def test_exact_byte_limit_succeeds_over_limit_rejected_before_read(self):
        data = self.path.read_bytes()
        self.path.write_bytes(data + b' ' * (app_sso.MAX_INPUT_BYTES - len(data)))
        self.assertEqual(cli(['--input', str(self.path)])[0], 0)
        self.path.write_bytes(b' ' * (app_sso.MAX_INPUT_BYTES + 1))
        with patch.object(check_app_sso.os, 'read') as read:
            with self.assertRaises(check_app_sso.InputFileError):
                check_app_sso.read_input_file(str(self.path))
        read.assert_not_called()

    def test_changed_file_metadata_is_unknown_input_not_retried(self):
        info = self.path.stat()
        fields = ('st_dev', 'st_ino', 'st_mode', 'st_uid', 'st_gid', 'st_nlink',
                  'st_size', 'st_mtime_ns', 'st_ctime_ns')
        changed = SimpleNamespace(**{key: getattr(info, key) + (key == 'st_mtime_ns') for key in fields})
        with patch.object(check_app_sso.os, 'fstat', side_effect=[info, changed]) as statted:
            code, report, _, err = cli(['--input', str(self.path)])
        self.assertEqual((code, err), (2, ''))
        self.assertIn('unsafe_input_file', labels(report))
        self.assertEqual(statted.call_count, 2)

    def test_read_failure_is_not_replayed_and_never_echoes_exception(self):
        with patch.object(check_app_sso.os, 'read', side_effect=OSError('synthetic-private-body')) as read:
            code, report, out, err = cli(['--input', str(self.path)])
        self.assertEqual((code, err), (2, ''))
        self.assertIn('input_file_unreadable', labels(report))
        self.assertNotIn('synthetic-private-body', out)
        self.assertEqual(read.call_count, 1)


if __name__ == '__main__':
    unittest.main()
