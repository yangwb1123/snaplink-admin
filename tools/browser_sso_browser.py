"""Real fresh Chrome UI driver. No fixture imports, provisioning or storage output."""

from contextlib import ExitStack
import os
import time
from urllib.parse import urlsplit

from tools.browser_sso_guard import Guard
from tools.browser_sso_plan import Failure, load_credentials, require
from tools.browser_sso_protocol import RP, Verifier, same_context
from tools.browser_sso_transport import Transport, preflight, remaining, tls_context


LABELS = {'en-US': ('Username', 'Password', 'Sign in', 'Allow', ' wants access'),
          'zh-CN': ('用户名', '密码', '登录', '允许', ' 请求访问')}
COOKIE = 'snaplink_op_session'
# Native process-wide denial: Playwright does not route SharedWorker targets.
# --enable-automation is required for the CDP command-line attestation below.
WORKER_ISOLATION_ARGS = ('--enable-automation', '--disable-shared-workers')


def timeout(end, ceiling=30000):
    return max(1, min(ceiling, int(remaining(end) * 1000)))


def wait(page, guard, end, condition):
    while True:
        guard.healthy()
        remaining(end)
        if condition():
            return
        page.wait_for_timeout(min(50, timeout(end)))


def semantics(page, guard, rp, end):
    placeholder = page.locator('flt-semantics-placeholder')
    wait(page, guard, end, lambda: rp.done.is_set() or placeholder.count() > 0)
    if not rp.done.is_set():
        placeholder.evaluate('(element) => element.click()', timeout=timeout(end))


def type_field(page, label, value, end):
    # Same stock Flutter focus/frame contract as the fixture, without importing
    # its permissive browser context/transport or synthetic credentials.
    from playwright.sync_api import expect
    field = page.get_by_role('textbox', name=label, exact=True)
    frame = '''() => new Promise((done, fail) => {
      const timer = setTimeout(() => fail(new Error('Editing unavailable')), 5000);
      requestAnimationFrame(() => requestAnimationFrame(() => { clearTimeout(timer); done(); }));
    })'''
    try:
        field.click(timeout=timeout(end))
        expect(field).to_be_focused(timeout=timeout(end, 10000))
        page.evaluate(frame)
        expect(field).to_be_focused(timeout=timeout(end, 10000))
        page.keyboard.type(value, delay=30)
        page.evaluate(frame)
        expect(field).to_have_value(value, timeout=timeout(end, 10000))
        page.keyboard.press('Tab')
        expect(field).to_have_value(value, timeout=timeout(end, 10000))
    except Exception:
        raise Failure('acceptance_failed') from None


def redirect_barrier(context, page, guard):
    """Pause native Chrome responses *before* automatic redirect forwarding.

    Playwright routes only the initial URL of a redirect chain. Keep Chrome's
    TLS/cookie transport (no API fetch/retry) but reject redirect headers before
    they can replay a write or escape the initial request allowlist.
    """
    session = context.new_cdp_session(page)
    def paused(event):
        request_id = event['requestId']
        try:
            guard.healthy()
            request = event['request']
            guard.redirect_response(request['url'], request['method'],
                                    event.get('responseStatusCode', 0), event.get('responseHeaders', []))
            session.send('Fetch.continueRequest', {'requestId': request_id})
            return
        except Failure as error:
            guard.stop(error.state)
        except Exception:
            guard.stop()
        try:
            session.send('Fetch.failRequest', {'requestId': request_id, 'errorReason': 'BlockedByClient'})
        except Exception:
            guard.stop()  # Never continue on an interception/transport failure.
    session.on('Fetch.requestPaused', paused)
    session.send('Fetch.enable', {'patterns': [{'urlPattern': '*', 'requestStage': 'Response'}]})


def require_worker_isolation(browser):
    """Fail closed before creating a context, not after a worker target starts."""
    session = None
    try:
        session = browser.new_browser_cdp_session()
        arguments = session.send('Browser.getBrowserCommandLine')['arguments']
        require(isinstance(arguments, list) and '--disable-shared-workers' in arguments,
                'browser_boundary_violation')
    except Exception:
        raise Failure('browser_boundary_violation') from None
    finally:
        if session is not None:
            try:
                session.detach()
            except Exception:
                raise Failure('browser_boundary_violation') from None


def browser_context(browser, plan, guard):
    require_worker_isolation(browser)
    context = browser.new_context(locale=plan['locale'], service_workers='block',
                                  accept_downloads=False, ignore_https_errors=False,
                                  viewport={'width': 1440, 'height': 1200})
    # Incognito state is memory-only; also deny the hosted UI's optional
    # Password Credential storage API, regardless of checkbox/default changes.
    context.add_init_script('''if (globalThis.CredentialsContainer) {
      Object.defineProperty(CredentialsContainer.prototype, 'store', {
        value: () => Promise.reject(new DOMException('Storage disabled', 'NotAllowedError'))
      });
    }''')
    context.route('**/*', guard.route)
    context.on('response', guard.response)
    def websocket(ws):
        guard.stop()
        ws.close()
    context.route_web_socket('**/*', websocket)
    page = context.new_page()
    try:
        # Check native capability on the untouched blank document before any
        # untrusted navigation or credential read. No JS constructor shim.
        require(page.evaluate("'SharedWorker' in globalThis") is False, 'browser_boundary_violation')
    except Exception:
        try:
            context.close()
        finally:
            raise Failure('browser_boundary_violation') from None
    guard.page = page
    redirect_barrier(context, page, guard)
    def unexpected_page(other):
        guard.stop()
        other.close()
    context.on('page', unexpected_page)
    page.on('download', lambda download: (guard.stop(), download.cancel()))
    page.on('dialog', lambda dialog: (guard.stop(), dialog.dismiss()))
    return context, page


def browser_trust(page, plan, end):
    """Chrome independently verifies TLS before credential *contents* are opened."""
    try:
        response = page.goto(plan['op']['discovery_url'], wait_until='load', timeout=timeout(end))
        require(response is not None and response.status == 200 and
                page.url == plan['op']['discovery_url'], 'browser_tls_or_navigation')
    except Exception:
        raise Failure('browser_tls_or_navigation') from None


def cookie(context, plan):
    cookies = [v for v in context.cookies(plan['op']['origin']) if v['name'] == COOKIE]
    require(len(cookies) == 1, 'invalid_token')
    value = cookies[0]
    require(value['httpOnly'] and value['secure'] and value['sameSite'] == 'Lax' and
            value['path'] == '/' and value['domain'] == urlsplit(plan['op']['origin']).hostname,
            'invalid_token')
    return value


def authorize(page, guard, rp, end, labels, *, primary=False):
    page.goto(rp.authorization_url(), wait_until='domcontentloaded', timeout=timeout(end))
    semantics(page, guard, rp, end)
    username, password, sign_in, allow, suffix = labels
    if primary:
        page.get_by_role('textbox', name=password, exact=True).wait_for(timeout=timeout(end))
        guard.healthy()
        # Explicit file reference only, read once, after both transports and UI
        # are ready. Never call navigator.credentials or any fixture fallback.
        credential = load_credentials(guard.plan['credential_file'])
        rp.verifier.subject = credential.pop('expected_subject')
        type_field(page, username, credential['username'], end)
        type_field(page, password, credential['password'], end)
        guard.healthy()
        guard.credential, guard.armed = credential, 'primary'
        page.get_by_role('button', name=sign_in, exact=True).click(timeout=timeout(end))
        credential = None
    if rp.config['consent'] == 'required':
        wait(page, guard, end, lambda: guard.challenge is not None or rp.done.is_set() or
             (not primary and page.get_by_role('textbox', name=password, exact=True).count() > 0))
        require(not rp.done.is_set() and guard.challenge is not None, 'authorization_blocked')
        require(primary or page.get_by_role('textbox', name=password, exact=True).count() == 0,
                'authorization_blocked')
        page.get_by_text(rp.config['display_name'] + suffix, exact=True).wait_for(timeout=timeout(end))
        guard.healthy()
        guard.armed = 'consent'
        page.get_by_role('button', name=allow, exact=True).click(timeout=timeout(end))
    else:
        wait(page, guard, end, lambda: rp.done.is_set() or
             (not primary and page.get_by_role('textbox', name=password, exact=True).count() > 0))
        require(rp.done.is_set(), 'authorization_blocked')
    wait(page, guard, end, rp.done.is_set)
    require(rp.failure is None and rp.grant is not None, rp.failure or 'acceptance_failed')
    page.wait_for_url('http://' + rp.target.netloc + '/complete', timeout=timeout(end))
    guard.healthy()


def run(plan, end):
    context = tls_context(plan.get('ca_file'))
    transport = Transport(plan['op'], plan['limits'], end, context=context)
    preflight(plan, transport)
    verifier = Verifier(plan, transport)
    verifier.keys()  # Bounded/purpose-checked public keys before authentication.
    try:
        import jwt
        from playwright.sync_api import sync_playwright
        require(hasattr(jwt, 'PyJWK') and hasattr(jwt, 'decode'), 'browser_unavailable')
    except ImportError:
        raise Failure('browser_unavailable') from None
    with ExitStack() as stack:
        rps = [RP(plan, cfg, verifier, end) for cfg in plan['rps']]
        for rp in rps:
            rp.start()
            stack.callback(rp.close)
        guard = Guard(plan, rps)
        playwright = stack.enter_context(sync_playwright())
        environment = {k: v for k, v in os.environ.items() if k in
                       ('PATH', 'HOME', 'LANG', 'TZ', 'XDG_RUNTIME_DIR')}
        browser = playwright.chromium.launch(headless=True, channel='chrome', timeout=timeout(end),
            env=environment, args=['--no-proxy-server', '--disable-breakpad', '--disable-crash-reporter',
                                   '--disable-save-password-bubble', '--disable-background-networking',
                                   '--disable-component-update', '--disable-sync', '--no-first-run',
                                   *WORKER_ISOLATION_ARGS])
        stack.callback(browser.close)
        context, page = browser_context(browser, plan, guard)
        stack.callback(context.close)
        browser_trust(page, plan, end)
        guard.healthy()
        try:
            authorize(page, guard, rps[0], end, LABELS[plan['locale']], primary=True)
            original = cookie(context, plan)
            canonical = verifier.cookie(original['value'])
            same_context(canonical, rps[0].grant['access'])
            guard.phase = 1
            authorize(page, guard, rps[1], end, LABELS[plan['locale']])
            current = cookie(context, plan)
            require(original == current, 'invalid_token')  # No rolling expiry or changed cookie.
            same_context(canonical, rps[1].grant['access'])
            first, second = (rp.grant for rp in rps)
            same_context(first['access'], second['access'])
            require(first['access']['sid'] != second['access']['sid'] and all(
                first['tokens'][k] != second['tokens'][k] for k in ('access_token', 'id_token')), 'invalid_token')
            if 'refresh_token' in first['tokens'] or 'refresh_token' in second['tokens']:
                require(first['tokens'].get('refresh_token') and second['tokens'].get('refresh_token') and
                        first['tokens']['refresh_token'] != second['tokens']['refresh_token'], 'invalid_token')
            guard.completed()
            return {'password_submissions': guard.primary, 'resume_submissions': guard.resume,
                    'consent_submissions': sum(guard.consent), 'code_exchanges': sum(r.consumed for r in rps)}
        except Failure as error:
            if error.state == 'deadline_exceeded' and (guard.primary or any(guard.consent)):
                raise Failure('unknown_result') from None
            raise
        except Exception:
            # A browser/continuation timeout may follow a committed login/consent.
            raise Failure('unknown_result' if guard.primary or guard.consent != [0, 0]
                          else 'acceptance_failed') from None
        finally:
            guard.credential = guard.challenge = None
            for rp in rps:
                rp.close()
                rp.grant = None
