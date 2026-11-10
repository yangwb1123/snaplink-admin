import hashlib
import json
from pathlib import Path
import struct
import tempfile
import unittest
from unittest.mock import patch

from tools import web_font_assets as fonts


ROOT = Path(__file__).resolve().parents[2]


class WebFontAssetsTest(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.sdk = self.root / 'sdk'
        self.assets = self.root / 'assets'
        self.engine = self.sdk / 'bin/cache/flutter_web_sdk/lib/_engine/engine'
        (self.engine / 'canvaskit').mkdir(parents=True)
        (self.engine / 'font_fallback_data.dart').write_text(
            "NotoFont('Noto Sans SC 0', 'notosanssc/v1/a.woff2')")
        (self.engine / 'canvaskit/fonts.dart').write_text(
            "'${configuration.fontFallbackBaseUrl}roboto/v1/b.woff2'")
        self.manifest = {'schema': 1, 'upstream': fonts.UPSTREAM, 'files': {}}
        self.add_asset('notosanssc/v1/a.woff2', self.woff())
        self.add_asset('roboto/v1/b.woff2', self.woff())
        self.add_asset('licenses/notosanssc.txt', b'SIL OPEN FONT LICENSE Version 1.1')
        self.add_asset('licenses/roboto.txt', b'Apache License Version 2.0')
        self.save_manifest()

    @staticmethod
    def woff():
        return b'wOF2' + bytes(4) + struct.pack('>I', 48) + bytes(36)

    def add_asset(self, name, body):
        path = self.assets / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(body)
        self.manifest['files'][name] = {
            'bytes': len(body), 'sha256': hashlib.sha256(body).hexdigest(),
        }

    def save_manifest(self):
        (self.assets / 'manifest.json').write_text(json.dumps(self.manifest))

    def test_check_is_offline_and_covers_sdk_english_chinese_and_licenses(self):
        with patch.object(fonts.subprocess, 'run', side_effect=AssertionError('network not permitted')):
            self.assertEqual(fonts.check(self.assets, self.sdk), (2, 96))

    def test_missing_sdk_font_fails_instead_of_using_a_cdn(self):
        del self.manifest['files']['notosanssc/v1/a.woff2']
        self.save_manifest()
        with self.assertRaisesRegex(ValueError, 'SDK font asset missing'):
            fonts.check(self.assets, self.sdk)

    def test_changed_or_incomplete_font_fails(self):
        for body in (b'corrupted', self.woff() + b'\0'):
            with self.subTest(size=len(body)):
                self.add_asset('roboto/v1/b.woff2', body)
                self.save_manifest()
                with self.assertRaises(ValueError):
                    fonts.check(self.assets, self.sdk)

    def test_checksum_changes_and_untracked_fonts_fail(self):
        (self.assets / 'roboto/v1/b.woff2').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'integrity mismatch'):
            fonts.check(self.assets, self.sdk)
        self.add_asset('roboto/v1/b.woff2', self.woff())
        self.save_manifest()
        (self.assets / 'roboto/v1/extra.woff2').write_bytes(self.woff())
        with self.assertRaisesRegex(ValueError, 'untracked'):
            fonts.check(self.assets, self.sdk)

    def test_missing_license_fails(self):
        del self.manifest['files']['licenses/notosanssc.txt']
        self.save_manifest()
        with self.assertRaisesRegex(ValueError, 'license missing'):
            fonts.check(self.assets, self.sdk)

    def test_unsafe_paths_symlinks_and_duplicate_keys_fail(self):
        for name in ('../escape', '/absolute', 'roboto\\escape'):
            with self.subTest(name=name), self.assertRaises(ValueError):
                fonts.local_file(self.assets, name)
        target = self.assets / 'roboto/v1/b.woff2'
        target.unlink()
        target.symlink_to(self.assets / 'notosanssc/v1/a.woff2')
        with self.assertRaisesRegex(ValueError, 'symlinked'):
            fonts.check(self.assets, self.sdk)
        (self.assets / 'manifest.json').write_text('{"schema":1,"schema":2}')
        with self.assertRaisesRegex(ValueError, 'duplicate'):
            fonts.check(self.assets, self.sdk)

    def test_unknown_sdk_table_or_default_font_fails_closed(self):
        (self.engine / 'font_fallback_data.dart').write_text('unknown newer schema')
        with self.assertRaisesRegex(ValueError, 'unsupported Flutter fallback'):
            fonts.check(self.assets, self.sdk)

    def test_public_download_checks_tls_status_and_disables_proxy_and_redirects(self):
        result = type('Result', (), {'returncode': 0, 'stdout': b'200'})()
        with patch.object(fonts.subprocess, 'run', return_value=result) as run:
            fonts.download(fonts.UPSTREAM + 'roboto/v1/b.woff2', self.root / 'download')
        command = run.call_args.args[0]
        self.assertEqual(command[command.index('--noproxy') + 1], '*')
        self.assertEqual(command[command.index('--proto') + 1], '=https')
        self.assertNotIn('--location', command)
        self.assertNotIn('--insecure', command)
        self.assertNotIn('--retry', command)
        for status in (b'302', b'404'):
            result.stdout = status
            with patch.object(fonts.subprocess, 'run', return_value=result), self.assertRaises(ValueError):
                fonts.download(fonts.UPSTREAM + 'roboto/v1/b.woff2', self.root / 'download')

    def test_fetch_does_not_replace_verified_existing_assets_or_use_network(self):
        before = (self.assets / 'manifest.json').read_bytes()
        with patch.object(fonts, 'download', side_effect=AssertionError('no refresh')):
            fonts.fetch(self.assets, self.sdk)
        self.assertEqual((self.assets / 'manifest.json').read_bytes(), before)

    def test_fetch_refuses_unverified_nonempty_destination(self):
        (self.assets / 'manifest.json').unlink()
        with self.assertRaisesRegex(ValueError, 'nonempty destination'):
            fonts.fetch(self.assets, self.sdk)

    def test_bootstrap_has_same_origin_renderer_and_font_fallbacks(self):
        bootstrap = (ROOT / 'web/flutter_bootstrap.js').read_text()
        self.assertIn("canvasKitBaseUrl: 'canvaskit/'", bootstrap)
        self.assertIn("fontFallbackBaseUrl: 'font-fallback/'", bootstrap)
        self.assertNotIn('https://', bootstrap)

    def test_vendored_production_assets_cover_current_sdk(self):
        count, total = fonts.check(fonts.ASSETS, fonts.sdk_root())
        self.assertGreater(count, 2)
        self.assertGreater(total, 96)

    def test_docker_context_includes_font_verifier(self):
        patterns = (ROOT / '.dockerignore').read_text().splitlines()
        self.assertNotIn('tools/', patterns)
        self.assertIn('tools/*', patterns)
        self.assertIn('!tools/web_font_assets.py', patterns)

    def test_production_builds_check_assets_before_compiling(self):
        makefile = (ROOT / 'Makefile').read_text()
        target = makefile.split('build-prod:\n', 1)[1].split('\n\n', 1)[0]
        self.assertLess(target.index('python3 tools/web_font_assets.py'), target.index('flutter build web'))
        dockerfile = (ROOT / 'Dockerfile').read_text()
        self.assertLess(dockerfile.index('RUN python3 tools/web_font_assets.py'), dockerfile.index('RUN flutter build web'))


if __name__ == '__main__':
    unittest.main()
