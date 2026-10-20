"""Fail-closed browser egress and one-shot password/resume/consent ledger."""

from urllib.parse import urlsplit

from tools.browser_sso_plan import Failure, require, strict_json, text
from tools.browser_sso_protocol import query


class Guard:
    def __init__(self, plan, rps):
        self.plan, self.rps, self.phase = plan, rps, 0
        self.failure, self.credential, self.armed, self.challenge = None, None, None, None
        self.primary, self.resume, self.consent = 0, 0, [0, 0]
        self.discovery = [0, 0]
        self.page = None

    def healthy(self):
        if self.failure:
            raise Failure(self.failure)

    def stop(self, state='browser_boundary_violation'):
        self.failure = self.failure or state

    def payload(self):
        rp = self.rps[self.phase]
        result = {**rp.params, 'scope': rp.config['scopes'], 'provider': ''}
        return result

    def login_request(self, raw):
        require(isinstance(raw, str), 'browser_boundary_violation')
        data = strict_json(raw.encode('utf-8'), 8192)
        rp = self.rps[self.phase]
        if set(data) == {'client_id'} and data['client_id'] == rp.config['client_id']:
            self.discovery[self.phase] += 1
            require(self.discovery[self.phase] <= 3, 'browser_boundary_violation')
            return
        if 'credential' in data:
            require(self.phase == 0 and self.primary == 0 and self.armed == 'primary' and
                    self.credential is not None and
                    data == {**self.payload(), 'provider': 'password', 'credential': self.credential},
                    'browser_boundary_violation')
            self.primary, self.armed, self.credential = 1, None, None
            return
        if data.get('resume_session') is True:
            require(self.phase == 1 and self.resume == 0 and
                    data == {**self.payload(), 'resume_session': True}, 'browser_boundary_violation')
            self.resume = 1
            return
        require(self.challenge is not None and self.armed == 'consent' and
                self.consent[self.phase] == 0 and data == {
                    'client_id': rp.config['client_id'], 'consent_decision': 'allow',
                    **self.challenge}, 'browser_boundary_violation')
        self.challenge, self.armed = None, None  # Before the sole continuation write.
        self.consent[self.phase] += 1

    def route(self, route):
        request = route.request
        try:
            self.healthy()
            url = urlsplit(request.url)
            request_headers = request.all_headers()
            origin = url.scheme + '://' + url.netloc
            require(not url.username and not url.fragment, 'browser_boundary_violation')
            if self.page is not None:
                require(request.frame == self.page.main_frame, 'browser_boundary_violation')
            op = self.plan['op']
            if origin == op['origin']:
                if request.method == 'POST':
                    require(request.url == op['authorization_endpoint'], 'browser_boundary_violation')
                    self.login_request(request.post_data)
                else:
                    require(request.method == 'GET', 'browser_boundary_violation')
                    if url.path == '/login/':
                        expected = query(self.rps[self.phase].authorization_url().split('?', 1)[1], resources=True)
                        require(query(url.query, resources=True) == expected, 'browser_boundary_violation')
                    else:
                        require((url.path.startswith('/app/') and not url.query) or
                                request.url in (op['discovery_url'], op['origin'] + '/branding',
                                                op['origin'] + '/favicon.ico'), 'browser_boundary_violation')
            else:
                rp = self.rps[self.phase]
                require(origin == 'http://' + rp.target.netloc and request.method == 'GET' and
                        not request_headers.get('cookie') and
                        (url.path == '/complete' and not url.query or url.path == '/callback' and bool(url.query)),
                        'browser_boundary_violation')
                if url.path == '/callback':
                    values = query(url.query)
                    require(values.get('state') == [rp.state] and values.get('iss') == [op['issuer']],
                            'browser_boundary_violation')
            # Protocol JSON is uncompressed so response length is enforceable.
            headers = {**request_headers, 'accept-encoding': 'identity', 'cache-control': 'no-store'}
            route.continue_(headers=headers)
        except Failure as error:
            self.stop(error.state)
            route.abort()
        except Exception:
            self.stop()
            route.abort()

    def redirect_response(self, url, method, status, headers):
        """Only the owned RP's fixed, body-free completion redirect is allowed."""
        if not 300 <= status < 400:
            return
        rp = self.rps[self.phase]
        locations = [h['value'] for h in headers if h['name'].lower() == 'location']
        require(method == 'GET' and status == 303 and locations == ['/complete'] and
                url.split('?', 1)[0] == rp.config['redirect_uri'] and '?' in url,
                'redirect_rejected')
        values = query(url.split('?', 1)[1])
        require(values.get('state') == [rp.state] and
                values.get('iss') == [self.plan['op']['issuer']], 'redirect_rejected')

    def response(self, response):
        if response.url != self.plan['op']['authorization_endpoint']:
            return
        try:
            self.healthy()
            headers = response.all_headers()
            length = headers.get('content-length', '')
            require(length.isdigit() and int(length) <= self.plan['limits']['body_bytes'] and
                    headers.get('content-type', '').split(';')[0] == 'application/json' and
                    headers.get('content-encoding', 'identity') == 'identity', 'invalid_response')
            data = strict_json(response.body(), self.plan['limits']['body_bytes'])
            require(data.get('iss') == self.plan['op']['issuer'], 'endpoint_mismatch')
            require(not ({'access_token', 'id_token', 'refresh_token'} & set(data)), 'browser_boundary_violation')
            if 'providers' in data:
                require(data.get('op_session_supported') is True and 'op_session_error' not in data and
                        data.get('op_session_available') is (self.phase == 1), 'capability_unverified')
                return
            if data.get('error') == 'consent_required':
                rp = self.rps[self.phase]
                scopes = data.get('scopes')
                require(rp.config['consent'] == 'required' and not self.challenge and
                        self.consent[self.phase] == 0 and isinstance(scopes, list) and
                        all(isinstance(v, dict) and text(v.get('scope')) for v in scopes) and
                        len(scopes) == len(rp.config['scopes']) and
                        {v['scope'] for v in scopes} == set(rp.config['scopes']) and
                        data.get('client_name') == rp.config['display_name'] and
                        not data.get('authorization_details') and
                        text(data.get('consent_challenge_id')) and text(data.get('login_transaction_id')),
                        'authorization_blocked')
                self.challenge = {key: data[key] for key in ('consent_challenge_id', 'login_transaction_id')}
            else:
                require('error' not in data, 'authorization_blocked')
                require(response.status == 200 and text(data.get('code')) and
                        data.get('redirect_uri_validated') is True and
                        data.get('redirect_uri') == self.rps[self.phase].config['redirect_uri'] and
                        data.get('state') == self.rps[self.phase].state and
                        data.get('response_mode') == 'query', 'authorization_blocked')
        except Failure as error:
            self.stop(error.state)
        except Exception:
            self.stop('invalid_response')

    def completed(self):
        self.healthy()
        require(self.primary == 1 and self.resume == 1 and
                self.consent == [int(r.config['consent'] == 'required') for r in self.rps],
                'acceptance_failed')
