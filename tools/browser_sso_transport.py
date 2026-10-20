"""Direct verified HTTPS, exact endpoint allowlist, bounded bodies and elapsed time.

No urllib proxy/redirect/auth/cookie handlers and no retries (including writes).
"""

import http.client
import os
import queue
import socket
import ssl
import threading
import time
from urllib.parse import urlencode, urlsplit

from tools.browser_sso_plan import Failure, OP_PATHS, read_file, require, strict_json


def tls_context(ca_file=None):
    context = ssl.SSLContext(ssl.PROTOCOL_TLS_CLIENT)
    context.minimum_version = ssl.TLSVersion.TLSv1_2
    try:
        if ca_file:
            context.load_verify_locations(cadata=read_file(ca_file, 262144, trusted=True).decode('ascii'))
        else:
            # Use platform defaults, not SSL_CERT_FILE/SSL_CERT_DIR environment overrides.
            paths = ssl.get_default_verify_paths()
            context.load_verify_locations(
                cafile=paths.openssl_cafile if os.path.isfile(paths.openssl_cafile) else None,
                capath=paths.openssl_capath if os.path.isdir(paths.openssl_capath) else None)
    except (OSError, ValueError, UnicodeError):
        raise Failure('tls_error') from None
    return context


def remaining(end):
    seconds = end - time.monotonic()
    require(seconds > 0, 'deadline_exceeded')
    return seconds


def resolve(host, port, end):
    # A stuck resolver cannot hold up the caller or later send an OAuth request.
    result = queue.Queue(maxsize=1)
    def lookup():
        try:
            result.put(socket.getaddrinfo(host, port, type=socket.SOCK_STREAM))
        except Exception:
            result.put(None)
    threading.Thread(target=lookup, daemon=True).start()
    try:
        addresses = result.get(timeout=remaining(end))
    except queue.Empty:
        raise Failure('deadline_exceeded') from None
    require(bool(addresses), 'transport_error')
    return addresses[0]


class Transport:
    def __init__(self, op, limits, end, *, context=None):
        self.op, self.limits, self.end = op, limits, end
        self.context = context or tls_context()
        require(self.context.check_hostname and self.context.verify_mode == ssl.CERT_REQUIRED, 'tls_error')

    def request(self, endpoint, *, client_id=None, form=None, token=None):
        require(self.context.check_hostname and self.context.verify_mode == ssl.CERT_REQUIRED, 'tls_error')
        require(endpoint in ('discovery_url', 'authorization_endpoint', 'jwks_uri',
                             'token_endpoint', 'userinfo_endpoint'), 'endpoint_mismatch')
        require((form is not None) == (endpoint == 'token_endpoint'), 'endpoint_mismatch')
        require((token is not None) == (endpoint == 'userinfo_endpoint'), 'endpoint_mismatch')
        require((client_id is not None) == (endpoint == 'authorization_endpoint'), 'endpoint_mismatch')
        target = urlsplit(self.op[endpoint])
        origin = urlsplit(self.op['origin'])
        require(self.op[endpoint] == self.op['origin'] + OP_PATHS[endpoint] and
                target.scheme == 'https' and target.netloc == origin.netloc and
                not target.query and not target.fragment and not target.username, 'endpoint_mismatch')
        end = min(self.end, time.monotonic() + self.limits['request_seconds'])
        method = 'POST' if form is not None else 'GET'
        body = urlencode(form).encode('ascii') if form is not None else None
        headers = {'Accept': 'application/json', 'Accept-Encoding': 'identity', 'Cache-Control': 'no-store'}
        if body is not None:
            require(len(body) <= 8192, 'body_too_large')
            headers['Content-Type'] = 'application/x-www-form-urlencoded'
        if token is not None:
            require(isinstance(token, str) and len(token) <= 16384 and
                    all(32 < ord(c) < 127 for c in token), 'invalid_token')
            headers['Authorization'] = 'Bearer ' + token
        path = target.path + ('?' + urlencode({'client_id': client_id}) if client_id is not None else '')
        connection, sock, timer = None, None, None
        sent = False
        try:
            family, kind, proto, _, address = resolve(target.hostname, target.port or 443, end)
            sock = socket.socket(family, kind, proto)
            sock.settimeout(remaining(end))
            sock.connect(address)
            sock.settimeout(remaining(end))
            sock = self.context.wrap_socket(sock, server_hostname=target.hostname)
            sock.settimeout(remaining(end))
            # Socket timeouts alone allow slow-drip headers/body forever. Interrupt
            # the *same* live socket at the absolute deadline, including read().
            def interrupt():
                try:
                    sock.shutdown(socket.SHUT_RDWR)
                except OSError:
                    pass
            timer = threading.Timer(remaining(end), interrupt)
            timer.daemon = True
            timer.start()
            connection = http.client.HTTPConnection(target.hostname, target.port or 443)
            connection.sock = sock  # Already verified TLS; HTTPConnection never connects itself.
            remaining(end)
            sent = True
            connection.request(method, path, body=body, headers=headers)
            response = connection.getresponse()
            remaining(end)
            status = response.status
            if status != 200:
                raise Failure('redirect_rejected' if 300 <= status < 400 else 'http_error', http_status=status)
            require(len(response.headers.get_all('Content-Type', [])) == 1 and
                    len(response.headers.get_all('Content-Encoding', [])) <= 1 and
                    len(response.headers.get_all('Transfer-Encoding', [])) <= 1 and
                    response.headers.get_content_type() == 'application/json' and
                    response.headers.get('Content-Encoding', 'identity') == 'identity', 'invalid_response')
            lengths = response.headers.get_all('Content-Length', [])
            require(len(lengths) <= 1 and (not lengths or lengths[0].isdigit()), 'invalid_response')
            limit = self.limits['body_bytes']
            require(not lengths or int(lengths[0]) <= limit, 'body_too_large')
            require(not (lengths and response.headers.get('Transfer-Encoding')), 'invalid_response')
            data = response.read(limit + 1)
            remaining(end)
            require(len(data) <= limit, 'body_too_large')
            return strict_json(data, limit)
        except Failure as error:
            if sent and method == 'POST' and error.state == 'deadline_exceeded':
                raise Failure('unknown_result') from None
            raise
        except ssl.SSLError:
            raise Failure('unknown_result' if sent and method == 'POST' else 'tls_error') from None
        except (OSError, TimeoutError, http.client.HTTPException, ValueError):
            raise Failure('unknown_result' if sent and method == 'POST' else 'transport_error') from None
        finally:
            if timer:
                timer.cancel()
            if connection:
                connection.close()
            if sock:
                sock.close()


def preflight(plan, transport):
    op = plan['op']
    discovery = transport.request('discovery_url')
    require(discovery.get('issuer') == op['issuer'] and all(
        discovery.get(key) == op[key] for key in ('authorization_endpoint', 'token_endpoint',
                                                  'jwks_uri', 'userinfo_endpoint')), 'endpoint_mismatch')
    for key, value in [('response_types_supported', 'code'), ('grant_types_supported', 'authorization_code'),
                       ('code_challenge_methods_supported', 'S256'), ('token_endpoint_auth_methods_supported', 'none'),
                       ('id_token_signing_alg_values_supported', op['signing_algorithm'])]:
        values = discovery.get(key)
        require(isinstance(values, list) and value in values, 'capability_unverified')
    for rp in plan['rps']:
        provider = transport.request('authorization_endpoint', client_id=rp['client_id'])
        require(provider.get('iss') == op['issuer'] and provider.get('op_session_supported') is True and
                provider.get('op_session_available') is False and 'op_session_error' not in provider and
                isinstance(provider.get('providers'), list) and 'password' in provider['providers'],
                'capability_unverified')
