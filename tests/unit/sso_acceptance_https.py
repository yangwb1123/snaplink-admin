"""Positively owned loopback HTTPS transport simulator (not a stock OP)."""

from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import ssl
import subprocess
import tempfile
import threading


class HTTPSFixture:
    def __init__(self, respond):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.cert, self.key = self.root / 'ca.pem', self.root / 'key.pem'
        result = subprocess.run(['openssl', 'req', '-x509', '-newkey', 'ed25519', '-nodes',
                                 '-keyout', str(self.key), '-out', str(self.cert), '-days', '1',
                                 '-subj', '/CN=owned-loopback', '-addext', 'subjectAltName=IP:127.0.0.1'],
                                capture_output=True, timeout=10)
        if result.returncode:
            self.temp.cleanup()
            raise RuntimeError('Owned certificate setup failed')
        self.counts = {'GET': 0, 'POST': 0}
        owner = self
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_GET(self):
                owner.counts['GET'] += 1
                respond(self)
            def do_POST(self):
                owner.counts['POST'] += 1
                respond(self)
        context = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
        context.load_cert_chain(self.cert, self.key)
        class Server(ThreadingHTTPServer):
            daemon_threads = True
            def handle_error(self, *_):
                pass
            def get_request(self):
                request, address = super().get_request()
                request.settimeout(1)
                try:
                    return context.wrap_socket(request, server_side=True, do_handshake_on_connect=False), address
                except Exception:
                    request.close()
                    raise
            def process_request_thread(self, request, address):
                try:
                    request.do_handshake()  # Bounded worker, never the listener.
                    super().process_request_thread(request, address)
                except (OSError, ssl.SSLError):
                    self.shutdown_request(request)
        self.server = Server(('127.0.0.1', 0), Handler)
        self.origin = 'https://127.0.0.1:' + str(self.server.server_port)
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)
        self.temp.cleanup()


def reply(handler, body=b'{"ok":true}', status=200, headers=None):
    handler.send_response(status)
    handler.send_header('Content-Type', 'application/json')
    handler.send_header('Content-Length', str(len(body)))
    for key, value in (headers or {}).items():
        handler.send_header(key, value)
    handler.end_headers()
    handler.wfile.write(body)
