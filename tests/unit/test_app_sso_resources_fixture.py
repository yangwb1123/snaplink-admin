"""Owned fixture failure paths; never contact Docker or touch a foreign owner."""

from contextlib import ExitStack
import json
from pathlib import Path
import signal
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import Mock, patch

from app_sso_fixture_support import entry, fixture, modules, resources, rp, scenario


class ContainerOwnershipTest(unittest.TestCase):
    arguments = ['docker', 'run', '-d', '--name', 'fixture-unique', '--network', 'host',
                 '--log-driver=none', '--read-only', '--tmpfs', '/run', '--tmpfs', '/var/cache/nginx', 'nginx:alpine']
    image = 'sha256:' + 'a' * 64
    container = 'b' * 64

    def test_foreign_collision_is_never_run_or_removed(self):
        with ExitStack() as stack, patch.object(resources, 'docker') as docker, \
                patch.object(resources, 'container_ids', return_value=['foreign']):
            with self.assertRaises(rp.FixtureFailure):
                resources.owned_container(stack, self.arguments)
            docker.assert_not_called()

    def test_bounded_cached_ownership_and_verified_removal_even_after_ambiguous_run(self):
        for ambiguous in (False, True):
            with self.subTest(ambiguous=ambiguous):
                calls, owner = [], []
                def docker(arguments, **_):
                    calls.append(arguments)
                    if arguments[:2] == ['image', 'inspect']:
                        return self.image
                    if arguments[0] == 'create':
                        owner.append(arguments[arguments.index('--label') + 1].split('=', 1)[1])
                        for flag in ('--memory', '--cpus', '--pids-limit', '--restart=no', '--read-only', '--log-driver=none'):
                            self.assertIn(flag, arguments)
                        self.assertEqual(arguments[-1], self.image)
                        self.assertIn('/run:size=8m', arguments)
                        self.assertIn('/var/cache/nginx:size=16m', arguments)
                        if ambiguous:
                            raise rp.FixtureFailure('Owned container command outcome unknown')
                        return self.container
                    if arguments[:2] == ['container', 'inspect']:
                        return json.dumps({'Id': self.container, 'Name': '/fixture-unique', 'Image': self.image,
                                           'Config': {'Labels': {resources.OWNER_LABEL: owner[0]}}})
                    return ''
                with patch.object(resources, 'docker', side_effect=docker), \
                        patch.object(resources, 'container_ids', side_effect=(
                            [[], [self.container], []] if ambiguous else [[], [self.container], [self.container], []])):
                    if ambiguous:
                        with self.assertRaises(rp.FixtureFailure), ExitStack() as stack:
                            resources.owned_container(stack, self.arguments)
                    else:
                        with ExitStack() as stack:
                            resources.owned_container(stack, self.arguments)
                self.assertEqual(sum(call[0] == 'create' for call in calls), 1)
                self.assertNotIn('run', [call[0] for call in calls])
                self.assertIn(['container', 'rm', '-f', self.container], calls)

    def test_creation_identity_is_known_before_start_and_run_is_never_replayed(self):
        calls, owner = [], []
        def docker(arguments, **_):
            calls.append(arguments)
            if arguments[:2] == ['image', 'inspect']:
                return self.image
            if arguments[0] in ('run', 'create'):
                owner.append(arguments[arguments.index('--label') + 1].split('=', 1)[1])
                return self.container
            if arguments[:2] == ['container', 'inspect']:
                return json.dumps({'Id': self.container, 'Name': '/fixture-unique', 'Image': self.image,
                                   'Config': {'Labels': {resources.OWNER_LABEL: owner[0]}}})
            return ''
        with patch.object(resources, 'docker', side_effect=docker), \
                patch.object(resources, 'container_ids', side_effect=[[], [self.container], [self.container], []]):
            with ExitStack() as stack:
                resources.owned_container(stack, self.arguments)
        self.assertNotIn('run', [call[0] for call in calls])
        create = next(call for call in calls if call[0] == 'create')
        self.assertIn('NGINX_ENTRYPOINT_WORKER_PROCESSES_AUTOTUNE=1', create)
        self.assertIn(['container', 'start', self.container], calls)

    def test_unobserved_ambiguous_creation_cannot_claim_cleanup_success(self):
        def docker(arguments, **_):
            if arguments[:2] == ['image', 'inspect']:
                return self.image
            raise rp.FixtureFailure('Controlled creation outcome unknown')
        with patch.object(resources, 'docker', side_effect=docker) as command, \
                patch.object(resources, 'container_ids', return_value=[]), \
                patch.object(resources, 'time', SimpleNamespace(monotonic=Mock(side_effect=[0, 10]))):
            with self.assertRaisesRegex(rp.FixtureFailure, 'cleanup unconfirmed'), ExitStack() as stack:
                resources.owned_container(stack, self.arguments)
        self.assertEqual(sum(call.args[0][0] == 'create' for call in command.call_args_list), 1)
        self.assertFalse(any(call.args[0][:2] == ['container', 'rm'] for call in command.call_args_list))

    def test_changed_ownership_or_failed_removal_prevents_pass(self):
        for matching, removed in ((False, True), (True, False)):
            owner = []
            def docker(arguments, **_):
                if arguments[:2] == ['image', 'inspect']:
                    return self.image
                if arguments[0] == 'create':
                    owner.append(arguments[arguments.index('--label') + 1].split('=', 1)[1])
                    return self.container
                if arguments[:2] == ['container', 'inspect']:
                    return json.dumps({'Id': self.container, 'Name': '/fixture-unique', 'Image': self.image,
                                       'Config': {'Labels': {resources.OWNER_LABEL: owner[0] if matching else 'foreign'}}})
                return ''
            with patch.object(resources, 'docker', side_effect=docker) as command, \
                    patch.object(resources, 'container_ids', side_effect=[[], [self.container], [self.container],
                                                                          [] if removed else [self.container]]):
                with self.assertRaises(rp.FixtureFailure), ExitStack() as stack:
                    resources.owned_container(stack, self.arguments)
                removals = [call for call in command.call_args_list if call.args[0][:2] == ['container', 'rm']]
                self.assertEqual(len(removals), int(matching))


class LiveResourcesTest(unittest.TestCase):
    def test_new_case_docker_commands_cannot_follow_remote_environment_context(self):
        result = SimpleNamespace(returncode=0, stdout=b'owned', stderr=b'private-fixture')
        with patch.dict('os.environ', {'DOCKER_HOST': 'tcp://unowned.test:2375', 'DOCKER_CONTEXT': 'unowned'}), \
                patch.object(resources.subprocess, 'run', return_value=result) as command:
            self.assertEqual(resources.docker(['image', 'inspect', 'redis:7-alpine']), 'owned')
        self.assertEqual(command.call_args.args[0][:3], ['docker', '--host', 'unix:///var/run/docker.sock'])
        self.assertFalse(any(key.startswith('DOCKER_') for key in command.call_args.kwargs['env']))
        self.assertEqual(command.call_args.kwargs['timeout'], 3)

    def test_redis_is_new_bounded_published_only_on_loopback_and_has_no_persistence(self):
        identity = 'b' * 64
        bindings = {'6379/tcp': [{'HostIp': '127.0.0.1', 'HostPort': '40004'}]}
        with ExitStack() as stack, patch.object(resources, 'owned_container', return_value=identity) as launch, \
                patch.object(resources, 'docker', return_value=json.dumps(bindings)):
            self.assertEqual(resources.owned_redis(stack, Path('/owned/unique')), 40004)
        args, command = launch.call_args.args[1], launch.call_args.kwargs['command']
        for flag in ('--log-driver=none', '--read-only', '--cap-drop=ALL', '--security-opt=no-new-privileges'):
            self.assertIn(flag, args)
        self.assertEqual(args[args.index('--publish') + 1], '127.0.0.1::6379')
        self.assertEqual(args[-1], 'redis:7-alpine')
        self.assertEqual(command[command.index('--save') + 1], '')
        self.assertEqual(command[command.index('--appendonly') + 1], 'no')
        self.assertEqual(command[command.index('--maxmemory-policy') + 1], 'noeviction')
        self.assertEqual(command[command.index('--maxmemory') + 1], '64mb')
        for invalid in ({}, {'6379/tcp': [{'HostIp': '0.0.0.0', 'HostPort': '40004'}]}):
            with ExitStack() as stack, patch.object(resources, 'owned_container', return_value=identity), \
                    patch.object(resources, 'docker', return_value=json.dumps(invalid)):
                with self.assertRaises(rp.FixtureFailure):
                    resources.owned_redis(stack, Path('/owned/unique'))

    def test_redis_image_command_follows_cached_immutable_image_and_cleanup_still_checks_owner(self):
        owner, calls = [], []
        image, identity = 'sha256:' + 'a' * 64, 'b' * 64
        def docker(arguments, **_):
            calls.append(arguments)
            if arguments[:2] == ['image', 'inspect']:
                return image
            if arguments[0] == 'create':
                owner.append(arguments[arguments.index('--label') + 1].split('=', 1)[1])
                self.assertEqual(arguments[-3:], [image, 'redis-server', '--version'])
                return identity
            if arguments[:2] == ['container', 'inspect']:
                return json.dumps({'Id': identity, 'Name': '/fixture-unique', 'Image': image,
                                   'Config': {'Labels': {resources.OWNER_LABEL: owner[0]}}})
            return ''
        args = ['docker', 'run', '-d', '--name', 'fixture-unique', '--network', 'bridge',
                '--publish', '127.0.0.1::6379', '--read-only', '--log-driver=none', 'redis:7-alpine']
        with patch.object(resources, 'docker', side_effect=docker), \
                patch.object(resources, 'container_ids', side_effect=[[], [identity], [identity], []]):
            with ExitStack() as stack:
                self.assertEqual(resources.owned_container(stack, args, command=['redis-server', '--version']), identity)
        self.assertIn(['container', 'rm', '-f', identity], calls)

    def test_both_owned_processes_are_signalled_before_wait_and_failed_second_start_is_owned(self):
        owned = entry.LiveReplicaFixture(Path('/source'), Path('/web'), 'python')
        first, second = Mock(pid=101), Mock(pid=202)
        events = []
        owned.processes = [first]  # R2 failed readiness before being appended.
        for index, process in enumerate((first, second), 1):
            process.poll.return_value = None
            process.terminate.side_effect = lambda n=index: events.append(('terminate', n))
            def wait(*_, p=process, n=index, **__):
                events.append(('wait', n))
                p.poll.return_value = 0
            process.wait.side_effect = wait
        import time
        owned.stack.fixture_deadline = time.monotonic() + 20
        owned.stop_backend(second)
        first_wait = next(i for i, event in enumerate(events) if event[0] == 'wait')
        self.assertEqual(set(events[:first_wait]), {('terminate', 1), ('terminate', 2)})
        for process in (first, second):
            self.assertEqual(process.poll(), 0)
            process.kill.assert_not_called()
        owned.stop_backend(first)
        self.assertEqual(events.count(('terminate', 1)), 1)


    def test_second_readiness_failure_registers_cleanup_before_failure_and_stops_both(self):
        import subprocess
        import time
        owned = entry.LiveReplicaFixture(Path('/source'), Path('/web'), 'python')
        owned.directory = Path(owned.stack.enter_context(tempfile.TemporaryDirectory(prefix='app-sso-unit-')))
        owned.binary = owned.directory / 'not-executed'
        first, second = Mock(pid=101), Mock(pid=202)
        owned.processes = [first]
        for process in (first, second):
            process.poll.return_value = None
            process.wait.side_effect = lambda *_, p=process, **__: setattr(p.poll, 'return_value', 0)
        with patch.object(fixture.subprocess, 'Popen', return_value=second) as spawn, \
                patch.object(fixture, 'wait_ready', side_effect=rp.FixtureFailure('Controlled second readiness failure')):
            with self.assertRaisesRegex(rp.FixtureFailure, '^Controlled second readiness failure$'):
                owned.launch_backend('http://127.0.0.1:40003', owned.directory / 'config.yaml')
        self.assertEqual(spawn.call_args.kwargs['stdout'], subprocess.DEVNULL)
        self.assertEqual(spawn.call_args.kwargs['stderr'], subprocess.DEVNULL)
        owned.stack.fixture_deadline = time.monotonic() + 20
        owned.stack.close()
        self.assertFalse(owned.directory.exists())
        for process in (first, second):
            process.terminate.assert_called_once_with()
            self.assertIsNotNone(process.poll())
        second.poll.return_value = None
        owned.processes.append(second)
        with self.assertRaisesRegex(rp.FixtureFailure, '^Owned replica cleanup not verified$'):
            owned.verify_closed()


    def test_live_cleanup_checks_redis_listener_without_touching_its_owner(self):
        import socket
        owned = entry.LiveReplicaFixture(Path('/source'), Path('/web'), 'python')
        with socket.socket() as listener:
            listener.bind(('127.0.0.1', 0))
            listener.listen()
            owned.redis_port = listener.getsockname()[1]
            with self.assertRaisesRegex(rp.FixtureFailure, '^Owned replica or Redis listener cleanup not verified'):
                owned.verify_closed()
            self.assertNotEqual(listener.fileno(), -1)
        owned.verify_closed()


class EntryLifecycleTest(unittest.TestCase):
    def test_controlled_termination_records_cancellation_without_raising_and_restores_handlers(self):
        import os
        previous = signal.getsignal(signal.SIGTERM)
        with modules['app_sso_children'].termination_flag() as cancelled:
            os.kill(os.getpid(), signal.SIGTERM)
            self.assertEqual(cancelled['signal'], signal.SIGTERM)
            # Repeated termination is recorded, not ignored; no library unwind.
            os.kill(os.getpid(), signal.SIGTERM)
            self.assertEqual(cancelled['signal'], signal.SIGTERM)
        self.assertIs(signal.getsignal(signal.SIGTERM), previous)

    def test_partial_start_and_browser_failure_cleanup_are_not_success(self):
        owned = entry.EntryFixture(Path('/missing'), Path('/missing'), 'python')
        cleanup = Mock()
        def fail():
            owned.stack.callback(cleanup)
            raise rp.FixtureFailure('Controlled partial startup failure')
        with patch.object(owned, 'start', side_effect=fail):
            with self.assertRaises(rp.FixtureFailure):
                with owned:
                    self.fail('failed fixture entered')
        cleanup.assert_called_once_with()
        factory, playwright = Mock(), Mock()
        manager = factory.return_value
        manager.__enter__ = Mock(return_value=Mock())
        manager.__exit__ = Mock(return_value=False)
        with patch.object(scenario, 'EntryFixture', factory), patch.object(scenario, 'entry_controls'), \
                patch.object(scenario, 'run_entry_browser', side_effect=rp.FixtureFailure('Controlled browser failure')):
            with self.assertRaises(rp.FixtureFailure):
                scenario.run_entry_case(playwright, Path('/source'), Path('/web'), 'python', 'chrome')
        playwright.chromium.launch.return_value.close.assert_called_once_with()
        manager.__exit__.assert_called_once()

    def test_partial_rp_creation_closes_the_first_listener_on_second_bind_failure(self):
        owned = entry.EntryFixture(Path('/source'), Path('/web'), 'python')
        first = Mock()
        with owned.stack, patch.object(entry, 'EntryRP', side_effect=[first, OSError('controlled bind failure')]):
            with self.assertRaises(OSError):
                owned.start_rps()
        first.close.assert_called_once_with()

    def test_server_activation_failure_closes_its_socket(self):
        import socketserver
        with ExitStack() as stack:
            server = socketserver.TCPServer(('127.0.0.1', 0), Mock())
            with patch.object(fixture.threading.Thread, 'start', side_effect=RuntimeError('controlled thread failure')):
                with self.assertRaises(RuntimeError):
                    fixture.start_server(stack, server)
        self.assertEqual(server.socket.fileno(), -1)

    def test_owned_http_partial_connection_is_closed_and_workers_join(self):
        from http.server import BaseHTTPRequestHandler
        import socket
        import time
        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_):
                pass
        connection = None
        try:
            with ExitStack() as stack:
                server = resources.OwnedHTTPServer(('127.0.0.1', 0), Handler)
                fixture.start_server(stack, server)
                connection = socket.create_connection(server.server_address, timeout=1)
                deadline = time.monotonic() + 2
                while not server.connections and time.monotonic() < deadline:
                    time.sleep(0.01)
                self.assertTrue(server.connections)
            self.assertFalse(server.fixture_thread.is_alive())
            self.assertTrue(all(not worker.is_alive() for worker in server.workers))
            self.assertEqual(server.socket.fileno(), -1)
        finally:
            if connection is not None:
                connection.close()

    def partial_entry_sink(self):
        import socket
        import time
        import urllib.parse
        owned = entry.EntryFixture(Path('/source'), Path('/web'), 'python')
        self.addCleanup(owned.close)
        owned.sink = owned.create_sink()
        server = owned.sink.server
        self.assertIsInstance(server, resources.OwnedHTTPServer)
        target = urllib.parse.urlsplit(owned.sink.origin)
        connection = socket.create_connection((target.hostname, target.port), timeout=1)
        self.addCleanup(connection.close)
        connection.sendall(b'GET /check HTTP/1.0\r\nX-Partial:')
        deadline = time.monotonic() + 2
        while not server.connections and time.monotonic() < deadline:
            time.sleep(0.01)
        with server.worker_lock:
            self.assertEqual(len(server.connections), 1)
            self.assertEqual(len(server.workers), 1)
            self.assertEqual(next(iter(server.connections)).gettimeout(), 5)
        return owned, connection

    def test_entry_sink_partial_request_cannot_serve_after_verified_teardown(self):
        owned, connection = self.partial_entry_sink()
        server = owned.sink.server
        owned.close()
        self.assertFalse(server.fixture_thread.is_alive())
        self.assertTrue(all(not worker.is_alive() for worker in server.workers))
        self.assertFalse(server.connections)
        self.assertEqual(server.socket.fileno(), -1)
        try:
            connection.sendall(b' fixture\r\n\r\n')
            response = connection.recv(4096)
        except (BrokenPipeError, ConnectionResetError):
            response = b''
        self.assertEqual(response, b'', 'Sink connection served data after verified teardown')

    def test_entry_cleanup_rejects_sink_workers_even_when_listener_is_closed(self):
        owned, _ = self.partial_entry_sink()
        server = owned.sink.server
        self.addCleanup(server.close_workers)
        with patch.object(server, 'close_workers'):
            with self.assertRaisesRegex(rp.FixtureFailure, '^Owned service sink cleanup not verified$'):
                owned.close()
        self.assertEqual(server.socket.fileno(), -1)
        self.assertFalse(server.fixture_thread.is_alive())
        self.assertTrue(any(worker.is_alive() for worker in server.workers))
        self.assertTrue(server.connections)
        server.close_workers()
        owned.verify_closed()

    def test_port_collision_fails_without_touching_its_foreign_listener(self):
        import socket
        with socket.socket() as foreign:
            foreign.bind(('127.0.0.1', 0))
            foreign.listen()
            with self.assertRaises(OSError):
                resources.OwnedHTTPServer(foreign.getsockname(), Mock())
            with socket.create_connection(foreign.getsockname(), timeout=1):
                connection, _ = foreign.accept()
                connection.close()

    def test_leftover_process_or_store_rejects_cleanup(self):
        owned = entry.EntryFixture(Path('/source'), Path('/web'), 'python')
        owned.process = Mock()
        owned.process.poll.return_value = None
        with self.assertRaises(rp.FixtureFailure):
            owned.verify_closed()
        owned.process = None
        with tempfile.TemporaryDirectory() as directory:
            owned.directory = Path(directory)
            with self.assertRaises(rp.FixtureFailure):
                owned.verify_closed()
        owned.verify_closed()


if __name__ == '__main__':
    unittest.main()
