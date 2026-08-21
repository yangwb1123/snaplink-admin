import 'package:flutter/material.dart';

import '../../api/snaplink_admin_api.dart';
import '../../api/sso_client.dart';
import '../../i18n/app_strings.dart';
import 'admin_live_events_tab.dart';
import 'admin_overview_tab.dart';
import 'admin_navigation.dart';
import 'clients_tab.dart';
import 'connections_tab.dart';
import 'dashboard_navigation_tail.dart';
import 'device_security_tab.dart';
import 'local_users_tab.dart';
import 'permissions_tab.dart';
import 'scim/scim_directory_tab.dart';
import 'token_security_tab.dart';
import 'user_support_tab.dart';
import 'users_tab.dart';

/// Builds the capability-gated admin navigation entries (rail destinations
/// and page widgets) for the dashboard.
///
/// Pure construction from the endpoint inventory, locale and commerce probe
/// state; the dashboard applies the mode filter and persona afterwards.
({
  List<AdminNavigationEntry<NavigationRailDestination, Widget>> entries,
  SnaplinkAdminCapabilities capabilities,
  SnaplinkAdminCapabilitySnapshot capabilitySnapshot,
})
buildDashboardNavigationEntries({
  required SSOAdminClient client,
  required SnaplinkAdminApi api,
  required List<SnaplinkAdminEndpoint> endpoints,
  required Object? capabilitiesError,
  bool capabilitiesLoading = false,
  required VoidCallback onRefresh,
  required AppStrings strings,
  required bool commerceAvailable,
  required Object? commerceProbeError,
}) {
  final navigation = AdminNavigationCapabilities(
    endpoints,
    // A failed inventory request is different from a successful empty
    // inventory. Optional pages must show an unknown/retry state in the
    // former case rather than claiming that the feature is disabled.
    runtimeInventoryLoading: capabilitiesLoading,
    runtimeInventoryAvailable:
        !capabilitiesLoading && capabilitiesError == null,
  );
  final capabilities = navigation.capabilities;
  final capabilitySnapshot = navigation.snapshot;
  final entries = <AdminNavigationEntry<NavigationRailDestination, Widget>>[
    AdminNavigationEntry(
      module: AdminModuleId.overview,
      destination: NavigationRailDestination(
        icon: const Icon(Icons.dashboard_outlined),
        selectedIcon: const Icon(Icons.dashboard),
        label: Text(strings.overview),
      ),
      page: AdminOverviewTab(
        endpoints: endpoints,
        loadError: capabilitiesError,
        onRefresh: onRefresh,
      ),
    ),
    AdminNavigationEntry(
      module: AdminModuleId.clients,
      destination: NavigationRailDestination(
        icon: const Icon(Icons.apps),
        label: Text(strings.clients),
      ),
      page: ClientsTab(client: client),
    ),
    AdminNavigationEntry(
      module: AdminModuleId.users,
      destination: NavigationRailDestination(
        icon: const Icon(Icons.people),
        label: Text(strings.users),
      ),
      page: UsersTab(client: client),
    ),
    if (navigation.supportsLocalUsers)
      AdminNavigationEntry(
        module: AdminModuleId.localUsers,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.password_outlined),
          selectedIcon: const Icon(Icons.password),
          label: Text(strings.localUsers),
        ),
        page: LocalUsersTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsScimDirectory)
      AdminNavigationEntry(
        module: AdminModuleId.scimDirectory,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.account_tree_outlined),
          selectedIcon: const Icon(Icons.account_tree),
          label: Text(strings.scimDirectory),
        ),
        page: ScimDirectoryTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsPermissions)
      AdminNavigationEntry(
        module: AdminModuleId.permissions,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.admin_panel_settings_outlined),
          selectedIcon: const Icon(Icons.admin_panel_settings),
          label: Text(strings.permissions),
        ),
        page: PermissionsTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsConnections)
      AdminNavigationEntry(
        module: AdminModuleId.connections,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.hub_outlined),
          selectedIcon: const Icon(Icons.hub),
          label: Text(strings.connections),
        ),
        page: ConnectionsTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsUserSupport)
      AdminNavigationEntry(
        module: AdminModuleId.userSupport,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.support_agent_outlined),
          selectedIcon: const Icon(Icons.support_agent),
          label: Text(strings.userSupport),
        ),
        page: UserSupportTab(api: api, capabilities: capabilities),
      ),
    if (navigation.supportsDeviceSecurity)
      AdminNavigationEntry(
        module: AdminModuleId.deviceSecurity,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.devices_other_outlined),
          selectedIcon: const Icon(Icons.devices_other),
          label: Text(strings.deviceSecurity),
        ),
        page: DeviceSecurityTab(
          api: api,
          capabilitySnapshot: capabilitySnapshot,
          onCapabilityRetry: onRefresh,
        ),
      ),
    AdminNavigationEntry(
      module: AdminModuleId.liveActivity,
      destination: NavigationRailDestination(
        icon: const Icon(Icons.sensors_outlined),
        selectedIcon: const Icon(Icons.sensors),
        label: Text(strings.liveActivity),
      ),
      page: AdminLiveEventsTab(api: api, endpoints: endpoints),
    ),
    AdminNavigationEntry(
      module: AdminModuleId.tokenSecurity,
      destination: NavigationRailDestination(
        icon: const Icon(Icons.shield_outlined),
        selectedIcon: const Icon(Icons.shield),
        label: Text(strings.tokenSecurity),
      ),
      page: TokenSecurityTab(api: api, capabilities: capabilities),
    ),
    ...buildDashboardNavigationTail(
      client: client,
      api: api,
      endpoints: endpoints,
      navigation: navigation,
      capabilities: capabilities,
      strings: strings,
      commerceAvailable: commerceAvailable,
      commerceProbeError: commerceProbeError,
    ),
  ];

  return (
    entries: entries,
    capabilities: capabilities,
    capabilitySnapshot: capabilitySnapshot,
  );
}
