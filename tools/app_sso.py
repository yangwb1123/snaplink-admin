"""Pure, declaration-only App A/B SSO diagnosis. No runtime identity facts or I/O."""

from dataclasses import dataclass
import json

MAX_INPUT_BYTES = 16 * 1024
RELATIONS = ('same', 'different', 'unknown')
PROMPTS = ('login', 'select_account', 'consent', 'none')
APP_FIELDS = {'flow', 'prompt', 'max_age', 'request_context', 'step_up', 'consent'}
ROOT_FIELDS = {'version', 'op_relation', 'browser_jar_relation', 'app_a', 'app_b'}


class DeclarationError(ValueError):
    def __init__(self):
        super().__init__('invalid_declarations')


@dataclass(frozen=True, repr=False)
class AppDeclaration:
    flow: str
    prompt: tuple[str, ...] | None
    max_age: int | str
    request_context: str
    step_up: str
    consent: str


@dataclass(frozen=True, repr=False)
class Declarations:
    op_relation: str | None
    browser_jar_relation: str | None
    app_a: AppDeclaration | None
    app_b: AppDeclaration | None


def _reject(*_):
    raise DeclarationError()


def _object(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            _reject()
        result[key] = value
    return result


def _integer(text):
    if len(text) > 10:
        _reject()
    return int(text)


def _choice(value, choices):
    if type(value) is not str or value not in choices:
        _reject()
    return value


def _app(value):
    if value is None:
        return None
    if type(value) is not dict or set(value) != APP_FIELDS:
        _reject()
    flow = _choice(value['flow'], ('canonical_code_s256', 'app_local_direct', 'unknown'))
    context = _choice(value['request_context'], ('plain', 'par', 'jar', 'unknown'))
    # PAR/JAR is an authorization request, not an app-local direct password call.
    if flow == 'app_local_direct' and context in ('par', 'jar'):
        _reject()
    prompt = value['prompt']
    if prompt is not None:
        if type(prompt) is not list or len(prompt) > len(PROMPTS):
            _reject()
        for token in prompt:
            _choice(token, PROMPTS)
        if len(set(prompt)) != len(prompt) or ('none' in prompt and len(prompt) != 1):
            _reject()
        prompt = tuple(token for token in PROMPTS if token in prompt)
    age = value['max_age']
    if type(age) is int:
        if not 0 <= age <= 2147483647:
            _reject()
    else:
        _choice(age, ('absent', 'unknown'))
    return AppDeclaration(
        flow, prompt, age, context,
        _choice(value['step_up'], ('required', 'not_declared', 'unknown')),
        _choice(value['consent'], ('required', 'not_required', 'unknown')),
    )


def decode_declarations(data: bytes) -> Declarations:
    """Accept only the bounded v1 enum/config schema, never URLs or references."""
    if type(data) is not bytes or not 0 < len(data) <= MAX_INPUT_BYTES:
        _reject()
    try:
        value = json.loads(data.decode('utf-8'), object_pairs_hook=_object,
                           parse_int=_integer, parse_float=_reject, parse_constant=_reject)
        if type(value) is not dict or set(value) - ROOT_FIELDS:
            _reject()
        if type(value.get('version')) is not int or value['version'] != 1:
            _reject()
        relations = []
        for field in ('op_relation', 'browser_jar_relation'):
            relation = value.get(field)
            relations.append(None if relation is None else _choice(relation, RELATIONS))
        return Declarations(*relations, _app(value.get('app_a')), _app(value.get('app_b')))
    except (ValueError, UnicodeError, RecursionError):
        raise DeclarationError() from None


def _reason(label, provenance):
    return {'label': label, 'provenance': provenance}


def _report(status, assessment, reasons):
    return {
        'version': 1,
        'mode': 'offline_declarations_only',
        'input_status': status,
        'assessment': assessment,
        'reasons': reasons + [_reason('static_data_is_not_login_evidence', 'tool_boundary')],
        'verification': {
            'target_a_to_b': 'not_run',
            'op_identity': 'not_verified',
            'browser_cookie_jar': 'not_verified',
            'op_session': 'not_verified',
            'client_registration': 'not_verified',
            'redirect_uri': 'not_verified',
            'runtime_policy': 'not_verified',
        },
    }


def input_report(kind):
    """The CLI's closed error vocabulary; never accepts an exception/message."""
    status, assessment, label, provenance = {
        'missing_file': ('missing', 'missing_inputs', 'input_file_missing', 'command_line'),
        'arguments': ('rejected', 'not_assessed', 'invalid_arguments', 'command_line'),
        'unsafe_file': ('rejected', 'not_assessed', 'unsafe_input_file', 'input_file'),
        'unreadable_file': ('unreadable', 'not_assessed', 'input_file_unreadable', 'input_file'),
        'declarations': ('rejected', 'not_assessed', 'invalid_declarations', 'input_structure'),
        'internal': ('unknown', 'not_assessed', 'offline_diagnostic_failed', 'tool_boundary'),
        'interrupted': ('unknown', 'not_assessed', 'offline_diagnostic_interrupted', 'tool_boundary'),
        'help': ('not_read', 'not_assessed', 'usage_in_existing_docs', 'tool_boundary'),
    }[kind]
    return _report(status, assessment, [_reason(label, provenance)])


def _app_reasons(app, provenance):
    reasons = [_reason({
        'canonical_code_s256': 'canonical_code_s256_declared',
        'app_local_direct': 'app_local_direct_is_not_code_navigation',
        'unknown': 'navigation_unconfirmed',
    }[app.flow], provenance)]
    if app.flow == 'app_local_direct':
        reasons.append(_reason('direct_login_does_not_prove_op_browser_session', provenance))
    if app.prompt is None:
        reasons.append(_reason('prompt_unconfirmed', provenance))
    elif not app.prompt:
        reasons.append(_reason('no_explicit_prompt_declared', provenance))
    else:
        for token in app.prompt:
            reasons.append(_reason({
                'login': 'prompt_login_declared',
                'select_account': 'prompt_select_account_declared',
                'consent': 'prompt_consent_is_not_password_authentication',
                'none': 'prompt_none_does_not_prove_session',
            }[token], provenance))
    if type(app.max_age) is int:
        age_reason = ('max_age_zero_declared' if app.max_age == 0 else
                      'session_age_cannot_be_checked_offline')
    else:
        age_reason = {'absent': 'no_explicit_max_age_declared',
                      'unknown': 'max_age_unconfirmed'}[app.max_age]
    reasons.append(_reason(age_reason, provenance))
    for value, choices in (
        (app.request_context, {
            'plain': 'plain_request_context_declared',
            'par': 'opaque_par_cannot_be_resolved_offline',
            'jar': 'opaque_jar_cannot_be_resolved_offline',
            'unknown': 'request_context_unconfirmed',
        }),
        (app.step_up, {
            'required': 'step_up_requires_runtime_decision',
            'not_declared': 'no_step_up_declared',
            'unknown': 'step_up_unconfirmed',
        }),
        (app.consent, {
            'required': 'consent_is_not_password_authentication',
            'not_required': 'consent_not_required_declared',
            'unknown': 'consent_policy_unconfirmed',
        }),
    ):
        reasons.append(_reason(choices[value], provenance))
    return reasons


def diagnose(declarations: Declarations):
    """Fixed-label analysis of caller claims, not a test of cookies or registration."""
    reasons = []
    for relation, labels in (
        (declarations.op_relation, {
            None: 'op_declaration_missing', 'same': 'same_op_declared',
            'different': 'different_ops_declared', 'unknown': 'op_unconfirmed',
        }),
        (declarations.browser_jar_relation, {
            None: 'browser_jar_declaration_missing', 'same': 'same_browser_jar_declared',
            'different': 'separate_browser_jars_declared', 'unknown': 'browser_jar_unconfirmed',
        }),
    ):
        reasons.append(_reason(labels[relation], 'input_structure' if relation is None else 'operator_pair'))
    a, b = declarations.app_a, declarations.app_b
    for app, provenance, missing_label in (
        (a, 'operator_app_a', 'app_a_input_missing'),
        (b, 'operator_app_b', 'app_b_input_missing'),
    ):
        reasons.extend(_app_reasons(app, provenance) if app is not None else
                       [_reason(missing_label, 'input_structure')])
    if a is None or b is None or declarations.op_relation is None or declarations.browser_jar_relation is None:
        assessment = 'missing_inputs'
    elif (declarations.op_relation == 'different' or declarations.browser_jar_relation == 'different'
          or a.flow == 'app_local_direct' or b.flow == 'app_local_direct'
          or bool(set(b.prompt or ()) & {'login', 'select_account'}) or b.max_age == 0):
        # Direct A may seed an OP cookie, but this declaration does not prove it.
        # Account selection/step-up/consent need not mean another password.
        assessment = 'declared_barriers_or_interaction'
    elif (declarations.op_relation == 'unknown' or declarations.browser_jar_relation == 'unknown'
          or a.flow == 'unknown' or b.flow == 'unknown'
          or a.request_context != 'plain' or b.request_context != 'plain'
          or b.prompt is None or b.max_age != 'absent' or b.step_up != 'not_declared'):
        assessment = 'offline_undetermined'
    else:
        assessment = 'compatible_static_declarations'
    # A's prompt/age/step-up is not B's authorization policy.
    return _report('accepted', assessment, reasons)
