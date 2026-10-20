#!/usr/bin/env python3
"""Check vendored Flutter web fallback fonts offline; fetch only when requested."""

import argparse
from concurrent.futures import ThreadPoolExecutor
import hashlib
import json
from pathlib import Path, PurePosixPath
import re
import shutil
import struct
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / 'web/font-fallback'
UPSTREAM = 'https://fonts.gstatic.com/s/'
FONT_PATH = re.compile(r'[a-z0-9]+/v[0-9]+/[A-Za-z0-9_.-]+\.woff2\Z')
MAX_FONT_BYTES = 16 * 1024 * 1024


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('duplicate manifest key')
        result[key] = value
    return result


def sdk_root():
    executable = shutil.which('flutter')
    if not executable:
        raise ValueError('Flutter SDK unavailable')
    return Path(executable).resolve().parents[1]


def sdk_fonts(sdk):
    engine = sdk / 'bin/cache/flutter_web_sdk/lib/_engine/engine'
    data = (engine / 'font_fallback_data.dart').read_text()
    pairs = re.findall(r"NotoFont\(\s*'([^']+)',\s*'([^']+)'", data)
    if not pairs or not any(name.startswith('Noto Sans SC ') for name, _ in pairs):
        raise ValueError('unsupported Flutter fallback font table')
    paths = {url for _, url in pairs}
    roboto = (engine / 'canvaskit/fonts.dart').read_text()
    defaults = re.findall(r'roboto/v[0-9]+/[A-Za-z0-9_.-]+\.woff2', roboto)
    if len(set(defaults)) != 1:
        raise ValueError('unsupported Flutter default font URL')
    paths.update(defaults)
    if not all(FONT_PATH.fullmatch(path) for path in paths):
        raise ValueError('unexpected Flutter font path')
    return paths, hashlib.sha256(data.encode()).hexdigest()


def font_bytes(data):
    if not 48 <= len(data) <= MAX_FONT_BYTES or data[:4] != b'wOF2':
        raise ValueError('invalid WOFF2 asset')
    if struct.unpack('>I', data[8:12])[0] != len(data):
        raise ValueError('incomplete WOFF2 asset')


def local_file(base, name):
    path = PurePosixPath(name)
    if path.is_absolute() or '..' in path.parts or '\\' in name:
        raise ValueError('unsafe font asset path')
    target = base / name
    if base.is_symlink() or any(p.is_symlink() for p in (target, *target.parents) if p == base or base in p.parents):
        raise ValueError('symlinked font asset')
    return target


def check(assets, sdk):
    manifest = json.loads((assets / 'manifest.json').read_text(), object_pairs_hook=unique_object)
    if manifest.get('schema') != 1 or manifest.get('upstream') != UPSTREAM:
        raise ValueError('unsupported font manifest')
    files = manifest['files']
    if not isinstance(files, dict) or not files:
        raise ValueError('invalid font manifest entries')
    required, _ = sdk_fonts(sdk)
    if not required <= files.keys():
        raise ValueError('SDK font asset missing; explicitly refresh the vendored set')
    fonts = {name for name in files if FONT_PATH.fullmatch(name)}
    if not fonts or {p.relative_to(assets).as_posix() for p in assets.rglob('*.woff2')} != fonts:
        raise ValueError('untracked or missing font asset')
    families = {name.split('/')[0] for name in fonts}
    for name, record in files.items():
        is_font = bool(FONT_PATH.fullmatch(name))
        if not is_font and not re.fullmatch(r'licenses/[a-z0-9]+\.txt', name):
            raise ValueError('unexpected font manifest entry')
        if not isinstance(record, dict) or type(record.get('bytes')) is not int or not re.fullmatch(r'[a-f0-9]{64}', record.get('sha256', '')):
            raise ValueError('invalid font integrity record')
        data = local_file(assets, name).read_bytes()
        if len(data) != record['bytes'] or hashlib.sha256(data).hexdigest() != record['sha256']:
            raise ValueError('font asset integrity mismatch')
        if is_font:
            font_bytes(data)
        elif b'SIL OPEN FONT LICENSE' not in data and b'Apache License' not in data:
            raise ValueError('font license missing')
    if not {'licenses/' + family + '.txt' for family in families} <= files.keys():
        raise ValueError('font family license missing')
    return len(fonts), sum(files[name]['bytes'] for name in fonts)


def download(url, target):
    target.parent.mkdir(parents=True, exist_ok=True)
    # Public static assets only. No proxy, redirects, cookies, auth or insecure TLS.
    result = subprocess.run([
        'curl', '-4', '--noproxy', '*', '--fail', '--silent', '--show-error',
        '--proto', '=https', '--connect-timeout', '10', '--max-time', '40',
        '--max-filesize', str(MAX_FONT_BYTES), '--write-out', '%{http_code}',
        '--output', str(target), url,
    ], capture_output=True, timeout=45)
    if result.returncode or result.stdout != b'200':
        raise ValueError('public font asset download failed')


def fetch(assets, sdk):
    paths, digest = sdk_fonts(sdk)
    if (assets / 'manifest.json').exists():
        check(assets, sdk)
        return  # Existing pinned generations are never silently replaced.
    if assets.exists() and any(assets.iterdir()):
        raise ValueError('nonempty destination without a verified manifest')
    with tempfile.TemporaryDirectory(prefix='snaplink-web-fonts-') as directory:
        stage = Path(directory)
        families = {name.split('/')[0] for name in paths}
        jobs = [(UPSTREAM + name, name) for name in sorted(paths)]
        if not all(family == 'roboto' or family.startswith('noto') for family in families):
            raise ValueError('unrecognized font license source')
        for family in sorted(families - {'roboto'}):
            jobs.append(('https://raw.githubusercontent.com/google/fonts/main/ofl/' + family + '/OFL.txt', 'licenses/' + family + '.txt'))
        with ThreadPoolExecutor(max_workers=8) as executor:
            list(executor.map(lambda job: download(job[0], stage / job[1]), jobs))
        license_file = sdk / 'bin/cache/artifacts/material_fonts/Roboto_LICENSE.txt'
        (stage / 'licenses').mkdir(exist_ok=True)
        shutil.copyfile(license_file, stage / 'licenses/roboto.txt')
        records = {}
        for path in sorted(stage.rglob('*')):
            if path.is_file():
                data = path.read_bytes()
                records[path.relative_to(stage).as_posix()] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
        manifest = {'schema': 1, 'upstream': UPSTREAM, 'sdk_font_table_sha256': digest, 'files': records}
        (stage / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
        check(stage, sdk)
        assets.parent.mkdir(parents=True, exist_ok=True)
        shutil.copytree(stage, assets, dirs_exist_ok=True)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--sdk-root', type=Path)
    parser.add_argument('--fetch', action='store_true', help='Explicit initial public-asset download; never used by builds')
    args = parser.parse_args()
    try:
        sdk = args.sdk_root or sdk_root()
        if args.fetch:
            fetch(ASSETS, sdk)
        count, size = check(ASSETS, sdk)
    except (OSError, ValueError, KeyError, TypeError, subprocess.SubprocessError):
        print('Web font assets: FAILED (missing/invalid assets, SDK mismatch or public download failure); no CDN fallback permitted.')
        return 1
    print(f'Web font assets: OK ({count} pinned WOFF2 files, {size} bytes; offline verification)')
    return 0


if __name__ == '__main__':
    raise SystemExit(main())
