"""Owned canonical-edge fixtures for entry and live replicas, not product routing."""

import socket
import subprocess
import time
import urllib.parse
import urllib.request

import yaml

from app_sso_entry_transport import IdentityIngress, get_json
from app_sso_resources import OwnedGatewayServer, OwnedHTTPServer, owned_container, owned_directory, owned_redis
from browser_sso_fixture import BrowserFixture, IndependentAPI, free_port, nginx_gateway, python_gateway
from browser_sso_rp import NoRedirect, RelyingParty, require


def authorization_endpoint(metadata, issuer):
    # Exact returned value only: no origin repair, redirects, credentials,
    # pre-populated authorization query, or alternative hosted-entry fallback.
    require(isinstance(metadata, dict) and metadata.get('issuer') == issuer and
            metadata.get('authorization_endpoint') == issuer + '/auth/login',
            'Discovery authorization endpoint is not the exact owned HTTPS identity entry')
    return metadata['authorization_endpoint']


def raw_entry_observation(metadata, issuer):
    target = urllib.parse.urlsplit(metadata.get('authorization_endpoint', ''))
    expected = urllib.parse.urlsplit(issuer)
    return {'issuer_matches': metadata.get('issuer') == issuer,
            'scheme_matches': target.scheme == expected.scheme,
            'authority_matches': target.netloc == expected.netloc,
            'path_matches': target.path == '/auth/login', 'endpoint_followed': False}


class EntryRP(RelyingParty):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, server_type=OwnedHTTPServer, **kwargs)

    def close(self):
        self.server.shutdown()
        try:
            self.server.close_workers()
        finally:
            self.server.server_close()
            self.thread.join(timeout=3)
        require(not self.thread.is_alive(), 'Owned RP thread cleanup not verified')

    def discovered_authorization_url(self, query):
        require(not query, 'Discovery entry case accepts no authorization overrides')
        _, metadata = get_json(self.issuer + '/.well-known/openid-configuration', self.tls_context)
        endpoint = authorization_endpoint(metadata, self.issuer)
        hosted = urllib.parse.urlsplit(super().authorization_url(''))
        return endpoint + '?' + hosted.query

    def handle(self, handler):
        target = urllib.parse.urlsplit(handler.path)
        if target.path != '/start-discovery':
            return super().handle(handler)
        location = self.discovered_authorization_url(target.query)
        handler.send_response(302)
        handler.send_header('Location', location)
        handler.send_header('Cache-Control', 'no-store')
        handler.end_headers()

    def discard(self, url):
        target = urllib.parse.urlsplit(url)
        require(target.scheme + '://' + target.netloc == self.issuer and target.path == '/auth/login',
                'Cannot discard an unrelated fixture request')
        states = urllib.parse.parse_qs(target.query).get('state', [])
        require(len(states) == 1, 'Abandoned RP state is missing or ambiguous')
        with self.lock:
            require(self.pending.pop(states[0], None) is not None, 'Abandoned RP state was already consumed')


class EntryFixture(BrowserFixture):
    """Raw gateway first; then explicit fixture-only canonical identity ingress."""

    def create_directory(self):
        return owned_directory(self.stack) or super().create_directory()

    def create_rps(self):
        for client, name, host in (('browser-rp-a', 'Browser App A', '127.0.0.2'),
                                   ('browser-rp-b', 'Browser App B', '127.0.0.3')):
            yield EntryRP(client, name, False, host=host)

    def create_sink(self):
        return IndependentAPI(self.stack, server_type=OwnedHTTPServer)

    def create_ingress(self):
        return IdentityIngress(self.stack, self.backend)

    def create_gateway(self, directory):
        self.ingress = self.create_ingress()
        if self.gateway == 'python':
            return python_gateway(self.stack, directory, self.web, self.ingress.origin, self.sink.origin,
                                  server_base=OwnedGatewayServer,
                                  opener=urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect()))
        return nginx_gateway(self.stack, directory, self.web, self.ingress.origin, self.sink.origin,
                             launch=lambda args: owned_container(self.stack, args))

    def stop_backend(self, process):
        def remaining(cap):
            return max(0, min(cap, self.stack.fixture_deadline - time.monotonic()))
        if process.poll() is None:
            process.terminate()
            try:
                process.wait(timeout=remaining(3))
            except subprocess.TimeoutExpired:
                process.kill()
                process.wait(timeout=remaining(2))
        require(process.poll() is not None, 'Owned OP cleanup not verified')

    def __enter__(self):
        try:
            self.start()
            return self
        except BaseException:
            self.close()
            raise

    def __exit__(self, *_):
        self.close()

    def close(self):
        # Cooperative normal/error teardown. SIGTERM/deadline cleanup is owned
        # independently by app_sso_supervisor, never a Playwright signal unwind.
        self.stack.fixture_deadline = time.monotonic() + 20
        for party in getattr(self, 'rps', []):
            party.server.fixture_deadline = self.stack.fixture_deadline
        self.stack.close()
        self.verify_closed()

    def verify_closed(self):
        require(self.process is None or self.process.poll() is not None, 'Owned OP cleanup not verified')
        for party in getattr(self, 'rps', []):
            require(not party.thread.is_alive() and party.server.socket.fileno() == -1,
                    'Owned RP cleanup not verified')
        sink = getattr(self, 'sink', None)
        if sink is not None:
            server = sink.server
            require(not server.fixture_thread.is_alive() and server.socket.fileno() == -1 and
                    not any(worker.is_alive() for worker in server.workers) and not server.connections,
                    'Owned service sink cleanup not verified')
        origins = [getattr(self, name, '') for name in ('issuer', 'backend')]
        if sink is not None:
            origins.append(sink.origin)
        if hasattr(self, 'ingress'):
            origins.append(self.ingress.origin)
        for origin in filter(None, origins):
            target = urllib.parse.urlsplit(origin)
            with socket.socket() as probe:
                probe.settimeout(0.2)
                require(probe.connect_ex((target.hostname, target.port)) != 0,
                        'Owned fixture listener cleanup not verified; port owner untouched')
        require(not hasattr(self, 'directory') or not self.directory.exists(),
                'Owned fixture temporary store cleanup not verified')


class LiveReplicaFixture(EntryFixture):
    """Two concurrent stock processes, Redis sessions, one fixed shared key; not HA.

    Frozen stock contracts: serverbuildstore.BuildSessionManager/BuildAuthCodeStore,
    sqlite.ConsentStore, serverbuildsign.BuildSigningIssuer/WithEd25519KeyFile.
    Complete transactions are pinned; only canonical resolution and verification
    cross processes. SharedStoreFixture's stop/start behavior remains separate.
    """

    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self.processes, self.redis_port = [], None

    def create_ingress(self):
        self.second_backend = f'http://127.0.0.1:{free_port()}'
        return IdentityIngress(self.stack, self.backend, secondary=self.second_backend)

    def configuration(self, backend_port):
        if self.redis_port is None:
            self.redis_port = owned_redis(self.stack, self.directory)
        require(self.redis_port not in {backend_port, urllib.parse.urlsplit(self.second_backend).port},
                'Allocated Redis and stock listener ports collided; owners untouched')
        config = super().configuration(backend_port)
        config['identity'].update(session_backend='redis', sqlite={
            'dsn': f'file:{self.directory}/identity.db?_journal=WAL&_pragma=busy_timeout(5000)'})
        config['redis'] = {'mode': 'single', 'addrs': [f'127.0.0.1:{self.redis_port}'], 'db': 0}
        config['oauth']['backend'] = 'redis'
        config['self_service']['consent'] = {'backend': 'sqlite', 'sqlite': {
            'dsn': f'file:{self.directory}/consent.db?_journal=WAL&_pragma=busy_timeout(5000)'}}
        config['keys'].update(signing={'alg': 'eddsa', 'key_file': str(self.directory / 'op-signing.pem')},
                              rotation={'enabled': False}, signing_key_registry={'backend': ''})
        return config

    def start_backend(self):
        require(not self.processes, 'Live fixture cannot restart or replace a stock process')
        self.process = self.launch_backend(self.backend, self.config_path)
        self.processes.append(self.process)
        require((self.directory / 'op-signing.pem').is_file(), 'First stock OP did not persist its fixture key')
        require(self.process.poll() is None, 'First stock OP stopped before second startup')
        second_config = self.directory / 'replica-2.yaml'
        second_config.write_text(yaml.safe_dump(self.configuration(urllib.parse.urlsplit(self.second_backend).port)))
        second_config.chmod(0o600)
        self.processes.append(self.launch_backend(self.second_backend, second_config))
        self.original_pids = tuple(process.pid for process in self.processes)
        self.assert_live()
        self.ingress.canonicalize(self.issuer)
        print('Phase: two distinct stock processes concurrently ready; no stop/restart (not session proof)', flush=True)

    def assert_live(self):
        require(len(self.processes) == 2 and self.process is self.processes[0] and
                len(set(self.original_pids)) == 2 and
                tuple(process.pid for process in self.processes) == self.original_pids and
                all(process.poll() is None for process in self.processes),
                'Both original stock processes must remain concurrently live')

    def select_replica(self, replica):
        self.assert_live()
        require(all(not party.pending for party in self.rps), 'Replica selection requires completed RP transactions')
        self.ingress.wait_idle()  # Client EOF can precede the handler's final unwind.
        self.ingress.select(replica)

    def after_primary(self):
        require(len(self.rps[0].grants) == 1 and not self.rps[1].grants and
                self.ingress.replica_counts.get((1, 'POST', '/auth/login')) == 3 and
                self.ingress.replica_counts.get((1, 'POST', '/token')) == 1 and
                not any(key[0] == 2 for key in self.ingress.replica_counts),
                'Primary password/consent/code transaction was not exclusively on replica 1')
        self.select_replica(2)

    def assert_routing(self):
        self.assert_live()
        posts = {key: value for key, value in self.ingress.replica_counts.items() if key[1] == 'POST'}
        # probeProviders is also a POST: A has discovery/password/consent; B
        # has discovery/resume/consent, and repeats each have discovery/resume.
        require(not self.ingress.failed and posts == {
            (1, 'POST', '/auth/login'): 3, (1, 'POST', '/token'): 1,
            (2, 'POST', '/auth/login'): 7, (2, 'POST', '/token'): 3,
        }, 'Live canonical resume and independent grants lack distinct replica routing evidence')
        require(self.ingress.cookie_responses == {1: 1}, 'Resumed identity cookie was reissued or primary issuance missing')

    def stop_backend(self, process):
        # Also includes a newly spawned R2 that failed readiness before append.
        processes = [process, *(party for party in self.processes if party is not process)]
        for party in processes:
            if party.poll() is None:
                party.terminate()
        for party in processes:
            remaining = lambda cap: max(0, min(cap, self.stack.fixture_deadline - time.monotonic()))
            if party.poll() is None:
                try:
                    party.wait(timeout=remaining(3))
                except subprocess.TimeoutExpired:
                    party.kill()
                    party.wait(timeout=remaining(2))
            require(party.poll() is not None, 'Owned replica cleanup not verified')

    def verify_closed(self):
        require(all(process.poll() is not None for process in self.processes), 'Owned replica cleanup not verified')
        super().verify_closed()
        origins = [getattr(self, 'second_backend', '')]
        if self.redis_port is not None:
            origins.append(f'http://127.0.0.1:{self.redis_port}')
        for origin in filter(None, origins):
            target = urllib.parse.urlsplit(origin)
            with socket.socket() as probe:
                probe.settimeout(0.2)
                require(probe.connect_ex((target.hostname, target.port)) != 0,
                        'Owned replica or Redis listener cleanup not verified; port owner untouched')
