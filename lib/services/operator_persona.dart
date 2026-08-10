/// Pure operator-persona derivation and metric ordering (no Flutter imports).
///
/// The persona is derived exclusively from the POST-GATING enabled module
/// set (the capability-surviving navigation entries) plus the commerce
/// probe result. It never reads the access token (opaque), never consults
/// claims, and grants/withholds nothing — pages only use it to emphasize
/// (reorder metric strips, distribution-bar segments, group cards).
library;

/// Operator personas, ordered by derivation precedence (first match wins):
/// `full` → `securityOps` → `auditor` → `support` → `identityOps` →
/// `general`. `general` is the fallback for any input (total function).
enum OperatorPersona {
  full,
  securityOps,
  auditor,
  support,
  identityOps,
  general,
}

/// Duplicates of `AdminModuleId` values — deliberately: the services layer
/// must not import `lib/screens/`. `operator_persona_test.dart` links every
/// constant to `AdminModuleId` (string equality) as a typo-drift guard.
abstract final class PersonaModuleId {
  static const cryptoKeys = 'crypto-keys';
  static const credentials = 'credentials';
  static const drMode = 'dr-mode';
  static const threatPolicies = 'threat-policies';
  static const networkPolicies = 'network-policies';
  static const accessPolicies = 'access-policies';
  static const auditLog = 'audit-log';
  static const privacyCompliance = 'privacy-compliance';
  static const governance = 'governance';
  static const changeApprovals = 'change-approvals';
  static const deviceSecurity = 'device-security';
  static const userSupport = 'user-support';
  static const emergencyAccess = 'emergency-access';
  static const liveActivity = 'live-activity';
  static const localUsers = 'local-users';
  static const scimDirectory = 'scim-directory';
  static const connections = 'connections';
  static const permissions = 'permissions';
  static const domains = 'domains';
  static const tokenPolicies = 'token-policies';
  static const tokenExchange = 'token-exchange';
  static const organizations = 'organizations';
}

/// Pure, total, deterministic persona derivation.
///
/// Inputs are the POST-GATING enabled module set and the commerce probe
/// result. Precedence (first match wins):
/// `full` → `securityOps` → `auditor` → `support` → `identityOps` →
/// `general`. Never throws; `{}` maps to `general`.
OperatorPersona deriveOperatorPersona({
  required Set<String> enabledModules,
  required bool commerceAvailable,
}) {
  bool has(String id) => enabledModules.contains(id);

  final securityOpsMatch =
      has(PersonaModuleId.cryptoKeys) &&
      has(PersonaModuleId.credentials) &&
      has(PersonaModuleId.drMode) &&
      (has(PersonaModuleId.threatPolicies) ||
          has(PersonaModuleId.networkPolicies) ||
          has(PersonaModuleId.accessPolicies));

  final identityOpsMatch =
      has(PersonaModuleId.localUsers) ||
      has(PersonaModuleId.scimDirectory) ||
      has(PersonaModuleId.connections) ||
      has(PersonaModuleId.permissions) ||
      has(PersonaModuleId.domains) ||
      has(PersonaModuleId.tokenPolicies) ||
      has(PersonaModuleId.tokenExchange) ||
      has(PersonaModuleId.organizations);

  if (securityOpsMatch &&
      identityOpsMatch &&
      commerceAvailable &&
      (has(PersonaModuleId.governance) || has(PersonaModuleId.auditLog))) {
    return OperatorPersona.full;
  }
  if (securityOpsMatch) return OperatorPersona.securityOps;

  if (has(PersonaModuleId.auditLog) &&
      (has(PersonaModuleId.privacyCompliance) ||
          has(PersonaModuleId.governance) ||
          has(PersonaModuleId.changeApprovals)) &&
      !has(PersonaModuleId.deviceSecurity) &&
      !has(PersonaModuleId.cryptoKeys)) {
    return OperatorPersona.auditor;
  }

  if (has(PersonaModuleId.userSupport) &&
      (has(PersonaModuleId.deviceSecurity) ||
          has(PersonaModuleId.emergencyAccess) ||
          has(PersonaModuleId.liveActivity)) &&
      !has(PersonaModuleId.cryptoKeys) &&
      !has(PersonaModuleId.credentials)) {
    return OperatorPersona.support;
  }

  if (identityOpsMatch) return OperatorPersona.identityOps;
  return OperatorPersona.general;
}

/// i18n source key for the persona display name ('Persona.full' etc.).
String personaLabelKey(OperatorPersona p) => switch (p) {
  OperatorPersona.full => 'Persona.full',
  OperatorPersona.securityOps => 'Persona.securityOps',
  OperatorPersona.auditor => 'Persona.auditor',
  OperatorPersona.support => 'Persona.support',
  OperatorPersona.identityOps => 'Persona.identityOps',
  OperatorPersona.general => 'Persona.general',
};

// ---------------------------------------------------------------------------
// Page metric enums + persona order/emphasis helpers (§4.9 of the design).
// Every order helper returns a true permutation of its page's metric set
// (same elements, no drops/duplicates) and is pinned by T-P-01.
// ---------------------------------------------------------------------------

enum OverviewMetric {
  liveEndpoints,
  featureGroups,
  documentedOnly,
  commerceAvailability,
}

enum ClientMetric { total, active, inactive, secretsExpiring }

enum UserMetric { total, providers }

enum TenantMetric { total, active, suspended }

enum AuditMetric { entries, errorRate, eventTypes }

enum ClientDetailMetric { grantTypes, scopes, secretExpiry }

enum TenantDetailMetric { members, invitations, residencyRegion }

List<OverviewMetric> overviewMetricOrder(OperatorPersona p) => switch (p) {
  OperatorPersona.full => const [
    OverviewMetric.liveEndpoints,
    OverviewMetric.featureGroups,
    OverviewMetric.documentedOnly,
    OverviewMetric.commerceAvailability,
  ],
  OperatorPersona.securityOps => const [
    OverviewMetric.documentedOnly,
    OverviewMetric.liveEndpoints,
    OverviewMetric.featureGroups,
    OverviewMetric.commerceAvailability,
  ],
  OperatorPersona.auditor => const [
    OverviewMetric.documentedOnly,
    OverviewMetric.commerceAvailability,
    OverviewMetric.liveEndpoints,
    OverviewMetric.featureGroups,
  ],
  OperatorPersona.support => const [
    OverviewMetric.liveEndpoints,
    OverviewMetric.featureGroups,
    OverviewMetric.documentedOnly,
    OverviewMetric.commerceAvailability,
  ],
  OperatorPersona.identityOps => const [
    OverviewMetric.featureGroups,
    OverviewMetric.liveEndpoints,
    OverviewMetric.documentedOnly,
    OverviewMetric.commerceAvailability,
  ],
  OperatorPersona.general => const [
    OverviewMetric.liveEndpoints,
    OverviewMetric.featureGroups,
    OverviewMetric.documentedOnly,
    OverviewMetric.commerceAvailability,
  ],
};

List<ClientMetric> clientMetricOrder(OperatorPersona p) => switch (p) {
  OperatorPersona.full => const [
    ClientMetric.total,
    ClientMetric.active,
    ClientMetric.inactive,
    ClientMetric.secretsExpiring,
  ],
  OperatorPersona.securityOps => const [
    ClientMetric.secretsExpiring,
    ClientMetric.total,
    ClientMetric.active,
    ClientMetric.inactive,
  ],
  OperatorPersona.auditor => const [
    ClientMetric.secretsExpiring,
    ClientMetric.active,
    ClientMetric.total,
    ClientMetric.inactive,
  ],
  OperatorPersona.support => const [
    ClientMetric.active,
    ClientMetric.total,
    ClientMetric.inactive,
    ClientMetric.secretsExpiring,
  ],
  OperatorPersona.identityOps => const [
    ClientMetric.active,
    ClientMetric.total,
    ClientMetric.inactive,
    ClientMetric.secretsExpiring,
  ],
  OperatorPersona.general => const [
    ClientMetric.total,
    ClientMetric.active,
    ClientMetric.inactive,
    ClientMetric.secretsExpiring,
  ],
};

List<UserMetric> userMetricOrder(OperatorPersona p) => switch (p) {
  OperatorPersona.auditor ||
  OperatorPersona.support ||
  OperatorPersona.identityOps => const [UserMetric.providers, UserMetric.total],
  _ => const [UserMetric.total, UserMetric.providers],
};

List<TenantMetric> tenantMetricOrder(OperatorPersona p) => switch (p) {
  OperatorPersona.securityOps || OperatorPersona.auditor => const [
    TenantMetric.suspended,
    TenantMetric.total,
    TenantMetric.active,
  ],
  OperatorPersona.identityOps => const [
    TenantMetric.active,
    TenantMetric.total,
    TenantMetric.suspended,
  ],
  _ => const [TenantMetric.total, TenantMetric.active, TenantMetric.suspended],
};

List<AuditMetric> auditMetricOrder(OperatorPersona p) => switch (p) {
  OperatorPersona.securityOps || OperatorPersona.auditor => const [
    AuditMetric.errorRate,
    AuditMetric.entries,
    AuditMetric.eventTypes,
  ],
  _ => const [
    AuditMetric.entries,
    AuditMetric.errorRate,
    AuditMetric.eventTypes,
  ],
};

List<ClientDetailMetric> clientDetailMetricOrder(OperatorPersona p) =>
    switch (p) {
      OperatorPersona.securityOps || OperatorPersona.auditor => const [
        ClientDetailMetric.secretExpiry,
        ClientDetailMetric.grantTypes,
        ClientDetailMetric.scopes,
      ],
      _ => const [
        ClientDetailMetric.grantTypes,
        ClientDetailMetric.scopes,
        ClientDetailMetric.secretExpiry,
      ],
    };

List<TenantDetailMetric> tenantDetailMetricOrder(OperatorPersona p) =>
    switch (p) {
      OperatorPersona.identityOps => const [
        TenantDetailMetric.invitations,
        TenantDetailMetric.members,
        TenantDetailMetric.residencyRegion,
      ],
      _ => const [
        TenantDetailMetric.members,
        TenantDetailMetric.invitations,
        TenantDetailMetric.residencyRegion,
      ],
    };

/// Clients distribution-bar emphasis: i18n key of the emphasized segment
/// label ('Active' / 'Inactive') or null for no emphasis.
String? clientsBarEmphasis(OperatorPersona p) => switch (p) {
  OperatorPersona.auditor ||
  OperatorPersona.support ||
  OperatorPersona.identityOps => 'Active',
  _ => null,
};

/// Tenants distribution-bar emphasis: i18n key of the emphasized segment
/// label ('Active' / 'Suspended') or null for no emphasis.
String? tenantsBarEmphasis(OperatorPersona p) => switch (p) {
  OperatorPersona.securityOps || OperatorPersona.auditor => 'Suspended',
  OperatorPersona.support || OperatorPersona.identityOps => 'Active',
  _ => null,
};
