#!/usr/bin/env python3
"""Credential-free, read-only checks against an explicitly selected OP gateway."""

import argparse
import http.client
import json
import ssl
import urllib.error
import urllib.parse
import urllib.request

if __package__:
    from .proxy_http import NoRedirect, valid_origin
else:
    from proxy_http import NoRedirect, valid_origin

MAX_RESPONSE_BYTES = 65536


def unique_object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValueError('Duplicate JSON field')
        result[key] = value
    return result


def fetch_json(opener, origin, path, timeout):
    # No bearer, cookies, credentials, continuation, PAR/JAR, redirects or retries.
    request = urllib.request.Request(
        origin.rstrip('/') + path,
        headers={'Accept': 'application/json', 'Cache-Control': 'no-cache'},
        method='GET',
    )
    try:
        with opener.open(request, timeout=timeout) as response:
            status = response.status
            if status != 200:
                return http_failure(status), None
            if response.headers.get_content_type() != 'application/json':
                return {'state': 'invalid_response', 'http_status': status}, None
            body = response.read(MAX_RESPONSE_BYTES + 1)
            if len(body) > MAX_RESPONSE_BYTES:
                return {'state': 'response_too_large', 'http_status': status}, None
            data = json.loads(body, object_pairs_hook=unique_object)
            if not isinstance(data, dict) or 'error' in data:
                return {'state': 'invalid_response', 'http_status': status}, None
            return {'state': 'ok', 'http_status': status}, data
    except urllib.error.HTTPError as error:
        with error:
            return http_failure(error.code), None
    except urllib.error.URLError as error:
        state = 'tls_error' if isinstance(error.reason, ssl.SSLError) else 'unreachable'
        return {'state': state}, None
    except ssl.SSLError:
        return {'state': 'tls_error'}, None
    except (OSError, TimeoutError):
        return {'state': 'unreachable'}, None
    except (ValueError, UnicodeError, http.client.HTTPException):
        return {'state': 'invalid_response'}, None


def http_failure(status):
    state = {401: 'unauthorized', 403: 'forbidden', 404: 'not_found'}.get(
        status, 'redirect_rejected' if 300 <= status < 400 else 'http_error'
    )
    return {'state': state, 'http_status': status}


def probe_status(opener, origin, path, expected, timeout):
    check, data = fetch_json(opener, origin, path, timeout)
    if data is not None and data.get('status') != expected:
        check['state'] = 'invalid_response'
    return check


def advertised(data, field, value):
    values = data.get(field)
    if not isinstance(values, list) or not all(isinstance(item, str) for item in values):
        return {'state': 'unknown'}
    return {'state': 'ok' if value in values else 'not_advertised'}


def issuer_url(value):
    try:
        url = urllib.parse.urlsplit(value)
        origin = urllib.parse.urlunsplit((url.scheme, url.netloc, '', '', ''))
        return (valid_origin(origin) and not url.query and not url.fragment
                and not any(char.isspace() for char in value))
    except ValueError:
        return False


def browser_capability(data):
    supported = data.get('op_session_supported')
    if supported is False:
        return {'state': 'disabled'}
    if supported is not True:
        # Older/feature-off builds omit this field; absence is not a diagnosis.
        return {'state': 'unknown'}
    if 'op_session_error' in data:
        return {'state': 'unavailable'}
    if type(data.get('op_session_available')) is not bool:
        return {'state': 'invalid_response'}
    # An anonymous probe has no identity cookie; false is normal, not disabled.
    return {'state': 'ok'}


def inspect_deployment(origin, issuer=None, client_id=None, *, timeout=5,
                       tls_context=None, health_only=False):
    # Do not inherit environment proxies, cookie jars or authorization handlers.
    opener = urllib.request.build_opener(
        urllib.request.ProxyHandler({}), NoRedirect(),
        urllib.request.HTTPSHandler(context=tls_context or ssl.create_default_context()),
    )
    checks = {'health': probe_status(opener, origin, '/health', 'ok', timeout)}
    if not health_only:
        checks['https'] = {'state': 'ok' if urllib.parse.urlsplit(origin).scheme == 'https' and
                          urllib.parse.urlsplit(issuer).scheme == 'https' else 'required'}
        checks['readiness'] = probe_status(opener, origin, '/readyz', 'ready', timeout)
        discovery, data = fetch_json(opener, origin, '/.well-known/openid-configuration', timeout)
        checks['discovery'] = discovery
        checks['issuer'] = {'state': 'unknown'}
        checks['code_response'] = {'state': 'unknown'}
        checks['code_grant'] = {'state': 'unknown'}
        checks['pkce_s256'] = {'state': 'unknown'}
        if data is not None:
            checks['issuer'] = {'state': 'ok' if data.get('issuer') == issuer else 'mismatch'}
            checks['code_response'] = advertised(data, 'response_types_supported', 'code')
            checks['code_grant'] = advertised(data, 'grant_types_supported', 'authorization_code')
            checks['pkce_s256'] = advertised(data, 'code_challenge_methods_supported', 'S256')
        # Published GET /auth/login with only client_id is provider discovery.
        # Never include provider, response_type, redirect, credential or opaque inputs.
        path = '/auth/login?' + urllib.parse.urlencode({'client_id': client_id})
        providers, data = fetch_json(opener, origin, path, timeout)
        checks['providers'] = providers
        checks['provider_issuer'] = {'state': 'unknown'}
        checks['browser_sso'] = {'state': 'unknown'}
        if data is not None:
            if not isinstance(data.get('providers'), list):
                checks['providers']['state'] = 'invalid_response'
            checks['provider_issuer'] = {'state': 'ok' if data.get('iss') == issuer else 'mismatch'}
            checks['browser_sso'] = browser_capability(data)
    return {
        'mode': 'health_only' if health_only else 'browser_sso_preflight',
        'checks': checks,
        'passed': all(check['state'] == 'ok' for check in checks.values()),
        'browser_acceptance': 'not_run',
        'shared_sessions_and_keys': 'not_verified',
        'per_client_authorization': 'not_verified',
    }


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--origin', required=True, help='Explicit API gateway HTTP(S) origin')
    parser.add_argument('--issuer', help='Exact expected published HTTPS issuer')
    parser.add_argument('--client-id', help='Explicit RP client for anonymous provider discovery')
    parser.add_argument('--ca-file', help='Trusted CA PEM; TLS verification is never disabled')
    parser.add_argument('--timeout', type=int, default=5, help='Socket timeout, 1–30 seconds')
    parser.add_argument('--health-only', action='store_true', help='Only GET /health (development startup)')
    args = parser.parse_args(argv)
    if not valid_origin(args.origin):
        parser.error('--origin must be an HTTP(S) origin without credentials, path, query or fragment')
    if not 1 <= args.timeout <= 30:
        parser.error('--timeout must be between 1 and 30 seconds')
    if not args.health_only:
        if not args.issuer or not issuer_url(args.issuer):
            parser.error('--issuer must be an explicit absolute issuer URL without credentials, query or fragment')
        if not args.client_id or len(args.client_id) > 512 or any(ord(c) < 32 for c in args.client_id):
            parser.error('--client-id must be an explicit nonempty RP client identifier')
    try:
        context = ssl.create_default_context(cafile=args.ca_file)
    except (OSError, ssl.SSLError):
        parser.error('Could not load the trusted CA file')
    report = inspect_deployment(args.origin, args.issuer, args.client_id,
                                timeout=args.timeout, tls_context=context,
                                health_only=args.health_only)
    # Fixed states/status only. No bodies, URLs, identifiers, keys or credentials.
    print(json.dumps(report, sort_keys=True))
    return 0 if report['passed'] else 1


if __name__ == '__main__':
    raise SystemExit(main())
