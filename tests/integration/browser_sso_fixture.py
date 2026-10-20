"""Build/run an isolated stock OP and HTTPS gateway; never manage live ports."""

from contextlib import ExitStack
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import json
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

from browser_sso_rp import FixtureFailure, NoRedirect, RelyingParty, require, run_normal_case

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
    environment = fixture_environment()
    environment['GOMAXPROCS'] = '4'
    result = subprocess.run(arguments, cwd=cwd, input=input, capture_output=True,
                            env=environment, timeout=240)
    # Identify only the allowlisted tool and exit status; command arguments and
    # output can contain credentials, paths or callback URLs and stay private.
    tool = Path(arguments[0]).name
    label = tool if tool in {'go', 'openssl', 'docker'} else 'command'
    require(result.returncode == 0, f'Fixture {label} failed (exit {result.returncode})')
    return result.stdout


def start_server(stack, server):
    thread = threading.Thread(target=server.serve_forever, daemon=True)
    server.fixture_thread = thread

    def close():
        if thread.ident is not None:
            server.shutdown()
        try:
            if hasattr(server, 'close_workers'):
                server.fixture_deadline = getattr(stack, 'fixture_deadline', float('inf'))
                server.close_workers()
        finally:
            server.server_close()
        if thread.ident is not None:
            thread.join(timeout=3)
        require(not thread.is_alive() and server.socket.fileno() == -1,
                'Owned fixture server cleanup not verified')
    stack.callback(close)
    thread.start()
    return server


class IndependentAPI:
    def __init__(self, stack, *, server_type=ThreadingHTTPServer):
        self.received_cookie, self.closing = None, False
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                # Socket shutdown can end a partial header read with EOF. Do
                # not begin a reply for that request during fixture teardown.
                if owner.closing:
                    return
                owner.received_cookie = self.headers.get('Cookie')
                self.send_response(200)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Set-Cookie', 'snaplink_op_session=must-not-replace; Path=/; Secure; HttpOnly')
                self.end_headers()
                self.wfile.write(b'{"fixture":true}')

        self.server = start_server(stack, server_type(('127.0.0.1', 0), Handler))
        stack.callback(setattr, self, 'closing', True)  # Before accepted sockets are closed.
        self.origin = f'http://127.0.0.1:{self.server.server_port}'


def create_tls(directory):
    certificate, key = directory / 'tls.crt', directory / 'tls.key'
    run_checked(['openssl', 'req', '-x509', '-newkey', 'rsa:2048', '-nodes',
                 '-keyout', str(key), '-out', str(certificate), '-days', '1',
                 '-subj', '/CN=127.0.0.1', '-addext', 'subjectAltName=IP:127.0.0.1'])
    key.chmod(0o600)
    return certificate, key


def python_gateway(stack, directory, web, backend, sink, *, server_base=socketserver.ThreadingTCPServer, opener=None):
    sys.path.insert(0, str(ROOT))
    from tools import robust_proxy
    robust_proxy.BACKEND, robust_proxy.STATIC = backend, web
    if opener is not None:
        stack.callback(setattr, robust_proxy, 'UPSTREAM_OPENER', robust_proxy.UPSTREAM_OPENER)
        robust_proxy.UPSTREAM_OPENER = opener
    for name in ('BILLING_BACKEND', 'STRIPE_ADAPTER_BACKEND', 'FORGE_BACKEND',
                 'AUDIT_GOVERNANCE_BACKEND', 'AGENT_HUB_BACKEND'):
        setattr(robust_proxy, name, sink)

    certificate, key = create_tls(directory)
    tls = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    tls.load_cert_chain(certificate, key)

    class Handler(socketserver.BaseRequestHandler):
        def handle(self):
            try:
                self.request.do_handshake()
            except (OSError, ssl.SSLError):
                return
            robust_proxy.handle(self.request)

    class Server(server_base):
        daemon_threads = True

        def get_request(self):
            raw, address = super().get_request()
            raw.settimeout(5)
            # A speculative/partial TLS connection must not block the listener
            # thread or shutdown. Only its bounded daemon worker handshakes.
            return tls.wrap_socket(raw, server_side=True, do_handshake_on_connect=False), address

    server = Server(('127.0.0.1', 0), Handler)
    start_server(stack, server)
    return f'https://127.0.0.1:{server.server_address[1]}'


def nginx_gateway(stack, directory, web, backend, sink, *, launch=None):
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
    arguments = ['docker', 'run', '-d', '--name', name, '--network', 'host', '--log-driver=none',
                 '--read-only', '--tmpfs', '/run', '--tmpfs', '/var/cache/nginx',
                 '-v', f'{web}:/usr/share/nginx/html:ro',
                 '-v', f'{config}:/etc/nginx/conf.d/default.conf:ro',
                 '-v', f'{certificate}:/fixture/tls.crt:ro',
                 '-v', f'{key}:/fixture/tls.key:ro', 'nginx:alpine']
    if launch is not None:
        launch(arguments)
    else:
        run_checked(arguments)
        stack.callback(lambda: subprocess.run(['docker', 'rm', '-f', name],
                                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=30))
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
    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    deadline = time.monotonic() + 30
    while time.monotonic() < deadline:
        require(process.poll() is None, 'Stock OP stopped before readiness')
        try:
            with opener.open(backend + '/readyz', timeout=1) as response:
                if response.status == 200:
                    return
        except (OSError, urllib.error.URLError):
            time.sleep(0.1)
    raise FixtureFailure('Stock OP did not become ready')


class BrowserFixture:
    def __init__(self, backend_repo, web, gateway, *, consent_skips=(True, False)):
        require(len(consent_skips) == 2 and all(type(value) is bool for value in consent_skips),
                'Fixture requires two explicit consent policies')
        self.backend_repo, self.web, self.gateway = backend_repo, web, gateway
        self.consent_skips = consent_skips
        self.process = None
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

    def create_rps(self):
        return [RelyingParty('browser-rp-a', 'Browser App A', self.consent_skips[0], host='127.0.0.2'),
                RelyingParty('browser-rp-b', 'Browser App B', self.consent_skips[1], host='127.0.0.3')]

    def create_sink(self):
        return IndependentAPI(self.stack)

    def create_gateway(self, directory):
        gateway = python_gateway if self.gateway == 'python' else nginx_gateway
        return gateway(self.stack, directory, self.web, self.backend, self.sink.origin)

    def start_rps(self):
        self.rps = []
        for rp in self.create_rps():
            self.rps.append(rp)
            self.stack.callback(rp.close)

    def create_directory(self):
        return Path(self.stack.enter_context(tempfile.TemporaryDirectory(prefix='snaplink-browser-sso-')))

    def start(self):
        print('Fixture: validate release artifacts', flush=True)
        require((self.backend_repo / 'cmd/sso-server/main.go').is_file(), 'Stock OP source is missing')
        require((self.web / 'main.dart.js').is_file(), 'Release Web build is missing')
        require((self.web / 'canvaskit').is_dir(), 'Local CanvasKit build is missing')
        directory = self.create_directory()
        self.directory = directory
        self.start_rps()
        self.sink = self.create_sink()
        backend_port = free_port()
        self.backend = f'http://127.0.0.1:{backend_port}'
        print('Fixture: create ' + self.gateway + ' HTTPS gateway', flush=True)
        self.issuer = self.create_gateway(directory)
        for rp in self.rps:
            rp.issuer = self.issuer
            rp.tls_context = ssl.create_default_context(cafile=str(directory / 'tls.crt'))
        self.binary = directory / 'sso-server'
        print('Fixture: build stock OP', flush=True)
        run_checked(['go', 'build', '-mod=readonly', '-p=4', '-o', str(self.binary), './cmd/sso-server'],
                    cwd=self.backend_repo)
        print('Fixture: create disposable credentials/config', flush=True)
        self.write_password(directory)
        self.config_path = directory / 'config.yaml'
        self.config_path.write_text(yaml.safe_dump(self.configuration(backend_port)))
        self.start_backend()

    def configuration(self, backend_port):
        return fixture_config(self.directory, self.issuer, backend_port,
                              [rp.client_config() for rp in self.rps])

    def start_backend(self):
        require(self.process is None or self.process.poll() is not None,
                'Fixture OP is already running')
        self.process = self.launch_backend(self.backend, self.config_path)

    def launch_backend(self, backend, config_path):
        print('Fixture: start stock OP', flush=True)
        process = subprocess.Popen([str(self.binary), '-config', str(config_path), '-grpc-listen', ''],
                                   cwd=self.directory, env=fixture_environment(),
                                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        self.stack.callback(self.stop_backend, process)
        wait_ready(backend, process)
        print('Fixture: stock OP ready', flush=True)
        return process

    def stop_backend(self, process):
        stop_process(process)

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
        digest = run_checked(['go', 'run', '-mod=readonly', str(helper)], cwd=self.backend_repo,
                             input=FIXTURE_PASSWORD.encode())
        password_file = directory / 'user.bcrypt'
        password_file.write_bytes(digest)
        password_file.chmod(0o600)


class SharedStoreFixture(BrowserFixture):
    """Two sequential stock processes sharing new owned SQLite/key state, NOT HA.

    Public YAML: backend docs/config-reference.md (storage toggles),
    config/config_identity.go, config/config_oauth2.go, config/config_self.go and
    config/config_keys.go (keys.signing.key_file). No SDK adapter or SQL writes.
    """

    replaced = False

    def configuration(self, backend_port):
        config = super().configuration(backend_port)
        config['identity']['session_backend'] = 'sqlite'
        config['oauth'].update(backend='sqlite', sqlite={'dsn': f'file:{self.directory}/oauth.db'})
        config['self_service']['consent'] = {
            'backend': 'sqlite', 'sqlite': {'dsn': f'file:{self.directory}/consent.db'},
        }
        config['keys']['signing']['key_file'] = str(self.directory / 'op-signing.pem')
        return config

    def replace_instance(self):
        require(not self.replaced and self.process is not None and self.process.poll() is None,
                'Fixture replacement requires its first live owned process')
        require((self.directory / 'op-signing.pem').is_file(), 'Stock OP did not persist its fixture key')
        first = self.process
        stop_process(first)
        require(first.poll() is not None, 'First fixture OP did not stop')
        # Stable gateway/issuer/config/key/store/browser/cookie; no in-flight request.
        self.start_backend()
        require(self.process.pid != first.pid, 'Fixture did not start a distinct stock process')
        self.replaced = True
        print('Phase: first owned OP stopped; replacement stock process ready (not session proof)')


# SkipConsent applies only to newly created temporary clients. Baseline covers
# (True, False); only the missing pairs and process-persistence case are added.
CASES = {'inverse': (False, True), 'both-required': (False, False),
         'both-skipped': (True, True), 'shared-store': (False, False)}


def run_case(playwright, backend, web, gateway, channel, case):
    factory = SharedStoreFixture if case == 'shared-store' else BrowserFixture
    with factory(backend, web, gateway, consent_skips=CASES[case]) as fixture:
        browser = playwright.chromium.launch(headless=True, channel=channel)
        try:
            print('Case:', case, '; gateway:', gateway, '; Chromium:', browser.version, flush=True)
            evidence = run_normal_case(browser, fixture,
                                       replace_instance=fixture.replace_instance if case == 'shared-store' else None,
                                       isolated_login=case == 'both-required')
            if case == 'shared-store':
                require(fixture.replaced, 'Shared-store case did not replace its stock process')
                print('PASS: B real UI resume + A/B grants after stock-process replacement; local persistence only, NOT HA')
            print('Evidence:', json.dumps({'case': case, 'gateway': gateway, **evidence}, sort_keys=True))
        finally:
            browser.close()
