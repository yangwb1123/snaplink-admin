"""Bounded, ownership-checked resources for the new loopback-only cases."""

from contextlib import contextmanager
from http.server import HTTPServer
import json
import os
from pathlib import Path
import socket
import socketserver
import subprocess
import threading
import time
import uuid

from browser_sso_rp import FixtureFailure, require


OWNER_LABEL = 'site.snaplink.app-sso.owner'
_supervisor = None


class CleanupPending(FixtureFailure):
    """Read-only reconciliation may continue; never replay a Docker mutation."""


class DockerNotStarted(FixtureFailure):
    """Popen failed before exec: no Docker command or mutation was submitted."""


@contextmanager
def supervised_resources(owner):
    global _supervisor
    require(_supervisor is None, 'Owned fixture supervisor cannot be nested')
    _supervisor = owner
    try:
        yield
    finally:
        _supervisor = None


def owned_directory(stack):
    if _supervisor is None:
        return None
    directory = Path(_supervisor.request('workspace'))
    stack.callback(_supervisor.request, 'release-workspace')
    return directory


def docker(arguments, *, timeout=3):
    # The two-process fixture's loopback is this host, never a remote
    # environment-selected daemon/context. No global Docker config changes.
    environment = {key: value for key, value in os.environ.items() if not key.startswith('DOCKER_')}
    try:
        process = subprocess.Popen(['docker', '--host', 'unix:///var/run/docker.sock', *arguments],
                                   env=environment, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    except OSError:
        # Only Popen's admission/exec failure proves that no command ran. An
        # OSError from communication, a nonzero exit or a timeout does NOT.
        raise DockerNotStarted('Owned container command not started') from None
    with process:
        try:
            output, _ = process.communicate(timeout=timeout)
        except (OSError, subprocess.TimeoutExpired):
            process.kill()
            process.wait()  # Reap our CLI; do not wait on inherited output pipes.
            raise FixtureFailure('Owned container command outcome unknown') from None
    require(process.returncode == 0, 'Owned container command failed')
    return output.decode().strip()


def container_ids(name, *, timeout=3):
    return docker(['container', 'ls', '-aq', '--no-trunc', '--filter', 'name=^/' + name + '$'], timeout=timeout).splitlines()


def owned_container(stack, arguments, *, command=()):
    """Run once; reconcile ambiguous outcomes by exact name/label/ID, never retry."""
    if _supervisor is not None:
        identity = _supervisor.request('container', arguments=arguments, command=list(command))
        stack.callback(_supervisor.request, 'release-container', identity=identity)
        return identity
    def continue_creation():
        require(not getattr(stack, 'fixture_cancelled', lambda: False)(),
                'Owned container creation interrupted; ownership reconciliation required')

    continue_creation()
    name = arguments[arguments.index('--name') + 1]
    require(not container_ids(name), 'Owned container name collision; foreign resource untouched')
    owner = uuid.uuid4().hex
    image = docker(['image', 'inspect', arguments[-1], '--format', '{{.Id}}'])
    require(image.startswith('sha256:') and len(image) == 71, 'Cached container image is unavailable')
    continue_creation()

    creation_pending = False
    created_identity, removal_requested, cleanup_verified = None, False, False

    def cleanup():
        nonlocal creation_pending, created_identity, removal_requested, cleanup_verified
        if cleanup_verified:
            return

        def observe(operation, *args, **kwargs):
            try:
                return operation(*args, **kwargs)
            except FixtureFailure:
                raise CleanupPending('Owned container census unavailable; cleanup unconfirmed') from None

        def remaining(cap):
            deadline = getattr(stack, 'fixture_deadline', None)
            if deadline is None:
                return cap
            left = deadline - time.monotonic()
            require(left > 0, 'Owned cleanup deadline expired; cleanup unconfirmed')
            return min(cap, left)
        ids = observe(container_ids, name, timeout=remaining(3))
        deadline = time.monotonic() + remaining(5)
        while creation_pending and not ids and time.monotonic() < deadline:
            time.sleep(min(0.1, max(0, deadline - time.monotonic())))
            ids = observe(container_ids, name, timeout=remaining(3))
        if not ids and creation_pending and not removal_requested:
            raise CleanupPending('Container creation outcome unknown; cleanup unconfirmed')
        if ids:
            require(len(ids) == 1, 'Owned container identity is ambiguous; untouched')
            data = json.loads(observe(docker, ['container', 'inspect', ids[0], '--format',
                                              '{{json .}}'], timeout=remaining(3)))
            require(data.get('Id') == ids[0] and data.get('Name') == '/' + name and
                    data.get('Config', {}).get('Labels', {}).get(OWNER_LABEL) == owner and
                    data.get('Image') == image and (created_identity is None or ids == [created_identity]),
                    'Container ownership mismatch; foreign resource untouched')
            created_identity, creation_pending = ids[0], False
            if not removal_requested:
                timeout = remaining(10)  # Budget admission must precede mutation admission.
                removal_requested = True  # Persist BEFORE the possibly ambiguous mutation.
                try:
                    docker(['container', 'rm', '-f', ids[0]], timeout=timeout)
                except DockerNotStarted:
                    removal_requested = False  # No command ran; still owe the one removal.
                    raise CleanupPending('Owned removal command not started; cleanup pending') from None
                except FixtureFailure:
                    pass  # Reconcile the one removal; never issue it twice.
        if observe(container_ids, name, timeout=remaining(3)):
            raise CleanupPending('Owned container removal not verified')
        cleanup_verified = True

    # Registered BEFORE creation/activation, including ambiguous timeouts. Existing
    # resources cannot have the new random label, and are never removed.
    stack.fixture_container_cleanup = cleanup  # Survives a consumed ExitStack callback.
    stack.callback(cleanup)
    bounded = ['--label', OWNER_LABEL + '=' + owner, '--memory', '128m', '--cpus', '1',
               '--pids-limit', '64', '--restart=no', '--env', 'NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=1']
    creation = ['create', *[item for item in arguments[2:-1] if item != '-d']]
    creation = [item.replace('/run', '/run:size=8m').replace('/var/cache/nginx', '/var/cache/nginx:size=16m')
                if item in ('/run', '/var/cache/nginx') else item for item in creation]
    continue_creation()
    creation_pending = True
    try:
        identity = docker([*creation, *bounded, image, *command],
                          timeout=getattr(stack, 'fixture_command_timeout', 30))
    except DockerNotStarted:
        creation_pending = False  # There is no ambiguous create to wait for or replay.
        raise
    require(len(identity) == 64 and all(char in '0123456789abcdef' for char in identity),
            'Owned container creation identity is invalid')
    created_identity = identity
    continue_creation()
    require(container_ids(name) == [identity], 'Owned container creation not verified')
    creation_pending = False
    continue_creation()
    docker(['container', 'start', identity], timeout=getattr(stack, 'fixture_command_timeout', 20))
    return identity


def owned_redis(stack, directory):
    # Docker atomically allocates the host port: never PING or reuse a listener
    # discovered on the host. The only published binding must be IPv4 loopback.
    identity = owned_container(stack, [
        'docker', 'run', '-d', '--name', 'snaplink-app-sso-redis-' + directory.name,
        '--network', 'bridge', '--publish', '127.0.0.1::6379', '--log-driver=none',
        '--read-only', '--user', 'redis:redis', '--cap-drop=ALL', '--security-opt=no-new-privileges',
        '--tmpfs', '/data:size=8m', '--tmpfs', '/tmp:size=2m', 'redis:7-alpine',
    ], command=['redis-server', '--bind', '0.0.0.0', '--protected-mode', 'no', '--save', '',
                '--appendonly', 'no', '--maxmemory', '64mb', '--maxmemory-policy', 'noeviction',
                '--loglevel', 'warning'])
    bindings = json.loads(docker(['container', 'inspect', identity, '--format', '{{json .NetworkSettings.Ports}}']))
    published = bindings.get('6379/tcp', [])
    require(set(bindings) == {'6379/tcp'} and len(published) == 1 and
            published[0].get('HostIp') == '127.0.0.1', 'Owned Redis loopback publication not verified')
    port = int(published[0].get('HostPort', '0'))
    require(0 < port < 65536, 'Owned Redis port is invalid')
    return port


class OwnedGatewayServer(socketserver.ThreadingTCPServer):
    """Cap accepted TLS workers; close only our accepted sockets at teardown."""
    def __init__(self, *args, **kwargs):
        self.worker_lock = threading.Lock()
        self.workers, self.connections = [], set()
        self.exhausted = self.worker_failed = False
        super().__init__(*args, **kwargs)

    def process_request(self, request, address):
        with self.worker_lock:
            if len(self.connections) >= 16 or len(self.workers) >= 512:
                self.exhausted = True
                self.shutdown_request(request)
                return
            self.connections.add(request)
            worker = threading.Thread(target=self.process_request_thread, args=(request, address), daemon=True)
            self.workers.append(worker)
            worker.start()

    def process_request_thread(self, request, address):
        try:
            super().process_request_thread(request, address)
        finally:
            with self.worker_lock:
                self.connections.discard(request)

    def handle_error(self, *_):
        self.worker_failed = True  # Fixed teardown failure, never a raw request traceback.

    def close_workers(self):
        with self.worker_lock:
            connections = list(self.connections)
        for connection in connections:
            try:
                connection.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
            connection.close()
        deadline = min(time.monotonic() + 3, getattr(self, 'fixture_deadline', float('inf')))
        for worker in self.workers:
            worker.join(timeout=max(0, deadline - time.monotonic()))
        require(not any(worker.is_alive() for worker in self.workers) and not self.exhausted and not self.worker_failed,
                'Owned gateway worker cleanup or resource bound not verified')


class OwnedHTTPServer(OwnedGatewayServer, HTTPServer):
    def get_request(self):
        connection, address = super().get_request()
        connection.settimeout(5)
        return connection, address
