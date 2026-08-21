import 'package:flutter/material.dart';

import '../../api/snaplink_admin_api.dart';
import '../../api/sso_client.dart';
import '../../i18n/app_strings.dart';
import '../../i18n/localized_text.dart';
import 'access_policies_tab.dart';
import 'admin_navigation.dart';
import 'admin_operations_tab.dart';
import 'audit_log_tab.dart';
import 'authz_check_tab.dart';
import 'break_glass_tab.dart';
import 'change_approvals_tab.dart';
import 'commerce/commerce_tab.dart';
import 'credentials_tab.dart';
import 'crypto_keys_tab.dart';
import 'domains_tab.dart';
import 'dr_mode_tab.dart';
import 'governance_tab.dart';
import 'health_tab.dart';
import 'network_policies_tab.dart';
import 'privacy_compliance_tab.dart';
import 'recovery_releases_tab.dart';
import 'tenant_organizations_tab.dart';
import 'tenants_tab.dart';
import 'threat_policies_tab.dart';
import 'token_exchange_tab.dart';
import 'token_policies_tab.dart';
import 'usage_analytics_tab.dart';
import 'webhooks_tab.dart';

/// Builds the lower-frequency admin destinations kept separate from the core
/// navigation factory so each source file stays within the structural budget.
List<AdminNavigationEntry<NavigationRailDestination, Widget>>
buildDashboardNavigationTail({
  required SSOAdminClient client,
  required SnaplinkAdminApi api,
  required List<SnaplinkAdminEndpoint> endpoints,
  required AdminNavigationCapabilities navigation,
  required SnaplinkAdminCapabilities capabilities,
  required AppStrings strings,
  required bool commerceAvailable,
  required Object? commerceProbeError,
}) {
  return [
    if (navigation.supportsUsageAnalytics)
      AdminNavigationEntry(
        module: AdminModuleId.usageAnalytics,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.insights_outlined),
          selectedIcon: const Icon(Icons.insights),
          label: Text(strings.usageInsights),
        ),
        page: UsageAnalyticsTab(api: api, capabilities: capabilities),
      ),
    AdminNavigationEntry(
      module: AdminModuleId.tenants,
      destination: NavigationRailDestination(
        icon: const Icon(Icons.business),
        label: Text(strings.tenants),
      ),
      page: TenantsTab(client: client),
    ),
    if (commerceAvailable)
      AdminNavigationEntry(
        module: AdminModuleId.commerce,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.payments_outlined),
          selectedIcon: const Icon(Icons.payments),
          label: const LocalizedText('Subscriptions & Billing'),
        ),
        page: CommerceTab(api: api, availabilityError: commerceProbeError),
      ),
    if (navigation.supportsOrganizations)
      AdminNavigationEntry(
        module: AdminModuleId.organizations,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.groups_outlined),
          selectedIcon: const Icon(Icons.groups),
          label: Text(strings.organizations),
        ),
        page: TenantOrganizationsTab(api: api, capabilities: capabilities),
      ),
    AdminNavigationEntry(
      module: AdminModuleId.operations,
      destination: NavigationRailDestination(
        icon: const Icon(Icons.terminal_outlined),
        selectedIcon: const Icon(Icons.terminal),
        label: Text(strings.operations),
      ),
      page: AdminOperationsTab(api: api, endpoints: endpoints),
    ),
    if (navigation.supportsCryptoKeys)
      AdminNavigationEntry(
        module: AdminModuleId.cryptoKeys,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.vpn_key_outlined),
          selectedIcon: const Icon(Icons.vpn_key),
          label: Text(strings.cryptoKeys),
        ),
        page: CryptoKeysTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsCredentials)
      AdminNavigationEntry(
        module: AdminModuleId.credentials,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.verified_user_outlined),
          selectedIcon: const Icon(Icons.verified_user),
          label: Text(strings.credentials),
        ),
        page: CredentialsTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsTokenPolicies)
      AdminNavigationEntry(
        module: AdminModuleId.tokenPolicies,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.policy_outlined),
          selectedIcon: const Icon(Icons.policy),
          label: Text(strings.tokenPolicies),
        ),
        page: TokenPoliciesTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsTokenExchange)
      AdminNavigationEntry(
        module: AdminModuleId.tokenExchange,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.swap_horiz_outlined),
          selectedIcon: const Icon(Icons.swap_horiz),
          label: Text(strings.tokenExchange),
        ),
        page: TokenExchangeTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsAuthzChecks)
      AdminNavigationEntry(
        module: AdminModuleId.authzChecks,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.verified_outlined),
          selectedIcon: const Icon(Icons.verified),
          label: Text(strings.authzChecks),
        ),
        page: AuthzCheckTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsDomains)
      AdminNavigationEntry(
        module: AdminModuleId.domains,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.language_outlined),
          selectedIcon: const Icon(Icons.language),
          label: Text(strings.domains),
        ),
        page: DomainsTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsNetworkPolicies)
      AdminNavigationEntry(
        module: AdminModuleId.networkPolicies,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.lan_outlined),
          selectedIcon: const Icon(Icons.lan),
          label: Text(strings.networkPolicies),
        ),
        page: NetworkPoliciesTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsAccessPolicies)
      AdminNavigationEntry(
        module: AdminModuleId.accessPolicies,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.verified_user_outlined),
          selectedIcon: const Icon(Icons.verified_user),
          label: Text(strings.accessPolicies),
        ),
        page: AccessPoliciesTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsDrMode)
      AdminNavigationEntry(
        module: AdminModuleId.drMode,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.monitor_heart_outlined),
          selectedIcon: const Icon(Icons.monitor_heart),
          label: Text(strings.drMode),
        ),
        page: DRModeTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsThreatPolicies)
      AdminNavigationEntry(
        module: AdminModuleId.threatPolicies,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.warning_amber_outlined),
          selectedIcon: const Icon(Icons.warning_amber),
          label: Text(strings.threatPolicies),
        ),
        page: ThreatPoliciesTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsWebhooks)
      AdminNavigationEntry(
        module: AdminModuleId.webhooks,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.webhook_outlined),
          selectedIcon: const Icon(Icons.webhook),
          label: Text(strings.webhooks),
        ),
        page: WebhooksTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsEmergencyAccess)
      AdminNavigationEntry(
        module: AdminModuleId.emergencyAccess,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.emergency_outlined),
          selectedIcon: const Icon(Icons.emergency),
          label: Text(strings.emergencyAccess),
        ),
        page: BreakGlassTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsChangeApprovals)
      AdminNavigationEntry(
        module: AdminModuleId.changeApprovals,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.approval_outlined),
          selectedIcon: const Icon(Icons.approval),
          label: Text(strings.changeApprovals),
        ),
        page: ChangeApprovalsTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsRecoveryReleases)
      AdminNavigationEntry(
        module: AdminModuleId.recoveryReleases,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.settings_backup_restore_outlined),
          selectedIcon: const Icon(Icons.settings_backup_restore),
          label: Text(strings.recoveryReleases),
        ),
        page: RecoveryReleasesTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsPrivacyCompliance)
      AdminNavigationEntry(
        module: AdminModuleId.privacyCompliance,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.privacy_tip_outlined),
          selectedIcon: const Icon(Icons.privacy_tip),
          label: Text(strings.privacyRetention),
        ),
        page: PrivacyComplianceTab(api: api, capabilities: capabilities),
      ),
    AdminNavigationEntry(
      module: AdminModuleId.governance,
      destination: NavigationRailDestination(
        icon: const Icon(Icons.verified_user_outlined),
        selectedIcon: const Icon(Icons.verified_user),
        label: Text(strings.governance),
      ),
      page: GovernanceTab(api: api, capabilities: capabilities),
    ),
    if (navigation.supportsAuditLog)
      AdminNavigationEntry(
        module: AdminModuleId.auditLog,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.receipt_long_outlined),
          selectedIcon: const Icon(Icons.receipt_long),
          label: Text(strings.auditLog),
        ),
        page: AuditLogTab(api: api, capabilities: capabilities),
      ),
    AdminNavigationEntry(
      module: AdminModuleId.health,
      destination: NavigationRailDestination(
        icon: const Icon(Icons.monitor_heart_outlined),
        selectedIcon: const Icon(Icons.monitor_heart),
        label: Text(strings.health),
      ),
      page: HealthTab(api: api),
    ),
  ];
}
