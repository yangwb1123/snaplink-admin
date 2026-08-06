import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  final documented = SnaplinkAdminOperationCatalog.endpoints;

  bool has(
    Iterable<SnaplinkAdminEndpoint> endpoints,
    String method,
    String path,
  ) => endpoints.any(
    (endpoint) => endpoint.method == method && endpoint.path == path,
  );

  group('generated OpenAPI route catalog', () {
    test('contains the complete unique operation inventory', () {
      expect(documented, hasLength(215));
      expect(
        documented
            .map((endpoint) => '${endpoint.method} ${endpoint.path}')
            .toSet(),
        hasLength(documented.length),
      );
    });

    test('contains only well-formed API paths and HTTP methods', () {
      const methods = {'GET', 'POST', 'PUT', 'PATCH', 'DELETE'};
      for (final endpoint in documented) {
        expect(methods, contains(endpoint.method), reason: endpoint.path);
        expect(endpoint.path, startsWith('/api/v1/'), reason: endpoint.path);
        expect(endpoint.path, isNot(contains(' ')), reason: endpoint.path);
      }
    });

    test('uses the current health, ReBAC, and DR contracts', () {
      expect(has(documented, 'GET', '/api/v1/admin/storage-health'), isTrue);
      expect(has(documented, 'GET', '/api/v1/admin/federation/health'), isTrue);
      expect(has(documented, 'GET', '/api/v1/admin/rebac/check'), isTrue);
      expect(has(documented, 'GET', '/api/v1/admin/dr/mode'), isTrue);
      expect(has(documented, 'POST', '/api/v1/admin/dr/mode'), isTrue);
      expect(has(documented, 'GET', '/api/v1/admin/operations'), isTrue);
      expect(has(documented, 'GET', '/api/v1/admin/operations/{id}'), isTrue);
      expect(
        has(documented, 'POST', '/api/v1/admin/access-policies/converge'),
        isTrue,
      );

      expect(has(documented, 'GET', '/api/v1/admin/health/storage'), isFalse);
      expect(
        has(documented, 'GET', '/api/v1/admin/health/federation'),
        isFalse,
      );
      expect(has(documented, 'GET', '/api/v1/admin/dr-mode'), isFalse);
      expect(has(documented, 'PUT', '/api/v1/admin/dr/mode'), isFalse);
      expect(has(documented, 'POST', '/api/v1/admin/rebac/check'), isFalse);
    });

    test('does not reintroduce known facade-only routes', () {
      const invalid = <(String, String)>[
        ('GET', '/api/v1/admin/break-glass/{id}'),
        ('POST', '/api/v1/admin/break-glass/{id}/reject'),
        ('GET', '/api/v1/admin/webhooks/subscriptions/{id}'),
        ('PUT', '/api/v1/admin/webhooks/subscriptions/{id}'),
        ('GET', '/api/v1/admin/webhooks/subscriptions/{id}/deadletters'),
        ('GET', '/api/v1/admin/credentials/{type}'),
        ('GET', '/api/v1/admin/crypto/keys/{id}'),
        ('GET', '/api/v1/admin/access-policies/{id}'),
        ('PUT', '/api/v1/admin/connections/{id}'),
      ];
      for (final route in invalid) {
        expect(
          has(documented, route.$1, route.$2),
          isFalse,
          reason: '${route.$1} ${route.$2}',
        );
      }
    });
  });

  group('published management route coverage', () {
    test('covers branding, providers, devices, and security activity', () {
      expect(has(documented, 'GET', '/api/v1/admin/branding'), isTrue);
      expect(has(documented, 'POST', '/api/v1/admin/providers'), isTrue);
      expect(has(documented, 'GET', '/api/v1/admin/devices/stats'), isTrue);
      expect(
        has(documented, 'POST', '/api/v1/admin/devices/bulk-revoke'),
        isTrue,
      );
      expect(
        has(documented, 'GET', '/api/v1/admin/users/{id}/login-history'),
        isTrue,
      );
      expect(has(documented, 'GET', '/api/v1/admin/security/activity'), isTrue);
      expect(
        has(
          documented,
          'DELETE',
          '/api/v1/admin/users/{id}/devices/{deviceId}',
        ),
        isTrue,
      );
    });
  });
}
