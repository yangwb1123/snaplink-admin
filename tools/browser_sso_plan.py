"""Strict offline plan and explicit file boundaries for browser SSO acceptance."""

import ipaddress
import json
import os
from pathlib import PurePosixPath
import re
import stat
from urllib.parse import urlsplit


class Failure(Exception):
    """Only fixed tool-owned states may cross the reporting boundary."""
    def __init__(self, state, *, missing=(), http_status=None):
        super().__init__('SSO acceptance stopped')
        self.state, self.missing, self.http_status = state, list(missing), http_status


def require(condition, state='invalid_plan'):
    if not condition:
        raise Failure(state)


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        require(key not in result, 'invalid_json')
        result[key] = value
    return result


def strict_json(raw, limit):
    try:
        require(len(raw) <= limit, 'body_too_large')
        value = json.loads(raw.decode('utf-8') if isinstance(raw, bytes) else raw, object_pairs_hook=unique_object,
                           parse_constant=lambda _: (_ for _ in ()).throw(Failure('invalid_json')))
        require(isinstance(value, dict), 'invalid_json')
        return value
    except (ValueError, UnicodeError, RecursionError):
        raise Failure('invalid_json') from None


def text(value, limit=512, *, empty=False):
    return (isinstance(value, str) and (empty or bool(value)) and len(value) <= limit and
            all(ord(c) >= 32 and ord(c) != 127 for c in value))


def reference(value):
    require(text(value, 4096) and value.startswith('/') and
            all(part not in ('.', '..', '') for part in value.split('/')[1:]))
    return value


def read_file(path, limit, *, private=False, trusted=False):
    """No symlink components, FIFO blocking, hardlinked secrets or unsafe owner/mode."""
    reference(path)
    descriptors = []
    try:
        directory = os.open('/', os.O_RDONLY | os.O_DIRECTORY | os.O_CLOEXEC)
        descriptors.append(directory)
        parts = PurePosixPath(path).parts[1:]
        for part in parts[:-1]:
            directory = os.open(part, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW | os.O_CLOEXEC,
                                dir_fd=directory)
            descriptors.append(directory)
        fd = os.open(parts[-1], os.O_RDONLY | os.O_NOFOLLOW | os.O_NONBLOCK | os.O_CLOEXEC,
                     dir_fd=directory)
        descriptors.append(fd)
        info = os.fstat(fd)
        require(stat.S_ISREG(info.st_mode) and info.st_size <= limit, 'unsafe_input_file')
        if trusted:
            require(info.st_uid in (0, os.getuid()) and not (info.st_mode & 0o022), 'unsafe_input_file')
        if private:
            require(info.st_uid == os.getuid() and info.st_nlink == 1 and
                    stat.S_IMODE(info.st_mode) in (0o400, 0o600), 'unsafe_credential_file')
        body = bytearray()
        while len(body) <= limit:
            chunk = os.read(fd, min(4096, limit + 1 - len(body)))
            if not chunk:
                break
            body.extend(chunk)
        require(len(body) <= limit, 'body_too_large')
        return bytes(body)
    except OSError:
        raise Failure('input_file_unavailable') from None
    finally:
        for fd in reversed(descriptors):
            os.close(fd)


def load_credentials(path):
    value = strict_json(read_file(path, 8192, private=True), 8192)
    require(set(value) == {'username', 'password', 'expected_subject'}, 'invalid_credentials_file')
    require(all(text(v, 4096 if k == 'password' else 512) for k, v in value.items()),
            'invalid_credentials_file')
    return value


def https_origin(value):
    try:
        require(text(value, 1024) and re.fullmatch(r'https://[a-z0-9.:-]+', value))
        url = urlsplit(value)
        require(url.hostname and not url.username and not url.password and not url.path and
                not url.query and not url.fragment and '\\' not in value)
        require(url.port is None or (1 <= url.port <= 65535 and url.port != 443))
        require(url.netloc == url.hostname + (f':{url.port}' if url.port else ''))
        require(all(part and not part.startswith('-') and not part.endswith('-')
                    for part in url.hostname.split('.')))
        return url
    except ValueError:
        raise Failure('invalid_plan') from None


def callback(value):
    try:
        require(text(value, 1024))
        url = urlsplit(value)
        require(url.scheme == 'http' and url.port is not None and 1024 <= url.port <= 65535 and
                url.path == '/callback' and not url.query and not url.fragment and
                url.netloc == f'{url.hostname}:{url.port}' and
                ipaddress.IPv4Address(url.hostname).is_loopback)
        require(value == f'http://{url.netloc}/callback')
        return url
    except (ValueError, TypeError):
        raise Failure('invalid_plan') from None


def fields(value, allowed, required, prefix, missing):
    require(isinstance(value, dict) and set(value) <= set(allowed))
    missing.extend(prefix + key for key in required if key not in value)


def string_list(value, count, *, scopes=False):
    require(isinstance(value, list) and 1 <= len(value) <= count and
            all(text(v) and not any(c.isspace() for c in v) for v in value) and
            len(set(value)) == len(value))
    if scopes:
        require('openid' in value and len(value) >= 2)


OP_PATHS = {'login_url': '/login/', 'discovery_url': '/.well-known/openid-configuration',
            'authorization_endpoint': '/auth/login', 'token_endpoint': '/token',
            'jwks_uri': '/.well-known/jwks.json', 'userinfo_endpoint': '/userinfo'}
RP_FIELDS = ('client_id', 'display_name', 'tenant_id', 'redirect_uri', 'scopes', 'resources', 'consent',
             'token_endpoint_auth_method', 'pkce', 'response_mode', 'provider')
TOP_FIELDS = ('version', 'op', 'rps', 'credential_file', 'registration_confirmed',
              'policy_confirmed', 'locale', 'limits', 'expected_auth')


def validate_plan(data):
    missing = []
    fields(data, (*TOP_FIELDS, 'ca_file'), TOP_FIELDS, '', missing)
    op_fields = ('origin', 'issuer', *OP_PATHS, 'signing_algorithm')
    if 'op' in data:
        fields(data['op'], op_fields, op_fields, 'op.', missing)
    if 'rps' in data:
        require(isinstance(data['rps'], list) and len(data['rps']) == 2)
        for i, rp in enumerate(data['rps']):
            fields(rp, RP_FIELDS, RP_FIELDS, f'rps.{i}.', missing)
    if 'limits' in data:
        keys = ('total_seconds', 'request_seconds', 'body_bytes')
        fields(data['limits'], keys, keys, 'limits.', missing)
    if 'expected_auth' in data:
        fields(data['expected_auth'], ('amr', 'acr'), ('amr', 'acr'), 'expected_auth.', missing)
    if missing:
        raise Failure('missing_inputs', missing=sorted(missing))
    require(type(data['version']) is int and data['version'] == 1)
    require(data['registration_confirmed'] is True and data['policy_confirmed'] is True)
    require(data['locale'] in ('en-US', 'zh-CN'), 'unsupported_by_tool')
    reference(data['credential_file'])
    if 'ca_file' in data:
        reference(data['ca_file'])
    op = data['op']
    origin = https_origin(op['origin'])
    # The first slice supports stock gateway paths only, not arbitrary URL/query passthrough.
    require(op['issuer'] == op['origin'])
    require(all(op[key] == op['origin'] + path for key, path in OP_PATHS.items()))
    require(op['signing_algorithm'] == 'EdDSA', 'unsupported_by_tool')
    hosts, clients, resources, scopes = {origin.hostname}, set(), set(), set()
    for rp in data['rps']:
        require(text(rp['client_id']) and text(rp['display_name']) and text(rp['tenant_id'], empty=True))
        require(rp['client_id'] not in clients)
        clients.add(rp['client_id'])
        target = callback(rp['redirect_uri'])
        require(target.hostname not in hosts)
        hosts.add(target.hostname)
        string_list(rp['scopes'], 16, scopes=True)
        string_list(rp['resources'], 4)
        require(not (resources & set(rp['resources'])) and
                not (scopes & (set(rp['scopes']) - {'openid'})))
        resources.update(rp['resources'])
        scopes.update(set(rp['scopes']) - {'openid'})
        require(rp['consent'] in ('required', 'not_required'), 'unsupported_by_tool')
        for key, expected in [('token_endpoint_auth_method', 'none'), ('pkce', 'S256'),
                              ('response_mode', 'query'), ('provider', 'password')]:
            require(rp[key] == expected, 'unsupported_by_tool')
    limits = data['limits']
    for key, low, high in [('total_seconds', 15, 300), ('request_seconds', 1, 30),
                           ('body_bytes', 1024, 65536)]:
        require(type(limits[key]) is int and low <= limits[key] <= high)
    require(limits['request_seconds'] <= limits['total_seconds'])
    string_list(data['expected_auth']['amr'], 8)
    require(text(data['expected_auth']['acr'], empty=True))
    return data


def load_plan(path):
    return validate_plan(strict_json(read_file(path, 32768, trusted=True), 32768))
