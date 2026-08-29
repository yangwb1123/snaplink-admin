import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/screens/admin/admin_module_groups.dart';
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

    test('module groups partition every route exactly once', () {
      final grouped = [for (final group in adminModuleGroups) ...group.modules];
      final expected = {
        AdminModuleId.overview,
        AdminModuleId.clients,
        AdminModuleId.users,
        AdminModuleId.localUsers,
        AdminModuleId.scimDirectory,
        AdminModuleId.permissions,
        AdminModuleId.connections,
        AdminModuleId.userSupport,
        AdminModuleId.deviceSecurity,
        AdminModuleId.liveActivity,
        AdminModuleId.tokenSecurity,
        AdminModuleId.usageAnalytics,
        AdminModuleId.tenants,
        AdminModuleId.commerce,
        AdminModuleId.organizations,
        AdminModuleId.operations,
        AdminModuleId.cryptoKeys,
        AdminModuleId.credentials,
        AdminModuleId.tokenPolicies,
        AdminModuleId.tokenExchange,
        AdminModuleId.authzChecks,
        AdminModuleId.domains,
        AdminModuleId.networkPolicies,
        AdminModuleId.accessPolicies,
        AdminModuleId.drMode,
        AdminModuleId.threatPolicies,
        AdminModuleId.webhooks,
        AdminModuleId.emergencyAccess,
        AdminModuleId.changeApprovals,
        AdminModuleId.recoveryReleases,
        AdminModuleId.privacyCompliance,
        AdminModuleId.governance,
        AdminModuleId.auditLog,
        AdminModuleId.health,
      };

      expect(adminModuleGroups, hasLength(6));
      expect(grouped, hasLength(expected.length));
      expect(grouped.toSet(), hasLength(grouped.length));
      expect(grouped.toSet(), expected);
      expect(adminGroupForModule('future-module'), 'overview');
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

    test(
      'snapshot separates runtime availability from documented fallback',
      () {
        final live = AdminNavigationCapabilities(const [
          SnaplinkAdminEndpoint(
            method: 'GET',
            path: '/api/v1/admin/devices/stats',
            feature: 'runtime-devices',
          ),
        ], documentedEndpoints: const []);
        expect(
          live.snapshot.stateForAnyPathPrefix('/api/v1/admin/devices'),
          SnaplinkAdminCapabilityState.available,
        );

        final absent = AdminNavigationCapabilities(
          const [],
          documentedEndpoints: const [],
        );
        expect(
          absent.snapshot.stateForAnyPathPrefix('/api/v1/admin/devices'),
          SnaplinkAdminCapabilityState.unavailable,
        );
        expect(
          absent.snapshot.effective.has('GET', '/api/v1/admin/devices/stats'),
          isFalse,
        );

        final loading = AdminNavigationCapabilities(
          const [],
          documentedEndpoints: const [],
          runtimeInventoryLoading: true,
          runtimeInventoryAvailable: false,
        );
        expect(
          loading.snapshot.stateForAnyPathPrefix('/api/v1/admin/devices'),
          SnaplinkAdminCapabilityState.unknown,
        );
        expect(loading.snapshot.runtimeInventoryLoading, isTrue);
      },
    );

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

    test('uses segment-aware capability prefix matching', () {
      final lookalikes = AdminNavigationCapabilities(const [
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/domains-x',
          feature: 'custom',
        ),
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/admin/devices-evil',
          feature: 'custom',
        ),
      ], documentedEndpoints: const []);
      expect(lookalikes.supportsDomains, isFalse);
      expect(lookalikes.supportsDeviceSecurity, isFalse);

      final customVerb = AdminNavigationCapabilities(const [
        SnaplinkAdminEndpoint(
          method: 'POST',
          path: '/api/v1/admin/users/{user_id}:suspend',
          feature: 'custom',
        ),
      ], documentedEndpoints: const []);
      expect(customVerb.supportsUserSupport, isTrue);
    });

    test('keeps descendants, custom verbs, and slash subtrees bounded', () {
      expect(
        SnaplinkAdminCapabilities.matchesPathPrefix(
          '/api/v1/admin/snapshots/{id}:restore',
          '/api/v1/admin/snapshots',
        ),
        isTrue,
      );
      expect(
        SnaplinkAdminCapabilities.matchesPathPrefix(
          '/api/v1/admin/releases/{id}:pin',
          '/api/v1/admin/releases',
        ),
        isTrue,
      );
      expect(
        SnaplinkAdminCapabilities.matchesPathPrefix(
          '/api/v1/audit/events',
          '/api/v1/audit',
        ),
        isTrue,
      );
      expect(
        SnaplinkAdminCapabilities.matchesPathPrefix(
          '/api/v1/auditx/events',
          '/api/v1/audit',
        ),
        isFalse,
      );
      expect(
        SnaplinkAdminCapabilities.matchesPathPrefix(
          '/api/v1/scim/v2/Users/42',
          '/api/v1/scim/',
        ),
        isTrue,
      );
    });

    test('recognizes a partial runtime SCIM deployment', () {
      final navigation = AdminNavigationCapabilities(const [
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/scim/v2/Users',
          feature: 'scim',
        ),
      ], documentedEndpoints: const []);

      expect(navigation.supportsScimDirectory, isTrue);
    });

    test('uses published device routes when runtime inventory is empty', () {
      final navigation = AdminNavigationCapabilities(const []);

      expect(navigation.supportsDeviceSecurity, isTrue);
      expect(
        SnaplinkAdminOperationCatalog.endpoints.any(
          (endpoint) => endpoint.path == '/api/v1/admin/devices',
        ),
        isTrue,
      );
    });

    test('AC-4.3: supportsAuditLog follows the merged audit-trio contract', () {
      // (i) default documented-catalog merge → true.
      final navigation = AdminNavigationCapabilities(const []);
      expect(navigation.supportsAuditLog, isTrue);
      expect(
        navigation.supportsAuditLog,
        navigation.capabilities.has('GET', '/api/v1/audit/events'),
      );

      // (ii) documentedEndpoints: const [] without the trio → false — an
      // inventory without the audit trio hides the tab.
      final culled = AdminNavigationCapabilities(
        const [],
        documentedEndpoints: const [],
      );
      expect(culled.supportsAuditLog, isFalse);
      expect(
        culled.supportsAuditLog,
        culled.capabilities.has('GET', '/api/v1/audit/events'),
      );

      // (iii) runtime set explicitly containing the trio → true.
      final runtime = AdminNavigationCapabilities(const [
        SnaplinkAdminEndpoint(
          method: 'GET',
          path: '/api/v1/audit/events',
          feature: 'runtime-audit',
        ),
      ], documentedEndpoints: const []);
      expect(runtime.supportsAuditLog, isTrue);
      expect(
        runtime.supportsAuditLog,
        runtime.capabilities.has('GET', '/api/v1/audit/events'),
      );

      // Module-list culling: the auditLog module is offered iff the entry
      // exists, and the getter is the predicate the dashboard cull uses.
      final withAudit = [
        _entry(AdminModuleId.overview),
        _entry(AdminModuleId.auditLog),
        _entry(AdminModuleId.health),
      ];
      expect(
        adminNavigationModules(withAudit),
        contains(AdminModuleId.auditLog),
      );
      expect(
        adminNavigationModules([
          _entry(AdminModuleId.overview),
          _entry(AdminModuleId.health),
        ]),
        isNot(contains(AdminModuleId.auditLog)),
      );
    });
  });
}
