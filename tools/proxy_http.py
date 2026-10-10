"""HTTP framing for the local SPA/API proxy; bodies remain opaque bytes."""

import urllib.parse
import urllib.request


MAX_HEADER_BYTES = 65536
HOP_BY_HOP = frozenset({
    'connection', 'keep-alive', 'proxy-authenticate', 'proxy-authorization',
    'te', 'trailer', 'transfer-encoding', 'upgrade',
})


class InvalidRequest(ValueError):
    """Incomplete or ambiguous framing must never reach a mutation endpoint."""


def recv_full(conn, size):
    chunks = []
    remaining = size
    while remaining > 0:
        chunk = conn.recv(min(remaining, 65536))
        if not chunk:
            raise InvalidRequest('Incomplete request body')
        chunks.append(chunk)
        remaining -= len(chunk)
    return b''.join(chunks)


def parse_request(conn):
    data = bytearray()
    while b'\r\n\r\n' not in data:
        chunk = conn.recv(65536)
        if not chunk:
            if not data:
                return None, None, None, None
            raise InvalidRequest('Incomplete request headers')
        data.extend(chunk)
        if data.find(b'\r\n\r\n') < 0 and len(data) > MAX_HEADER_BYTES:
            raise InvalidRequest('Request headers are too large')
    head, received = bytes(data).split(b'\r\n\r\n', 1)
    if len(head) > MAX_HEADER_BYTES:
        raise InvalidRequest('Request headers are too large')
    lines = head.decode('iso-8859-1').split('\r\n')
    parts = lines[0].split()
    if (len(parts) != 3 or not parts[2].startswith('HTTP/1.') or
            not parts[1].startswith('/') or parts[1].startswith('//')):
        raise InvalidRequest('Invalid request target')
    method, path = parts[:2]
    headers = {}
    for line in lines[1:]:
        key, separator, value = line.partition(':')
        if not separator or not key or key != key.strip():
            raise InvalidRequest('Invalid request header')
        key = key.lower()
        if key in headers and key in ('content-length', 'transfer-encoding'):
            raise InvalidRequest('Ambiguous request framing')
        headers[key] = value.strip()
    if 'transfer-encoding' in headers:
        raise InvalidRequest('Transfer-Encoding is not supported')
    length = headers.get('content-length', '0')
    if not length.isascii() or not length.isdecimal():
        raise InvalidRequest('Invalid Content-Length')
    length = int(length)
    body = None
    if length:
        body = received[:length]
        body += recv_full(conn, length - len(body))
    return method, path, headers, body


def hop_headers(headers_items):
    items = list(headers_items)
    nominated = {
        name.strip().lower()
        for key, value in items if key.lower() == 'connection'
        for name in value.split(',')
    }
    return HOP_BY_HOP | nominated


def response_head(status, headers_items, *, length=None, reason=''):
    items = list(headers_items)
    excluded = hop_headers(items) | {'content-length', 'access-control-allow-origin'}
    lines = [f'HTTP/1.1 {status}' + (f' {reason}' if reason else ''),
             'Access-Control-Allow-Origin: *']
    lines.extend(f'{key}: {value}' for key, value in items
                 if key.lower() not in excluded)
    if length is not None:
        lines.append(f'Content-Length: {length}')
    lines.extend(['Connection: close', '', ''])
    return '\r\n'.join(lines).encode('iso-8859-1')


def forward_response(conn, status, headers_items, body, reason=''):
    # urllib does not decompress responses. Preserve Content-Encoding so the
    # browser can decode gzip bytes, including compressed upstream errors.
    conn.sendall(response_head(status, headers_items, length=len(body),
                               reason=reason) + body)


def forward_stream_response(conn, response, *, headers_items=None):
    # SSE must deliver headers and each available chunk without waiting for
    # the upstream to close. Connection-close framing works after urllib has
    # removed the upstream's transfer-encoding framing.
    items = response.headers.items() if headers_items is None else headers_items
    conn.sendall(response_head(response.status, items))
    while True:
        chunk = response.read1(65536)
        if not chunk:
            return
        conn.sendall(chunk)


class NoRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Relay redirects to the caller. Never follow them with its bearer or
        # turn a proxied mutation into a different request behind its back.
        return None


def valid_origin(value):
    try:
        uri = urllib.parse.urlsplit(value)
        return (uri.scheme in ('http', 'https') and bool(uri.hostname)
                and uri.username is None and uri.password is None
                and uri.path in ('', '/') and not uri.query and not uri.fragment
                and (uri.port is None or 0 < uri.port < 65536)
                and not any(char.isspace() for char in value))
    except ValueError:
        return False


def upstream_opener():
    return urllib.request.build_opener(NoRedirect())
