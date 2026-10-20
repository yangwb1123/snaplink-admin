"""Load only the independent stock modules; no target-helper dependency."""

import base64
from contextlib import contextmanager
import importlib.util
import json
from pathlib import Path
import sys


INTEGRATION = Path(__file__).parents[1] / 'integration'
modules = {}
_ABSENT = object()


@contextmanager
def fixture_imports(overrides=None):
    """Restore only our bindings; retain transitive stdlib/third-party imports.

    patch.dict(sys.modules) restores the entire registry, discarding imports made
    inside it while packages and fixture globals still retain those objects.
    Later imports can then create incompatible duplicate module/class identities.
    """
    bindings = {**modules, **(overrides or {})}
    previous = {name: sys.modules.get(name, _ABSENT) for name in bindings}
    try:
        sys.modules.update(bindings)
        yield
    finally:
        for name, original in previous.items():
            if original is _ABSENT:
                sys.modules.pop(name, None)
            else:
                sys.modules[name] = original


for name in ('browser_sso_rp', 'browser_sso_fixture', 'browser_sso_test',
             'app_sso_entry_transport', 'app_sso_resources', 'app_sso_children', 'app_sso_supervisor',
             'app_sso_entry_fixture', 'app_sso_entry'):
    spec = importlib.util.spec_from_file_location(name, INTEGRATION / (name + '.py'))
    module = importlib.util.module_from_spec(spec)
    with fixture_imports({name: module}):
        spec.loader.exec_module(module)
    modules[name] = module

rp = modules['browser_sso_rp']
fixture = modules['browser_sso_fixture']
shared = runner = fixture
flow = rp
cli = modules['browser_sso_test']
transport = modules['app_sso_entry_transport']
resources = modules['app_sso_resources']
entry = modules['app_sso_entry_fixture']
scenario = modules['app_sso_entry']


def cookie_and_grants():
    original = {'sub': 'fixture-user', 'sid': 'primary-session', 'auth_time': 1700000000}
    encoded = base64.urlsafe_b64encode(json.dumps(original).encode()).decode().rstrip('=')
    cookie = {'value': 'fixture.' + encoded + '.fixture'}
    grants = []
    for index, sid in enumerate(('primary-session', 'second-session', 'repeat-session')):
        claims = {**original, 'sid': sid, 'amr': ['pwd'], 'acr': 'fixture-acr'}
        grants.append({'access': dict(claims), 'identity': {**claims, 'nonce': 'nonce-' + str(index)},
                       'tokens': {field: field + '-' + str(index)
                                  for field in ('access_token', 'refresh_token', 'id_token')},
                       'request': {field: field + '-' + str(index) for field in ('code', 'state', 'pkce')}})
    return cookie, grants
