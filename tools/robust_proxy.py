import os, sys, socket, threading, time, json, urllib.request, urllib.error, urllib.parse

PORT = int(os.environ.get('PORT', '4444'))
BACKEND = os.environ.get('BACKEND', 'http://localhost:8080')
STATIC = os.environ.get('STATIC_DIR', '/home/dwp/sso-console/build/web')

API_PREFIXES = (
    '/auth/', '/api/', '/me', '/.well-known/', '/health', '/token',
    '/branding', '/logout', '/userinfo', '/roles/', '/permissions/',
    '/menus/', '/sessions/', '/consents/',
)

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

def serve_file(conn, filepath):
    """Serve a static file."""
    try:
        with open(filepath, 'rb') as f:
            body = f.read()
        ext = os.path.splitext(filepath)[1].lower()
        ct = CONTENT_TYPES.get(ext, 'application/octet-stream')
        resp = (
            f'HTTP/1.1 200 OK\r\n'
            f'Content-Type: {ct}\r\n'
            f'Content-Length: {len(body)}\r\n'
            f'Access-Control-Allow-Origin: *\r\n'
            f'Connection: close\r\n'
            f'\r\n'
        )
        conn.sendall(resp.encode() + body)
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
    except:
        pass

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

    return any(clean_path.startswith(prefix) for prefix in API_PREFIXES)

def proxy_request(conn, method, path, headers, body):
    """Proxy request to backend server."""
    try:
        # Build backend URL
        qs = ''
        if '?' in path:
            path, qs = path.split('?', 1)
        url = f"{BACKEND}{path}"
        if qs:
            url += f'?{qs}'
        
        # Build request
        req_headers = {}
        for k, v in headers.items():
            if k.lower() not in ('host', 'content-length', 'transfer-encoding', 'connection'):
                req_headers[k] = v
        incoming_host = headers.get('host')
        req_headers['Host'] = incoming_host or urllib.parse.urlsplit(BACKEND).netloc
        if incoming_host:
            req_headers['X-Forwarded-Host'] = incoming_host
        req_headers['X-Forwarded-Proto'] = 'http'
        
        req = urllib.request.Request(url, data=body, headers=req_headers, method=method)
        
        with urllib.request.urlopen(req, timeout=15) as resp:
            resp_body = resp.read()
            status = resp.status
            # Forward response headers
            resp_headers = (
                f'HTTP/1.1 {status}\r\n'
                f'Access-Control-Allow-Origin: *\r\n'
            )
            for k, v in resp.headers.items():
                if k.lower() not in ('transfer-encoding', 'content-encoding', 'content-length', 'connection'):
                    resp_headers += f'{k}: {v}\r\n'
            resp_headers += f'Content-Length: {len(resp_body)}\r\n'
            resp_headers += 'Connection: close\r\n\r\n'
            conn.sendall(resp_headers.encode() + resp_body)
    except urllib.error.HTTPError as e:
        error_body = e.read()
        resp_headers = (
            f'HTTP/1.1 {e.code} {e.reason}\r\n'
            f'Access-Control-Allow-Origin: *\r\n'
        )
        for k, v in e.headers.items():
            if k.lower() not in (
                'transfer-encoding', 'content-encoding', 'content-length',
                'connection', 'access-control-allow-origin',
            ):
                resp_headers += f'{k}: {v}\r\n'
        resp_headers += f'Content-Length: {len(error_body)}\r\n'
        resp_headers += 'Connection: close\r\n\r\n'
        conn.sendall(resp_headers.encode() + error_body)
    except Exception as e:
        send_error(conn, 502, f'Proxy error: {e}')

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
                'Access-Control-Allow-Methods: GET, POST, PUT, DELETE, OPTIONS\r\n'
                'Access-Control-Allow-Headers: Authorization, Content-Type, X-Requested-With\r\n'
                'Access-Control-Max-Age: 86400\r\n'
                'Content-Length: 0\r\n'
                'Connection: close\r\n\r\n'
            )
            conn.sendall(resp.encode())
            return
        
        clean_path = path.split('?')[0]
        
        # API proxy
        is_api = should_proxy(method, path)
        if is_api:
            proxy_request(conn, method, path, headers, body)
            return
        
        # Static file serving with SPA fallback
        if method == 'GET':
            if clean_path == '/':
                clean_path = '/index.html'
            
            filepath = os.path.join(STATIC, clean_path.lstrip('/'))
            if not os.path.exists(filepath) or os.path.isdir(filepath):
                filepath = os.path.join(STATIC, 'index.html')
            
            serve_file(conn, filepath)
        else:
            send_error(conn, 405, 'Method Not Allowed')
    except Exception:
        try:
            send_error(conn, 500, 'Internal Server Error')
        except:
            pass
    finally:
        try:
            conn.close()
        except:
            pass

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
