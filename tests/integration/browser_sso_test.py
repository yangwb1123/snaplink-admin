#!/usr/bin/env python3
"""Real release UI + stock OP + Chromium. Local disposable fixtures ONLY."""

import argparse
from pathlib import Path
import sys
import urllib.parse

from browser_sso_fixture import BrowserFixture, FIXTURE_PASSWORD, FIXTURE_USER, ROOT
from browser_sso_rp import FixtureFailure, require

COOKIE = 'snaplink_op_session'


def enable_semantics(page):
    placeholder = page.locator('flt-semantics-placeholder')
    placeholder.wait_for(state='attached', timeout=60000)
    placeholder.evaluate('(element) => element.click()')


def login_form(page):
    print('Phase: activate Flutter accessibility')
    enable_semantics(page)
    print('Phase: wait for username field')
    page.get_by_role('textbox', name='Username', exact=True).wait_for(timeout=30000)
    return page.get_by_role('textbox', name='Password', exact=True)


def cookie_for(context, issuer):
    cookies = [cookie for cookie in context.cookies(issuer) if cookie['name'] == COOKIE]
    require(len(cookies) == 1, 'Browser OP cookie is missing or ambiguous')
    return cookies[0]


def observe(context, issuer, diagnostics=None):
    counts = {'password': 0, 'resume': 0, 'continuation': 0, 'unexpected': 0}

    def request_seen(request):
        target = urllib.parse.urlsplit(request.url)
        if target.scheme + '://' + target.netloc != issuer or target.path != '/auth/login' or request.method != 'POST':
            return
        try:
            body = request.post_data_json
            # Retain counts only, never request bodies, passwords or Cookie headers.
            if body.get('credential'):
                counts['password'] += 1
                if diagnostics is not None:
                    credential = body['credential']
                    diagnostics['credential_complete'] = (
                        credential.get('username') == FIXTURE_USER and
                        credential.get('password') == FIXTURE_PASSWORD
                    )
            if body.get('resume_session') is True:
                counts['resume'] += 1
            if body.get('login_transaction_id'):
                counts['continuation'] += 1
        except Exception:
            counts['unexpected'] += 1
    context.on('request', request_seen)
    if diagnostics is not None:
        def response_seen(response):
            target = urllib.parse.urlsplit(response.url)
            if target.scheme + '://' + target.netloc != issuer or target.path != '/auth/login':
                return
            # Keep only allowlisted wire codes/status, never response bodies.
            try:
                body = response.json()
                known = {'invalid_credentials', 'invalid_request', 'invalid_client',
                         'invalid_scope', 'invalid_resource', 'login_required',
                         'consent_required', 'mfa_required', 'temporarily_unavailable',
                         'authenticator_not_allowed_for_client', 'unsupported_provider'}
                error = body.get('error')
                diagnostics['result'] = error if error in known else (
                    'code' if 'code' in body else 'discovery' if 'providers' in body else 'other'
                )
                diagnostics['status'] = response.status
            except Exception:
                diagnostics['result'] = 'unreadable'
        context.on('response', response_seen)
    return counts


def assert_grants(fixture):
    a, b = fixture.rps
    require(not a.failure and not b.failure, 'RP callback verification failed')
    require(not a.received_identity_cookie and not b.received_identity_cookie, 'OP identity cookie leaked to an RP host')
    require(len(a.grants) == 1 and len(b.grants) == 1, 'Independent code exchanges did not complete')
    ga, gb = a.grants[0], b.grants[0]
    for field in ('access_token', 'refresh_token', 'id_token'):
        require(ga['tokens'].get(field) and ga['tokens'][field] != gb['tokens'].get(field), 'RPs shared or lost credentials')
    require(ga['access'].get('sid') and ga['access']['sid'] != gb['access'].get('sid'), 'RP authorization sessions were shared')
    require(ga['identity']['sub'] == gb['identity']['sub'], 'Second RP restored a different identity')
    for field in ('auth_time', 'amr', 'acr'):
        require(ga['access'].get(field) == gb['access'].get(field), 'Restoration changed authentication context')
        require(ga['identity'].get(field) == gb['identity'].get(field), 'ID-token authentication context changed')
    require(ga['access'].get('auth_time', 0) > 0, 'Original authentication time is missing')


def check_http_only_and_service_isolation(context, fixture, original):
    page = context.new_page()
    page.goto(fixture.issuer + '/health')
    require(COOKIE not in page.evaluate('document.cookie'), 'OP identity cookie is readable by JavaScript')
    result = page.evaluate('''async () => {
      const response = await fetch('/api/v1/agent/check', {
        headers: {'Authorization': 'Bearer independent-fixture'}
      });
      return response.status;
    }''')
    require(result == 200 and fixture.sink.received_cookie is None, 'Independent API received the OP cookie')
    require(cookie_for(context, fixture.issuer)['value'] == original['value'], 'Independent API overwrote OP identity')
    page.close()


def browser_context(browser, fixture):
    context = browser.new_context(ignore_https_errors=True, locale='en-US', viewport={'width': 1440, 'height': 1200})
    # No HAR/screenshots/traces and no requests outside our owned fixture origins.
    origins = {fixture.issuer, *(rp.origin for rp in fixture.rps)}

    def route_request(route):
        target = urllib.parse.urlsplit(route.request.url)
        if target.scheme + '://' + target.netloc in origins:
            route.continue_()
        else:
            route.abort()
    context.route('**/*', route_request)
    return context


def run_browser(playwright, fixture, channel):
    browser = playwright.chromium.launch(headless=True, channel=channel)
    print('Chromium:', browser.version)
    try:
        context = browser_context(browser, fixture)
        diagnostics = {}
        counts = observe(context, fixture.issuer, diagnostics)
        a, b = fixture.rps
        first = context.new_page()
        first.goto(a.origin + '/start')
        login_form(first)
        print('Phase: fill primary credentials')
        first.get_by_role('textbox', name='Username', exact=True).click()
        # Flutter editing uses sequential key events; bulk DOM fill does not
        # guarantee that its TextEditingController has received the credential.
        first.keyboard.type(FIXTURE_USER, delay=25)
        first.keyboard.press('Tab')
        first.get_by_role('textbox', name='Password', exact=True).click()
        first.keyboard.type(FIXTURE_PASSWORD, delay=25)
        first.keyboard.press('Tab')
        from playwright.sync_api import expect
        expect(first.get_by_role('textbox', name='Username', exact=True)).to_have_value(FIXTURE_USER)
        expect(first.get_by_role('textbox', name='Password', exact=True)).to_have_value(FIXTURE_PASSWORD)
        print('Phase: submit primary login')
        first.get_by_role('button', name='Sign in', exact=True).click()
        print('Phase: primary callback; counts:', counts)
        try:
            first.wait_for_url(a.origin + '/callback?**', timeout=30000)
        except Exception:
            print('RP callback failed:', a.failure, '; safe OP diagnostics:', diagnostics)
            raise FixtureFailure('Primary UI callback failed; request counts: ' + str(counts)) from None
        first.get_by_role('heading', name='Grant accepted').wait_for()
        require(diagnostics.get('credential_complete') is True, 'Primary form did not submit the complete fixture credential')
        original = cookie_for(context, fixture.issuer)
        require(original['httpOnly'] and original['secure'] and original['sameSite'] == 'Lax' and original['path'] == '/', 'Unsafe browser-cookie attributes')
        require(original['domain'] == '127.0.0.1', 'OP cookie is not host-only')
        print('PASS: actual password UI and HTTPS OP cookie')

        second = context.new_page()
        second.goto(b.origin + '/start')
        enable_semantics(second)
        second.get_by_text('Browser App B wants access', exact=True).wait_for(timeout=30000)
        require(second.get_by_role('textbox', name='Password', exact=True).count() == 0, 'Second RP demanded another password')
        second.get_by_role('button', name='Allow', exact=True).click()
        second.wait_for_url(b.origin + '/callback?**', timeout=30000)
        second.get_by_role('heading', name='Grant accepted').wait_for()
        require(counts == {'password': 1, 'resume': 1, 'continuation': 1, 'unexpected': 0}, 'Browser login/continuation was replayed or skipped')
        current = cookie_for(context, fixture.issuer)
        require(current['value'] == original['value'] and current['expires'] == original['expires'], 'SSO renewed the OP cookie')
        assert_grants(fixture)
        print('PASS: second RP consent, independent grants and preserved authentication age')

        check_http_only_and_service_isolation(context, fixture, original)
        print('PASS: HttpOnly and independent-service request/response cookie isolation')
        check_authentication_boundaries(browser, context, fixture, counts)
        browser.close()
    finally:
        if browser.is_connected():
            browser.close()


def check_authentication_boundaries(browser, context, fixture, counts):
    b = fixture.rps[1]
    before = dict(counts)
    for suffix in ('prompt=login', 'prompt=select_account', 'max_age=0'):
        page = context.new_page()
        page.goto(b.origin + '/start?' + suffix)
        login_form(page).wait_for(timeout=30000)
        page.close()
    require(counts == before, 'Forced authentication submitted an automatic resume')
    isolated = browser_context(browser, fixture)
    page = isolated.new_page()
    page.goto(b.origin + '/start')
    login_form(page).wait_for(timeout=30000)
    require(not [c for c in isolated.cookies(fixture.issuer) if c['name'] == COOKIE], 'Isolated browser received OP identity')
    isolated.close()
    # The RP's own hint is used only for its validated end-session operation,
    # never for another RP's authentication. No URL/header is recorded.
    response = context.request.get(fixture.issuer + '/end_session', params={
        'id_token_hint': b.grants[0]['tokens']['id_token'],
    })
    require(response.status == 204, 'Gateway did not deliver the validated OP logout')
    require(not [c for c in context.cookies(fixture.issuer) if c['name'] == COOKIE], 'Logout retained OP identity')
    page = context.new_page()
    page.goto(b.origin + '/start')
    login_form(page).wait_for(timeout=30000)
    require(counts == before, 'Logged-out navigation replayed authorization')
    page.close()
    print('PASS: forced authentication, isolated browser and real end-session cookie clearing')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend-repo', type=Path, default=ROOT.parent / 'snaplink')
    parser.add_argument('--web-build', type=Path, default=ROOT / 'build/web')
    parser.add_argument('--gateway', choices=('python', 'nginx', 'both'), default='both')
    parser.add_argument('--browser-channel', choices=('chrome',), default=None,
                        help='Explicit system Chrome for hosts unsupported by bundled Chromium')
    args = parser.parse_args()
    try:
        from playwright.sync_api import sync_playwright
        gateways = ('python', 'nginx') if args.gateway == 'both' else (args.gateway,)
        with sync_playwright() as playwright:
            for gateway in gateways:
                with BrowserFixture(args.backend_repo.resolve(), args.web_build.resolve(), gateway) as fixture:
                    print('Gateway:', gateway)
                    run_browser(playwright, fixture, args.browser_channel)
        print('Browser SSO: PASS (isolated fixtures, not target-deployment acceptance)')
        return 0
    except FixtureFailure as error:
        print('Browser SSO: FAIL:', error, file=sys.stderr)
    except Exception as error:
        # Playwright errors can contain password-fill call logs or callback URLs.
        print('Browser SSO: FAIL:', type(error).__name__, '(sensitive details withheld)', file=sys.stderr)
    return 1


if __name__ == '__main__':
    sys.exit(main())
