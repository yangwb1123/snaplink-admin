#!/usr/bin/env python3
"""External real-Chrome SIGTERM probes of the actual loopback CLI; no mocks."""

import argparse
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import time

import yaml

from app_sso_children import OwnedChildren, process_identity, termination_flag
from app_sso_resources import OWNER_LABEL, container_ids, docker
from browser_sso_fixture import ROOT, fixture_environment
from browser_sso_rp import FixtureFailure, require


def command_line(pid):
    try:
        return [part.decode() for part in Path(f'/proc/{pid}/cmdline').read_bytes().split(b'\0') if part]
    except (FileNotFoundError, ProcessLookupError, PermissionError):
        return []


def tcp_listeners():
    entries = {}
    for line in Path('/proc/net/tcp').read_text().splitlines()[1:]:
        fields = line.split()
        if fields[3] == '0A':
            address, port = fields[1].split(':')
            entries[fields[9]] = (socket.inet_ntoa(bytes.fromhex(address)[::-1]), int(port, 16))
    return entries


class Observation:
    def __init__(self):
        self.before = set(docker(['container', 'ls', '-aq', '--no-trunc']).splitlines())
        self.directories, self.containers, self.stock, self.listeners = {}, {}, {}, set()
        self.chrome, self.profiles, self.cli, self.worker = set(), set(), None, None

    def sample(self, children, make_pid):
        children.sample()
        listeners = tcp_listeners()
        for (pid, ticks), descriptor in list(children.identities.items()):
            identity = process_identity(pid)
            if identity is None or identity[1] != ticks:
                continue
            args = command_line(pid)
            if not args:
                continue
            executable = Path(args[0]).name
            if any(Path(arg).name == 'browser_sso_test.py' for arg in args) and identity[0] == make_pid:
                self.cli = (pid, descriptor)
            if any(Path(arg).name == 'app_sso_worker.py' for arg in args):
                self.worker = (pid, descriptor)
            if executable == 'chrome':
                self.chrome.add((pid, ticks))
                for argument in args:
                    if argument.startswith('--user-data-dir='):
                        profile = Path(argument.split('=', 1)[1])
                        require(profile.parent in self.directories, 'Chrome profile escaped owned temporary storage')
                        self.profiles.add(profile)
            try:
                for path in Path(f'/proc/{pid}/fd').iterdir():
                    try:
                        link = os.readlink(path)
                        if link.startswith('socket:[') and link[8:-1] in listeners:
                            self.listeners.add(listeners[link[8:-1]])
                    except (FileNotFoundError, ProcessLookupError, PermissionError):
                        pass
            except (FileNotFoundError, ProcessLookupError, PermissionError):
                pass  # Chrome's transient non-dumpable /proc FD view; pidfds still track exit.
            if executable != 'sso-server':
                continue
            directory = Path(args[0]).parent
            require(directory.parent == Path('/tmp') and directory.name.startswith('snaplink-browser-sso-'),
                    'Probe stock directory attribution failed')
            info = directory.lstat()
            require(not directory.is_symlink() and info.st_uid == os.getuid(), 'Probe directory ownership mismatch')
            new = directory not in self.directories
            self.directories[directory] = (info.st_dev, info.st_ino, info.st_uid)
            config = yaml.safe_load(Path(args[args.index('-config') + 1]).read_text())
            self.stock[(pid, ticks)] = tuple(config['server']['listen'].rsplit(':', 1))
            self.listeners.add(('127.0.0.1', int(config['server']['listen'].rsplit(':', 1)[1])))
            if new:
                self.observe_containers(directory)

    def observe_containers(self, directory):
        for name in ('snaplink-app-sso-redis-' + directory.name, 'snaplink-browser-sso-' + directory.name):
            ids = container_ids(name)
            if not ids:
                continue
            require(len(ids) == 1 and ids[0] not in self.before, 'Probe encountered pre-existing container; untouched')
            data = json.loads(docker(['container', 'inspect', ids[0], '--format', '{{json .}}']))
            owner = data.get('Config', {}).get('Labels', {}).get(OWNER_LABEL, '')
            require(data['Id'] == ids[0] and data['Name'] == '/' + name and
                    re.fullmatch('[0-9a-f]{32}', owner) is not None,
                    'Probe container attribution failed; untouched')
            self.containers[ids[0]] = (name, owner, data['Image'])
            if name.startswith('snaplink-app-sso-redis-'):
                bindings = data['NetworkSettings']['Ports']['6379/tcp']
                require(len(bindings) == 1 and bindings[0]['HostIp'] == '127.0.0.1',
                        'Probe Redis is not loopback-only')
                self.listeners.add(('127.0.0.1', int(bindings[0]['HostPort'])))

    def absent(self, children):
        children.sample()
        live = children.living()
        remaining = set(docker(['container', 'ls', '-aq', '--no-trunc']).splitlines())
        require(not live and not (set(self.containers) & remaining) and
                all(not path.exists() for path in self.directories) and
                not (self.listeners & set(tcp_listeners().values())) and self.before <= remaining,
                'Probe found leftover owned resources or changed foreign container inventory')

    def emergency_cleanup(self):
        # Only used if the fixture fails. Such a probe remains FAIL, even when
        # this independent fallback removes its attributable test resources.
        for identity, (name, owner, image) in self.containers.items():
            ids = container_ids(name)
            if not ids:
                continue
            require(ids == [identity], 'Probe emergency container identity changed; untouched')
            data = json.loads(docker(['container', 'inspect', identity, '--format', '{{json .}}']))
            require(data['Id'] == identity and data['Name'] == '/' + name and data['Image'] == image and
                    data['Config']['Labels'].get(OWNER_LABEL) == owner, 'Probe emergency ownership mismatch; untouched')
            try:
                docker(['container', 'rm', '-f', identity], timeout=10)
            except FixtureFailure:
                pass  # One removal only; reconcile, never replay.
            require(not container_ids(name), 'Probe emergency container removal unconfirmed')
        for directory, identity in self.directories.items():
            if directory.exists() or directory.is_symlink():
                info = directory.lstat()
                require(not directory.is_symlink() and
                        (info.st_dev, info.st_ino, info.st_uid) == identity,
                        'Probe emergency directory identity changed; untouched')
                shutil.rmtree(directory)


def probe(args, gateway, phase, cancelled):
    observation = Observation()
    environment = fixture_environment()
    environment['PYTHONUNBUFFERED'] = '1'
    command = ['make', 'test-browser-sso', 'BROWSER_SSO_ARGS=--browser-channel chrome --backend-repo ' +
               str(args.backend_repo.resolve()) + ' --case live-replicas --gateway ' + gateway]
    start, sent = time.monotonic(), None
    text, tail, failure, fallback = '', '', None, False
    with OwnedChildren() as children:
        make = subprocess.Popen(command, cwd=ROOT, env=environment, stdout=subprocess.PIPE,
                                stderr=subprocess.STDOUT, start_new_session=True)
        os.set_blocking(make.stdout.fileno(), False)
        try:
            while True:
                require(cancelled['signal'] is None, 'Termination regression interrupted; owned cleanup required')
                try:
                    data = os.read(make.stdout.fileno(), 65536)
                except BlockingIOError:
                    data = None
                if data:
                    tail += data.decode(errors='replace')
                    require(len(text) + len(tail) <= 262144, 'Probe output exceeded its budget')
                    if '\n' in tail:
                        lines, tail = tail.rsplit('\n', 1)
                        text += lines + '\n'
                observation.sample(children, make.pid)
                require(time.monotonic() - start < 180, 'Probe startup exceeded its budget')
                if sent is None:
                    ready = 'Phase: two distinct stock processes concurrently ready;' in text
                    launched = 'Case: live-replicas;' in text
                    active = 'Phase: wait for username field' in text
                    target = (phase == 'launch' and ready and observation.chrome and not launched) or (
                        phase == 'active-stopped' and active and observation.chrome)
                    if target:
                        require(observation.cli and observation.worker and len(observation.stock) == 2 and
                                len(observation.profiles) == 1 and len(observation.directories) == 1 and
                                len(observation.containers) == (1 if gateway == 'python' else 2),
                                'Probe lacks attributable live replicas/Chrome/owned containers')
                        if phase == 'active-stopped':
                            signal.pidfd_send_signal(observation.worker[1], signal.SIGSTOP)
                            # A real OS-stopped worker cannot run its ExitStack.
                            until = time.monotonic() + 1
                            while time.monotonic() < until:
                                stat = Path(f'/proc/{observation.worker[0]}/stat').read_text().rsplit(')', 1)[1].split()
                                if stat[0] == 'T':
                                    break
                                time.sleep(0.005)
                            require(stat[0] == 'T', 'Probe worker stop was not observed')
                        signal.pidfd_send_signal(observation.cli[1], signal.SIGTERM)
                        sent = time.monotonic()
                else:
                    require(time.monotonic() - sent < 25, 'Probe SIGTERM teardown exceeded twenty-five seconds')
                if make.poll() is not None and data == b'':
                    break
                time.sleep(0.005)
            code = make.wait(timeout=1)
            require(sent is not None and code != 0 and 'supervisor cleanup verified' in text and
                    'Evidence:' not in text and 'Browser SSO: PASS' not in text,
                    'Probe did not observe the expected interrupted/verified CLI failure')
            children.reap(make)
            observation.absent(children)
        except BaseException as error:
            failure = error
            print('Termination probe primary failure:', str(error) if isinstance(error, FixtureFailure) else
                  type(error).__name__ + ' (details withheld)', file=sys.stderr, flush=True)
            print('Termination probe milestones:', json.dumps({
                'gateway': gateway, 'phase': phase, 'signal_sent': sent is not None,
                'concurrent_ready': 'Phase: two distinct stock processes' in text,
                'chrome_launched': 'Case: live-replicas;' in text,
                'active_navigation': 'Phase: wait for username field' in text,
                'stock_processes': len(observation.stock), 'containers': len(observation.containers),
                'supervisor_verified_message': 'supervisor cleanup verified' in text,
            }, sort_keys=True), file=sys.stderr, flush=True)
        finally:
            try:
                # Cleanup even when the regression itself fails. All pidfds were
                # opened only for descendants of this newly launched make.
                if failure is not None:
                    fallback = True
                    if observation.cli is not None:
                        try:
                            signal.pidfd_send_signal(observation.cli[1], signal.SIGTERM)
                        except ProcessLookupError:
                            pass
                    # Do not kill the independent supervisor while its bounded
                    # ownership reconciliation may still be running.
                    until = time.monotonic() + 25
                    while make.poll() is None and time.monotonic() < until:
                        children.sample()
                        time.sleep(0.02)
                    children.stop(make, time.monotonic() + 5)
                    observation.emergency_cleanup()
                else:
                    children.stop(make, time.monotonic() + 5)
                observation.absent(children)
            finally:
                make.stdout.close()
        if failure is not None:
            raise failure
    # No captured browser output, URLs, config, credentials or tokens persisted.
    return {'gateway': gateway, 'phase': phase, 'command_exit': code,
            'sigterm_cleanup_seconds': round(time.monotonic() - sent, 3),
            'stock_processes_observed': len(observation.stock), 'chrome_processes_observed': len(observation.chrome),
            'containers_observed': len(observation.containers), 'directories_observed': len(observation.directories),
            'chrome_profiles_within_owned_store': len(observation.profiles),
            'observed_descendants': len(children.identities), 'worker_stopped': phase == 'active-stopped',
            'cleanup_verified': True, 'emergency_cleanup_used': fallback}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--backend-repo', type=Path, required=True)
    parser.add_argument('--browser-channel', choices=('chrome',), required=True)
    parser.add_argument('--gateway', choices=('python', 'nginx', 'both'), default='both')
    parser.add_argument('--phase', choices=('launch', 'active-stopped', 'both'), default='both')
    args = parser.parse_args()
    try:
        with termination_flag() as cancelled:
            for gateway in (('python', 'nginx') if args.gateway == 'both' else (args.gateway,)):
                for phase in (('launch', 'active-stopped') if args.phase == 'both' else (args.phase,)):
                    require(cancelled['signal'] is None, 'Termination regression interrupted')
                    result = probe(args, gateway, phase, cancelled)
                    print('Termination evidence:', json.dumps(result, sort_keys=True), flush=True)
        print('PASS: real Chrome lifecycle SIGTERM; owned cleanup verified; no fixture grants/HA claim', flush=True)
        return 0
    except Exception as error:
        print('Termination regression: FAIL:', str(error) if isinstance(error, FixtureFailure) else
              type(error).__name__ + ' (details withheld)', file=sys.stderr, flush=True)
        return 1


if __name__ == '__main__':
    sys.exit(main())
