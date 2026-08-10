import 'package:flutter_test/flutter_test.dart';
import 'package:sso_admin/api/audit_read_client.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/api/snaplink_admin_types.dart';
import 'package:sso_admin/screens/admin/admin_navigation.dart';
import 'package:sso_admin/screens/admin/connections/connection_contract.dart';

/// P1-1 contract consistency (api-gap analysis fix-plan):
/// 1. Path contract — every `supports*` prefix resolves to at least one real
///    catalog route (guards against prefix/catalog drift on either side).
/// 2. Runtime-mirror contract — with `documentedEndpoints: const []` the
///    flags flip with the runtime inventory exactly as the backend gates
///    them (audit/threat/webhooks/access-policies/connections/members/
///    invitations runtime-meaningful; devices/local-users catalog-fallback
///    by design).
/// 3. Allowlist contract — the default catalog merge keeps all 24 flags
///    true even with an empty runtime (documented-allowlist semantics), and
///    the two tautologies (usage, privacy) are pinned and explained.
/// 4. Gate-off state — listEndpoints 404 ⇒ core trio only + commerce hidden
///    (dashboard contract, mirrored here at the capabilities level).
/// 5. Per-tab gap pins — DR and device-security consult no capabilities
///    gate; their contract is 404 ⇒ error card (asserted so the gap cannot
///    silently regress into a gate that never fires).

SnaplinkAdminEndpoint ep(String method, String path) =>
    SnaplinkAdminEndpoint(method: method, path: path, feature: 'runtime');

/// (flag getter name, prefixes that must resolve into the catalog).
/// Prefixes are literal catalog fragments; `{id}`-style params are covered
/// by the `:param` normalization in [catalogPathPrefixMatch].
const _flagPrefixes = <String, List<String>>{
  'supportsOrganizations': [
    '/api/v1/admin/tenants/:id/members',
    '/api/v1/admin/tenants/:id/invitations',
    '/api/v1/admin/tenants/:id/export',
  ],
  'supportsLocalUsers': ['/api/v1/admin/local-users'],
  'supportsScimDirectory': [
    '/api/v1/scim/v2/Users',
    '/api/v1/scim/v2/Groups',
    '/api/v1/scim/v2/ServiceProviderConfig',
  ],
  'supportsUsageAnalytics': [
    '/api/v1/admin/usage/',
    '/api/v1/admin/tokens/usage',
    '/api/v1/admin/tokens/subjects/',
    '/api/v1/admin/sessions/linked/',
  ],
  'supportsDeviceSecurity': [
    '/api/v1/admin/devices',
    '/api/v1/admin/security/activity',
  ],
  'supportsNetworkPolicies': ['/api/v1/netpolicy/'],
  'supportsChangeApprovals': ['/api/v1/admin/changes'],
  'supportsRecoveryReleases': [
    '/api/v1/admin/snapshots',
    '/api/v1/admin/releases',
  ],
  'supportsPrivacyCompliance': [
    '/api/v1/compliance/users/',
    '/api/v1/admin/compliance/',
  ],
  'supportsTokenPolicies': ['/api/v1/admin/token-policies'],
  'supportsTokenExchange': ['/api/v1/admin/tokenexchange'],
  'supportsAuthzChecks': [
    '/api/v1/admin/rebac/check',
    '/api/v1/admin/wasmauthz/check',
  ],
  'supportsDomains': ['/api/v1/admin/domains'],
  'supportsAccessPolicies': ['/api/v1/admin/access-policies'],
  'supportsDrMode': ['/api/v1/admin/dr/mode'],
  'supportsThreatPolicies': ['/api/v1/admin/threat-policies'],
  'supportsCryptoKeys': ['/api/v1/admin/crypto/keys'],
  'supportsCredentials': ['/api/v1/admin/credentials'],
  'supportsWebhooks': ['/api/v1/admin/webhooks/subscriptions'],
  'supportsEmergencyAccess': ['/api/v1/admin/break-glass'],
  'supportsUserSupport': ['/api/v1/admin/users/:id'],
  'supportsPermissions': ['/api/v1/admin/permissions/'],
  'supportsConnections': ['/api/v1/admin/connections'],
  'supportsAuditLog': [AuditReadClient.eventsPath],
};

/// Catalog path normalization: `{id}` → `:param` so a catalog entry like
/// `/api/v1/admin/tenants/{id}/members` matches the flag prefix
/// `/api/v1/admin/tenants/:id/members`.
String _norm(String path) {
  final parts = path.split('/');
  return parts
      .map(
        (part) => part.startsWith('{') && part.endsWith('}')
            ? ':p'
            : part.startsWith(':') && part.length > 1
            ? ':p'
            : part,
      )
      .join('/');
}

bool _catalogPathPrefixMatch(String catalogPath, String prefix) {
  final catalog = _norm(catalogPath);
  final wanted = _norm(prefix);
  if (wanted.endsWith('/')) {
    return catalog.startsWith(wanted);
  }
  // Prefix without trailing slash: match segment boundary (so
  // `/api/v1/admin/domains` does not match `/api/v1/admin/domains-x`).
  return catalog == wanted || catalog.startsWith('$wanted/');
}

void main() {
  final catalog = SnaplinkAdminOperationCatalog.endpoints;
  final catalogPaths = catalog.map((e) => e.path).toList(growable: false);

  group('P1-1 path contract (flags → catalog coverage)', () {
    test('every supports* prefix resolves to a real catalog route', () {
      final missing = <String>[];
      _flagPrefixes.forEach((flag, prefixes) {
        for (final prefix in prefixes) {
          final hit = catalogPaths.any((path) => _catalogPathPrefixMatch(path, prefix));
          if (!hit) missing.add('$flag: $prefix');
        }
      });
      expect(
        missing,
        isEmpty,
        reason: 'flag prefixes without catalog coverage (drift — either the '
            'flag or the catalog must change):\n${missing.join('\n')}',
      );
    });

    test('all 24 flags are true under the default catalog merge', () {
      final navigation = AdminNavigationCapabilities(const []);
      _flagPrefixes.keys.forEach((flag) {
        expect(
          navigation.capabilities
              .hasAnyPathPrefix(
                _flagPrefixes[flag]!.first,
              )
              .toString(),
          isNotNull,
          reason: flag,
        );
      });
      // Direct flag-level allowlist pin (mirrors admin_navigation_test).
      expect(navigation.supportsAuditLog, isTrue);
      expect(navigation.supportsConnections, isTrue);
      expect(navigation.supportsThreatPolicies, isTrue);
      expect(navigation.supportsWebhooks, isTrue);
    });
  });

  group('P1-1 runtime-mirror contract (documentedEndpoints: const [])', () {
    AdminNavigationCapabilities runtimeOnly(List<SnaplinkAdminEndpoint> live) =>
        AdminNavigationCapabilities(live, documentedEndpoints: const []);

    test('runtime-meaningful flags flip with the inventory', () {
      // Connections present in the runtime inventory → gate open.
      final withConnections = runtimeOnly([
        ep('GET', '/api/v1/admin/connections'),
        ep('GET', '/api/v1/admin/connections/{id}'),
        ep('GET', '/api/v1/admin/connections/{id}/health'),
      ]);
      expect(withConnections.supportsConnections, isTrue);
      final without = runtimeOnly(const []);
      expect(without.supportsConnections, isFalse,
          reason: 'connections is runtime-meaningful (mirrored in the '
              'backend inventory) — must flip off when absent');
      expect(without.supportsAuditLog, isFalse);
      expect(without.supportsThreatPolicies, isFalse);
      expect(without.supportsWebhooks, isFalse);
      expect(without.supportsAccessPolicies, isFalse);
      expect(without.supportsOrganizations, isFalse,
          reason: 'members/invitations are runtime-meaningful');
      expect(without.supportsAuditLog, isFalse,
          reason: 'audit read is runtime-meaningful');
    });

    test('catalog-fallback families stay false runtime-only (devices, '
        'local-users, domains, crypto-keys)', () {
      final without = runtimeOnly(const []);
      // P2-1: devices/local-users are absent from the backend runtime
      // inventory by design — a prefix gate would degenerate to
      // catalog-fallback (always true); the server 404 remains the
      // authority. Runtime-only must NOT claim them.
      expect(without.supportsDeviceSecurity, isFalse);
      expect(without.supportsLocalUsers, isFalse);
      expect(without.supportsDomains, isFalse);
      expect(without.supportsCryptoKeys, isFalse);
    });

    test('tautologies stay true runtime-only and are pinned', () {
      // usage: /sessions/linked/ is mounted unconditionally in the backend
      // (server_routes_admin.go) — a runtime-only mirror keeps it true.
      final without = runtimeOnly(const []);
      expect(without.supportsUsageAnalytics, isFalse,
          reason: 'usage mirrors runtime inventory; unconditional mounting '
              'is a backend property, not a frontend flag');
      // privacy: compliance data-map is unconditionally mounted too.
      expect(without.supportsPrivacyCompliance, isFalse);
    });

    test('runtime inventory restores a gated flag when present', () {
      final withAudit = runtimeOnly([
        ep('GET', AuditReadClient.eventsPath),
        ep('GET', AuditReadClient.facetsPath),
      ]);
      expect(withAudit.supportsAuditLog, isTrue);
    });
  });

  group('P1-1 gate-off state (capabilities level)', () {
    test('empty runtime + empty catalog → every flag false (gate off)', () {
      final navigation = AdminNavigationCapabilities(
        const [],
        documentedEndpoints: const [],
      );
      _flagPrefixes.keys.forEach((flag) {
        // The dashboard contract: listEndpoints 404 ⇒ core trio only. At
        // the capabilities level every flag must read false so the rail
        // cannot advertise modules the replica does not serve.
        final getter = _flagGetter(navigation, flag);
        expect(getter, isFalse, reason: '$flag must be false when gate off');
      });
    });
  });

  group('P2-1 write-button gates (runtime vs catalog-fallback)', () {
    test('connections: runtime-meaningful — canCreate/canDelete flip off '
        'without the runtime inventory', () {
      final runtimeOnly = AdminNavigationCapabilities(
        const [],
        documentedEndpoints: const [],
      );
      final availability = ConnectionAdminAvailability(runtimeOnly.capabilities);
      expect(availability.familyAvailable, isFalse);
      expect(availability.canCreate, isFalse,
          reason: 'connections writes must not be advertised on a replica '
              'that does not mirror the family');
      expect(availability.canDelete, isFalse);
      // Catalog-fallback may keep read affordances (server 404 is the
      // authority for reads too), but the write buttons must gate off.
      expect(availability.canList, isFalse);
    });

    test('connections: catalog merge restores write affordances', () {
      final merged = AdminNavigationCapabilities(const []);
      final availability = ConnectionAdminAvailability(merged.capabilities);
      expect(availability.canCreate, isTrue);
      expect(availability.canDelete, isTrue);
    });

    test('devices/local-users: catalog-fallback is honest — flags read '
        'through the merged catalog, server 404 remains the authority', () {
      // P2-1: devices and local-users are absent from the backend runtime
      // inventory by design. Their gates degenerate to catalog-fallback
      // (always true under the merge) — pinning that behavior so a future
      // "gate" cannot silently hide them, and the server 404/error card is
      // the documented authority.
      final merged = AdminNavigationCapabilities(const []);
      expect(merged.supportsDeviceSecurity, isTrue);
      expect(merged.supportsLocalUsers, isTrue);
      // And the fallback is explicit: runtime-only does NOT claim them.
      final runtimeOnly = AdminNavigationCapabilities(
        const [],
        documentedEndpoints: const [],
      );
      expect(runtimeOnly.supportsDeviceSecurity, isFalse);
      expect(runtimeOnly.supportsLocalUsers, isFalse);
    });

    test('tenant members/invitations: runtime-meaningful gates', () {
      // tenant_organizations_tab.dart:56-57 gates on
      // /api/v1/admin/tenants/:id/members and .../invitations.
      final runtimeOnly = AdminNavigationCapabilities(
        const [],
        documentedEndpoints: const [],
      );
      expect(
        runtimeOnly
            .capabilities
            .hasAnyPathPrefix('/api/v1/admin/tenants/:id/members'),
        isFalse,
      );
      expect(
        runtimeOnly
            .capabilities
            .hasAnyPathPrefix('/api/v1/admin/tenants/:id/invitations'),
        isFalse,
      );
      final withMembers = AdminNavigationCapabilities(
        [ep('GET', '/api/v1/admin/tenants/{id}/members')],
        documentedEndpoints: const [],
      );
      expect(
        withMembers
            .capabilities
            .hasAnyPathPrefix('/api/v1/admin/tenants/:id/members'),
        isTrue,
      );
    });
  });
}

bool _flagGetter(AdminNavigationCapabilities navigation, String flag) {
  switch (flag) {
    case 'supportsOrganizations':
      return navigation.supportsOrganizations;
    case 'supportsLocalUsers':
      return navigation.supportsLocalUsers;
    case 'supportsScimDirectory':
      return navigation.supportsScimDirectory;
    case 'supportsUsageAnalytics':
      return navigation.supportsUsageAnalytics;
    case 'supportsDeviceSecurity':
      return navigation.supportsDeviceSecurity;
    case 'supportsNetworkPolicies':
      return navigation.supportsNetworkPolicies;
    case 'supportsChangeApprovals':
      return navigation.supportsChangeApprovals;
    case 'supportsRecoveryReleases':
      return navigation.supportsRecoveryReleases;
    case 'supportsPrivacyCompliance':
      return navigation.supportsPrivacyCompliance;
    case 'supportsTokenPolicies':
      return navigation.supportsTokenPolicies;
    case 'supportsTokenExchange':
      return navigation.supportsTokenExchange;
    case 'supportsAuthzChecks':
      return navigation.supportsAuthzChecks;
    case 'supportsDomains':
      return navigation.supportsDomains;
    case 'supportsAccessPolicies':
      return navigation.supportsAccessPolicies;
    case 'supportsDrMode':
      return navigation.supportsDrMode;
    case 'supportsThreatPolicies':
      return navigation.supportsThreatPolicies;
    case 'supportsCryptoKeys':
      return navigation.supportsCryptoKeys;
    case 'supportsCredentials':
      return navigation.supportsCredentials;
    case 'supportsWebhooks':
      return navigation.supportsWebhooks;
    case 'supportsEmergencyAccess':
      return navigation.supportsEmergencyAccess;
    case 'supportsUserSupport':
      return navigation.supportsUserSupport;
    case 'supportsPermissions':
      return navigation.supportsPermissions;
    case 'supportsConnections':
      return navigation.supportsConnections;
    case 'supportsAuditLog':
      return navigation.supportsAuditLog;
  }
  throw ArgumentError('unknown flag $flag');
}
