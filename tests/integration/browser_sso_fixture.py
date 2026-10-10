"""Build/run an isolated stock OP and HTTPS gateway; never manage live ports."""

from contextlib import ExitStack
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import os
import re
import socket
import socketserver
import ssl
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request

import yaml

from browser_sso_rp import FixtureFailure, RelyingParty, require

ROOT = Path(__file__).resolve().parents[2]
FIXTURE_USER = 'browser-fixture-user'
FIXTURE_PASSWORD = 'disposable-browser-fixture-password'


def fixture_environment():
    # Production SSO environment cannot override our disposable config/store.
    return {key: value for key, value in os.environ.items()
            if not key.startswith(('SSO_', 'SNAPLINK_', 'AUDIT_', 'AGENT_', 'FORGE_'))
            and key not in {'BACKEND', 'PORT', 'STATIC_DIR'}}


def free_port():
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', 0))
        return listener.getsockname()[1]


def stop_process(process):
    if process.poll() is None:
        process.terminate()
        try:
            process.wait(timeout=10)
        except subprocess.TimeoutExpired:
            process.kill()
            process.wait(timeout=5)


def run_checked(arguments, *, cwd=None, input=None):
    result = subprocess.run(arguments, cwd=cwd, input=input, capture_output=True,
                            env=fixture_environment(), timeout=240)
    require(result.returncode == 0, 'Fixture build/configuration command failed')
    return result.stdout


def start_server(stack, server):
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    thread.start()

    def close():
        server.shutdown()
        server.server_close()
        thread.join(timeout=3)
    stack.callback(close)
    return server


class IndependentAPI:
    def __init__(self, stack):
        self.received_cookie = None
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                owner.received_cookie = self.headers.get('Cookie')
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Set-Cookie', 'snaplink_op_session=must-not-replace; Path=/; Secure; HttpOnly')
                self.end_headers()
                self.wfile.write(b'{"fixture":true}')

        server = start_server(stack, ThreadingHTTPServer(('127.0.0.1', 0), Handler))
        self.origin = f'http://127.0.0.1:{server.server_port}'


def create_tls(directory):
    certificate, key = directory / 'tls.crt', directory / 'tls.key'
    run_checked(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                 '-keyout', str(key), '-out', str(certificate), '-days', '1',
                 '-subj', '/CN=127.0.0.1', '-addext', 'subjectAltName=IP:127.0.0.1'])
    key.chmod(0o600)
    return certificate, key


def python_gateway(stack, directory, web, backend, sink):
    sys.path.insert(0, str(ROOT))
    from tools import robust_proxy
    robust_proxy.BACKEND, robust_proxy.STATIC = backend, web
    for name in ('BILLING_BACKEND', 'STRIPE_ADAPTER_BACKEND', 'FORGE_BACKEND',
                 'AUDIT_GOVERNANCE_BACKEND', 'AGENT_HUB_BACKEND'):
        setattr(robust_proxy, name, sink)

    class Handler(socketserver.BaseRequestHandler):
        def handle(self):
            robust_proxy.handle(self.request)

    class Server(socketserver.ThreadingTCPServer):
        daemon_threads = True

    server = Server(('127.0.0.1', 0), Handler)
    certificate, key = create_tls(directory)
    tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    tls.load_cert_chain(certificate, key)
    server.socket = tls.wrap_socket(server.socket, server_side=True)
    start_server(stack, server)
    return f'https://127.0.0.1:{server.server_address[1]}'


def nginx_gateway(stack, directory, web, backend, sink):
    port = free_port()
    certificate, key = create_tls(directory)
    text = (ROOT / 'nginx.conf').read_text()

    def expand(match):
        name = match.group(1)
        if name == 'SNAPLINK_UPSTREAM':
            return backend
        if name.endswith('UPSTREAM'):
            return sink
        if name.endswith('SERVER_NAME'):
            return 'localhost'
        if name.endswith('CA'):
            return '/etc/ssl/certs/ca-certificates.crt'
        raise FixtureFailure('Unknown gateway template parameter')

    text = re.sub(r'\$\{([A-Z_]+)\}', expand, text)
    require(text.count('listen       80;') == 1, 'Production gateway listener template changed')
    text = 'error_log /dev/null;\n' + text
    text = text.replace('listen       80;', f'listen 127.0.0.1:{port} ssl;\n'
                        '    ssl_certificate /fixture/tls.crt;\n'
                        '    ssl_certificate_key /fixture/tls.key;\n    access_log off;')
    config = directory / 'default.conf'
    config.write_text(text)
    name = 'snaplink-browser-sso-' + directory.name
    # Only our newly named container is stopped; no existing listeners are killed.
    run_checked(['docker', 'run', '-d', '--name', name, '--network', 'host', '--log-driver=none',
                 '--read-only', '--tmpfs', '/run', '--tmpfs', '/var/cache/nginx',
                 '-v', f'{web}:/usr/share/nginx/html:ro',
                 '-v', f'{config}:/etc/nginx/conf.d/default.conf:ro',
                 '-v', f'{certificate}:/fixture/tls.crt:ro',
                 '-v', f'{key}:/fixture/tls.key:ro', 'nginx:alpine'])
    stack.callback(lambda: subprocess.run(['docker', 'rm', '-f', name],
                                        stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL))
    return f'https://127.0.0.1:{port}'


def fixture_config(directory, issuer, backend_port, clients):
    return {
        'version': 1,
        'server': {'issuer': issuer, 'base_url': issuer,
                   'listen': f'127.0.0.1:{backend_port}', 'session_ttl': '2h'},
        'bootstrap': {'disabled': True},
        'logging': {'level': 'error', 'access_log': {'enabled': False}},
        'identity': {'backend': 'sqlite', 'sqlite': {'dsn': f'file:{directory}/identity.db'}},
        'oidc': {'browser_sso': {'enabled': True}},
        'oauth': {'auth_code': {'enabled': True}, 'refresh_token': {'enabled': True}},
        'self_service': {'consent': {'backend': 'memory'}},
        'keys': {'signing': {'alg': 'eddsa'}},
        'authenticators': {'password': {'enabled': True, 'users': [{
            'username': FIXTURE_USER, 'subject_id': FIXTURE_USER,
            'bcrypt_hash_file': str(directory / 'user.bcrypt'),
        }]}},
        'clients': clients,
    }


def wait_ready(backend, process):
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        require(process.poll() is None, 'Stock OP stopped before readiness')
        try:
            with urllib.request.urlopen(backend + '/readyz', timeout=1) as response:
                if response.status == 200:
                    return
        except (OSError, urllib.error.URLError):
            time.sleep(0.1)
    raise FixtureFailure('Stock OP did not become ready')


class BrowserFixture:
    def __init__(self, backend_repo, web, gateway):
        self.backend_repo, self.web, self.gateway = backend_repo, web, gateway
        self.stack = ExitStack()

    def __enter__(self):
        try:
            self.start()
            return self
        except BaseException:
            self.stack.close()
            raise

    def __exit__(self, *_):
        self.stack.close()

    def start(self):
        require((self.backend_repo / 'cmd/sso-server/main.go').is_file(), 'Stock OP source is missing')
        require((self.web / 'main.dart.js').is_file(), 'Release Web build is missing')
        require((self.web / 'canvaskit').is_dir(), 'Local CanvasKit build is missing')
        directory = Path(self.stack.enter_context(tempfile.TemporaryDirectory(prefix='snaplink-browser-sso-')))
        self.directory = directory
        self.rps = [RelyingParty('browser-rp-a', 'Browser App A', True, host='127.0.0.2'),
                    RelyingParty('browser-rp-b', 'Browser App B', False, host='127.0.0.3')]
        for rp in self.rps:
            self.stack.callback(rp.close)
        self.sink = IndependentAPI(self.stack)
        backend_port = free_port()
        self.backend = f'http://127.0.0.1:{backend_port}'
        gateway = python_gateway if self.gateway == 'python' else nginx_gateway
        self.issuer = gateway(self.stack, directory, self.web, self.backend, self.sink.origin)
        for rp in self.rps:
            rp.issuer = self.issuer
            rp.tls_context = ssl.create_default_context(cafile=str(directory / 'tls.crt'))
        binary = directory / 'sso-server'
        run_checked(['go', 'build', '-o', str(binary), './cmd/sso-server'], cwd=self.backend_repo)
        self.write_password(directory)
        config = directory / 'config.yaml'
        config.write_text(yaml.safe_dump(fixture_config(directory, self.issuer, backend_port,
                                                     [rp.client_config() for rp in self.rps])))
        process = subprocess.Popen([str(binary), '-config', str(config), '-grpc-listen', ''],
                                   cwd=directory, env=fixture_environment(),
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.stack.callback(stop_process, process)
        wait_ready(self.backend, process)

    def write_password(self, directory):
        helper = directory / 'fixture_hash.go'
        helper.write_text('''package main
import ("io"; "os"; "golang.org/x/crypto/bcrypt")
func main() {
 p, e := io.ReadAll(os.Stdin); if e != nil { panic("fixture input failed") }
 h, e := bcrypt.GenerateFromPassword(p, bcrypt.DefaultCost); if e != nil { panic("fixture hash failed") }
 os.Stdout.Write(h)
}
''')
        digest = run_checked(['go', 'run', str(helper)], cwd=self.backend_repo,
                             input=FIXTURE_PASSWORD.encode())
        password_file = directory / 'user.bcrypt'
        password_file.write_bytes(digest)
        password_file.chmod(0o600)
