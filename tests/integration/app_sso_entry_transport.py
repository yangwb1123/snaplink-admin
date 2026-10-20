"""Fixture-only identity ingress. Never rewrite discovery or retry a request."""

import http.client
from http.server import BaseHTTPRequestHandler, HTTPServer
import ipaddress
import json
import ssl
import threading
import urllib.parse

from browser_sso_fixture import start_server
from browser_sso_rp import require

LIMIT = 65536
HOP = {'connection', 'keep-alive', 'transfer-encoding', 'te', 'trailer',
       'upgrade', 'proxy-authorization', 'proxy-authenticate', 'content-length'}
PATHS = {'/auth/login', '/.well-known/openid-configuration', '/.well-known/jwks.json',
         '/health', '/readyz', '/branding', '/token', '/userinfo'}


def connection_for(url, tls_context=None):
    target = urllib.parse.urlsplit(url)
    require(target.scheme in ('http', 'https') and target.hostname and
            target.username is None and target.password is None and not target.fragment,
            'Fixture HTTP target is invalid')
    require(ipaddress.ip_address(target.hostname).is_loopback and target.port,
            'Fixture HTTP target is not owned loopback')
    connection = (http.client.HTTPSConnection(target.hostname, target.port, timeout=5,
                  context=tls_context or ssl.create_default_context()) if target.scheme == 'https'
                  else http.client.HTTPConnection(target.hostname, target.port, timeout=5))
    return connection, target


def get_document(url, tls_context, *, accept='application/json'):
    connection, target = connection_for(url, tls_context)
    try:
        connection.request('GET', urllib.parse.urlunsplit(('', '', target.path, target.query, '')),
                           headers={'Accept': accept, 'Cache-Control': 'no-cache'})
        with connection.getresponse() as response:
            raw = response.read(LIMIT + 1)
            require(len(raw) <= LIMIT, 'Fixture HTTP response exceeded its budget')
            return response.status, {key.lower(): value for key, value in response.getheaders()}, raw
    finally:
        connection.close()


def get_json(url, tls_context):
    status, headers, raw = get_document(url, tls_context)
    require(status == 200 and headers.get('content-type', '').split(';')[0] == 'application/json',
            'Fixture discovery response is not HTTP 200 JSON')
    data = json.loads(raw)
    require(isinstance(data, dict), 'Fixture discovery response is not an object')
    return raw, data


def provider_contract(status, headers):
    require(status == 200 and headers.get('content-type', '').split(';')[0] == 'application/json',
            'Authorization navigation did not return provider JSON')
    require('location' not in headers and 'set-cookie' not in headers,
            'Provider discovery redirected or issued a cookie')
    require('no-store' in headers.get('cache-control', '') and headers.get('pragma') == 'no-cache',
            'Provider discovery lost its no-store/no-cache contract')


class IdentityIngress:
    def __init__(self, stack, backend, *, secondary=None):
        self.backends = {1: backend, **({2: secondary} if secondary is not None else {})}
        require(len(set(self.backends.values())) == len(self.backends), 'Replica listeners must be distinct')
        for origin in self.backends.values():
            connection, target = connection_for(origin)
            connection.close()
            require(target.scheme == 'http' and not target.path and not target.query,
                    'Replica upstream must be an owned loopback HTTP origin')
        self.replica, self.canonical = 1, None
        self.active, self.failed = False, False
        self.counts, self.replica_counts, self.cookie_responses = {}, {}, {}
        self.lock = threading.Lock()
        self.idle = threading.Condition(self.lock)
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass

            def do_GET(self):
                self.forward()

            def do_POST(self):
                self.forward()

            def forward(self):
                with owner.lock:
                    owner.active = True
                try:
                    owner.forward(self)
                except Exception:
                    owner.failed = True
                    self.send_error(502, 'Owned identity ingress failed')
                finally:
                    with owner.idle:
                        owner.active = False
                        owner.idle.notify_all()

        class Server(HTTPServer):
            def handle_error(self, *_):
                owner.failed = True

            def get_request(self):
                sock, address = super().get_request()
                sock.settimeout(5)
                return sock, address

        self.server = start_server(stack, Server(('127.0.0.1', 0), Handler))
        self.origin = f'http://127.0.0.1:{self.server.server_port}'

    def wait_idle(self):
        with self.idle:
            require(self.idle.wait_for(lambda: not self.active, timeout=5) and not self.failed,
                    'Identity ingress did not drain its completed transaction')

    def select(self, replica):
        with self.lock:
            require(type(replica) is int and replica in self.backends and not self.active and not self.failed,
                    'Identity ingress cannot select that replica or switch during a request')
            self.replica = replica  # In-process control only; no retry/fallback or control endpoint.

    def canonicalize(self, issuer):
        with self.lock:
            require(not self.active, 'Identity ingress cannot change during a request')
            connection, target = connection_for(issuer)
            connection.close()
            require(target.scheme == 'https' and not target.query and target.path == '',
                    'Fixture canonical origin is invalid')
            self.canonical = target.netloc

    def forward(self, handler):
        target = urllib.parse.urlsplit(handler.path)
        require(target.path in PATHS and not target.scheme and not target.netloc,
                'Identity ingress rejected an unexpected path')
        require(not handler.headers.get('Transfer-Encoding') and
                len(handler.headers.get_all('Content-Length', [])) <= 1,
                'Identity ingress rejected ambiguous framing')
        length = int(handler.headers.get('Content-Length', '0'))
        require(0 <= length <= LIMIT, 'Identity ingress request exceeded its budget')
        body = handler.rfile.read(length) if length else None
        require(body is None or len(body) == length, 'Identity ingress body is incomplete')
        nominated = set(handler.headers.get('Connection', '').lower().split(','))
        headers = {key: value for key, value in handler.headers.items()
                   if key.lower() not in HOP | nominated}
        if self.canonical is not None:
            headers = {key: value for key, value in headers.items()
                       if key.lower() not in {'host', 'forwarded', 'x-forwarded-host', 'x-forwarded-proto'}}
            headers.update({'Host': self.canonical, 'X-Forwarded-Host': self.canonical,
                            'X-Forwarded-Proto': 'https'})
        key = (handler.command, target.path)
        self.counts[key] = self.counts.get(key, 0) + 1
        replica_key = (self.replica, *key)
        self.replica_counts[replica_key] = self.replica_counts.get(replica_key, 0) + 1
        connection, _ = connection_for(self.backends[self.replica])
        try:
            connection.request(handler.command, handler.path, body, headers)
            with connection.getresponse() as response:
                raw = response.read(LIMIT + 1)
                require(len(raw) <= LIMIT, 'Identity ingress response exceeded its budget')
                handler.send_response(response.status)
                nominated = set(response.getheader('Connection', '').lower().split(','))
                for name, value in response.getheaders():
                    if name.lower() == 'set-cookie' and value.split('=', 1)[0].strip() == 'snaplink_op_session':
                        self.cookie_responses[self.replica] = self.cookie_responses.get(self.replica, 0) + 1
                    if name.lower() not in HOP | nominated:
                        handler.send_header(name, value)
                handler.send_header('Content-Length', str(len(raw)))
                handler.end_headers()
                handler.wfile.write(raw)
        finally:
            connection.close()
