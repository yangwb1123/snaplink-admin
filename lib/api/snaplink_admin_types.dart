import 'dart:typed_data';

/// One route in Snaplink's runtime inventory (`GET /api/v1/admin/endpoints`).
///
/// Unlike a build-time list, this is the source of truth for the replica the
/// operator is connected to: routes behind a disabled feature gate or an
/// unwired optional store are absent.
class SnaplinkAdminEndpoint {
  final String method;
  final String path;
  final String feature;

  const SnaplinkAdminEndpoint({
    required this.method,
    required this.path,
    required this.feature,
  });

  factory SnaplinkAdminEndpoint.fromJson(Map<String, dynamic> json) =>
      SnaplinkAdminEndpoint(
        method: json['method']?.toString().toUpperCase() ?? '',
        path: json['path']?.toString() ?? '',
        feature: json['feature']?.toString() ?? 'core',
      );

  List<String> get pathParameters {
    final names = <String>{
      ...RegExp(
        r'\{([A-Za-z_][A-Za-z0-9_]*)\}',
      ).allMatches(path).map((match) => match.group(1)!),
      ...path
          .split('/')
          .where((segment) => segment.startsWith(':'))
          .map((segment) => segment.substring(1).split(':').first),
    };
    return names.toList(growable: false);
  }

  String resolvePath(Map<String, String> values) {
    var resolved = path;
    for (final parameter in pathParameters) {
      final value = values[parameter]?.trim() ?? '';
      if (value.isEmpty) {
        throw ArgumentError.value(
          parameter,
          'values',
          'A path value is required',
        );
      }
      final encoded = Uri.encodeComponent(value);
      if (resolved.contains('{$parameter}')) {
        resolved = resolved.replaceFirst('{$parameter}', encoded);
      } else {
        resolved = resolved.replaceFirst('/:$parameter', '/$encoded');
      }
    }
    return resolved;
  }
}

/// A redacted notification from Snaplink's admin Server-Sent Events feed.
class SnaplinkAdminEvent {
  final String? id;
  final String type;
  final Map<String, dynamic> data;

  const SnaplinkAdminEvent({
    required this.id,
    required this.type,
    required this.data,
  });
}

/// A server-produced export that must be handled as an attachment, not shown
/// in the console or copied to an operator's clipboard.
class SnaplinkAdminDownload {
  final Uint8List bytes;
  final String contentType;
  final String? filename;

  const SnaplinkAdminDownload({
    required this.bytes,
    required this.contentType,
    required this.filename,
  });
}

/// Small query helper shared by capability-aware admin screens.
class SnaplinkAdminCapabilities {
  final List<SnaplinkAdminEndpoint> endpoints;

  const SnaplinkAdminCapabilities(this.endpoints);

  bool has(String method, String path) {
    final expected = _normalizePath(path);
    return endpoints.any(
      (endpoint) =>
          endpoint.method == method.toUpperCase() &&
          _normalizePath(endpoint.path) == expected,
    );
  }

  bool hasAnyPathPrefix(String prefix) {
    final expected = _normalizePath(prefix);
    return endpoints.any(
      (endpoint) => _normalizePath(endpoint.path).startsWith(expected),
    );
  }

  Map<String, int> get featureCounts {
    final counts = <String, int>{};
    for (final endpoint in endpoints) {
      counts.update(endpoint.feature, (count) => count + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  static String _normalizePath(String path) => path.replaceAllMapped(
    RegExp(r'(?:\{[A-Za-z_][A-Za-z0-9_]*\}|/:[A-Za-z_][A-Za-z0-9_]*)'),
    (match) => match.group(0)!.startsWith('/') ? '/:param' : ':param',
  );
}

/// The result of deciding whether an optional admin capability can be used on
/// the connected replica.
///
/// The published OpenAPI catalog describes what this console knows how to
/// use, while the runtime inventory describes what the current replica has
/// actually mounted. Keeping those facts separate prevents a documented-only
/// route from being mistaken for a live feature.
enum SnaplinkAdminCapabilityState { available, unavailable, unknown }

/// Runtime capability view shared by navigation and domain screens.
///
/// [runtimeInventoryAvailable] is false when the inventory request failed.
/// In that case the UI must not turn an empty list into "disabled": the
/// server state is unknown and the operator should be offered a retry.
class SnaplinkAdminCapabilitySnapshot {
  final SnaplinkAdminCapabilities effective;
  final SnaplinkAdminCapabilities runtime;
  final bool runtimeInventoryLoading;
  final bool runtimeInventoryAvailable;

  const SnaplinkAdminCapabilitySnapshot({
    required this.effective,
    required this.runtime,
    this.runtimeInventoryLoading = false,
    required this.runtimeInventoryAvailable,
  });

  SnaplinkAdminCapabilityState stateFor(String method, String path) {
    if (runtimeInventoryLoading || !runtimeInventoryAvailable) {
      return SnaplinkAdminCapabilityState.unknown;
    }
    return runtime.has(method, path)
        ? SnaplinkAdminCapabilityState.available
        : SnaplinkAdminCapabilityState.unavailable;
  }

  SnaplinkAdminCapabilityState stateForAnyPathPrefix(String prefix) {
    if (runtimeInventoryLoading || !runtimeInventoryAvailable) {
      return SnaplinkAdminCapabilityState.unknown;
    }
    return runtime.hasAnyPathPrefix(prefix)
        ? SnaplinkAdminCapabilityState.available
        : SnaplinkAdminCapabilityState.unavailable;
  }

  bool canUse(String method, String path) =>
      stateFor(method, path) == SnaplinkAdminCapabilityState.available;

  bool canUseAnyPathPrefix(String prefix) =>
      stateForAnyPathPrefix(prefix) == SnaplinkAdminCapabilityState.available;
}

const routes = '''
GET /api/v1/admin/events/stream
GET /api/v1/admin/authz/policy-bundle
GET /api/v1/admin/storage-health
GET /api/v1/admin/federation/health
POST /api/v1/admin/credentials/{type}/compromise
GET /api/v1/admin/compliance/soc2-evidence
GET /api/v1/admin/compliance/data-map
GET /api/v1/admin/compliance/consents
POST /api/v1/admin/compliance/retention-sweep
GET /api/v1/admin/endpoints
GET /api/v1/admin/docs
GET /api/v1/admin/docs/openapi.json
GET /api/v1/admin/config/running
GET /api/v1/admin/credentials
GET /api/v1/admin/crypto/keys
POST /api/v1/admin/crypto/keys/{id}/compromise
GET /api/v1/admin/config/applied
GET /api/v1/admin/config/diff
POST /api/v1/admin/config/cluster-diff
GET /api/v1/admin/config/history
POST /api/v1/admin/backup
GET /api/v1/admin/dr/status
GET /api/v1/admin/access-policies
POST /api/v1/admin/access-policies/converge
GET /api/v1/admin/webhooks/subscriptions
POST /api/v1/admin/webhooks/subscriptions
DELETE /api/v1/admin/webhooks/subscriptions/{id}
GET /api/v1/admin/webhooks/deadletters
POST /api/v1/admin/webhooks/deadletters/{id}/replay
GET /api/v1/admin/rebac/check
POST /api/v1/admin/wasmauthz/check
GET /api/v1/admin/dr/mode
POST /api/v1/admin/dr/mode
POST /api/v1/admin/snapshots
GET /api/v1/admin/snapshots
GET /api/v1/admin/snapshots/{id}
DELETE /api/v1/admin/snapshots/{id}
POST /api/v1/admin/snapshots/{id}:restore
POST /api/v1/admin/releases
GET /api/v1/admin/releases
GET /api/v1/admin/releases:current
GET /api/v1/admin/releases/{id}
DELETE /api/v1/admin/releases/{id}
POST /api/v1/admin/releases/{id}:pin
POST /api/v1/admin/releases/{id}:rollback
GET /api/v1/admin/operations
GET /api/v1/admin/operations/{id}
GET /api/v1/admin/tenants
POST /api/v1/admin/tenants
GET /api/v1/admin/tenants/{id}
PUT /api/v1/admin/tenants/{id}
DELETE /api/v1/admin/tenants/{id}
GET /api/v1/admin/tenants/{id}/usage
GET /api/v1/admin/commerce/plans
POST /api/v1/admin/commerce/plans
GET /api/v1/admin/commerce/tenants/{tenant_id}/subscriptions
POST /api/v1/admin/commerce/tenants/{tenant_id}/subscriptions
PATCH /api/v1/admin/commerce/subscriptions/{id}/status
PATCH /api/v1/admin/commerce/subscriptions/{id}/plan
POST /api/v1/admin/commerce/subscriptions/{id}/renew
GET /api/v1/admin/commerce/tenants/{tenant_id}/entitlement
GET /api/v1/admin/commerce/tenants/{tenant_id}/wallet
GET /api/v1/admin/commerce/tenants/{tenant_id}/wallet/entries
POST /api/v1/admin/commerce/tenants/{tenant_id}/wallet/adjustments
GET /api/v1/admin/commerce/tenants/{tenant_id}/payments/orders
POST /api/v1/admin/commerce/tenants/{tenant_id}/payments/orders
GET /api/v1/admin/commerce/tenants/{tenant_id}/payments/orders/{order_id}
GET /api/v1/admin/commerce/tenants/{tenant_id}/payments/orders/{order_id}/events
POST /api/v1/admin/commerce/tenants/{tenant_id}/payments/reconcile
GET /api/v1/admin/usage/top-tenants
GET /api/v1/admin/tokens/usage
GET /api/v1/admin/token-policies
GET /api/v1/admin/tokens/portfolio
GET /api/v1/admin/tokens/subjects/{subject}
GET /api/v1/admin/tokens/expiring
GET /api/v1/admin/tokenexchange/chains/{jti}
GET /api/v1/admin/sessions
GET /api/v1/admin/tokens
DELETE /api/v1/admin/tokens/{id}
POST /api/v1/admin/logout
GET /api/v1/admin/sessions/linked/{subject}
GET /api/v1/admin/tokens/suspicious
GET /api/v1/admin/threat-policies
GET /api/v1/admin/threat-policies/{name}
PUT /api/v1/admin/threat-policies/{name}
DELETE /api/v1/admin/threat-policies/{name}
POST /api/v1/admin/tokens/bulk-revoke
POST /api/v1/admin/tenants/{id}:set-status
GET /api/v1/admin/domains
POST /api/v1/admin/domains
GET /api/v1/admin/domains/{hostname}
PUT /api/v1/admin/domains/{hostname}
DELETE /api/v1/admin/domains/{hostname}
GET /api/v1/admin/clients
GET /api/v1/admin/clients/expiring
POST /api/v1/admin/clients
GET /api/v1/admin/clients/{id}
PUT /api/v1/admin/clients/{id}
DELETE /api/v1/admin/clients/{id}
POST /api/v1/admin/clients/{id}/rotate-secret
POST /api/v1/admin/clients/{id}/approve
POST /api/v1/admin/clients/{id}/reject
GET /api/v1/clients/{id}
GET /api/v1/admin/keys
POST /api/v1/admin/keys/rotate
GET /api/v1/admin/users
POST /api/v1/admin/users
GET /api/v1/admin/users/{id}
PUT /api/v1/admin/users/{id}
DELETE /api/v1/admin/users/{id}
GET /api/v1/admin/users/{id}/sessions
GET /api/v1/admin/local-users
POST /api/v1/admin/local-users
GET /api/v1/admin/local-users/{id}
PUT /api/v1/admin/local-users/{id}
DELETE /api/v1/admin/local-users/{id}
GET /api/v1/admin/users/{id}/consents
DELETE /api/v1/admin/users/{id}/consents/{client_id}
GET /api/v1/admin/users/{id}/mfa
DELETE /api/v1/admin/users/{id}/mfa/{factor_id}
GET /api/v1/admin/users/{id}/lifecycle
POST /api/v1/admin/users/{id}/lifecycle
POST /api/v1/admin/users/{id}/mfa/recovery-codes
POST /api/v1/admin/users/{id}/password
POST /api/v1/admin/users/{id}/email
POST /api/v1/admin/account-lockout/clear
POST /api/v1/admin/break-glass
GET /api/v1/admin/break-glass
DELETE /api/v1/admin/break-glass/{id}
POST /api/v1/admin/break-glass/{id}/approve
POST /api/v1/admin/break-glass/{id}/impersonate
POST /api/v1/admin/changes
GET /api/v1/admin/changes
GET /api/v1/admin/changes/{id}
POST /api/v1/admin/changes/{id}/approve
POST /api/v1/admin/changes/{id}/reject
GET /api/v1/admin/connections
POST /api/v1/admin/connections
GET /api/v1/admin/connections/{id}
DELETE /api/v1/admin/connections/{id}
GET /api/v1/admin/connections/{id}/domains
POST /api/v1/admin/connections/{id}/domains/{domain}/verify
GET /api/v1/admin/connections/{id}/health
POST /api/v1/admin/connections/{id}/probe
GET /api/v1/admin/branding
PUT /api/v1/admin/branding
DELETE /api/v1/admin/branding
GET /api/v1/admin/providers
POST /api/v1/admin/providers
GET /api/v1/admin/providers/{id}
PUT /api/v1/admin/providers/{id}
DELETE /api/v1/admin/providers/{id}
GET /api/v1/admin/users/{id}/devices
DELETE /api/v1/admin/users/{id}/devices/{deviceId}
GET /api/v1/admin/devices
GET /api/v1/admin/devices/stats
POST /api/v1/admin/devices/bulk-revoke
GET /api/v1/admin/devices/{id}/activity
POST /api/v1/admin/devices/{id}/trust
GET /api/v1/admin/users/{id}/login-history
GET /api/v1/admin/security/activity
GET /api/v1/admin/tenants/{id}/members
PUT /api/v1/admin/tenants/{id}/members/{user_id}
DELETE /api/v1/admin/tenants/{id}/members/{user_id}
POST /api/v1/admin/tenants/{id}/export
GET /api/v1/admin/tenants/{id}/invitations
POST /api/v1/admin/tenants/{id}/invitations
DELETE /api/v1/admin/tenants/{id}/invitations/{email}
DELETE /api/v1/admin/users/{id}/device-secrets
DELETE /api/v1/admin/users/{id}/refresh-tokens
GET /api/v1/admin/users/{id}/password-reset-tokens
DELETE /api/v1/admin/users/{id}/password-reset-tokens
GET /api/v1/admin/users/{id}/email-change-tokens
DELETE /api/v1/admin/users/{id}/email-change-tokens
GET /api/v1/admin/tokens/sessions
POST /api/v1/admin/tokens/revoke
POST /api/v1/admin/tokens/temp
GET /api/v1/admin/permissions/{client_id}/roles
POST /api/v1/admin/permissions/{client_id}/roles
PUT /api/v1/admin/permissions/{client_id}/roles/{role_code}
DELETE /api/v1/admin/permissions/{client_id}/roles/{role_code}
GET /api/v1/admin/permissions/{client_id}/assignments
POST /api/v1/admin/permissions/{client_id}/assignments/{user_id}
POST /api/v1/admin/permissions/{client_id}/assignments/{user_id}/unassign
PUT /api/v1/admin/permissions/{client_id}/menus
GET /api/v1/audit/events
GET /api/v1/audit/facets
GET /api/v1/audit/events/{id}
GET /api/v1/netpolicy/policies
POST /api/v1/netpolicy/policies
GET /api/v1/netpolicy/policies/{name}
DELETE /api/v1/netpolicy/policies/{name}
GET /api/v1/netpolicy/classify
GET /api/v1/netpolicy/resolve-me
GET /api/v1/compliance/users/{id}/export
POST /api/v1/compliance/users/{id}/erase
GET /api/v1/scim/v2/ServiceProviderConfig
GET /api/v1/scim/v2/Schemas
POST /api/v1/scim/v2/Bulk
GET /api/v1/scim/v2/Me
PUT /api/v1/scim/v2/Me
PATCH /api/v1/scim/v2/Me
DELETE /api/v1/scim/v2/Me
GET /api/v1/scim/v2/Users
POST /api/v1/scim/v2/Users
GET /api/v1/scim/v2/Users/{id}
PUT /api/v1/scim/v2/Users/{id}
PATCH /api/v1/scim/v2/Users/{id}
DELETE /api/v1/scim/v2/Users/{id}
GET /api/v1/scim/v2/Groups
POST /api/v1/scim/v2/Groups
GET /api/v1/scim/v2/Groups/{id}
PUT /api/v1/scim/v2/Groups/{id}
PATCH /api/v1/scim/v2/Groups/{id}
DELETE /api/v1/scim/v2/Groups/{id}
''';
