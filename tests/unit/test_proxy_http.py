import gzip
import http.client
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import socket
import threading
import unittest
from contextlib import contextmanager
from unittest.mock import patch

from tools import proxy_http, robust_proxy


class FragmentedConnection:
    def __init__(self, chunks):
        self.chunks = list(chunks)

    def recv(self, size):
        if not self.chunks:
            return b''
        data = self.chunks.pop(0)
        if len(data) > size:
            self.chunks.insert(0, data[size:])
        return data[:size]


class RequestFramingTest(unittest.TestCase):
    def test_fragmented_headers_and_utf8_binary_body_are_preserved(self):
        body = '{"title":"会话"}'.encode() + b'\x00\xff'
        conn = FragmentedConnection([
            b'POST /api/v1/conversations HTTP/1.1\r\nAu',
            b'thorization: Bearer fixture\r\nContent-Len',
            f'gth: {len(body)}\r\nIdempotency-Key: original\r\n\r'.encode(),
            b'\n' + body[:11], body[11:13], body[13:],
        ])
        method, path, headers, received = robust_proxy.parse_request(conn)
        self.assertEqual(method, 'POST')
        self.assertEqual(path, '/api/v1/conversations')
        self.assertEqual(headers['authorization'], 'Bearer fixture')
        self.assertEqual(headers['idempotency-key'], 'original')
        self.assertEqual(received, body)

    def test_incomplete_and_ambiguous_requests_are_rejected(self):
        cases = (
            b'POST /api/v1/test HTTP/1.1\r\nContent-Length: 4\r\n\r\n{}',
            b'GET /health HTTP/1.1\r\nHost: example',
            b'POST /api/v1/test HTTP/1.1\r\nContent-Length: -1\r\n\r\n',
            b'POST /api/v1/test HTTP/1.1\r\nContent-Length: x\r\n\r\n',
            b'POST /api/v1/test HTTP/1.1\r\nContent-Length: 2\r\nContent-Length: 4\r\n\r\n{}',
            b'POST /api/v1/test HTTP/1.1\r\nTransfer-Encoding: chunked\r\n\r\n',
            b'GET http://foreign.test/health HTTP/1.1\r\n\r\n',
            b'GET //foreign.test/health HTTP/1.1\r\n\r\n',
            b'GET /health HTTP/1.1\r\n' + b'X-Large: ' + b'a' * 65536,
        )
        for raw in cases:
            with self.subTest(raw=raw[:80]):
                with self.assertRaises(proxy_http.InvalidRequest):
                    robust_proxy.parse_request(FragmentedConnection([raw]))

    def test_hop_headers_are_removed_but_auth_and_concurrency_survive(self):
        headers = robust_proxy._forward_headers({
            'host': 'console.test',
            'connection': 'keep-alive, X-Hop',
            'x-hop': 'private hop',
            'forwarded': 'for=spoofed',
            'x-forwarded-proto': 'spoofed',
            'authorization': 'Bearer fixture',
            'idempotency-key': 'original',
            'if-match': 'version-1',
        }, 'http://upstream.test')
        self.assertNotIn('connection', headers)
        self.assertNotIn('x-hop', headers)
        self.assertNotIn('forwarded', headers)
        self.assertEqual(headers['authorization'], 'Bearer fixture')
        self.assertEqual(headers['idempotency-key'], 'original')
        self.assertEqual(headers['if-match'], 'version-1')
        self.assertEqual(headers['Host'], 'console.test')
        self.assertEqual(headers['X-Forwarded-Proto'], 'http')


class OriginValidationTest(unittest.TestCase):
    def test_only_http_origins_without_credentials_or_paths_are_accepted(self):
        for value in ('http://localhost:8080', 'https://forge.test', 'http://[::1]:9000/'):
            with self.subTest(valid=value):
                self.assertTrue(proxy_http.valid_origin(value))
        for value in ('', 'forge.test', 'ftp://forge.test', 'http://forge.test/api',
                      'https://user:private@forge.test', 'https://forge.test?token=private',
                      'https://forge.test#fragment', 'http://forge.test:99999',
                      'https://forge.test\r\nInjected: private'):
            with self.subTest(invalid=value):
                self.assertFalse(proxy_http.valid_origin(value))
        with patch.object(robust_proxy, 'FORGE_BACKEND', 'https://user:private@forge.test'), \
                patch.object(robust_proxy, '_forward_response') as forward, \
                patch.object(robust_proxy.UPSTREAM_OPENER, 'open') as upstream:
            robust_proxy.proxy_request(object(), 'GET', '/api/v1/conversations', {}, None)
            upstream.assert_not_called()
            error = json.loads(forward.call_args.args[3])['error']
            self.assertEqual(forward.call_args.args[1], 503)
            self.assertEqual(error['code'], 'forge_invalid_upstream')
            self.assertNotIn('private', error['message'])


class ProxyTransportTest(unittest.TestCase):
    def setUp(self):
        self.seen = []
        self.release_stream = threading.Event()
        owner = self

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *args):
                pass

            def do_POST(self):
                self.do_GET()

            def do_GET(self):
                body = self.rfile.read(int(self.headers.get('Content-Length', 0)))
                owner.seen.append((self.command, self.path, self.headers, body))
                if self.path in ('/api/v1/stream', '/api/v1/conversation-changes/stream'):
                    self.send_response(200)
                    self.send_header('Content-Type', 'text/event-stream')
                    self.send_header('Set-Cookie', 'snaplink_op_session=fixture; Path=/; HttpOnly')
                    self.end_headers()
                    self.wfile.write(b'data: {"state":"ready"}\n\n')
                    self.wfile.flush()
                    owner.release_stream.wait(5)
                    return
                if self.path == '/api/v1/redirect':
                    self.send_response(302)
                    self.send_header('Location', owner.origin + '/api/v1/foreign')
                    self.end_headers()
                    return
                status = 403 if self.path == '/api/v1/denied' else 200
                if self.path == '/api/v1/failure':
                    status = 500
                payload = gzip.compress(json.dumps({'status': status}).encode())
                self.send_response(status)
                self.send_header('Content-Type', 'application/json')
                self.send_header('Content-Encoding', 'gzip')
                self.send_header('Content-Length', str(len(payload)))
                self.send_header('Cache-Control', 'no-store')
                self.send_header('Set-Cookie', 'snaplink_op_session=fixture; Path=/; HttpOnly; Secure; SameSite=Lax')
                self.send_header('Set-Cookie', 'second_fixture=1; Path=/; HttpOnly')
                self.end_headers()
                self.wfile.write(payload)

        self.server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        self.origin = f'http://127.0.0.1:{self.server.server_port}'
        self.server_thread = threading.Thread(target=self.server.serve_forever,
                                              daemon=True)
        self.server_thread.start()
        self.addCleanup(self.close_server)
        self.backend = patch.object(robust_proxy, 'BACKEND', self.origin)
        self.backend.start()
        self.addCleanup(self.backend.stop)

    def close_server(self):
        self.release_stream.set()
        self.server.shutdown()
        self.server.server_close()
        self.server_thread.join(timeout=3)

    @contextmanager
    def request(self, raw):
        client, downstream = socket.socketpair()
        client.settimeout(2)
        worker = threading.Thread(target=robust_proxy.handle,
                                  args=(downstream,), daemon=True)
        worker.start()
        response = None
        try:
            client.sendall(raw)
            client.shutdown(socket.SHUT_WR)
            response = http.client.HTTPResponse(client)
            response.begin()
            yield response
        finally:
            self.release_stream.set()
            if response is not None:
                response.close()
            client.close()
            worker.join(timeout=3)
            self.assertFalse(worker.is_alive(), 'proxy worker did not finish')

    def get(self, path, extra=''):
        return self.request(
            f'GET {path} HTTP/1.1\r\nHost: console.test\r\n{extra}\r\n'.encode()
        )

    def test_hosted_login_preserves_identity_cookie_headers(self):
        body = b'{"client_id":"rp-b","resume_session":true,"response_type":"code"}'
        raw = (b'POST /auth/login HTTP/1.1\r\nHost: console.test\r\n'
               b'Content-Type: application/json\r\n'
               b'Cookie: snaplink_op_session=fixture\r\n'
               + f'Content-Length: {len(body)}\r\n\r\n'.encode() + body)
        with self.request(raw) as response:
            self.assertEqual(response.status, 200)
            self.assertEqual(response.getheader('Cache-Control'), 'no-store')
            cookies = [value for key, value in response.getheaders()
                       if key.lower() == 'set-cookie']
            self.assertEqual(cookies, [
                'snaplink_op_session=fixture; Path=/; HttpOnly; Secure; SameSite=Lax',
                'second_fixture=1; Path=/; HttpOnly',
            ])
            response.read()
        self.assertEqual(len(self.seen), 1)
        self.assertEqual(self.seen[0][2]['Cookie'], 'snaplink_op_session=fixture')
        self.assertEqual(self.seen[0][3], body)

    def test_independent_apis_never_receive_or_overwrite_op_cookies(self):
        cases = (
            ('/api/v1/agent/instances', 'AGENT_HUB_BACKEND'),
            ('/api/v1/admin/commerce/plans', 'BILLING_BACKEND'),
            ('/api/v1/checkout/sessions', 'STRIPE_ADAPTER_BACKEND'),
            ('/api/v1/audit/events', 'AUDIT_GOVERNANCE_BACKEND'),
            ('/api/v1/conversations', 'FORGE_BACKEND'),
        )
        for path, setting in cases:
            with self.subTest(path=path), patch.object(robust_proxy, setting, self.origin):
                with self.get(path, 'Cookie: snaplink_op_session=fixture\r\n'
                              'Authorization: Bearer scoped-fixture\r\n') as response:
                    self.assertEqual(response.status, 200)
                    self.assertIsNone(response.getheader('Set-Cookie'))
                    response.read()
                self.assertIsNone(self.seen[-1][2].get('Cookie'))
                self.assertEqual(self.seen[-1][2]['Authorization'], 'Bearer scoped-fixture')

    def test_independent_stream_cannot_set_the_op_cookie(self):
        with patch.object(robust_proxy, 'FORGE_BACKEND', self.origin):
            with self.get('/api/v1/conversation-changes/stream',
                          'Cookie: snaplink_op_session=fixture\r\n') as response:
                self.assertEqual(response.status, 200)
                self.assertIsNone(response.getheader('Set-Cookie'))
                event = b'data: {"state":"ready"}\n\n'
                self.assertEqual(response.read(len(event)), event)
            self.assertIsNone(self.seen[-1][2].get('Cookie'))

    def test_end_session_reaches_identity_and_preserves_cookie(self):
        with self.get('/end_session?id_token_hint=fixture',
                      'Cookie: snaplink_op_session=fixture\r\n') as response:
            self.assertEqual(response.status, 200)
            self.assertIn('snaplink_op_session=fixture', response.getheader('Set-Cookie'))
            response.read()
        self.assertEqual(self.seen[0][1], '/end_session?id_token_hint=fixture')
        self.assertEqual(self.seen[0][2]['Cookie'], 'snaplink_op_session=fixture')

    def test_readiness_reaches_upstream_instead_of_spa(self):
        with self.get('/readyz') as response:
            self.assertEqual(response.status, 200)
            self.assertEqual(response.getheader('Content-Type'), 'application/json')
            self.assertEqual(json.loads(gzip.decompress(response.read())), {'status': 200})
        self.assertEqual(self.seen[0][1], '/readyz')

    def test_compressed_json_and_http_errors_preserve_encoding(self):
        for path, status in (('/api/v1/ok', 200), ('/api/v1/denied', 403)):
            with self.subTest(status=status):
                with self.get(path) as response:
                    self.assertEqual(response.status, status)
                    self.assertEqual(response.getheader('Content-Encoding'), 'gzip')
                    self.assertEqual(json.loads(gzip.decompress(response.read())), {'status': status})

    def test_sse_delivers_before_upstream_closes(self):
        with self.get('/api/v1/stream', 'Accept: text/event-stream\r\n') as response:
            self.assertFalse(self.release_stream.is_set())
            event = b'data: {"state":"ready"}\n\n'
            self.assertEqual(response.read(len(event)), event)
            self.assertFalse(self.release_stream.is_set())
            self.assertIsNone(response.getheader('Content-Length'))

    def test_redirect_is_not_followed_with_bearer(self):
        with self.get('/api/v1/redirect', 'Authorization: Bearer fixture\r\n') as response:
            self.assertEqual(response.status, 302)
            self.assertEqual(response.getheader('Location'), self.origin + '/api/v1/foreign')
            response.read()
        self.assertEqual(len(self.seen), 1)
        self.assertEqual(self.seen[0][2]['Authorization'], 'Bearer fixture')

    def test_failed_mutation_is_not_replayed_and_body_is_opaque(self):
        body = b'{"title":"original"}\x00\xff'
        request = (
            b'POST /api/v1/failure HTTP/1.1\r\nHost: console.test\r\n'
            b'Authorization: Bearer fixture\r\nIdempotency-Key: original\r\n'
            + f'Content-Length: {len(body)}\r\n\r\n'.encode() + body
        )
        with self.request(request) as response:
            self.assertEqual(response.status, 500)
            response.read()
        self.assertEqual(len(self.seen), 1)
        self.assertEqual(self.seen[0][3], body)
        self.assertEqual(self.seen[0][2]['Idempotency-Key'], 'original')

    def test_incomplete_mutation_never_reaches_upstream(self):
        with self.request(
            b'POST /api/v1/failure HTTP/1.1\r\nContent-Length: 8\r\n\r\n{}'
        ) as response:
            self.assertEqual(response.status, 400)
            response.read()
        self.assertEqual(self.seen, [])

    def test_preflight_allows_required_request_headers(self):
        with self.request(
            b'OPTIONS /api/v1/conversations HTTP/1.1\r\nHost: console.test\r\n\r\n'
        ) as response:
            self.assertEqual(response.status, 204)
            allowed = response.getheader('Access-Control-Allow-Headers').lower()
            for name in ('idempotency-key', 'if-match', 'last-event-id', 'cache-control'):
                self.assertIn(name, allowed)


if __name__ == '__main__':
    unittest.main()
