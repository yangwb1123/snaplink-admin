"""Offline format/integrity contracts; not font rendering or authentication proof."""

import hashlib
import importlib.util
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location(
    'browser_sso_fonts_contract', Path(__file__).parents[2] / 'tools/web_font_assets.py')
fonts = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(fonts)


class DefaultRobotoContractTest(unittest.TestCase):
    def setUp(self):
        directory = tempfile.TemporaryDirectory(prefix='owned-font-contract-')
        self.addCleanup(directory.cleanup)
        self.web, self.sdk = Path(directory.name) / 'web', Path(directory.name) / 'sdk'
        self.manifest = self.web / 'assets/FontManifest.json'
        self.bundled = self.web / ('assets/' + fonts.BUNDLED_ASSET)
        self.canonical = self.sdk / 'engine/src/flutter/txt/third_party/fonts/Roboto-Regular.ttf'
        self.ttf = b'\x00\x01\x00\x00' + b'\x00' * 28
        self.write(self.canonical, self.ttf)
        self.write(self.bundled, self.ttf)
        self.json(self.manifest, [{'family': 'Roboto', 'fonts': [{'asset': fonts.BUNDLED_ASSET}]}])

    def write(self, path, data):
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)

    def json(self, path, value):
        self.write(path, json.dumps(value).encode())

    def woff_fixture(self):
        self.json(self.manifest, [])
        asset = 'roboto/v32/fixture.woff2'
        source = self.sdk / 'bin/cache/flutter_web_sdk/lib/_engine/engine/canvaskit/fonts.dart'
        self.write(source, ("String url = '" + asset + "';").encode())
        data = bytearray(52)
        data[:4] = b'wOF2'
        struct.pack_into('>I', data, 8, len(data))
        data = bytes(data)
        path = self.web / ('font-fallback/' + asset)
        self.write(path, data)
        record = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        self.json(self.web / 'font-fallback/manifest.json', {'files': {asset: record}})
        return path, data

    def test_bundled_ttf_matches_canonical_sdk_and_received_payload(self):
        suffix, digest, magic = fonts.default_roboto(self.web, self.sdk)
        self.assertEqual(suffix, '/assets/' + fonts.BUNDLED_ASSET)
        self.assertEqual(magic, b'\x00\x01\x00\x00')
        self.assertTrue(fonts.matches_roboto(self.ttf, digest, magic))

    def test_built_ttf_different_from_sdk_is_rejected(self):
        self.write(self.bundled, self.ttf + b'changed')
        with self.assertRaisesRegex(ValueError, 'differs'):
            fonts.default_roboto(self.web, self.sdk)

    def test_invalid_canonical_ttf_is_rejected(self):
        self.write(self.canonical, b'not-a-font')
        self.write(self.bundled, b'not-a-font')
        with self.assertRaisesRegex(ValueError, 'Invalid SDK'):
            fonts.default_roboto(self.web, self.sdk)

    def test_unknown_custom_or_traversing_roboto_never_falls_back(self):
        for asset in ('fonts/custom.ttf', '../outside.ttf', 'https://outside.invalid/font.ttf'):
            with self.subTest(asset=asset):
                self.json(self.manifest, [{'family': 'Roboto', 'fonts': [{'asset': asset}]}])
                with self.assertRaisesRegex(ValueError, 'Unsupported built'):
                    fonts.default_roboto(self.web, self.sdk)

    def test_duplicate_roboto_families_are_rejected(self):
        row = {'family': 'Roboto', 'fonts': [{'asset': fonts.BUNDLED_ASSET}]}
        self.json(self.manifest, [row, row])
        with self.assertRaisesRegex(ValueError, 'Unsupported built'):
            fonts.default_roboto(self.web, self.sdk)

    def test_missing_declared_ttf_is_not_replaced_with_another_font(self):
        self.bundled.unlink()
        with self.assertRaisesRegex(ValueError, 'Missing'):
            fonts.default_roboto(self.web, self.sdk)

    def test_vendored_woff2_uses_exact_sdk_url_and_integrity_record(self):
        _, data = self.woff_fixture()
        suffix, digest, magic = fonts.default_roboto(self.web, self.sdk)
        self.assertEqual(suffix, '/font-fallback/roboto/v32/fixture.woff2')
        self.assertEqual(magic, b'wOF2')
        self.assertTrue(fonts.matches_roboto(data, digest, magic))

    def test_wrong_woff2_hash_is_rejected(self):
        path, data = self.woff_fixture()
        self.write(path, data[:-1] + b'X')
        with self.assertRaisesRegex(ValueError, 'integrity mismatch'):
            fonts.default_roboto(self.web, self.sdk)

    def test_woff2_integrity_record_cannot_authorize_invalid_framing(self):
        path, data = self.woff_fixture()
        data = b'bad!' + data[4:]
        self.write(path, data)
        self.json(self.web / 'font-fallback/manifest.json', {'files': {
            'roboto/v32/fixture.woff2': {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}}})
        with self.assertRaisesRegex(ValueError, 'WOFF2'):
            fonts.default_roboto(self.web, self.sdk)

    def test_received_payload_must_match_hash_and_format(self):
        _, digest, magic = fonts.default_roboto(self.web, self.sdk)
        self.assertFalse(fonts.matches_roboto(self.ttf + b'changed', digest, magic))
        self.assertFalse(fonts.matches_roboto(self.ttf, digest, b'wOF2'))

    def test_symlinked_built_payload_is_rejected(self):
        self.bundled.unlink()
        self.bundled.symlink_to(self.canonical)
        with self.assertRaisesRegex(ValueError, 'symlinked'):
            fonts.default_roboto(self.web, self.sdk)

    def test_oversized_input_is_rejected_before_parsing(self):
        self.write(self.canonical, self.ttf + b'X' * 300)
        with patch.object(fonts, 'MAX_FONT_BYTES', 256):
            with self.assertRaisesRegex(ValueError, 'budget'):
                fonts.default_roboto(self.web, self.sdk)

    def test_invalid_manifest_shape_is_rejected(self):
        self.json(self.manifest, {'family': 'Roboto'})
        with self.assertRaisesRegex(ValueError, 'manifest'):
            fonts.default_roboto(self.web, self.sdk)

    def test_duplicate_json_keys_are_rejected(self):
        self.write(self.manifest, b'[{"family":"Other","family":"Roboto","fonts":[]}]')
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            fonts.default_roboto(self.web, self.sdk)


if __name__ == '__main__':
    unittest.main()
