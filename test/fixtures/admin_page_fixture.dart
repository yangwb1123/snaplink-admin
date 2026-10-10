import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/sso_client.dart';

import 'admin_proto_fixture.dart';
export 'admin_proto_fixture.dart';

/// Contract-shaped test data, not a deployment capability or identity source.
class AdminPageFixture {
  final requests = <http.Request>[];
  final unhandled = <String>[];
  late final transport = MockClient((request) async {
    requests.add(request);
    if (request.method != 'GET') {
      unhandled.add('${request.method} ${request.url}');
      throw StateError(
        'Page loading must not mutate: ${request.method} ${request.url.path}',
      );
    }
    if (request.url.path == '/api/v1/admin/events/stream') {
      return http.Response(
        'id: 1\nevent: login\ndata: {"id":"1","actor":"fixture-user"}\n\n',
        200,
        headers: {'content-type': 'text/event-stream'},
      );
    }
    if (request.url.path == '/api/v1/checkout/sessions') {
      return http.Response('', 405); // Published read-only enabled probe.
    }
    final value = responses[request.url.path];
    if (value == null) {
      unhandled.add(request.url.toString());
      throw StateError('Missing page fixture: ${request.url}');
    }
    return http.Response(
      jsonEncode(value),
      200,
      headers: {'content-type': 'application/json'},
    );
  });
  late final api = SnaplinkAdminApi(
    baseUrl: 'https://sso.example.test',
    accessToken: 'fixture',
    httpClient: transport,
  )..maxRetries = 0;
  late final client = SSOAdminClient(
    'https://sso.example.test',
    httpClient: transport,
  );
  List<String> get paths => requests.map((r) => r.url.path).toList();
}

const fixtureSubscription = {
  'id': 'webhook-1',
  'url': 'https://receiver.example.test/hook',
  'disabled': false,
  'has_secret': false,
  'event_types': ['login'],
  'created_at': '2026-01-01T00:00:00Z',
};
const fixtureConnection = {
  'id': 'connection-1',
  'tenant_id': 'tenant-1',
  'display_name': 'Contract connection',
  'type': 'oidc',
  'enabled': true,
  'domains': ['example.test'],
  'config': {},
};
const fixtureDeadLetter = {
  'id': 'dead-1',
  'subscription_id': 'webhook-1',
  'url': 'https://receiver.example.test/hook',
  'event': {'type': 'login'},
  'attempts': 3,
  'last_error': 'fixture delivery failure',
  'last_failed_at': '2026-01-01T00:00:00Z',
};

final responses = <String, Object>{
  ...protoResponses,
  '/health': {'status': 'ok', 'issuer': 'https://sso.example.test'},
  '/readyz': {
    'status': 'ok',
    'checks': {'storage': 'ok'},
  },
  '/api/v1/status': {
    'status': 'ok',
    'modules': {'identity': 'ok'},
  },
  '/.well-known/jwks.json': {
    'keys': [
      {'kid': 'key-1', 'kty': 'RSA'},
    ],
  },
  '/api/v1/admin/endpoints': {
    'endpoints': [
      for (final e in SnaplinkAdminOperationCatalog.endpoints)
        {'method': e.method, 'path': e.path, 'feature': 'fixture'},
    ],
  },
  '/api/v1/admin/local-users': {
    'users': [
      {
        'id': 'local-1',
        'username': 'contract-local',
        'email': 'local@example.test',
      },
    ],
    'total': 1,
  },
  '/api/v1/admin/tenants/tenant-1/members': {
    'members': [
      {'user_id': 'user-1', 'role': 'member'},
    ],
  },
  '/api/v1/admin/tenants/tenant-1/invitations': {
    'invitations': [
      {'email': 'invite@example.test', 'role': 'member'},
    ],
  },
  '/api/v1/admin/tenants/tenant-1/usage': {'period': 'day', 'active_users': 1},
  '/api/v1/admin/branding': {
    'tenant_id': 'tenant-1',
    'branding': {'brand_name': 'Contract brand'},
    'revision': 'revision-1',
  },
  '/api/v1/admin/crypto/keys': {
    'keys': [
      {
        'key_id': 'key-1',
        'status': 'active',
        'algorithm': 'RS256',
        'purpose': 'jwt_signing',
      },
    ],
  },
  '/api/v1/admin/credentials': {
    'credentials': [
      {'type': 'password', 'status': 'active', 'version': 1},
    ],
  },
  '/api/v1/admin/authz/policy-bundle': {
    'client_id': 'client-1',
    'roles': [],
    'assignments': [],
  },
  '/api/v1/admin/rebac/check': {
    'allowed': true,
    'object': 'document:1',
    'relation': 'viewer',
    'subject': 'user:1',
  },
  '/api/v1/admin/connections': {
    'connections': [fixtureConnection],
  },
  '/api/v1/admin/connections/connection-1': fixtureConnection,
  '/api/v1/admin/connections/connection-1/health': {
    'healthy': true,
    'status': 'ok',
  },
  '/api/v1/admin/connections/connection-1/domains': {
    'domains': ['example.test'],
  },
  '/api/v1/admin/devices': {
    'devices': [
      {
        'id': 'device-1',
        'user_id': 'user-1',
        'client_id': 'client-1',
        'device_name': 'Contract device',
        'trusted': true,
      },
    ],
  },
  '/api/v1/admin/devices/stats': {'total': 1, 'trusted': 1},
  '/api/v1/admin/security/activity': {'events': []},
  '/api/v1/admin/users/user-1/devices': {'devices': []},
  '/api/v1/admin/users/user-1/login-history': {'events': []},
  '/api/v1/admin/users/user-1/consents': {'consents': []},
  '/api/v1/admin/users/user-1/mfa': {'factors': []},
  '/api/v1/admin/users/user-1/lifecycle': {
    'user_id': 'user-1',
    'state': 'active',
    'allowed_transitions': [],
  },
  '/api/v1/admin/users/user-1/password-reset-tokens': {
    'count': 0,
    'tokens': [],
  },
  '/api/v1/admin/users/user-1/email-change-tokens': {'count': 0, 'tokens': []},
  '/api/v1/admin/sessions': {'status': 'ok', 'sessions': [], 'total': 0},
  '/api/v1/admin/tokens': {'status': 'ok', 'tokens': []},
  '/api/v1/admin/tokens/portfolio': {
    'status': 'ok',
    'portfolio': {
      'total_events': 0,
      'issued_total': 0,
      'by_client': [],
      'by_kind': {},
      'trend': [],
    },
  },
  '/api/v1/admin/tokens/expiring': {'status': 'ok', 'tokens': [], 'count': 0},
  '/api/v1/admin/tokens/suspicious': {
    'status': 'ok',
    'findings': [],
    'total': 0,
  },
  '/api/v1/admin/tokens/usage': {'status': 'ok', 'buckets': [], 'total': 0},
  '/api/v1/admin/tokens/subjects/user-1': {
    'status': 'ok',
    'subject': 'user-1',
    'counted': [],
    'active_refresh_tokens': [],
  },
  '/api/v1/admin/sessions/linked/user-1': {
    'status': 'ok',
    'subject': 'user-1',
    'linked_sessions': [],
    'total': 0,
  },
  '/api/v1/admin/usage/top-tenants': {
    'status': 'ok',
    'tenants': [],
    'total': 0,
  },
  '/api/v1/admin/token-policies': {'status': 'ok', 'policies': [], 'total': 0},
  '/api/v1/admin/tokenexchange/chains/token-1': {
    'status': 'ok',
    'jti': 'token-1',
    'chain': [],
  },
  '/api/v1/netpolicy/policies': {'policies': []},
  '/api/v1/netpolicy/classify': {'class': 'default'},
  '/api/v1/admin/access-policies': {'policies': []},
  '/api/v1/admin/threat-policies': {'status': 'ok', 'policies': [], 'total': 0},
  '/api/v1/admin/dr/mode': {'mode': 'normal', 'reason': ''},
  '/api/v1/admin/dr/status': {'ready': true},
  '/api/v1/admin/break-glass': {
    'sessions': [
      {'id': 'break-1', 'subject': 'user-1', 'status': 'active'},
    ],
    'total': 1,
  },
  '/api/v1/admin/changes': {'changes': [], 'total': 0},
  '/api/v1/admin/storage-health': {'status': 'ok', 'stores': []},
  '/api/v1/admin/federation/health': {'status': 'ok', 'entities': []},
  '/api/v1/admin/compliance/data-map': {
    'generated_at': '2026-01-01T00:00:00Z',
    'categories': [],
  },
  '/api/v1/admin/compliance/soc2-evidence': {
    'generated_at': '2026-01-01T00:00:00Z',
    'errors': [],
  },
  '/api/v1/admin/compliance/consents': {
    'generated_at': '2026-01-01T00:00:00Z',
    'total': 0,
    'consents': [],
  },
  '/api/v1/admin/config/running': {
    'snapshot': {'version': 1, 'resources': {}},
  },
  '/api/v1/admin/config/applied': {
    'snapshot': {'version': 1, 'resources': {}},
  },
  '/api/v1/admin/config/diff': {'changes': []},
  '/api/v1/admin/config/history': {'entries': []},
  '/api/v1/admin/webhooks/subscriptions': {
    'subscriptions': [fixtureSubscription],
  },
  '/api/v1/admin/webhooks/deadletters': {
    'dead_letters': [fixtureDeadLetter],
  },
  '/api/v1/audit/events': {
    'events': [
      {
        'id': 'audit-1',
        'type': 'login',
        'timestamp': '2026-01-01T00:00:00Z',
        'actor_id': 'fixture-user',
      },
    ],
  },
  '/api/v1/audit/facets': {
    'facets': {
      'total': 1,
      'types': {'login': 1},
      'outcomes': {},
      'clients': {},
      'providers': {},
    },
  },
  '/api/v1/admin/commerce/plans': {
    'plans': [
      {
        'id': 'plan-1',
        'version': 1,
        'name': 'Contract plan',
        'status': 'active',
        'billing_interval': 'month',
        'price': {'currency': 'USD', 'minor_units': 100},
      },
    ],
    'total': 1,
  },
  '/api/v1/scim/v2/ServiceProviderConfig': {
    'schemas': ['urn:ietf:params:scim:schemas:core:2.0:ServiceProviderConfig'],
    'patch': {'supported': true},
    'bulk': {
      'supported': true,
      'maxOperations': 1000,
      'maxPayloadSize': 1048576,
    },
    'filter': {'supported': true, 'maxResults': 100},
    'sort': {'supported': true},
    'etag': {'supported': true},
  },
  '/api/v1/scim/v2/Schemas': {
    'schemas': ['urn:ietf:params:scim:api:messages:2.0:ListResponse'],
    'Resources': [],
    'totalResults': 0,
  },
  '/api/v1/scim/v2/Users': {
    'schemas': ['urn:ietf:params:scim:api:messages:2.0:ListResponse'],
    'Resources': [],
    'totalResults': 0,
    'startIndex': 1,
    'itemsPerPage': 0,
  },
  '/api/v1/scim/v2/Groups': {
    'schemas': ['urn:ietf:params:scim:api:messages:2.0:ListResponse'],
    'Resources': [],
    'totalResults': 0,
    'startIndex': 1,
    'itemsPerPage': 0,
  },
};
