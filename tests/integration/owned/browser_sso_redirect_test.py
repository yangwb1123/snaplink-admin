#!/usr/bin/env python3
"""Owned Chrome redirect prevention only; NOT stock/target authentication.

HTTP is substituted solely to isolate native browser redirect/routing behavior.
No HTTP operator plan is validated/executed and no TLS bypass is used. All
listeners, synthetic in-memory credentials and browser state are freshly owned.
"""

import argparse
from contextlib import ExitStack
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import json
import os
from pathlib import Path
import secrets
import sys
import tempfile
import threading
import time
import unittest
from unittest.mock import patch
from urllib.parse import urlencode

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / 'tests/unit'))
from sso_acceptance_support import plan
from tools.browser_sso_acceptance import clean_environment
from tools.browser_sso_browser import browser_context, WORKER_ISOLATION_ARGS
from tools.browser_sso_guard import Guard
from tools.browser_sso_protocol import RP
from playwright.sync_api import Error, sync_playwright
from browser_sso_shared_worker_test import ChromeSharedWorkerBoundaryTest


class Loopback:
    def __init__(self, stack, respond, host='127.0.0.1'):
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_GET(self):
                respond(self)
            def do_POST(self):
                respond(self)
        self.server = ThreadingHTTPServer((host, 0), Handler)
        self.server.daemon_threads = True
        self.origin = f'http://{host}:{self.server.server_port}'
        self.thread = threading.Thread(target=self.server.serve_forever,
                                       kwargs={'poll_interval': .05}, daemon=True)
        self.thread.start()
        stack.callback(self.close)

    def close(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=2)


def reply(handler, body=b'{}', *, status=200, location=None, content_type='application/json'):
    handler.send_response(status)
    handler.send_header('Content-Type', content_type)
    handler.send_header('Content-Length', str(len(body)))
    handler.send_header('Cache-Control', 'no-store')
    if location is not None:
        handler.send_header('Location', location)
    handler.end_headers()
    handler.wfile.write(body)


class ChromeRedirectBoundaryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.stack = ExitStack()
        cls.addClassCleanup(cls.stack.close)
        home = cls.stack.enter_context(tempfile.TemporaryDirectory(prefix='sso-redirect-chrome-'))
        cls.stack.enter_context(patch.dict(os.environ, {'HOME': home}))
        cls.stack.enter_context(clean_environment())
        playwright = cls.stack.enter_context(sync_playwright())
        cls.browser = playwright.chromium.launch(channel='chrome', headless=True, env=dict(os.environ),
            args=['--no-proxy-server', '--disable-breakpad', '--disable-crash-reporter',
                  '--disable-background-networking', '--disable-component-update', '--disable-sync', '--no-first-run',
                  *WORKER_ISOLATION_ARGS])
        cls.stack.callback(cls.browser.close)

    def setup_guard(self, stack, origin, *, callback=None):
        data = plan()
        old = data['op']['origin']
        data['op'] = {k: v.replace(old, origin) for k, v in data['op'].items()}
        if callback:
            data['rps'][0]['redirect_uri'] = callback
        rps = [RP(data, cfg, None, time.monotonic() + 10) for cfg in data['rps']]
        guard = Guard(data, rps)
        context, page = browser_context(self.browser, data, guard)
        stack.callback(context.close)
        return guard, page, rps

    def wait_for_block(self, page, guard):
        end = time.monotonic() + 2
        while guard.failure is None and time.monotonic() < end:
            page.wait_for_timeout(20)
        page.wait_for_timeout(100)
        self.assertEqual(guard.failure, 'redirect_rejected')

    def write_case(self, status, destination, action, *, worker=False):
        observations = {'initial': 0, 'forbidden': 0, 'body_matches': False}
        state = {}
        def respond(handler):
            if handler.command == 'GET' and handler.path.startswith('/login/?'):
                reply(handler, state['html'], content_type='text/html')
            elif handler.command == 'GET' and handler.path == '/favicon.ico':
                reply(handler)
            elif handler.command == 'POST' and handler.path == '/auth/login' and not observations['initial']:
                observations['initial'] += 1
                body = handler.rfile.read(min(int(handler.headers.get('Content-Length', 0)), 8193))
                observations['body_matches'] = body == state['body']
                reply(handler, status=status, location=state['destination'])
            else:
                observations['forbidden'] += 1
                reply(handler)
        with ExitStack() as stack:
            owned, trap = Loopback(stack, respond), Loopback(stack, respond)
            state['destination'] = {'same_origin': owned.origin + '/forbidden',
                                    'cross_origin': trap.origin + '/forbidden',
                                    'same_endpoint': owned.origin + '/auth/login'}[destination]
            guard, page, rps = self.setup_guard(stack, owned.origin)
            if action == 'primary':
                guard.credential = {'username': secrets.token_urlsafe(12), 'password': secrets.token_urlsafe(32)}
                guard.armed = 'primary'
                payload = {**guard.payload(), 'provider': 'password', 'credential': guard.credential}
            elif action == 'resume':
                guard.phase = 1
                payload = {**guard.payload(), 'resume_session': True}
            else:
                guard.challenge = {'consent_challenge_id': secrets.token_urlsafe(24),
                                   'login_transaction_id': secrets.token_urlsafe(24)}
                guard.armed = 'consent'
                payload = {'client_id': rps[0].config['client_id'], 'consent_decision': 'allow', **guard.challenge}
            state['body'] = json.dumps(payload).encode()
            script = ('fetch(' + json.dumps(owned.origin + '/auth/login') + ', {method:"POST",'
                      'headers:{"Content-Type":"application/json"},body:' + json.dumps(state['body'].decode()) +
                      '}).catch(()=>{});')
            if worker:
                script = 'new Worker(URL.createObjectURL(new Blob([' + json.dumps(script) + '], {type:"application/javascript"})));'
            state['html'] = ('<!doctype html><script>' + script + '</script>').encode()
            page.goto(rps[guard.phase].authorization_url(), wait_until='domcontentloaded', timeout=5000)
            self.wait_for_block(page, guard)
            self.assertEqual(observations['initial'], 1)
            self.assertEqual(observations['forbidden'], 0, 'Redirect destination received a request')
            self.assertTrue(observations['body_matches'], 'Initial synthetic body was changed')
            self.assertEqual(guard.primary, int(action == 'primary'))
            self.assertEqual(guard.resume, int(action == 'resume'))
            self.assertEqual(guard.consent, [int(action == 'consent'), 0])
            self.assertIsNone(guard.credential)
            self.assertIsNone(guard.challenge)

    def test_307_and_308_never_replay_password_resume_or_consent_to_any_destination(self):
        for status in (307, 308):
            for destination in ('same_origin', 'cross_origin', 'same_endpoint'):
                for action in ('primary', 'resume', 'consent'):
                    with self.subTest(status=status, destination=destination, action=action):
                        self.write_case(status, destination, action)

    def test_stock_consent_response_passes_native_barrier_without_replay(self):
        state, counts = {}, {'posts': 0}
        def respond(handler):
            if handler.command == 'POST':
                counts['posts'] += 1
                handler.rfile.read(min(int(handler.headers.get('Content-Length', 0)), 8193))
                reply(handler, json.dumps(state['consent']).encode())
            elif handler.path.startswith('/login/?'):
                reply(handler, state['html'], content_type='text/html')
            else:
                reply(handler)
        with ExitStack() as stack:
            owned = Loopback(stack, respond)
            guard, page, rps = self.setup_guard(stack, owned.origin)
            guard.credential = {'username': secrets.token_urlsafe(12), 'password': secrets.token_urlsafe(32)}
            guard.armed = 'primary'
            payload = {**guard.payload(), 'provider': 'password', 'credential': guard.credential}
            state['consent'] = {'iss': guard.plan['op']['issuer'], 'error': 'consent_required',
                                'client_name': rps[0].config['display_name'],
                                'scopes': [{'scope': scope, 'description': ''} for scope in rps[0].config['scopes']],
                                'consent_challenge_id': secrets.token_urlsafe(24),
                                'login_transaction_id': secrets.token_urlsafe(24)}
            state['html'] = ('<!doctype html><script>fetch("/auth/login", {method:"POST",'
                             'headers:{"Content-Type":"application/json"},body:JSON.stringify(' + json.dumps(payload) +
                             ')}).then(r=>r.json()).then(()=>{document.body.textContent="owned-response-read";});'
                             '</script><body></body>').encode()
            page.goto(rps[0].authorization_url(), wait_until='domcontentloaded', timeout=5000)
            page.get_by_text('owned-response-read', exact=True).wait_for(timeout=5000)
            self.assertIsNone(guard.failure)
            self.assertIsNotNone(guard.challenge)
            self.assertIsNone(guard.armed)
            self.assertIsNone(guard.credential)
            self.assertEqual((counts['posts'], guard.primary, guard.consent), (1, 1, [0, 0]))

    def test_dedicated_worker_redirect_cannot_bypass_response_barrier(self):
        for status in (307, 308):
            with self.subTest(status=status):
                self.write_case(status, 'cross_origin', 'primary', worker=True)

    def test_navigation_and_static_resource_redirects_are_rejected_before_forwarding(self):
        for status in (301, 302, 303, 307, 308):
            for navigation in (True, False):
                for cross in (False, True):
                    with self.subTest(status=status, navigation=navigation, cross_origin=cross), ExitStack() as stack:
                        counts = {'redirects': 0, 'forbidden': 0}
                        state = {}
                        def respond(handler):
                            if (navigation and handler.path.startswith('/login/?') or
                                    not navigation and handler.path == '/app/redirect.js'):
                                counts['redirects'] += 1
                                reply(handler, status=status, location=state['destination'])
                            elif handler.path.startswith('/login/?'):
                                reply(handler, b'<!doctype html><script src="/app/redirect.js"></script>', content_type='text/html')
                            elif handler.path == '/favicon.ico':
                                reply(handler)
                            else:
                                counts['forbidden'] += 1
                                reply(handler)
                        owned, trap = Loopback(stack, respond), Loopback(stack, respond)
                        # /branding would be allowed as an initial read, but not as a redirect hop.
                        state['destination'] = (trap.origin if cross else owned.origin) + '/branding'
                        guard, page, rps = self.setup_guard(stack, owned.origin)
                        try:
                            page.goto(rps[0].authorization_url(), wait_until='domcontentloaded', timeout=5000)
                        except Error:
                            pass  # A rejected navigation is expected; assert the actual policy below.
                        self.wait_for_block(page, guard)
                        self.assertEqual(counts, {'redirects': 1, 'forbidden': 0})

    def test_only_owned_callback_303_to_exact_complete_is_allowed(self):
        for status, location, allowed in ((303, '/complete', True), (307, '/complete', False),
                                           (308, '/complete', False), (303, '/complete?extra=x', False),
                                           (303, '/auth/login', False)):
            with self.subTest(status=status, allowed=allowed), ExitStack() as stack:
                counts = {'callback': 0, 'complete': 0, 'forbidden': 0}
                def respond(handler):
                    if handler.path.startswith('/callback?'):
                        counts['callback'] += 1
                        reply(handler, status=status, location=location)
                    elif handler.path == '/complete':
                        counts['complete'] += 1
                        reply(handler, b'finished', content_type='text/plain')
                    else:
                        counts['forbidden'] += 1
                        reply(handler)
                owned = Loopback(stack, respond)
                callback = Loopback(stack, respond, host='127.0.0.2')
                guard, page, rps = self.setup_guard(stack, owned.origin, callback=callback.origin + '/callback')
                url = rps[0].config['redirect_uri'] + '?' + urlencode({'iss': guard.plan['op']['issuer'],
                                                                        'state': rps[0].state, 'code': secrets.token_urlsafe(24)})
                try:
                    page.goto(url, wait_until='load', timeout=5000)
                except Error:
                    pass
                if allowed:
                    self.assertIsNone(guard.failure)
                    self.assertEqual(page.url, callback.origin + '/complete')
                else:
                    self.wait_for_block(page, guard)
                self.assertEqual(counts, {'callback': 1, 'complete': int(allowed), 'forbidden': 0})


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browser-channel', choices=('chrome',), required=True)
    parser.parse_args()
    unittest.main(argv=[sys.argv[0]], verbosity=2)
