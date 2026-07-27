import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

void main() {
  final documented = SnaplinkAdminOperationCatalog.endpoints;
  final supplemental = SnaplinkAdminSupplementalCatalog.endpoints;

  bool has(
    Iterable<SnaplinkAdminEndpoint> endpoints,
    String method,
    String path,
  ) => endpoints.any(
    (endpoint) => endpoint.method == method && endpoint.path == path,
  );

  group('generated OpenAPI route catalog', () {
    test('contains the complete unique operation inventory', () {
      expect(documented, hasLength(178));
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

  group('source-only compatibility manifest', () {
    test('tracks exactly the 17 mounted but unpublished operations', () {
      expect(supplemental, hasLength(17));
      expect(
        supplemental
            .map((endpoint) => '${endpoint.method} ${endpoint.path}')
            .toSet(),
        hasLength(17),
      );
    });

    test('keeps unpublished routes out of the OpenAPI catalog', () {
      for (final endpoint in supplemental) {
        expect(
          has(documented, endpoint.method, endpoint.path),
          isFalse,
          reason: '${endpoint.method} ${endpoint.path}',
        );
      }
    });

    test('covers branding, providers, devices, and security activity', () {
      expect(has(supplemental, 'GET', '/api/v1/admin/branding'), isTrue);
      expect(has(supplemental, 'POST', '/api/v1/admin/providers'), isTrue);
      expect(has(supplemental, 'GET', '/api/v1/admin/devices/stats'), isTrue);
      expect(
        has(supplemental, 'POST', '/api/v1/admin/devices/bulk-revoke'),
        isTrue,
      );
      expect(
        has(supplemental, 'GET', '/api/v1/admin/users/{id}/login-history'),
        isTrue,
      );
      expect(
        has(supplemental, 'GET', '/api/v1/admin/security/activity'),
        isTrue,
      );
    });
  });
}
