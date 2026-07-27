import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  final catalog = SnaplinkAdminOperationCatalog.endpoints;

  bool has(String method, String path) => catalog.any(
    (endpoint) => endpoint.method == method && endpoint.path == path,
  );

  group('high-value Snaplink administration contracts', () {
    test('supports local and federated user operations', () {
      expect(has('GET', '/api/v1/admin/users'), isTrue);
      expect(has('POST', '/api/v1/admin/users/{id}/password'), isTrue);
      expect(has('POST', '/api/v1/admin/account-lockout/clear'), isTrue);
      expect(has('GET', '/api/v1/admin/local-users'), isTrue);
      expect(has('PUT', '/api/v1/admin/local-users/{id}'), isTrue);
    });

    test('uses user-scoped permission assignments', () {
      expect(
        has(
          'POST',
          '/api/v1/admin/permissions/{client_id}/assignments/{user_id}',
        ),
        isTrue,
      );
      expect(
        has('POST', '/api/v1/admin/permissions/{client_id}/assignments'),
        isFalse,
      );
    });

    test('supports token, session, and usage investigations', () {
      const expected = <(String, String)>[
        ('GET', '/api/v1/admin/tokens/portfolio'),
        ('GET', '/api/v1/admin/tokens/usage'),
        ('GET', '/api/v1/admin/tokens/subjects/{subject}'),
        ('GET', '/api/v1/admin/sessions/linked/{subject}'),
        ('GET', '/api/v1/admin/tokens/suspicious'),
        ('POST', '/api/v1/admin/tokens/bulk-revoke'),
        ('POST', '/api/v1/admin/tokens/revoke'),
        ('POST', '/api/v1/admin/tokens/temp'),
      ];
      for (final route in expected) {
        expect(has(route.$1, route.$2), isTrue, reason: route.$2);
      }
    });

    test('supports two-person changes and recovery lifecycle', () {
      const expected = <(String, String)>[
        ('GET', '/api/v1/admin/changes'),
        ('POST', '/api/v1/admin/changes'),
        ('POST', '/api/v1/admin/changes/{id}/approve'),
        ('POST', '/api/v1/admin/changes/{id}/reject'),
        ('POST', '/api/v1/admin/backup'),
        ('GET', '/api/v1/admin/snapshots'),
        ('POST', '/api/v1/admin/snapshots/{id}:restore'),
        ('GET', '/api/v1/admin/releases:current'),
        ('POST', '/api/v1/admin/releases/{id}:pin'),
        ('POST', '/api/v1/admin/releases/{id}:rollback'),
      ];
      for (final route in expected) {
        expect(has(route.$1, route.$2), isTrue, reason: route.$2);
      }
    });

    test('uses global webhook dead letters and revoke semantics', () {
      expect(has('GET', '/api/v1/admin/webhooks/deadletters'), isTrue);
      expect(
        has('POST', '/api/v1/admin/webhooks/deadletters/{id}/replay'),
        isTrue,
      );
      expect(has('DELETE', '/api/v1/admin/break-glass/{id}'), isTrue);
      expect(has('POST', '/api/v1/admin/break-glass/{id}/approve'), isTrue);
    });

    test('supports network policy diagnostics', () {
      expect(has('GET', '/api/v1/netpolicy/policies'), isTrue);
      expect(has('POST', '/api/v1/netpolicy/policies'), isTrue);
      expect(has('DELETE', '/api/v1/netpolicy/policies/{name}'), isTrue);
      expect(has('GET', '/api/v1/netpolicy/classify'), isTrue);
      expect(has('GET', '/api/v1/netpolicy/resolve-me'), isTrue);
    });

    test('supports privacy export, erasure, and retention workflows', () {
      expect(has('GET', '/api/v1/compliance/users/{id}/export'), isTrue);
      expect(has('POST', '/api/v1/compliance/users/{id}/erase'), isTrue);
      expect(has('POST', '/api/v1/admin/compliance/retention-sweep'), isTrue);
    });
  });

  group('capability path normalization', () {
    test('matches brace and colon path parameter styles', () {
      const capabilities = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/users/{id}/sessions',
          feature: 'users',
        ),
      ]);
      expect(
        capabilities.has('GET', '/api/v1/admin/users/:user_id/sessions'),
        isTrue,
      );
    });

    test('does not confuse custom verbs with path parameters', () {
      const capabilities = SnaplinkAdminCapabilities([
        SnaplinkAdminEndpoint(
          method: 'POST',
          path: '/api/v1/admin/snapshots/{id}:restore',
          feature: 'recovery',
        ),
      ]);
      expect(
        capabilities.has(
          'POST',
          '/api/v1/admin/snapshots/:snapshot_id:restore',
        ),
        isTrue,
      );
      expect(
        capabilities.has('POST', '/api/v1/admin/snapshots/:snapshot_id'),
        isFalse,
      );
    });
  });
}
