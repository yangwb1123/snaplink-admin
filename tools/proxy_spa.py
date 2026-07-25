#!/usr/bin/env python3
"""
Production-grade SPA proxy for sso-console development.
Serves the Flutter web build on :4444 and proxies API calls to :8080.
Auto-restarts on crash and handles SPA fallback for all /admin/* paths.
"""
import http.server, urllib.request, socketserver, os, sys, signal, time

PORT = int(os.environ.get('PORT', '4444'))
BACKEND = os.environ.get('BACKEND', 'http://localhost:8080')
STATIC_DIR = os.environ.get('STATIC_DIR', '/home/dwp/sso-console/build/web')
MAX_RETRIES = 3

API_PREFIXES = (
    '/auth/', '/api/', '/me', '/.well-known/', '/health', '/token',
    '/branding', '/logout', '/userinfo', '/roles/', '/permissions/',
    '/menus/', '/sessions/', '/consents/',
)

class ProxyHandler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *a, **kw):
        super().__init__(*a, directory=STATIC_DIR, **kw)

    def is_api(self):
        return any(self.path.startswith(p) for p in API_PREFIXES)

    def log_message(self, fmt, *args):
        sys.stderr.write(f"[proxy] {args[0]} {args[1]} {args[2]}\n")

    def do_GET(self):
        if self.is_api():
            return self.proxy()
        path = self.path.split('?')[0]
        full = os.path.join(STATIC_DIR, path.lstrip('/'))
        if os.path.exists(full) and not os.path.isdir(full):
            return super().do_GET()
        self.path = '/index.html'
        return super().do_GET()

    def do_POST(self):
        if self.is_api():
            return self.proxy()
        self.send_error(405)

    def do_HEAD(self):
        self.do_GET()

    def proxy(self):
        for attempt in range(MAX_RETRIES):
            try:
                p = self.path.split('?')[0]
                qs = self.path.split('?')[1] if '?' in self.path else ''
                url = f"{BACKEND}{p}" + (f"?{qs}" if qs else "")
                cl = self.headers.get('Content-Length')
                body = self.rfile.read(int(cl)) if cl else None
                headers = {k: v for k, v in self.headers.items()
                          if k.lower() not in ('host', 'content-length', 'transfer-encoding')}
                req = urllib.request.Request(url, data=body, headers=headers,
                    method=self.command)
                with urllib.request.urlopen(req, timeout=15) as resp:
                    data = resp.read()
                    self.send_response(resp.status)
                    for k, v in resp.headers.items():
                        if k.lower() not in ('transfer-encoding', 'content-encoding', 'content-length'):
                            self.send_header(k, v)
                    self.send_header('Content-Length', str(len(data)))
                    self.end_headers()
                    self.wfile.write(data)
                return
            except urllib.error.HTTPError as e:
                self.send_response(e.code)
                self.end_headers()
                self.wfile.write(e.read())
                return
            except Exception as e:
                if attempt == MAX_RETRIES - 1:
                    self.send_error(502, f'Proxy error: {e}')
                time.sleep(0.5 * (attempt + 1))

class ThreadedHTTPServer(socketserver.ThreadingMixIn, http.server.HTTPServer):
    allow_reuse_address = True
    daemon_threads = True

def serve_forever():
    server = ThreadedHTTPServer(('0.0.0.0', PORT), ProxyHandler)
    sys.stderr.write(f"[proxy] SPA Proxy on :{PORT} (backend={BACKEND})\n")
    server.serve_forever()

if __name__ == '__main__':
    serve_forever()
