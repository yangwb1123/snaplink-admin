"""Synthetic declarations and in-process CLI capture; no identity/test-backend imports."""

from contextlib import redirect_stderr, redirect_stdout
from copy import deepcopy
import io
import json

from tools import app_sso, check_app_sso


def declarations():
    app = {
        'flow': 'canonical_code_s256',
        'prompt': [],
        'max_age': 'absent',
        'request_context': 'plain',
        'step_up': 'not_declared',
        'consent': 'required',
    }
    return {
        'version': 1,
        'op_relation': 'same',
        'browser_jar_relation': 'same',
        'app_a': deepcopy(app),
        'app_b': deepcopy(app),
    }


def diagnose(value):
    return app_sso.diagnose(app_sso.decode_declarations(json.dumps(value).encode()))


def labels(report, provenance=None):
    return [reason['label'] for reason in report['reasons']
            if provenance is None or reason['provenance'] == provenance]


def cli(args):
    out, err = io.StringIO(), io.StringIO()
    with redirect_stdout(out), redirect_stderr(err):
        exit_code = check_app_sso.main(args)
    return exit_code, json.loads(out.getvalue()), out.getvalue(), err.getvalue()


def assert_unverified(test, report):
    test.assertEqual(report['mode'], 'offline_declarations_only')
    test.assertEqual(report['verification'], {
        'target_a_to_b': 'not_run',
        'op_identity': 'not_verified',
        'browser_cookie_jar': 'not_verified',
        'op_session': 'not_verified',
        'client_registration': 'not_verified',
        'redirect_uri': 'not_verified',
        'runtime_policy': 'not_verified',
    })
    test.assertIn({'label': 'static_data_is_not_login_evidence',
                   'provenance': 'tool_boundary'}, report['reasons'])
