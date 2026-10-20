"""Linux child ownership for the loopback supervisor, independent of Playwright."""

from contextlib import contextmanager
import ctypes
import os
from pathlib import Path
import select
import signal
import time

from browser_sso_rp import require


def process_identity(pid):
    try:
        fields = Path(f'/proc/{pid}/stat').read_text().rsplit(')', 1)[1].split()
        return int(fields[1]), int(fields[19])  # parent PID, immutable start ticks
    except (FileNotFoundError, ProcessLookupError):
        return None


def child_pids(pid):
    try:
        return [int(value) for value in Path(f'/proc/{pid}/task/{pid}/children').read_text().split()]
    except (FileNotFoundError, ProcessLookupError):
        return []


class OwnedChildren:
    """Subreap detached Chrome children; signal pinned pidfds, never port owners.

    The supervisor starts with NO children. All subsequent children are its
    worker/descendants or its own synchronous Docker commands. A process can
    change session/group without escaping this ancestry boundary.
    """
    def __enter__(self):
        require(not child_pids(os.getpid()), 'Supervisor has pre-existing children; untouched')
        require(hasattr(os, 'pidfd_open') and hasattr(signal, 'pidfd_send_signal'),
                'Owned process cleanup requires Linux pidfds')
        self.libc = ctypes.CDLL(None, use_errno=True)
        previous = ctypes.c_int()
        require(self.libc.prctl(37, ctypes.byref(previous), 0, 0, 0) == 0,
                'Owned child subreaper state unavailable')
        self.previous = previous.value
        require(self.libc.prctl(36, 1, 0, 0, 0) == 0, 'Owned child subreaper unavailable')
        self.identities = {}
        return self

    def sample(self):
        pending = [os.getpid()]
        while pending:
            parent = pending.pop()
            for pid in child_pids(parent):
                identity = process_identity(pid)
                if identity is None or identity[0] != parent:
                    continue  # Exit/reparent race: the next census reconciles it.
                pending.append(pid)
                key = (pid, identity[1])
                if key in self.identities:
                    continue
                try:
                    descriptor = os.pidfd_open(pid)
                except ProcessLookupError:
                    continue
                if process_identity(pid) != identity:
                    os.close(descriptor)
                    continue
                self.identities[key] = descriptor

    def reap(self, worker):
        worker.poll()  # Let Popen retain the direct child's real exit status.
        for pid, _ in self.identities:
            if pid == worker.pid:
                continue
            try:
                os.waitpid(pid, os.WNOHANG)
            except ChildProcessError:
                pass  # Still the worker's child, or already reaped by its owner.

    def living(self):
        self.sample()
        return [descriptor for descriptor in self.identities.values()
                if not select.select([descriptor], [], [], 0)[0]]

    def stop(self, worker, deadline):
        # No Python exception is injected into a sync-Playwright fiber. Even a
        # SIGSTOPped/spinning worker cannot prevent this independent cleanup.
        for sig, grace in ((signal.SIGTERM, 0.3), (signal.SIGKILL, 2)):
            until = min(deadline, time.monotonic() + grace)
            while True:
                for descriptor in self.living():
                    try:
                        signal.pidfd_send_signal(descriptor, sig)
                    except ProcessLookupError:
                        pass
                self.reap(worker)
                if not self.living() or time.monotonic() >= until:
                    break
                time.sleep(0.02)
        self.reap(worker)
        require(not self.living() and not child_pids(os.getpid()), 'Owned descendant cleanup not verified')

    def __exit__(self, *_):
        for descriptor in self.identities.values():
            os.close(descriptor)
        require(self.libc.prctl(36, self.previous, 0, 0, 0) == 0,
                'Owned child subreaper restoration failed')


@contextmanager
def termination_flag():
    """Only set state in signal handlers; never raise into library/greenlet code."""
    state = {'signal': None}
    previous = {sig: signal.getsignal(sig) for sig in (signal.SIGTERM, signal.SIGINT)}

    def interrupted(sig, _):
        state['signal'] = sig

    try:
        for sig in previous:
            signal.signal(sig, interrupted)
        yield state
    finally:
        for sig, handler in previous.items():
            signal.signal(sig, handler)
