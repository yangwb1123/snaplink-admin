#!/usr/bin/env python3
"""Opt-in registered-loopback-RP SSO acceptance. Default: offline plan validation."""

from contextlib import contextmanager
import json
import multiprocessing
import os
from pathlib import Path
import resource
import signal
import sys
import time

if __package__ in (None, ''):
    sys.path.insert(0, str(Path(__file__).resolve().parents[1]))
from tools.browser_sso_plan import Failure, load_credentials, load_plan


STATES = frozenset('''valid_plan missing_inputs invalid_arguments invalid_plan invalid_json
body_too_large unsafe_input_file unsafe_credential_file input_file_unavailable
invalid_credentials_file unsupported_by_tool authentication_consent_required
transport_error tls_error deadline_exceeded invalid_response redirect_rejected http_error
endpoint_mismatch capability_unverified invalid_jwks invalid_token invalid_callback
callback_replayed callback_unavailable authorization_blocked browser_boundary_violation
browser_tls_or_navigation browser_unavailable unknown_result acceptance_failed accepted'''.split())


def report(state, mode, *, acceptance='not_run', missing=(), http_status=None):
    # Do not serialize exceptions, plans, URLs, identifiers, subjects or protocol data.
    result = {'mode': mode, 'state': state if state in STATES else 'acceptance_failed',
              'browser_acceptance': acceptance, 'target_app_integration': 'not_verified',
              'native': 'not_run', 'ha': 'not_verified'}
    if missing:
        result['missing'] = list(missing)
    if type(http_status) is int and 100 <= http_status <= 599:
        result['http_status'] = http_status
    return result


def arguments(argv):
    """No argparse error echo, abbreviation, repeated options or secret arguments."""
    values, i = {}, 0
    while i < len(argv):
        key = argv[i]
        if key not in ('--plan', '--execute', '--allow-authentication', '--help') or key in values:
            raise Failure('invalid_arguments')
        if key == '--plan':
            i += 1
            if i >= len(argv) or argv[i].startswith('--'):
                raise Failure('invalid_arguments')
            values[key] = argv[i]
        else:
            values[key] = True
        i += 1
    if '--help' in values and len(values) != 1:
        raise Failure('invalid_arguments')
    return values


@contextmanager
def clean_environment():
    # Playwright's driver inherits DEBUG/PWDEBUG/NODE_OPTIONS, not just launch(env=).
    original = dict(os.environ)
    allowed = {k: v for k, v in original.items() if k in ('PATH', 'HOME', 'LANG', 'TZ', 'XDG_RUNTIME_DIR')}
    os.environ.clear()
    os.environ.update(allowed)
    try:
        yield allowed
    finally:
        os.environ.clear()
        os.environ.update(original)


def _worker(plan, pipe):
    try:
        # All owned browser/driver diagnostics are discarded, including exception call logs.
        resource.setrlimit(resource.RLIMIT_CORE, (0, 0))
        with open(os.devnull, 'wb') as sink:
            os.dup2(sink.fileno(), 1)
            os.dup2(sink.fileno(), 2)
        with clean_environment():
            from tools.browser_sso_browser import run
            counts = run(plan, time.monotonic() + plan['limits']['total_seconds'] - 2)
        result = report('accepted', 'execute', acceptance='passed')
        result['counts'] = counts
    except Failure as failure:
        acceptance = 'unknown_result' if failure.state == 'unknown_result' else 'failed'
        result = report(failure.state, 'execute', acceptance=acceptance, http_status=failure.http_status)
    except BaseException:
        result = report('unknown_result', 'execute', acceptance='unknown_result')
    try:
        pipe.send(result)
    finally:
        pipe.close()


def kill_owned_tree(process):
    """Freeze/kill only verified descendants via pidfds, even detached Chrome.

    Killing just the Python worker or its process group can orphan Playwright's
    detached browser group. Never signal a port owner or a shared daemon.
    """
    handles, seen, end = [], set(), time.monotonic() + 1
    def visit(pid, parent=None):
        if pid in seen or time.monotonic() >= end or len(handles) >= 256:
            return
        seen.add(pid)
        fd = None
        try:
            fd = os.pidfd_open(pid)
            status = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
            if parent is not None and int(status[1]) != parent:
                return
            signal.pidfd_send_signal(fd, signal.SIGSTOP)
            handles.append(fd)
            fd = None
            for task in Path(f'/proc/{pid}/task').iterdir():
                for child in (task / 'children').read_text().split():
                    visit(int(child), pid)
        except (OSError, ValueError):
            pass  # Positively owned process already exited, not authority to find another.
        finally:
            if fd is not None:
                os.close(fd)
    visit(process.pid)
    for fd in reversed(handles):
        try:
            signal.pidfd_send_signal(fd, signal.SIGKILL)
        except OSError:
            pass
        finally:
            os.close(fd)


def execute(plan):
    """Hard parent wall-clock ceiling includes DNS, browser launch and cleanup.

    Credentials/tokens never enter argv or an IPC payload. Only the validated,
    non-secret plan goes into the worker and fixed reporting states come out.
    """
    context = multiprocessing.get_context('fork')
    receiver, sender = context.Pipe(duplex=False)
    process = context.Process(target=_worker, args=(plan, sender), daemon=False)
    deadline = time.monotonic() + plan['limits']['total_seconds']
    process.start()
    sender.close()
    try:
        process.join(timeout=max(0, deadline - time.monotonic() - 2))
        if process.is_alive():
            kill_owned_tree(process)
            process.join(timeout=max(0, deadline - time.monotonic()))
            if process.is_alive():
                process.kill()
                process.join(timeout=0.1)
            return report('unknown_result', 'execute', acceptance='unknown_result')
        if receiver.poll():
            try:
                return receiver.recv()
            except EOFError:
                pass
        return report('unknown_result', 'execute', acceptance='unknown_result')
    finally:
        receiver.close()
        if process.is_alive():
            kill_owned_tree(process)
            process.join(timeout=1)
        process.close()


def main(argv=None):
    mode, started = 'plan', False
    try:
        args = arguments(list(sys.argv[1:] if argv is None else argv))
        if '--help' in args:
            print('Usage: browser_sso_acceptance.py --plan /operator/plan.json '
                  '[--execute --allow-authentication]\nDefault: offline only. No provisioning or credential discovery.')
            return 0
        mode = 'execute' if '--execute' in args else 'plan'
        if not args.get('--plan'):
            raise Failure('missing_inputs', missing=['plan'])
        plan = load_plan(args['--plan'])
        if bool(args.get('--execute')) != bool(args.get('--allow-authentication')):
            raise Failure('authentication_consent_required')
        if '--execute' in args:
            started = True
            result = execute(plan)
        else:
            result = report('valid_plan', mode)
    except Failure as failure:
        result = report(failure.state, mode, missing=failure.missing, http_status=failure.http_status)
    except BaseException:
        result = (report('unknown_result', mode, acceptance='unknown_result') if started else
                  report('acceptance_failed', mode))
    print(json.dumps(result, sort_keys=True))
    return 0 if result['state'] in ('valid_plan', 'accepted') else 1


if __name__ == '__main__':
    raise SystemExit(main())
