"""Admission versus unknown Docker outcomes; no daemon or foreign resources."""

import errno
import json
import subprocess
from types import SimpleNamespace
import unittest
from unittest.mock import patch

from app_sso_fixture_support import modules, resources, rp

supervisor = modules['app_sso_supervisor']


class DockerAdmissionTest(unittest.TestCase):
    def test_exec_failure_is_known_not_started_and_never_exposes_os_details(self):
        with patch.object(resources.subprocess, 'Popen', side_effect=OSError(errno.EAGAIN, 'private details')):
            with self.assertRaisesRegex(resources.DockerNotStarted, '^Owned container command not started$'):
                resources.docker(['container', 'rm', '-f', 'b' * 64])

    def test_communication_failure_is_unknown_not_safe_to_replay(self):
        for error in (OSError('private details'), subprocess.TimeoutExpired('private command', 0.1)):
            with self.subTest(error=type(error).__name__), patch.object(resources.subprocess, 'Popen') as launch:
                launch.return_value.communicate.side_effect = error
                with self.assertRaises(rp.FixtureFailure) as caught:
                    resources.docker(['container', 'rm', '-f', 'b' * 64], timeout=0.1)
                self.assertNotIsInstance(caught.exception, resources.DockerNotStarted)
                self.assertEqual(str(caught.exception), 'Owned container command outcome unknown')
                launch.return_value.kill.assert_called_once_with()
                launch.return_value.wait.assert_called_once_with()
                # A killed CLI's descendants may still hold its pipes: never
                # start an unbounded second communicate after timeout.
                launch.return_value.communicate.assert_called_once_with(timeout=0.1)

    def test_nonzero_exit_is_not_misclassified_as_never_submitted(self):
        with patch.object(resources.subprocess, 'Popen') as launch:
            launch.return_value.returncode = 1
            launch.return_value.communicate.return_value = (b'private output', b'private details')
            with self.assertRaises(rp.FixtureFailure) as caught:
                resources.docker(['container', 'rm', '-f', 'b' * 64])
            self.assertNotIsInstance(caught.exception, resources.DockerNotStarted)
            self.assertEqual(str(caught.exception), 'Owned container command failed')


class AbortRemovalTest(unittest.TestCase):
    def exercise(self, mode):
        owner = supervisor.ResourceOwner()
        name = 'snaplink-app-sso-redis-' + owner.directory.name
        identity, image = 'b' * 64, 'sha256:' + 'a' * 64
        arguments = ['docker', 'run', '-d', '--name', name, '--network', 'none',
                     '--log-driver=none', '--read-only', 'redis:7-alpine']
        state = {'clock': 0, 'created': False, 'removed': False, 'owner': None,
                 'admissions': 0, 'submissions': 0, 'create_calls': 0, 'start_calls': 0}

        def inventory(*_, **__):
            return [identity] if state['created'] and not state['removed'] else []

        def docker(command, **_):
            if command[:2] == ['image', 'inspect']:
                return image
            if command[0] == 'create':
                state['create_calls'] += 1
                if mode == 'create-not-started':
                    raise resources.DockerNotStarted('Controlled exec admission failure')
                state['created'] = True
                state['owner'] = command[command.index('--label') + 1].split('=', 1)[1]
                if mode == 'ambiguous-create':
                    raise rp.FixtureFailure('Controlled unknown create outcome')
                return identity
            if command[:2] == ['container', 'start']:
                state['start_calls'] += 1
                raise rp.FixtureFailure('Controlled start failure')
            if command[:2] == ['container', 'inspect']:
                return json.dumps({'Id': identity, 'Name': '/' + name, 'Image': image,
                                   'Config': {'Labels': {resources.OWNER_LABEL:
                                                        'foreign' if mode == 'foreign' else state['owner']}}})
            if command[:2] == ['container', 'rm']:
                self.assertEqual(command, ['container', 'rm', '-f', identity])
                state['admissions'] += 1
                if mode == 'persistent-not-started' or (mode != 'unknown-remove' and state['admissions'] == 1):
                    raise resources.DockerNotStarted('Controlled exec admission failure')
                state['submissions'] += 1
                if mode == 'unknown-remove':
                    raise rp.FixtureFailure('Controlled unknown removal outcome')
                state['removed'] = True
            return ''

        def sleep(seconds):
            state['clock'] += seconds
        clock = SimpleNamespace(monotonic=lambda: state['clock'], sleep=sleep)
        try:
            with patch.object(resources, 'docker', side_effect=docker), \
                    patch.object(resources, 'container_ids', side_effect=inventory), \
                    patch.object(resources, 'time', clock), patch.object(supervisor, 'time', clock):
                with self.assertRaises(rp.FixtureFailure):
                    owner.dispatch({'operation': 'container', 'arguments': arguments, 'command': []})
                if mode in ('persistent-not-started', 'unknown-remove'):
                    with self.assertRaisesRegex(rp.FixtureFailure, 'deadline expired; cleanup unconfirmed'):
                        owner.close(0.5)
                    self.assertTrue(state['created'] and not state['removed'])
                    self.assertEqual(state['submissions'], int(mode == 'unknown-remove'))
                    self.assertLessEqual(state['clock'], 0.5)
                elif mode == 'foreign':
                    with self.assertRaisesRegex(rp.FixtureFailure, 'ownership mismatch; foreign resource untouched'):
                        owner.close(20)
                    self.assertEqual(state['admissions'], 0)
                else:
                    owner.close(20)
                    self.assertEqual(state['submissions'], int(mode != 'create-not-started'))
                    self.assertEqual(state['admissions'], 0 if mode == 'create-not-started' else 2)
                    self.assertEqual(state['clock'], 0 if mode == 'create-not-started' else 0.1)
                    self.assertFalse(owner.directory.exists())
                self.assertEqual(state['create_calls'], 1)  # Never replay create, even definite admission failure.
                self.assertEqual(state['start_calls'], int(mode not in ('ambiguous-create', 'create-not-started')))
        finally:
            owner.stack.pop_all()  # All Docker resources here are doubles.
            owner.release_directory()

    def test_start_failed_and_one_rm_exec_failure_still_submits_exactly_one_removal(self):
        self.exercise('start-failed')

    def test_ambiguous_creation_keeps_cleanup_obligation_until_one_removal_is_submitted(self):
        self.exercise('ambiguous-create')

    def test_create_not_spawned_needs_no_ambiguous_creation_wait_or_replay(self):
        self.exercise('create-not-started')

    def test_unknown_removal_is_never_replayed_even_if_it_leaves_a_resource(self):
        self.exercise('unknown-remove')

    def test_persistent_admission_failure_still_fails_with_original_bounded_diagnostic(self):
        self.exercise('persistent-not-started')

    def test_reconciliation_does_not_relax_exact_owner_checks(self):
        self.exercise('foreign')


if __name__ == '__main__':
    unittest.main()
