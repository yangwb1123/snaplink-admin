"""Out-of-Playwright ownership and cancellation for the new loopback cases."""

from contextlib import ExitStack
import json
import os
from pathlib import Path
import select
import shutil
import socket
import subprocess
import sys
import tempfile
import time

from app_sso_children import OwnedChildren, termination_flag
from app_sso_resources import CleanupPending, owned_container
from browser_sso_fixture import fixture_environment
from browser_sso_rp import FixtureFailure, require

PACKET_LIMIT = 16384


def send_packet(connection, packet):
    data = json.dumps(packet).encode()
    require(len(data) <= PACKET_LIMIT and connection.send(data) == len(data),
            'Owned supervisor control write failed')


def receive_packet(connection):
    data, _, flags, _ = connection.recvmsg(PACKET_LIMIT)
    if not data:
        return None  # EOF is reconciled against the worker's actual exit/result.
    require(not flags & socket.MSG_TRUNC, 'Owned supervisor control packet invalid')
    packet = json.loads(data)
    require(isinstance(packet, dict), 'Owned supervisor control packet invalid')
    return packet


class WorkerOwner:
    """Private inherited socket only; contains resource metadata, never credentials."""
    def __init__(self, connection):
        self.connection = connection
        connection.settimeout(25)

    def request(self, operation, **arguments):
        send_packet(self.connection, {'operation': operation, **arguments})
        result = receive_packet(self.connection)
        require(result is not None and result.get('ok') is True, 'Owned supervisor resource operation failed')
        return result.get('value')


class ResourceOwner:
    def __init__(self, cancelled=lambda: False):
        self.cancelled = cancelled
        self.stack = ExitStack()
        self.containers, self.container_stacks = {}, []
        self.result = None
        self.cleanup_deadline = None
        self.directory = Path(tempfile.mkdtemp(prefix='snaplink-browser-sso-'))
        info = self.directory.lstat()
        self.directory_identity = (info.st_dev, info.st_ino, info.st_uid)
        self.stack.callback(self.release_directory)

    def release_directory(self):
        if self.directory.exists() or self.directory.is_symlink():
            info = self.directory.lstat()
            require(not self.directory.is_symlink() and self.directory.is_dir() and
                    (info.st_dev, info.st_ino, info.st_uid) == self.directory_identity and info.st_uid == os.getuid(),
                    'Owned temporary directory identity changed; foreign resource untouched')
            shutil.rmtree(self.directory)
        require(not self.directory.exists() and not self.directory.is_symlink(),
                'Owned temporary store cleanup not verified')

    def dispatch(self, packet):
        operation = packet.get('operation')
        if operation == 'workspace':
            return str(self.directory)
        if operation == 'release-workspace':
            self.release_directory()
        elif operation == 'container':
            # Parent registers BEFORE creation. It alone creates/removes Docker
            # resources; killing a worker cannot lose a create/removal outcome.
            stack = ExitStack()
            stack.fixture_command_timeout = 5
            stack.fixture_cancelled = self.cancelled
            self.container_stacks.append(stack)
            self.stack.callback(stack.close)
            arguments = packet['arguments']
            name = arguments[arguments.index('--name') + 1]
            require(name in ('snaplink-app-sso-redis-' + self.directory.name,
                             'snaplink-browser-sso-' + self.directory.name),
                    'Supervisor rejected unrelated container name')
            identity = owned_container(stack, arguments, command=packet['command'])
            self.containers[identity] = stack
            return identity
        elif operation == 'release-container':
            identity = packet['identity']
            require(identity in self.containers, 'Supervisor container identity is unknown')
            self.begin_cleanup()
            self.containers[identity].close()
            del self.containers[identity]
        elif operation == 'result':
            require(self.result is None and isinstance(packet.get('value'), dict),
                    'Owned fixture result is missing or duplicated')
            self.result = packet['value']
        else:
            raise FixtureFailure('Owned supervisor control operation rejected')

    def begin_cleanup(self, deadline=None):
        # A failed worker release has already spent part of the cleanup budget;
        # fallback must retain that deadline, never start a second twenty seconds.
        requested = time.monotonic() + 20 if deadline is None else deadline
        self.cleanup_deadline = min(requested, self.cleanup_deadline if self.cleanup_deadline is not None else requested)
        for stack in self.container_stacks:
            stack.fixture_deadline = self.cleanup_deadline
        return self.cleanup_deadline

    def close(self, deadline):
        deadline = self.begin_cleanup(deadline)
        # ExitStack consumes callbacks even when they raise. Keep the registered
        # obligation independently, including creation that never returned an ID
        # and a worker release that failed after issuing its one removal.
        pending = list(reversed(self.container_stacks))
        try:
            while pending:
                retry = []
                for stack in pending:
                    cleanup = getattr(stack, 'fixture_container_cleanup', None)
                    if cleanup is None:  # No mutation was attempted.
                        continue
                    try:
                        cleanup()
                    except CleanupPending:
                        retry.append(stack)
                pending = retry
                if pending:
                    require(time.monotonic() < deadline, 'Owned container cleanup deadline expired; cleanup unconfirmed')
                    time.sleep(min(0.1, max(0, deadline - time.monotonic())))
        finally:
            self.stack.close()
            self.release_directory()


def run_owned_case(backend, web, gateway, channel, case, *, seconds=600):
    """Supervise a fresh worker. Parent never imports/enters sync Playwright.

    SIGTERM/deadline stops the owned tree using pidfds, then reconciles containers
    by exact name/owner/image/ID and removes only the original private directory.
    No signal exception, ignored-SIGTERM interval or worker ExitStack is relied on.
    """
    require(case in ('rp-entry', 'live-replicas'), 'Unsupported supervised fixture case')
    with termination_flag() as cancelled, OwnedChildren() as children:
        deadline = time.monotonic() + seconds
        owner = ResourceOwner(lambda: cancelled['signal'] is not None or time.monotonic() >= deadline)
        control = peer = worker = None
        failure, interrupted = None, False
        try:
            control, peer = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
            environment = fixture_environment()
            # Debug transports may print protocol payloads; never enable them in
            # this credential-bearing, disposable browser worker.
            for name in ('DEBUG', 'DEBUGP', 'PWDEBUG'):
                environment.pop(name, None)
            environment['PYTHONUNBUFFERED'] = '1'
            # Include Playwright's real Chrome profiles/artifacts and compiler
            # scratch files in the parent's inode-checked cleanup boundary.
            for name in ('TMPDIR', 'TMP', 'TEMP'):
                environment[name] = str(owner.directory)
            environment['XDG_CONFIG_HOME'] = str(owner.directory / 'browser-config')
            command = [sys.executable, str(Path(__file__).with_name('app_sso_worker.py')),
                       '--control-fd', str(peer.fileno()), '--backend-repo', str(backend),
                       '--web-build', str(web), '--gateway', gateway, '--case', case]
            if channel:
                command += ['--browser-channel', channel]
            worker = subprocess.Popen(command, pass_fds=(peer.fileno(),), env=environment,
                                      start_new_session=True)
            peer.close()
            while worker.poll() is None:
                children.sample()
                if cancelled['signal'] is not None or time.monotonic() >= deadline:
                    interrupted = True
                    break
                if not select.select([control], [], [], 0.02)[0]:
                    continue
                packet = receive_packet(control)
                if packet is None:
                    worker.wait(timeout=2)
                    break
                value = owner.dispatch(packet)
                send_packet(control, {'ok': True, 'value': value})
            if not interrupted:
                require(worker.wait(timeout=1) == 0 and owner.result is not None,
                        'Owned browser worker failed; sensitive details withheld')
                # A clean worker exit must also have closed its driver/Chrome.
                until = time.monotonic() + 1
                while children.living() and time.monotonic() < until:
                    children.reap(worker)
                    time.sleep(0.02)
                require(not children.living(), 'Owned browser worker left live descendants')
                require(not owner.containers and not owner.directory.exists(),
                        'Owned browser worker did not complete resource cleanup')
        except BaseException as error:
            failure = error
        finally:
            # Independent fallback always runs, including abrupt worker death,
            # partial startup, browser launch/close hangs and a SIGSTOPped worker.
            cleanup_deadline = owner.begin_cleanup()
            try:
                try:
                    if worker is not None:
                        children.stop(worker, cleanup_deadline)
                finally:
                    owner.close(cleanup_deadline)
            finally:
                if control is not None:
                    control.close()
                if peer is not None:
                    peer.close()
        if interrupted or cancelled['signal'] is not None or time.monotonic() >= deadline:
            raise FixtureFailure('Owned fixture interrupted or exceeded its wall-clock budget; supervisor cleanup verified')
        if failure is not None:
            raise FixtureFailure('Owned fixture failed; supervisor cleanup verified; sensitive details withheld') from None
        print('PASS:', case, '; gateway:', gateway, '; independent supervisor cleanup verified', flush=True)
        print('Evidence:', json.dumps(owner.result, sort_keys=True), flush=True)
