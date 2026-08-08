import 'package:sso_admin/api/audit_read_client.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';

/// Stable route identifiers for the admin navigation.
///
/// Navigation order and availability are represented by the actual
/// [AdminNavigationEntry] instances. These constants only prevent route
/// strings from being repeated throughout the dashboard.
abstract final class AdminModuleId {
  static const overview = '';
  static const clients = 'clients';
  static const users = 'users';
  static const localUsers = 'local-users';
  static const scimDirectory = 'scim-directory';
  static const permissions = 'permissions';
  static const connections = 'connections';
  static const userSupport = 'user-support';
  static const deviceSecurity = 'device-security';
  static const liveActivity = 'live-activity';
  static const tokenSecurity = 'token-security';
  static const usageAnalytics = 'usage-analytics';
  static const tenants = 'tenants';
  static const commerce = 'commerce';
  static const organizations = 'organizations';
  static const operations = 'operations';
  static const cryptoKeys = 'crypto-keys';
  static const credentials = 'credentials';
  static const tokenPolicies = 'token-policies';
  static const tokenExchange = 'token-exchange';
  static const authzChecks = 'authz-checks';
  static const domains = 'domains';
  static const networkPolicies = 'network-policies';
  static const accessPolicies = 'access-policies';
  static const drMode = 'dr-mode';
  static const threatPolicies = 'threat-policies';
  static const webhooks = 'webhooks';
  static const emergencyAccess = 'emergency-access';
  static const changeApprovals = 'change-approvals';
  static const recoveryReleases = 'recovery-releases';
  static const privacyCompliance = 'privacy-compliance';
  static const governance = 'governance';
  static const auditLog = 'audit-log';
  static const health = 'health';
}

/// Capability decisions used to include optional admin navigation entries.
///
/// Keeping these decisions together makes the endpoint contract independently
/// testable and avoids rebuilding [SnaplinkAdminCapabilities] for every item.
class AdminNavigationCapabilities {
  /// Effective console contract: published routes and runtime entries, with
  /// runtime feature metadata taking precedence.
  ///
  /// Snaplink's runtime inventory currently omits some mounted gateway
  /// routes. Passing only that inventory to domain screens made the
  /// navigation advertise a documented module while the page disabled every
  /// action. Screens receive this merged view and still rely on the server's
  /// 404/501, authorization, tenant, and feature-gate response as the final
  /// authority.
  final SnaplinkAdminCapabilities capabilities;

  AdminNavigationCapabilities(
    List<SnaplinkAdminEndpoint> endpoints, {
    List<SnaplinkAdminEndpoint>? documentedEndpoints,
  }) : capabilities = SnaplinkAdminCapabilities(
         _mergeEndpoints(
           endpoints,
           documentedEndpoints ?? SnaplinkAdminOperationCatalog.endpoints,
         ),
       );

  bool get supportsOrganizations =>
      _hasAnyPathPrefix('/api/v1/admin/tenants/:id/members') ||
      _hasAnyPathPrefix('/api/v1/admin/tenants/:id/invitations') ||
      _hasAnyPathPrefix('/api/v1/admin/tenants/:id/export');

  bool get supportsLocalUsers => _hasAnyPathPrefix('/api/v1/admin/local-users');

  bool get supportsScimDirectory =>
      _hasAnyPathPrefix('/api/v1/scim/v2/Users') ||
      _hasAnyPathPrefix('/api/v1/scim/v2/Groups') ||
      _hasAnyPathPrefix('/api/v1/scim/v2/ServiceProviderConfig');

  bool get supportsUsageAnalytics =>
      _hasAnyPathPrefix('/api/v1/admin/usage/') ||
      _hasAnyPathPrefix('/api/v1/admin/tokens/usage') ||
      _hasAnyPathPrefix('/api/v1/admin/tokens/subjects/') ||
      _hasAnyPathPrefix('/api/v1/admin/sessions/linked/');

  bool get supportsDeviceSecurity =>
      _hasAnyPathPrefix('/api/v1/admin/devices') ||
      _hasAnyPathPrefix('/api/v1/admin/security/activity');

  bool get supportsNetworkPolicies => _hasAnyPathPrefix('/api/v1/netpolicy/');

  bool get supportsChangeApprovals =>
      _hasAnyPathPrefix('/api/v1/admin/changes');

  bool get supportsRecoveryReleases =>
      _hasAnyPathPrefix('/api/v1/admin/snapshots') ||
      _hasAnyPathPrefix('/api/v1/admin/releases') ||
      _has('POST', '/api/v1/admin/backup');

  bool get supportsPrivacyCompliance =>
      _hasAnyPathPrefix('/api/v1/compliance/users/') ||
      _hasAnyPathPrefix('/api/v1/admin/compliance/');

  bool get supportsTokenPolicies =>
      _hasAnyPathPrefix('/api/v1/admin/token-policies');

  bool get supportsTokenExchange =>
      _hasAnyPathPrefix('/api/v1/admin/tokenexchange');

  bool get supportsAuthzChecks =>
      _has('GET', '/api/v1/admin/rebac/check') ||
      _has('POST', '/api/v1/admin/wasmauthz/check');

  bool get supportsDomains => _hasAnyPathPrefix('/api/v1/admin/domains');

  bool get supportsAccessPolicies =>
      _hasAnyPathPrefix('/api/v1/admin/access-policies');

  bool get supportsDrMode => _hasAnyPathPrefix('/api/v1/admin/dr/mode');

  bool get supportsThreatPolicies =>
      _hasAnyPathPrefix('/api/v1/admin/threat-policies');

  bool get supportsCryptoKeys => _hasAnyPathPrefix('/api/v1/admin/crypto/keys');

  bool get supportsCredentials =>
      _hasAnyPathPrefix('/api/v1/admin/credentials');

  bool get supportsWebhooks =>
      _hasAnyPathPrefix('/api/v1/admin/webhooks/subscriptions');

  bool get supportsEmergencyAccess =>
      _hasAnyPathPrefix('/api/v1/admin/break-glass');

  bool get supportsUserSupport => _hasAnyPathPrefix('/api/v1/admin/users/:id');

  bool get supportsPermissions =>
      _has('GET', '/api/v1/admin/authz/policy-bundle') ||
      _hasAnyPathPrefix('/api/v1/admin/permissions/');

  bool get supportsConnections =>
      _hasAnyPathPrefix('/api/v1/admin/connections');

  bool get supportsAuditLog => _has('GET', AuditReadClient.eventsPath);

  bool _has(String method, String path) => capabilities.has(method, path);

  bool _hasAnyPathPrefix(String prefix) => capabilities.endpoints.any(
    (endpoint) => _normalizedPath(endpoint.path).startsWith(prefix),
  );

  static String _normalizedPath(String path) => path.replaceAllMapped(
    RegExp(r'\{([A-Za-z_][A-Za-z0-9_]*)\}'),
    (match) => ':${match.group(1)}',
  );

  static List<SnaplinkAdminEndpoint> _mergeEndpoints(
    List<SnaplinkAdminEndpoint> runtime,
    List<SnaplinkAdminEndpoint> documented,
  ) {
    final merged = <String, SnaplinkAdminEndpoint>{};
    for (final endpoint in [...documented, ...runtime]) {
      merged['${endpoint.method} ${_normalizedPath(endpoint.path)}'] = endpoint;
    }
    return merged.values.toList(growable: false);
  }
}

/// A visible navigation destination and its corresponding page and route.
///
/// The module travels with the destination, so removing capability-gated
/// entries cannot shift route mappings onto another page.
class AdminNavigationEntry<Destination, Page> {
  final String module;
  final Destination destination;
  final Page page;

  const AdminNavigationEntry({
    required this.module,
    required this.destination,
    required this.page,
  });
}

int adminNavigationIndexForModule<Destination, Page>(
  List<AdminNavigationEntry<Destination, Page>> entries,
  String module,
) {
  assert(
    entries.isNotEmpty,
    'Admin navigation must contain an overview entry.',
  );
  final index = entries.indexWhere((entry) => entry.module == module);
  return index < 0 ? 0 : index;
}

String? adminNavigationModuleAt<Destination, Page>(
  List<AdminNavigationEntry<Destination, Page>> entries,
  int index,
) {
  if (index < 0 || index >= entries.length) return null;
  return entries[index].module;
}

List<String> adminNavigationModules<Destination, Page>(
  List<AdminNavigationEntry<Destination, Page>> entries,
) => entries.map((entry) => entry.module).toList(growable: false);
