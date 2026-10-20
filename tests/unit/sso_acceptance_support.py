"""Synthetic inputs only; never imports fixture or deployment credentials."""

import json
from pathlib import Path


def plan():
    origin = 'https://op.example.invalid'
    return {
        'version': 1,
        'op': {'origin': origin, 'issuer': origin, 'login_url': origin + '/login/',
               'discovery_url': origin + '/.well-known/openid-configuration',
               'authorization_endpoint': origin + '/auth/login',
               'token_endpoint': origin + '/token', 'jwks_uri': origin + '/.well-known/jwks.json',
               'userinfo_endpoint': origin + '/userinfo', 'signing_algorithm': 'EdDSA'},
        'rps': [
            {'client_id': name, 'display_name': 'Owned ' + name, 'tenant_id': '',
             'redirect_uri': f'http://127.0.0.{i + 2}:{42000 + i}/callback',
             'scopes': ['openid', name + ':read'], 'resources': [name + '-api'],
             'consent': 'required', 'token_endpoint_auth_method': 'none',
             'pkce': 'S256', 'response_mode': 'query', 'provider': 'password'}
            for i, name in enumerate(('rp-a', 'rp-b'))],
        'credential_file': '/operator/credentials.json',
        'registration_confirmed': True, 'policy_confirmed': True,
        'locale': 'en-US', 'limits': {'total_seconds': 60, 'request_seconds': 3, 'body_bytes': 65536},
        'expected_auth': {'amr': ['password'], 'acr': ''},
    }


def write_json(path, value, mode=0o600):
    Path(path).write_text(json.dumps(value), encoding='utf-8')
    Path(path).chmod(mode)
    return str(path)
