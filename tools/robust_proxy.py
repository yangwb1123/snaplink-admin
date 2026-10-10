import gzip
import json
import os
from pathlib import Path
import socket
import sys
import threading
import time
import urllib.error
import urllib.parse
import urllib.request

if __package__:
    from .proxy_http import (InvalidRequest, parse_request, hop_headers,
                             forward_response as _forward_response,
                             forward_stream_response, upstream_opener, valid_origin)
else:
    from proxy_http import (InvalidRequest, parse_request, hop_headers,
                            forward_response as _forward_response,
                            forward_stream_response, upstream_opener, valid_origin)

UPSTREAM_OPENER = upstream_opener()

PORT = int(os.environ.get('PORT', os.environ.get('SNAPLINK_PROXY_PORT', '4444')))
BACKEND = os.environ.get(
    'BACKEND',
    os.environ.get('SNAPLINK_API_URL',
                   os.environ.get('SNAPLINK_UPSTREAM', 'http://localhost:8080')),
).rstrip('/')
# Independent services must be configured explicitly, never sent to core SSO.
BILLING_BACKEND = os.environ.get('SNAPLINK_BILLING_UPSTREAM', '').rstrip('/')
STRIPE_ADAPTER_BACKEND = os.environ.get(
    'SNAPLINK_STRIPE_ADAPTER_UPSTREAM',
    os.environ.get('SNAPLINK_STRIPE_ADAPTER_URL', ''),
).rstrip('/')
FORGE_BACKEND = os.environ.get('FORGE_CONVERSATIONS_UPSTREAM', '').rstrip('/')
AUDIT_GOVERNANCE_BACKEND = os.environ.get(
    'AUDIT_GOVERNANCE_UPSTREAM', ''
).rstrip('/')
AGENT_HUB_BACKEND = os.environ.get('AGENT_HUB_UPSTREAM', '').rstrip('/')
PROJECT_ROOT = Path(__file__).resolve().parent.parent
STATIC = Path(
    os.environ.get('STATIC_DIR', PROJECT_ROOT / 'build' / 'web')
).expanduser().resolve()

API_PREFIXES = (
    '/auth/', '/api/', '/.well-known/', '/roles/', '/permissions/', '/menus/',
    '/sessions/', '/consents/',
)
API_ROOTS = ('/me', '/health', '/readyz', '/token', '/branding', '/logout', '/userinfo',
             '/end_session', '/check_session_iframe')

CONTENT_TYPES = {
    '.html': 'text/html; charset=utf-8',
    '.js': 'application/javascript; charset=utf-8',
    '.css': 'text/css; charset=utf-8',
    '.png': 'image/png',
    '.jpg': 'image/jpeg',
    '.jpeg': 'image/jpeg',
    '.svg': 'image/svg+xml',
    '.json': 'application/json',
    '.wasm': 'application/wasm',
    '.ico': 'image/x-icon',
    '.map': 'application/json',
    '.txt': 'text/plain; charset=utf-8',
}

# Textual formats compress well; images do not. A release main.dart.js is
# ~4.7MB and CanvasKit wasm ~7MB — gzip roughly halves the transfer size and
# makes localhost first loads dramatically faster.
COMPRESSIBLE_EXTENSIONS = frozenset((
    '.html', '.js', '.css', '.json', '.svg', '.txt', '.map', '.wasm',
))
GZIP_MIN_BYTES = 1024

def serve_file(conn, filepath, include_body=True, accept_encoding=''):
    """Serve a static file, gzip-compressing when the client allows it."""
    try:
        with open(filepath, 'rb') as f:
            body = f.read()
        ext = os.path.splitext(filepath)[1].lower()
        ct = CONTENT_TYPES.get(ext, 'application/octet-stream')
        headers = [
            f'HTTP/1.1 200 OK',
            f'Content-Type: {ct}',
            f'Cache-Control: no-store, no-cache, must-revalidate, max-age=0',
            f'Pragma: no-cache',
            f'Expires: 0',
            f'Access-Control-Allow-Origin: *',
            f'Connection: close',
        ]
        if (
            len(body) >= GZIP_MIN_BYTES
            and ext in COMPRESSIBLE_EXTENSIONS
            and 'gzip' in (accept_encoding or '').lower()
        ):
            body = gzip.compress(body, mtime=0)
            headers.append('Content-Encoding: gzip')
            headers.append('Vary: Accept-Encoding')
        headers.append(f'Content-Length: {len(body)}')
        conn.sendall(
            ('\r\n'.join(headers) + '\r\n\r\n').encode()
            + (body if include_body else b'')
        )
    except FileNotFoundError:
        send_error(conn, 404, 'Not Found')
    except Exception as e:
        send_error(conn, 500, f'Server error: {e}')

def send_error(conn, code, msg):
    """Send HTTP error response."""
    body = json.dumps({'error': msg}).encode()
    resp = (
        f'HTTP/1.1 {code} {msg}\r\n'
        f'Content-Type: application/json\r\n'
        f'Content-Length: {len(body)}\r\n'
        f'Access-Control-Allow-Origin: *\r\n'
        f'Connection: close\r\n'
        f'\r\n'
    )
    try:
        conn.sendall(resp.encode() + body)
    except Exception as exc:
        print(f'robust_proxy: handler error: {exc}')

def should_proxy(method, path):
    """Return whether a request belongs to the Snaplink API."""
    parsed = urllib.parse.urlsplit(path)
    clean_path = parsed.path

    # RFC 7591/7592 registration lives at a root path rather than /api/.
    if clean_path == '/register' or clean_path.startswith('/register/'):
        return True

    # /device/verify is both a Flutter route and the RFC 8628 verification API.
    # Browser navigation stays in the SPA; API preview and form submissions go
    # to Snaplink.
    if clean_path == '/device/verify':
        query = urllib.parse.parse_qs(parsed.query, keep_blank_values=True)
        return method != 'GET' or 'check' in query

    return (
        any(clean_path.startswith(prefix) for prefix in API_PREFIXES)
        or any(
            clean_path == root or clean_path.startswith(f'{root}/')
            for root in API_ROOTS
        )
    )

def resolve_static_file(path):
    """Resolve a request to a file inside STATIC, with an SPA fallback.

    Production bundles use ``/app/`` as their asset prefix even though the
    local proxy serves the build directory at its root. Encoded traversal and
    symlink escapes are rejected rather than turned into SPA navigations.
    """
    clean_path = urllib.parse.unquote(urllib.parse.urlsplit(path).path)
    uses_app_prefix = clean_path == '/app' or clean_path.startswith('/app/')
    if clean_path == '/app':
        clean_path = '/'
    elif clean_path.startswith('/app/'):
        clean_path = clean_path[len('/app'):]

    relative = clean_path.lstrip('/') or 'index.html'
    candidate = (STATIC / relative).resolve()
    try:
        candidate.relative_to(STATIC)
    except ValueError:
        return None

    if candidate.is_file():
        return candidate
    if uses_app_prefix:
        return None
    return STATIC / 'index.html'

def _audit_compatibility_path(path: str) -> str:
    """Rewrite the Console audit paths to Audit Governance compatibility paths.

    Match the exact and segment-bounded locations in ``nginx.conf``.  The
    request path is deliberately treated as an opaque string: identifiers may
    contain percent-encoded octets, which must reach the upstream unchanged.
    """
    collection = '/api/v1/audit/events'
    detail_prefix = f'{collection}/'
    facets = '/api/v1/audit/facets'
    compat_collection = '/api/v1/compat/snaplink/audit/events'
    compat_facets = '/api/v1/compat/snaplink/audit/facets'

    if path == collection:
        return compat_collection
    if path.startswith(detail_prefix) and len(path) > len(detail_prefix):
        return f'{compat_collection}{path[len(collection):]}'
    if path == facets:
        return compat_facets
    return path


def _build_backend_url(path: str) -> tuple[str, str]:
    """Build the upstream URL while preserving the raw query string."""
    request_path, separator, qs = path.partition('?')
    backend = backend_for(path)
    url = f"{backend}{_audit_compatibility_path(request_path)}"
    if separator:
        url += f'?{qs}'
    return url, qs


def _forward_headers(headers: dict, backend: str, *, identity=True) -> dict:
    """Forward OP cookies only to identity; independent APIs use bearer grants."""
    req_headers = {}
    excluded = set(hop_headers(headers.items())) | {
        'host', 'content-length', 'forwarded', 'x-forwarded-for',
        'x-forwarded-host', 'x-forwarded-proto', 'x-real-ip',
    }
    if not identity:
        excluded.add('cookie')
    for k, v in headers.items():
        if k.lower() not in excluded:
            req_headers[k] = v
    incoming_host = headers.get('host')
    req_headers['Host'] = (
        incoming_host or urllib.parse.urlsplit(backend).netloc
    )
    if incoming_host:
        req_headers['X-Forwarded-Host'] = incoming_host
    req_headers['X-Forwarded-Proto'] = 'http'
    return req_headers


def _service_response_headers(service, items):
    # A same-origin independent API cannot overwrite the OP identity cookie.
    return [(key, value) for key, value in items
            if service == 'snaplink' or key.lower() != 'set-cookie']


def proxy_request(conn, method, path, headers, body):
    """Proxy once; optional services never fall through to identity APIs."""
    started = False
    try:
        service, backend, setting = _upstream_for(path)
        if not backend or not valid_origin(backend):
            suffix = 'invalid_upstream' if backend else 'unconfigured'
            message = (f'Service upstream is invalid. Set {setting} to an HTTP(S) origin.'
                       if backend else f'Service is not configured. Set {setting}.')
            error_body = json.dumps({'error': {
                'code': f'{service}_{suffix}',
                'message': message,
            }}).encode()
            _forward_response(conn, 503,
                              [('Content-Type', 'application/json; charset=utf-8')],
                              error_body)
            return
        url, _ = _build_backend_url(path)
        req = urllib.request.Request(url, data=body,
                                     headers=_forward_headers(headers, backend,
                                                              identity=service == 'snaplink'),
                                     method=method)
        with UPSTREAM_OPENER.open(req, timeout=60) as resp:
            response_headers = _service_response_headers(service, resp.headers.items())
            if resp.headers.get_content_type() == 'text/event-stream':
                started = True
                forward_stream_response(conn, resp, headers_items=response_headers)
            else:
                _forward_response(conn, resp.status, response_headers, resp.read())
    except urllib.error.HTTPError as error:
        with error:
            _forward_response(conn, error.code,
                              _service_response_headers(service, error.headers.items()),
                              error.read(), reason=error.reason)
    except Exception:
        # A broken SSE connection ends the stream, not a second HTTP response.
        # Do not expose upstream URLs, credentials or exception internals.
        if not started:
            send_error(conn, 502, 'Upstream unavailable. Check service connectivity.')


def _upstream_for(path):
    clean_path = urllib.parse.urlsplit(path).path
    families = (
        ('/api/v1/agent', 'agent_hub', AGENT_HUB_BACKEND, 'AGENT_HUB_UPSTREAM'),
        ('/api/v1/admin/commerce', 'billing', BILLING_BACKEND, 'SNAPLINK_BILLING_UPSTREAM'),
        ('/api/v1/commerce', 'billing', BILLING_BACKEND, 'SNAPLINK_BILLING_UPSTREAM'),
        ('/api/v1/metering', 'billing', BILLING_BACKEND, 'SNAPLINK_BILLING_UPSTREAM'),
        ('/api/v1/conversations', 'forge', FORGE_BACKEND, 'FORGE_CONVERSATIONS_UPSTREAM'),
        ('/api/v1/conversation-changes', 'forge', FORGE_BACKEND, 'FORGE_CONVERSATIONS_UPSTREAM'),
    )
    for prefix, service, backend, setting in families:
        if clean_path == prefix or clean_path.startswith(f'{prefix}/'):
            return service, backend, setting
    if clean_path == '/api/v1/checkout/sessions':
        return ('stripe_adapter', STRIPE_ADAPTER_BACKEND,
                'SNAPLINK_STRIPE_ADAPTER_UPSTREAM')
    detail = '/api/v1/audit/events/'
    if clean_path in ('/api/v1/audit/events', '/api/v1/audit/facets') or (
            clean_path.startswith(detail) and len(clean_path) > len(detail)):
        return 'audit_governance', AUDIT_GOVERNANCE_BACKEND, 'AUDIT_GOVERNANCE_UPSTREAM'
    return 'snaplink', BACKEND, 'SNAPLINK_API_URL'


def backend_for(path):
    """Resolve the same-origin service upstream, preserving segment boundaries."""
    return _upstream_for(path)[1]

def handle(conn):
    """Handle a single HTTP connection."""
    try:
        conn.settimeout(15)
        method, path, headers, body = parse_request(conn)
        if not method or not path:
            send_error(conn, 400, 'Bad Request')
            return
        
        # Handle CORS preflight
        if method == 'OPTIONS':
            _send_cors_preflight(conn)
            return

        # API proxy
        is_api = should_proxy(method, path)
        if is_api:
            proxy_request(conn, method, path, headers, body)
            return
        
        # Static file serving with SPA fallback
        if method in ('GET', 'HEAD'):
            filepath = resolve_static_file(path)
            if filepath is None:
                send_error(conn, 404, 'Not Found')
                return
            serve_file(
                conn,
                filepath,
                include_body=method == 'GET',
                accept_encoding=headers.get('accept-encoding', ''),
            )
        else:
            send_error(conn, 405, 'Method Not Allowed')
    except (InvalidRequest, socket.timeout):
        send_error(conn, 400, 'Bad Request')
    except Exception:
        try:
            send_error(conn, 500, 'Internal Server Error')
        except Exception as exc:
            print(f'robust_proxy: response error: {exc}')
    finally:
        try:
            conn.close()
        except Exception as exc:
            print(f'robust_proxy: close error: {exc}')

def _send_cors_preflight(conn):
    """Reply to a CORS preflight (OPTIONS) with the allowed methods/headers."""
    resp = (
        'HTTP/1.1 204 No Content\r\n'
        'Access-Control-Allow-Origin: *\r\n'
        'Access-Control-Allow-Methods: GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS\r\n'
        'Access-Control-Allow-Headers: Authorization, Content-Type, X-Requested-With, '
        'Idempotency-Key, If-Match, Last-Event-ID, Cache-Control, X-Request-Id\r\n'
        'Access-Control-Max-Age: 86400\r\n'
        'Content-Length: 0\r\n'
        'Connection: close\r\n\r\n'
    )
    conn.sendall(resp.encode())


def serve():
    """Main server loop."""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', PORT))
    server.listen(128)
    server.settimeout(1.0)
    label = BACKEND if valid_origin(BACKEND) else '<invalid origin>'
    sys.stderr.write(f"[proxy] Robust SPA+API proxy on :{PORT} (backend={label})\n")
    while True:
        try:
            conn, addr = server.accept()
            t = threading.Thread(target=handle, args=(conn,), daemon=True)
            t.start()
        except socket.timeout:
            continue
        except Exception:
            time.sleep(0.1)

if __name__ == '__main__':
    serve()
