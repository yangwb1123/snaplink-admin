#!/usr/bin/env python3
"""Native SharedWorker denial, with unguarded capability/attack controls.

Only owned numeric-loopback HTTP is used; this is browser-policy evidence, not
an HTTP operator plan, stock UI, target authentication or a TLS bypass. Bodies
are random synthetic JSON, compared only in memory and never printed/captured.
Also loaded by browser_sso_redirect_test.py, so its normal command executes us.
"""

import argparse
from contextlib import contextmanager, ExitStack
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

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT))
sys.path.insert(0, str(ROOT / 'tests/unit'))
from sso_acceptance_support import plan
from tools.browser_sso_acceptance import clean_environment
from tools.browser_sso_browser import browser_context, WORKER_ISOLATION_ARGS
from tools.browser_sso_guard import Guard
from tools.browser_sso_plan import Failure
from tools.browser_sso_protocol import RP
from playwright.sync_api import sync_playwright


# No JS override is installed: these are actual native constructors in fresh
# realms. Blob URLs are created in that realm, not borrowed from the parent.
ATTACK = '''async ({entry, kind, source, scriptURL}) => {
  let realm = window;
  if (entry === 'srcdoc' || entry === 'blank-frame') {
    const frame = document.createElement('iframe');
    const loaded = new Promise((resolve, reject) => {
      const timer = setTimeout(() => reject(new Error('Frame timeout')), 2000);
      frame.onload = () => {clearTimeout(timer); resolve();};
    });
    if (entry === 'srcdoc') frame.srcdoc = '<!doctype html><body></body>';
    else frame.src = 'about:blank';
    document.body.append(frame);
    await loaded;
    realm = frame.contentWindow;
  }
  const result = {shared_type:typeof realm.SharedWorker};
  const url = source === 'blob' ? realm.URL.createObjectURL(
    new realm.Blob([scriptURL.script], {type:'application/javascript'})) : scriptURL.url;
  try {
    const options = {type:kind, name:scriptURL.name};
    const worker = entry === 'reflect' ? Reflect.construct(realm.SharedWorker, [url, options]) :
                                        new realm.SharedWorker(url, options);
    result.constructed = true;
    const completed = await new Promise(resolve => {
      const timer = setTimeout(() => resolve({outcome:'timeout'}), 2500);
      worker.port.onmessage = e => {clearTimeout(timer); resolve(e.data);};
      worker.onerror = () => {clearTimeout(timer); resolve({outcome:'worker_error'});};
      worker.port.start();
    });
    worker.port.close();
    Object.assign(result, completed);
  } catch (error) { result.outcome = 'constructor_denied'; result.error_type = error.name; }
  if (source === 'blob') realm.URL.revokeObjectURL(url);
  return result;
}'''

NESTED = r'''async kind => {
  const script = (kind === 'module' ? 'export {};\n' : '') +
                 `postMessage({shared_type:typeof SharedWorker,worker_type:typeof Worker});`;
  const url = URL.createObjectURL(new Blob([script], {type:'application/javascript'}));
  const result = await new Promise(resolve => {
    const worker = new Worker(url, {type:kind});
    const timer = setTimeout(() => {worker.terminate();resolve({outcome:'timeout'});}, 2500);
    worker.onmessage = e => {clearTimeout(timer);worker.terminate();resolve(e.data);};
    worker.onerror = () => {clearTimeout(timer);worker.terminate();resolve({outcome:'worker_error'});};
  });
  URL.revokeObjectURL(url);
  return result;
}'''


class OwnedAttack:
    def __init__(self, stack):
        self.counts = {'scripts': 0, 'initial': 0, 'forbidden': 0, 'forbidden_posts': 0,
                       'initial_matches': False, 'forbidden_matches': False}
        self.script = b''
        self.body = b''
        self.origin = self.listener(stack, False)
        self.trap = self.listener(stack, True)

    def listener(self, stack, trap):
        attack = self
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
            def do_GET(self):
                self.respond()
            def do_POST(self):
                self.respond()
            def do_OPTIONS(self):
                self.respond()
            def respond(self):
                body = self.rfile.read(min(int(self.headers.get('Content-Length', 0)), 8193))
                content, status, location = b'{}', 200, None
                mime = 'application/json'
                if trap:
                    attack.counts['forbidden'] += 1
                    if self.command == 'POST':
                        attack.counts['forbidden_posts'] += 1
                        attack.counts['forbidden_matches'] = body == attack.body
                elif self.command == 'POST' and self.path == '/auth/login':
                    attack.counts['initial'] += 1
                    attack.counts['initial_matches'] = body == attack.body
                    status, location = 307, attack.trap + '/forbidden'
                elif self.path == '/app/shared.js':
                    attack.counts['scripts'] += 1
                    content, mime = attack.script, 'application/javascript'
                else:
                    content, mime = b'<!doctype html><body></body>', 'text/html'
                self.send_response(status)
                self.send_header('Content-Type', mime)
                self.send_header('Content-Length', str(len(content)))
                self.send_header('Cache-Control', 'no-store')
                self.send_header('Access-Control-Allow-Origin', '*')
                self.send_header('Access-Control-Allow-Headers', 'content-type,cache-control')
                if location:
                    self.send_header('Location', location)
                self.end_headers()
                self.wfile.write(content)
        server = ThreadingHTTPServer(('127.0.0.1', 0), Handler)
        server.daemon_threads = True
        thread = threading.Thread(target=server.serve_forever, kwargs={'poll_interval': .05}, daemon=True)
        thread.start()
        def close():
            server.shutdown()
            server.server_close()
            thread.join(2)
        stack.callback(close)
        return f'http://127.0.0.1:{server.server_port}'

    def prepare(self, guard, redirect, kind):
        guard.credential = {'username': secrets.token_urlsafe(12), 'password': secrets.token_urlsafe(32)}
        guard.armed = 'primary'
        self.body = json.dumps({**guard.payload(), 'provider': 'password', 'credential': guard.credential}).encode()
        destination = self.origin + '/auth/login' if redirect else self.trap + '/forbidden'
        options = {'method': 'POST', 'mode': 'no-cors', 'headers': {'Content-Type': 'text/plain'},
                   'body': self.body.decode()}
        self.script = ('self.onconnect=e=>{const port=e.ports[0];port.start();const result={outcome:"done",'
                       'nested_shared_type:typeof SharedWorker,nested_worker_type:typeof Worker};'
                       'fetch(' + json.dumps(destination) + ',' + json.dumps(options) + ')'
                       '.then(()=>port.postMessage(result))'
                       '.catch(()=>port.postMessage({...result,outcome:"fetch_failed"}));};').encode()
        if kind == 'module':
            self.script = b'export {};\n' + self.script


class ChromeSharedWorkerBoundaryTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.stack = ExitStack()
        cls.addClassCleanup(cls.stack.close)
        home = cls.stack.enter_context(tempfile.TemporaryDirectory(prefix='sso-shared-chrome-'))
        cls.stack.enter_context(patch.dict(os.environ, {'HOME': home}))
        cls.stack.enter_context(clean_environment())
        cls.playwright = cls.stack.enter_context(sync_playwright())

    @contextmanager
    def launch(self, deny):
        # Same installed Chrome, transport and environment on both sides. The
        # control deliberately omits only the native SharedWorker disable flag.
        args = ['--enable-automation', '--no-proxy-server', '--disable-breakpad', '--disable-crash-reporter',
                '--disable-background-networking', '--disable-component-update', '--disable-sync', '--no-first-run']
        if deny:
            args.extend(arg for arg in WORKER_ISOLATION_ARGS if arg not in args)
        browser = self.playwright.chromium.launch(channel='chrome', headless=True, env=dict(os.environ), args=args)
        try:
            yield browser
        finally:
            browser.close()

    def guard(self, origin):
        data = plan()
        old = data['op']['origin']
        data['op'] = {k: v.replace(old, origin) for k, v in data['op'].items()}
        rps = [RP(data, cfg, None, time.monotonic() + 20) for cfg in data['rps']]
        return data, rps, Guard(data, rps)

    def test_native_shared_worker_denial_has_zero_direct_or_307_egress_across_realms(self):
        executed, denied = 0, 0
        for restricted in (False, True):
            with self.launch(restricted) as browser:
                for entry in ('window', 'reflect', 'srcdoc', 'blank-frame'):
                    for source in ('url', 'blob'):
                        for kind in ('classic', 'module'):
                            for redirect in (False, True):
                                with self.subTest(restricted=restricted, entry=entry, source=source,
                                                  kind=kind, redirect=redirect), ExitStack() as stack:
                                    attack = OwnedAttack(stack)
                                    data, rps, guard = self.guard(attack.origin)
                                    if restricted:
                                        context, page = browser_context(browser, data, guard)
                                    else:
                                        context = browser.new_context(service_workers='block', ignore_https_errors=False)
                                        page = context.new_page()
                                    stack.callback(context.close)
                                    attack.prepare(guard, redirect, kind)
                                    page.goto(rps[0].authorization_url(), wait_until='domcontentloaded', timeout=5000)
                                    result = page.evaluate(ATTACK, {'entry': entry, 'kind': kind, 'source': source,
                                        'scriptURL': {'script': attack.script.decode(), 'url': attack.origin + '/app/shared.js',
                                                      'name': secrets.token_hex(8)}})
                                    # Listener observations are independent of JS exceptions and Guard.
                                    # Drain pending browser work before independently inspecting all sinks.
                                    page.wait_for_timeout(150)
                                    context.close()  # No later worker activity can outlive the observation.
                                    time.sleep(.05)
                                    counts = attack.counts
                                    if restricted:
                                        self.assertEqual(counts, {'scripts': 0, 'initial': 0, 'forbidden': 0,
                                            'forbidden_posts': 0, 'initial_matches': False, 'forbidden_matches': False})
                                        self.assertEqual(result.get('outcome'), 'constructor_denied')
                                        self.assertEqual(result['shared_type'], 'undefined')
                                        self.assertIsNone(guard.failure)
                                        self.assertEqual((guard.primary, guard.resume, guard.consent), (0, 0, [0, 0]))
                                        denied += 1
                                    else:
                                        self.assertEqual(result.get('outcome'), 'done')
                                        self.assertTrue(result.get('constructed'))
                                        self.assertEqual(result['nested_shared_type'], 'undefined')
                                        self.assertEqual(counts['scripts'], int(source == 'url'))
                                        self.assertEqual((counts['initial'], counts['forbidden'], counts['forbidden_posts']),
                                                         (int(redirect), 1, 1))
                                        self.assertTrue(counts['forbidden_matches'])
                                        self.assertEqual(counts['initial_matches'], redirect)
                                        executed += 1
        self.assertEqual((executed, denied), (32, 32))
        print(json.dumps({'shared_worker_supported_attack_controls': executed,
                          'native_denials_with_zero_listener_requests': denied,
                          'shared_worker_nested_constructor': 'unsupported_in_installed_chrome'}, sort_keys=True))

    def test_dedicated_classic_and_module_nested_shared_constructor_is_unsupported(self):
        observations = []
        for restricted in (False, True):
            with self.launch(restricted) as browser, ExitStack() as stack:
                attack = OwnedAttack(stack)
                data, rps, guard = self.guard(attack.origin)
                if restricted:
                    context, page = browser_context(browser, data, guard)
                else:
                    context = browser.new_context(service_workers='block', ignore_https_errors=False)
                    page = context.new_page()
                stack.callback(context.close)
                page.goto(rps[0].authorization_url(), wait_until='domcontentloaded', timeout=5000)
                for kind in ('classic', 'module'):
                    result = page.evaluate(NESTED, kind)
                    self.assertEqual(result, {'shared_type': 'undefined', 'worker_type': 'function'})
                    observations.append({'restricted': restricted, 'dedicated_kind': kind, 'nested_shared': 'unsupported'})
                page.wait_for_timeout(150)
                self.assertEqual((attack.counts['initial'], attack.counts['forbidden'], attack.counts['scripts']), (0, 0, 0))
                self.assertIsNone(guard.failure)
        print(json.dumps({'nested_capabilities': observations}, sort_keys=True))

    def test_unflagged_chrome_is_rejected_before_any_context_navigation(self):
        with self.launch(False) as browser, ExitStack() as stack:
            attack = OwnedAttack(stack)
            data, _, guard = self.guard(attack.origin)
            with self.assertRaises(Failure) as raised:
                browser_context(browser, data, guard)
            self.assertEqual(raised.exception.state, 'browser_boundary_violation')
            self.assertEqual(browser.contexts, [])
            self.assertEqual((attack.counts['scripts'], attack.counts['initial'], attack.counts['forbidden']), (0, 0, 0))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--browser-channel', choices=('chrome',), required=True)
    parser.parse_args()
    unittest.main(argv=[sys.argv[0]], verbosity=2)
