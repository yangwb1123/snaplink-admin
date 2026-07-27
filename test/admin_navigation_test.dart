import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/admin_navigation.dart';

AdminNavigationEntry<String, String> _entry(String module) =>
    AdminNavigationEntry(
      module: module,
      destination: 'destination:$module',
      page: 'page:$module',
    );

List<AdminNavigationEntry<String, String>> _entriesFor({
  required bool permissions,
  required bool connections,
  required bool userSupport,
  required bool domains,
}) => [
  _entry(AdminModuleId.overview),
  _entry(AdminModuleId.clients),
  _entry(AdminModuleId.users),
  if (permissions) _entry(AdminModuleId.permissions),
  if (connections) _entry(AdminModuleId.connections),
  if (userSupport) _entry(AdminModuleId.userSupport),
  _entry(AdminModuleId.liveActivity),
  if (domains) _entry(AdminModuleId.domains),
  _entry(AdminModuleId.health),
];

void main() {
  group('Admin navigation route mapping', () {
    test('maps routes against the capability-filtered entries', () {
      final entries = _entriesFor(
        permissions: false,
        connections: true,
        userSupport: false,
        domains: true,
      );

      final connectionIndex = adminNavigationIndexForModule(
        entries,
        AdminModuleId.connections,
      );
      final domainIndex = adminNavigationIndexForModule(
        entries,
        AdminModuleId.domains,
      );

      expect(connectionIndex, 3);
      expect(
        adminNavigationModuleAt(entries, connectionIndex),
        AdminModuleId.connections,
      );
      expect(domainIndex, 5);
      expect(
        adminNavigationModuleAt(entries, domainIndex),
        AdminModuleId.domains,
      );
    });

    test('remains correct for a different capability combination', () {
      final entries = _entriesFor(
        permissions: true,
        connections: false,
        userSupport: true,
        domains: false,
      );

      expect(adminNavigationModules(entries), [
        AdminModuleId.overview,
        AdminModuleId.clients,
        AdminModuleId.users,
        AdminModuleId.permissions,
        AdminModuleId.userSupport,
        AdminModuleId.liveActivity,
        AdminModuleId.health,
      ]);
      expect(
        adminNavigationModuleAt(
          entries,
          adminNavigationIndexForModule(entries, AdminModuleId.userSupport),
        ),
        AdminModuleId.userSupport,
      );
    });

    test('falls back to overview for an unavailable route', () {
      final entries = _entriesFor(
        permissions: false,
        connections: false,
        userSupport: false,
        domains: false,
      );

      expect(
        adminNavigationIndexForModule(entries, AdminModuleId.connections),
        0,
      );
      expect(adminNavigationModuleAt(entries, -1), isNull);
      expect(adminNavigationModuleAt(entries, entries.length), isNull);
    });
  });

  group('Admin navigation capabilities', () {
    test('uses documented routes when the live inventory is empty', () {
      final navigation = AdminNavigationCapabilities(const []);

      expect(navigation.supportsOrganizations, isTrue);
      expect(navigation.supportsScimDirectory, isTrue);
      expect(navigation.supportsTokenPolicies, isTrue);
      expect(navigation.supportsTokenExchange, isTrue);
      expect(navigation.supportsAuthzChecks, isTrue);
      expect(navigation.supportsDomains, isTrue);
      expect(navigation.supportsAccessPolicies, isTrue);
      expect(navigation.supportsDrMode, isTrue);
      expect(navigation.supportsThreatPolicies, isTrue);
      expect(navigation.supportsCryptoKeys, isTrue);
      expect(navigation.supportsCredentials, isTrue);
      expect(navigation.supportsWebhooks, isTrue);
      expect(navigation.supportsEmergencyAccess, isTrue);
      expect(navigation.supportsUserSupport, isTrue);
      expect(navigation.supportsDeviceSecurity, isTrue);
      expect(navigation.supportsPermissions, isTrue);
      expect(navigation.supportsConnections, isTrue);
      expect(
        navigation.capabilities.has(
          'GET',
          '/api/v1/admin/webhooks/subscriptions',
        ),
        isTrue,
        reason:
            'the same effective contract used by navigation must reach pages',
      );
    });

    test('runtime metadata wins when an effective route is merged', () {
      final navigation = AdminNavigationCapabilities(const [
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/webhooks/subscriptions',
          feature: 'runtime-webhooks',
        ),
      ]);

      final endpoint = navigation.capabilities.endpoints.singleWhere(
        (value) =>
            value.method == 'GET' &&
            value.path == '/api/v1/admin/webhooks/subscriptions',
      );
      expect(endpoint.feature, 'runtime-webhooks');
    });

    test('matches the documented ReBAC and DR endpoint contracts', () {
      final documented = SnaplinkAdminOperationCatalog.endpoints;
      final postOnlyRebac = AdminNavigationCapabilities(const [
        SnaplinkAdminEndpoint(
          method: 'POST',
          path: '/api/v1/admin/rebac/check',
          feature: 'custom',
        ),
      ], documentedEndpoints: const []);
      final documentedMethods = AdminNavigationCapabilities(const [
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/rebac/check',
          feature: 'custom',
        ),
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/dr/mode',
          feature: 'custom',
        ),
      ], documentedEndpoints: const []);

      expect(postOnlyRebac.supportsAuthzChecks, isFalse);
      expect(documentedMethods.supportsAuthzChecks, isTrue);
      expect(documentedMethods.supportsDrMode, isTrue);
      expect(
        documented.any(
          (endpoint) =>
              endpoint.method == 'GET' &&
              endpoint.path == '/api/v1/admin/rebac/check',
        ),
        isTrue,
      );
      expect(
        documented.any(
          (endpoint) =>
              endpoint.method == 'POST' &&
              endpoint.path == '/api/v1/admin/rebac/check',
        ),
        isFalse,
      );
      expect(
        documented.any((endpoint) => endpoint.path == '/api/v1/admin/dr/mode'),
        isTrue,
      );
    });

    test('also accepts live endpoint path parameters', () {
      final navigation = AdminNavigationCapabilities(const [
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/users/{id}/custom-support-action',
          feature: 'custom',
        ),
      ], documentedEndpoints: const []);

      expect(navigation.supportsUserSupport, isTrue);
    });

    test('recognizes a partial runtime SCIM deployment', () {
      final navigation = AdminNavigationCapabilities(
        const [
          SnaplinkAdminEndpoint(
            method: 'GET',
            path: '/api/v1/scim/v2/Users',
            feature: 'scim',
          ),
        ],
        documentedEndpoints: const [],
        supplementalEndpoints: const [],
      );

      expect(navigation.supportsScimDirectory, isTrue);
    });

    test('keeps source-only routes distinct from documented routes', () {
      final navigation = AdminNavigationCapabilities(
        const [],
        documentedEndpoints: const [],
      );

      expect(navigation.supportsDeviceSecurity, isTrue);
      expect(
        SnaplinkAdminOperationCatalog.endpoints.any(
          (endpoint) => endpoint.path == '/api/v1/admin/devices',
        ),
        isFalse,
      );
      expect(
        SnaplinkAdminSupplementalCatalog.endpoints.any(
          (endpoint) => endpoint.path == '/api/v1/admin/devices',
        ),
        isTrue,
      );
    });
  });
}
