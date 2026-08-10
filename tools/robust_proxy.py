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

PORT = int(os.environ.get('PORT', os.environ.get('SNAPLINK_PROXY_PORT', '4444')))
BACKEND = os.environ.get(
    'BACKEND',
    os.environ.get('SNAPLINK_API_URL', 'http://localhost:8080'),
).rstrip('/')
STRIPE_ADAPTER_BACKEND = os.environ.get(
    'SNAPLINK_STRIPE_ADAPTER_URL', BACKEND,
).rstrip('/')
PROJECT_ROOT = Path(__file__).resolve().parent.parent
STATIC = Path(
    os.environ.get('STATIC_DIR', PROJECT_ROOT / 'build' / 'web')
).expanduser().resolve()

API_PREFIXES = (
    '/auth/', '/api/', '/.well-known/', '/roles/', '/permissions/', '/menus/',
    '/sessions/', '/consents/',
)
API_ROOTS = ('/me', '/health', '/token', '/branding', '/logout', '/userinfo')

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

def recv_full(conn, size):
    """Receive exactly `size` bytes from connection."""
    chunks = []
    remaining = size
    while remaining > 0:
        chunk = conn.recv(remaining)
        if not chunk:
            break
        chunks.append(chunk)
        remaining -= len(chunk)
    return b''.join(chunks)

def parse_request(conn):
    """Parse raw HTTP request from connection into method, path, headers, body."""
    # Read up to 64KB for headers
    data = conn.recv(65536)
    if not data:
        return None, None, None, None
    try:
        text = data.decode('utf-8', errors='replace')
    except:
        return None, None, None, None
    lines = text.split('\r\n')
    if not lines:
        return None, None, None, None
    parts = lines[0].split(' ')
    if len(parts) < 2:
        return None, None, None, None
    method, path = parts[0], parts[1]
    
    headers = {}
    body_start = text.find('\r\n\r\n')
    header_lines = text[:body_start].split('\r\n')[1:] if body_start >= 0 else []
    for hl in header_lines:
        if ':' in hl:
            k, v = hl.split(':', 1)
            headers[k.strip().lower()] = v.strip()
    
    # Read body based on Content-Length
    body = None
    content_length = int(headers.get('content-length', 0))
    if content_length > 0:
        body_start_idx = data.find(b'\r\n\r\n') + 4
        body_received = len(data) - body_start_idx
        if body_received < content_length:
            # Need to read more data
            remaining = content_length - body_received
            more_data = recv_full(conn, remaining)
            body = data[body_start_idx:] + more_data
        else:
            body = data[body_start_idx:body_start_idx + content_length]
    
    return method, path, headers, body

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

def _build_backend_url(path: str) -> tuple[str, str]:
    """Split the raw request path into (backend_url, query_string)."""
    backend = backend_for(path)
    qs = ''
    if '?' in path:
        path, qs = path.split('?', 1)
    url = f"{backend}{path}"
    if qs:
        url += f'?{qs}'
    return url, qs


def _forward_headers(headers: dict, backend: str) -> dict:
    """Copy request headers, rewriting Host and adding X-Forwarded-*."""
    req_headers = {}
    for k, v in headers.items():
        if k.lower() not in ('host', 'content-length', 'transfer-encoding', 'connection'):
            req_headers[k] = v
    incoming_host = headers.get('host')
    req_headers['Host'] = (
        incoming_host or urllib.parse.urlsplit(backend).netloc
    )
    if incoming_host:
        req_headers['X-Forwarded-Host'] = incoming_host
    req_headers['X-Forwarded-Proto'] = 'http'
    return req_headers


def _forward_response(conn, status: int, headers_items, body: bytes,
                     reason: str = "") -> None:
    """Write the proxy response: CORS + content-length + connection close.
    Shared by the success and HTTPError paths."""
    status_line = f'HTTP/1.1 {status}' + (f' {reason}' if reason else '')
    resp_headers = f'{status_line}\r\nAccess-Control-Allow-Origin: *\r\n'
    for k, v in headers_items:
        if k.lower() not in ('transfer-encoding', 'content-encoding',
                             'content-length', 'connection',
                             'access-control-allow-origin'):
            resp_headers += f'{k}: {v}\r\n'
    resp_headers += f'Content-Length: {len(body)}\r\n'
    resp_headers += 'Connection: close\r\n\r\n'
    conn.sendall(resp_headers.encode() + body)


def proxy_request(conn, method, path, headers, body):
    """Proxy request to backend server."""
    try:
        # Build backend URL
        url, _ = _build_backend_url(path)
        req_headers = _forward_headers(headers, backend_for(path))
        req = urllib.request.Request(url, data=body, headers=req_headers, method=method)
        
        with urllib.request.urlopen(req, timeout=15) as resp:
            resp_body = resp.read()
            _forward_response(conn, resp.status, resp.headers.items(), resp_body)
    except urllib.error.HTTPError as e:
        error_body = e.read()
        _forward_response(conn, e.code, e.headers.items(), error_body,
                          reason=e.reason)
    except Exception as e:
        send_error(conn, 502, f'Proxy error: {e}')

def backend_for(path):
    """Resolve the explicitly separate same-origin Checkout upstream."""
    clean_path = urllib.parse.urlsplit(path).path
    if clean_path == '/api/v1/checkout/sessions':
        return STRIPE_ADAPTER_BACKEND
    return BACKEND

def handle(conn):
    """Handle a single HTTP connection."""
    try:
        method, path, headers, body = parse_request(conn)
        if not method or not path:
            send_error(conn, 400, 'Bad Request')
            return
        
        # Handle CORS preflight
        if method == 'OPTIONS':
            resp = (
                'HTTP/1.1 204 No Content\r\n'
                'Access-Control-Allow-Origin: *\r\n'
                'Access-Control-Allow-Methods: GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS\r\n'
                'Access-Control-Allow-Headers: Authorization, Content-Type, X-Requested-With\r\n'
                'Access-Control-Max-Age: 86400\r\n'
                'Content-Length: 0\r\n'
                'Connection: close\r\n\r\n'
            )
            conn.sendall(resp.encode())
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

def serve():
    """Main server loop."""
    server = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
    server.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
    server.bind(('0.0.0.0', PORT))
    server.listen(128)
    server.settimeout(1.0)
    sys.stderr.write(f"[proxy] Robust SPA+API proxy on :{PORT} (backend={BACKEND})\n")
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
