"""Real Linux cancellation and deterministic owned-container reconciliation."""

import json
import os
from pathlib import Path
import signal
import socket
import subprocess
import sys
import time
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from app_sso_fixture_support import modules, resources, rp

children_module = modules['app_sso_children']
supervisor = modules['app_sso_supervisor']


class SupervisorOwnershipTest(unittest.TestCase):
    def test_stopped_worker_and_detached_descendant_are_independently_killed_and_reaped(self):
        code = '''import subprocess, sys, time
child = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'], start_new_session=True)
print(child.pid, flush=True)
time.sleep(30)
'''
        with children_module.OwnedChildren() as owned:
            worker = subprocess.Popen([sys.executable, '-c', code], stdout=subprocess.PIPE, text=True)
            try:
                descendant = int(worker.stdout.readline())
                deadline = time.monotonic() + 2
                while not any(pid == descendant for pid, _ in owned.identities) and time.monotonic() < deadline:
                    owned.sample()
                    time.sleep(0.01)
                self.assertTrue(any(pid == descendant for pid, _ in owned.identities))
                self.assertNotEqual(os.getsid(worker.pid), os.getsid(descendant))
                descriptor = next(fd for (pid, _), fd in owned.identities.items() if pid == worker.pid)
                signal.pidfd_send_signal(descriptor, signal.SIGSTOP)
                owned.stop(worker, time.monotonic() + 3)
                self.assertIsNotNone(worker.poll())
                self.assertIsNone(children_module.process_identity(descendant))
                self.assertEqual(children_module.child_pids(os.getpid()), [])
            finally:
                owned.stop(worker, time.monotonic() + 3)
                worker.stdout.close()

    def test_preexisting_child_is_rejected_and_left_alive(self):
        foreign = subprocess.Popen([sys.executable, '-c', 'import time; time.sleep(30)'])
        try:
            with self.assertRaisesRegex(rp.FixtureFailure, 'pre-existing children'):
                with children_module.OwnedChildren():
                    self.fail('Pre-existing process accepted as fixture ownership')
            self.assertIsNone(foreign.poll())
        finally:
            foreign.terminate()
            foreign.wait(timeout=3)

    def test_workspace_identity_replacement_is_untouched(self):
        owner = supervisor.ResourceOwner()
        original = owner.directory.with_name(owner.directory.name + '-original')
        owner.directory.rename(original)
        owner.directory.mkdir(mode=0o700)
        marker = owner.directory / 'foreign-marker'
        marker.write_text('not-the-original-directory')
        try:
            with self.assertRaisesRegex(rp.FixtureFailure, 'identity changed'):
                owner.release_directory()
            self.assertTrue(marker.exists())
        finally:
            marker.unlink()
            owner.directory.rmdir()
            original.rename(owner.directory)
            owner.close(time.monotonic() + 3)
        self.assertFalse(owner.directory.exists())

    def test_control_packets_are_bounded_and_eof_is_not_a_result(self):
        first, second = socket.socketpair(socket.AF_UNIX, socket.SOCK_SEQPACKET)
        try:
            supervisor.send_packet(first, {'operation': 'workspace'})
            self.assertEqual(supervisor.receive_packet(second), {'operation': 'workspace'})
            first.send(b'{' + b'x' * supervisor.PACKET_LIMIT)
            with self.assertRaisesRegex(rp.FixtureFailure, 'packet invalid'):
                supervisor.receive_packet(second)
            first.close()
            self.assertIsNone(supervisor.receive_packet(second))
        finally:
            first.close()
            second.close()

    def test_parent_deadline_cleans_real_worker_without_entering_a_browser(self):
        before = set(Path('/tmp').glob('snaplink-browser-sso-*'))
        with self.assertRaisesRegex(rp.FixtureFailure, 'wall-clock budget; supervisor cleanup verified'):
            supervisor.run_owned_case(Path('/missing-source'), Path('/missing-web'),
                                      'python', 'chrome', 'live-replicas', seconds=0)
        self.assertEqual(set(Path('/tmp').glob('snaplink-browser-sso-*')), before)
        self.assertEqual(children_module.child_pids(os.getpid()), [])


class ContainerReconciliationTest(unittest.TestCase):
    def exercise(self, fault):
        owner = supervisor.ResourceOwner()
        image, identity = 'sha256:' + 'a' * 64, 'b' * 64
        label, calls, state = [], [], {'created': False, 'removed': False, 'reads': 0, 'clock': 0}
        name = 'snaplink-app-sso-redis-' + owner.directory.name
        arguments = ['docker', 'run', '-d', '--name', name, '--network', 'none',
                     '--log-driver=none', '--read-only', 'redis:7-alpine']

        def sleep(seconds):
            state['clock'] += seconds

        def inventory(*_, **__):
            if state['created']:
                state['reads'] += 1
                if fault == 'read-failed' and state['reads'] == 1:
                    raise rp.FixtureFailure('Owned container command failed')
                if fault == 'late-create' and state['clock'] < 6:
                    return []
                if fault in ('late-remove', 'late-create-remove') and state.get('removal_requested') and state['clock'] >= 1:
                    state['removed'] = True
            return [identity] if state['created'] and not state['removed'] else []

        def docker(command, **_):
            calls.append(command)
            if command[:2] == ['image', 'inspect']:
                return image
            if command[0] == 'create':
                state['created'] = True
                label.append(command[command.index('--label') + 1].split('=', 1)[1])
                if fault in ('read-failed', 'late-create', 'late-create-remove'):
                    raise rp.FixtureFailure('Owned container command outcome unknown')
                return identity
            if command[:2] == ['container', 'inspect']:
                return json.dumps({'Id': identity, 'Name': '/' + name, 'Image': image,
                                   'Config': {'Labels': {resources.OWNER_LABEL: label[0]}}})
            if command[:2] == ['container', 'rm']:
                state['removal_requested'] = True
                if fault in ('late-remove', 'late-create-remove'):
                    raise rp.FixtureFailure('Owned container command outcome unknown')
                state['removed'] = True
            return ''

        clock = SimpleNamespace(monotonic=lambda: state['clock'], sleep=sleep)
        try:
            with patch.object(resources, 'docker', side_effect=docker), \
                    patch.object(resources, 'container_ids', side_effect=inventory), \
                    patch.object(resources, 'time', clock), patch.object(supervisor, 'time', clock):
                if fault in ('read-failed', 'late-create', 'late-create-remove'):
                    with self.assertRaises(rp.FixtureFailure):
                        owner.dispatch({'operation': 'container', 'arguments': arguments, 'command': []})
                else:
                    self.assertEqual(owner.dispatch({'operation': 'container', 'arguments': arguments,
                                                     'command': []}), identity)
                    # A worker's failed release consumes its ExitStack callback;
                    # the independent parent must retain the obligation anyway.
                    with self.assertRaises(rp.FixtureFailure):
                        owner.dispatch({'operation': 'release-container', 'identity': identity})
                owner.close(20)
                self.assertTrue(state['removed'])
                self.assertFalse(owner.directory.exists())
                self.assertLessEqual(state['clock'], 20)
                self.assertEqual(sum(command[0] == 'create' for command in calls), 1)
                self.assertEqual(sum(command[:2] == ['container', 'rm'] for command in calls), 1)
                self.assertEqual(sum(command[:2] == ['container', 'start'] for command in calls),
                                 int(fault == 'late-remove'))
        finally:
            # No real Docker resource exists in these deterministic doubles.
            owner.stack.pop_all()
            owner.release_directory()

    def test_created_but_not_started_survives_one_census_failure_without_leaking(self):
        self.exercise('read-failed')

    def test_late_ambiguous_creation_is_reconciled_without_replaying_create(self):
        self.exercise('late-create')

    def test_consumed_worker_callback_retains_late_removal_without_replaying_rm(self):
        self.exercise('late-remove')

    def test_ambiguous_create_and_remove_keep_the_same_identity_and_one_rm(self):
        self.exercise('late-create-remove')

    def test_unknown_creation_fails_closed_at_the_unchanged_parent_deadline(self):
        owner = supervisor.ResourceOwner()
        now = [0]
        def sleep(seconds):
            now[0] += seconds
        def docker(command, **_):
            if command[:2] == ['image', 'inspect']:
                return 'sha256:' + 'a' * 64
            if command[0] == 'create':
                raise rp.FixtureFailure('Owned container command outcome unknown')
            self.fail('Unknown creation mutation replayed')
        clock = SimpleNamespace(monotonic=lambda: now[0], sleep=sleep)
        try:
            with patch.object(resources, 'docker', side_effect=docker) as command, \
                    patch.object(resources, 'container_ids', return_value=[]), \
                    patch.object(resources, 'time', clock), patch.object(supervisor, 'time', clock):
                with self.assertRaises(rp.FixtureFailure):
                    owner.dispatch({'operation': 'container', 'arguments': [
                        'docker', 'run', '-d', '--name', 'snaplink-app-sso-redis-' + owner.directory.name,
                        '--network', 'none', '--log-driver=none', 'redis:7-alpine'], 'command': []})
                with self.assertRaisesRegex(rp.FixtureFailure, 'deadline expired; cleanup unconfirmed'):
                    owner.close(0.5)
                self.assertLessEqual(now[0], 0.5)
                self.assertEqual(sum(call.args[0][0] == 'create' for call in command.call_args_list), 1)
        finally:
            owner.stack.pop_all()
            owner.release_directory()

    def test_worker_release_and_parent_fallback_share_one_twenty_second_budget(self):
        from contextlib import ExitStack
        owner = supervisor.ResourceOwner()
        stack, now, seen = ExitStack(), [0], []
        def cleanup():
            seen.append(getattr(stack, 'fixture_deadline', None))
            raise resources.CleanupPending('Controlled pending census')
        def sleep(seconds):
            now[0] += seconds
        clock = SimpleNamespace(monotonic=lambda: now[0], sleep=sleep)
        stack.fixture_container_cleanup = cleanup
        stack.callback(cleanup)
        owner.container_stacks.append(stack)
        owner.containers['owned-id'] = stack
        try:
            with patch.object(supervisor, 'time', clock):
                with self.assertRaises(resources.CleanupPending):
                    owner.dispatch({'operation': 'release-container', 'identity': 'owned-id'})
                self.assertEqual(seen, [20])
                now[0] = 19.9
                with self.assertRaisesRegex(rp.FixtureFailure, 'deadline expired; cleanup unconfirmed'):
                    owner.close(39.9)  # Must not reset the consumed worker callback's budget.
                self.assertLessEqual(now[0], 20)
                self.assertEqual(set(seen), {20})
        finally:
            stack.pop_all()
            owner.stack.pop_all()
            owner.release_directory()

    def test_parent_reconciliation_never_removes_a_replacement_owner(self):
        owner = supervisor.ResourceOwner()
        name = 'snaplink-app-sso-redis-' + owner.directory.name
        image, identity, label = 'sha256:' + 'a' * 64, 'b' * 64, []
        def docker(command, **_):
            if command[:2] == ['image', 'inspect']:
                return image
            if command[0] == 'create':
                label.append(command[command.index('--label') + 1])
                raise rp.FixtureFailure('Owned container command outcome unknown')
            if command[:2] == ['container', 'inspect']:
                return json.dumps({'Id': identity, 'Name': '/' + name, 'Image': image,
                                   'Config': {'Labels': {resources.OWNER_LABEL: 'foreign'}}})
            self.fail('Foreign container mutation attempted')
        try:
            with patch.object(resources, 'docker', side_effect=docker) as command, \
                    patch.object(resources, 'container_ids', side_effect=lambda *_, **__: [identity] if label else []):
                with self.assertRaises(rp.FixtureFailure):
                    owner.dispatch({'operation': 'container', 'arguments': [
                        'docker', 'run', '-d', '--name', name, '--network', 'none',
                        '--log-driver=none', 'redis:7-alpine'], 'command': []})
                with self.assertRaisesRegex(rp.FixtureFailure, 'ownership mismatch'):
                    owner.close(time.monotonic() + 20)
                self.assertFalse(any(call.args[0][:2] == ['container', 'rm'] for call in command.call_args_list))
        finally:
            owner.stack.pop_all()
            owner.release_directory()


if __name__ == '__main__':
    unittest.main()
