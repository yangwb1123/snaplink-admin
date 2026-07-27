import 'package:flutter/material.dart';
import '../../i18n/app_strings.dart';
import 'admin_route.dart';
import '../../session.dart';
import '../../sso_client.dart';
import '../settings_screen.dart';
import 'package:sso_admin/widgets/offline_banner.dart';
import 'package:sso_admin/widgets/error_boundary.dart';
import 'package:sso_admin/services/shortcut_service.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/command_palette.dart';
import 'package:sso_admin/widgets/responsive_navigation_scaffold.dart';
import 'package:sso_admin/widgets/shortcuts_dialog.dart';
import 'admin_overview_tab.dart';
import 'admin_live_events_tab.dart';
import 'admin_operations_tab.dart';
import 'client_detail_screen.dart';
import 'clients_tab.dart';
import 'connection_detail_screen.dart';
import 'connections_tab.dart';
import 'audit_log_tab.dart';
import 'health_tab.dart';
import 'governance_tab.dart';
import 'permission_detail_screen.dart';
import 'permissions_tab.dart';
import 'snaplink_admin_api.dart';
import 'tenant_organizations_tab.dart';
import 'token_security_tab.dart';
import 'access_policies_tab.dart';
import 'authz_check_tab.dart';
import 'break_glass_detail_screen.dart';
import 'break_glass_tab.dart';
import 'credentials_tab.dart';
import 'crypto_keys_tab.dart';
import 'domains_tab.dart';
import 'dr_mode_tab.dart';
import 'device_security_tab.dart';
import 'threat_policies_tab.dart';
import 'token_exchange_tab.dart';
import 'token_policies_tab.dart';
import 'webhooks_tab.dart';
import 'user_detail_screen.dart';
import 'user_support_tab.dart';
import 'users_tab.dart';
import 'webhook_detail_screen.dart';
import 'tenant_detail_screen.dart';
import 'tenants_tab.dart';
import 'admin_navigation.dart';
import 'change_approvals_tab.dart';
import 'local_users_tab.dart';
import 'network_policies_tab.dart';
import 'recovery_releases_tab.dart';
import 'privacy_compliance_tab.dart';
import 'usage_analytics_tab.dart';
import 'scim/scim_directory_tab.dart';

class DashboardScreen extends StatefulWidget {
  final SSOAdminClient client;
  const DashboardScreen({super.key, required this.client});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedModule = AdminModuleId.overview;
  AdminRoute _currentRoute = const AdminRoute(module: AdminModuleId.overview);
  List<String> _visibleModules = const [
    AdminModuleId.overview,
    AdminModuleId.clients,
    AdminModuleId.users,
  ];
  late final SnaplinkAdminApi _api;
  List<SnaplinkAdminEndpoint> _endpoints = const [];
  Object? _capabilitiesError;
  late final void Function() _cancelLocationChange;

  @override
  void initState() {
    super.initState();
    _api = SnaplinkAdminApi(
      baseUrl: widget.client.baseUrl,
      accessToken: Session.read() ?? '',
      onUnauthorized: _localLogout,
    );
    _currentRoute = AdminRoute.fromUri(Uri.base);
    _selectedModule = _currentRoute.module;
    _refreshCapabilities();
    _initShortcuts();
    _cancelLocationChange = BrowserNavigation.listenToLocationChange(
      _syncRouteFromLocation,
    );
  }

  @override
  void dispose() {
    _cancelLocationChange();
    ShortcutService().dispose();
    super.dispose();
  }

  void _syncRouteFromLocation() {
    if (!mounted) return;
    final nextRoute = AdminRoute.fromUri(Uri.base);
    if (nextRoute == _currentRoute) return;
    setState(() {
      _currentRoute = nextRoute;
      _selectedModule = nextRoute.module;
    });
  }

  Future<void> _refreshCapabilities() async {
    setState(() => _capabilitiesError = null);
    try {
      final endpoints = await _api.listEndpoints();
      if (!mounted) return;
      setState(() {
        _endpoints = endpoints;
      });
    } catch (error) {
      if (mounted) setState(() => _capabilitiesError = error);
    }
  }

  void _initShortcuts() {
    ShortcutService().init(
      onCreate: () {
        final module =
            _selectedModule.isNotEmpty &&
                _visibleModules.contains(_selectedModule)
            ? _selectedModule
            : _visibleModules.firstWhere(
                (candidate) => candidate.isNotEmpty,
                orElse: () => AdminModuleId.overview,
              );
        if (module.isNotEmpty) {
          AdminRoute.go(module, action: 'new');
        }
      },
      onRefresh: () {
        _refreshCapabilities();
      },
      onEscape: () => Navigator.of(context).maybePop(),
      onCommandPalette: () => CommandPalette.show(
        context,
        currentModule: _visibleModules.contains(_selectedModule)
            ? _selectedModule
            : AdminModuleId.overview,
        allModules: _visibleModules
            .where((module) => module.isNotEmpty)
            .toList(growable: false),
      ),
      onShowShortcuts: () => ShortcutsDialog.show(context),
    );
  }

  void _localLogout() {
    widget.client.logout();
    Session.clear();
    BrowserNavigation.assignLocation('/login/');
  }

  Future<void> _logout() async {
    try {
      await _api.post('/api/v1/admin/logout');
    } catch (_) {
      // Logout is best-effort; ignore errors
    }
    _localLogout();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    return OfflineBanner(child: _buildBody(context, strings));
  }

  Widget _buildBody(BuildContext context, AppStrings strings) {
    final navigation = AdminNavigationCapabilities(_endpoints);
    final capabilities = navigation.capabilities;
    final entries = <AdminNavigationEntry<NavigationRailDestination, Widget>>[
      AdminNavigationEntry(
        module: AdminModuleId.overview,
        destination: const NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: Text('Overview'),
        ),
        page: AdminOverviewTab(
          endpoints: _endpoints,
          loadError: _capabilitiesError,
          onRefresh: _refreshCapabilities,
        ),
      ),
      AdminNavigationEntry(
        module: AdminModuleId.clients,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.apps),
          label: Text(strings.clients),
        ),
        page: ClientsTab(client: widget.client),
      ),
      AdminNavigationEntry(
        module: AdminModuleId.users,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.people),
          label: Text(strings.users),
        ),
        page: UsersTab(client: widget.client),
      ),
      if (navigation.supportsLocalUsers)
        AdminNavigationEntry(
          module: AdminModuleId.localUsers,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.password_outlined),
            label: Text('Local users'),
          ),
          page: LocalUsersTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsScimDirectory)
        AdminNavigationEntry(
          module: AdminModuleId.scimDirectory,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.account_tree_outlined),
            label: Text('SCIM directory'),
          ),
          page: ScimDirectoryTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsPermissions)
        AdminNavigationEntry(
          module: AdminModuleId.permissions,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            label: Text('Permissions'),
          ),
          page: PermissionsTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsConnections)
        AdminNavigationEntry(
          module: AdminModuleId.connections,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.hub_outlined),
            label: Text('Connections'),
          ),
          page: ConnectionsTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsUserSupport)
        AdminNavigationEntry(
          module: AdminModuleId.userSupport,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.support_agent_outlined),
            label: Text('User support'),
          ),
          page: UserSupportTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsDeviceSecurity)
        AdminNavigationEntry(
          module: AdminModuleId.deviceSecurity,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.devices_other_outlined),
            label: Text('Device security'),
          ),
          page: DeviceSecurityTab(api: _api),
        ),
      AdminNavigationEntry(
        module: AdminModuleId.liveActivity,
        destination: const NavigationRailDestination(
          icon: Icon(Icons.sensors_outlined),
          label: Text('Live activity'),
        ),
        page: AdminLiveEventsTab(api: _api, endpoints: _endpoints),
      ),
      AdminNavigationEntry(
        module: AdminModuleId.tokenSecurity,
        destination: const NavigationRailDestination(
          icon: Icon(Icons.shield_outlined),
          label: Text('Token security'),
        ),
        page: TokenSecurityTab(api: _api, capabilities: capabilities),
      ),
      if (navigation.supportsUsageAnalytics)
        AdminNavigationEntry(
          module: AdminModuleId.usageAnalytics,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.insights_outlined),
            label: Text('Usage insights'),
          ),
          page: UsageAnalyticsTab(api: _api, capabilities: capabilities),
        ),
      AdminNavigationEntry(
        module: AdminModuleId.tenants,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.business),
          label: Text(strings.tenants),
        ),
        page: TenantsTab(client: widget.client),
      ),
      if (navigation.supportsOrganizations)
        AdminNavigationEntry(
          module: AdminModuleId.organizations,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.groups_outlined),
            label: Text('Organizations'),
          ),
          page: TenantOrganizationsTab(api: _api, capabilities: capabilities),
        ),
      AdminNavigationEntry(
        module: AdminModuleId.operations,
        destination: const NavigationRailDestination(
          icon: Icon(Icons.terminal_outlined),
          label: Text('Operations'),
        ),
        page: AdminOperationsTab(api: _api, endpoints: _endpoints),
      ),
      if (navigation.supportsCryptoKeys)
        AdminNavigationEntry(
          module: AdminModuleId.cryptoKeys,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.vpn_key_outlined),
            label: Text('Crypto keys'),
          ),
          page: CryptoKeysTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsCredentials)
        AdminNavigationEntry(
          module: AdminModuleId.credentials,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.verified_user_outlined),
            label: Text('Credentials'),
          ),
          page: CredentialsTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsTokenPolicies)
        AdminNavigationEntry(
          module: AdminModuleId.tokenPolicies,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.policy_outlined),
            label: Text('Token policies'),
          ),
          page: TokenPoliciesTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsTokenExchange)
        AdminNavigationEntry(
          module: AdminModuleId.tokenExchange,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            label: Text('Token exchange'),
          ),
          page: TokenExchangeTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsAuthzChecks)
        AdminNavigationEntry(
          module: AdminModuleId.authzChecks,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.verified_outlined),
            label: Text('Authz checks'),
          ),
          page: AuthzCheckTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsDomains)
        AdminNavigationEntry(
          module: AdminModuleId.domains,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.language_outlined),
            label: Text('Domains'),
          ),
          page: DomainsTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsNetworkPolicies)
        AdminNavigationEntry(
          module: AdminModuleId.networkPolicies,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.lan_outlined),
            label: Text('Network policies'),
          ),
          page: NetworkPoliciesTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsAccessPolicies)
        AdminNavigationEntry(
          module: AdminModuleId.accessPolicies,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.verified_user_outlined),
            label: Text('Access policies'),
          ),
          page: AccessPoliciesTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsDrMode)
        AdminNavigationEntry(
          module: AdminModuleId.drMode,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            label: Text('DR mode'),
          ),
          page: DRModeTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsThreatPolicies)
        AdminNavigationEntry(
          module: AdminModuleId.threatPolicies,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.warning_amber_outlined),
            label: Text('Threat policies'),
          ),
          page: ThreatPoliciesTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsWebhooks)
        AdminNavigationEntry(
          module: AdminModuleId.webhooks,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.webhook_outlined),
            label: Text('Webhooks'),
          ),
          page: WebhooksTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsEmergencyAccess)
        AdminNavigationEntry(
          module: AdminModuleId.emergencyAccess,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.emergency_outlined),
            label: Text('Emergency access'),
          ),
          page: BreakGlassTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsChangeApprovals)
        AdminNavigationEntry(
          module: AdminModuleId.changeApprovals,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.approval_outlined),
            label: Text('Change approvals'),
          ),
          page: ChangeApprovalsTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsRecoveryReleases)
        AdminNavigationEntry(
          module: AdminModuleId.recoveryReleases,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.settings_backup_restore_outlined),
            label: Text('Recovery & releases'),
          ),
          page: RecoveryReleasesTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsPrivacyCompliance)
        AdminNavigationEntry(
          module: AdminModuleId.privacyCompliance,
          destination: const NavigationRailDestination(
            icon: Icon(Icons.privacy_tip_outlined),
            label: Text('Privacy & retention'),
          ),
          page: PrivacyComplianceTab(api: _api, capabilities: capabilities),
        ),
      AdminNavigationEntry(
        module: AdminModuleId.governance,
        destination: const NavigationRailDestination(
          icon: Icon(Icons.verified_user_outlined),
          label: Text('Governance'),
        ),
        page: GovernanceTab(api: _api, capabilities: capabilities),
      ),
      const AdminNavigationEntry(
        module: AdminModuleId.auditLog,
        destination: NavigationRailDestination(
          icon: Icon(Icons.receipt_long_outlined),
          label: Text('Audit Log'),
        ),
        page: AuditLogTab(),
      ),
      AdminNavigationEntry(
        module: AdminModuleId.health,
        destination: const NavigationRailDestination(
          icon: Icon(Icons.monitor_heart_outlined),
          label: Text('Health'),
        ),
        page: HealthTab(api: _api),
      ),
    ];
    _visibleModules = adminNavigationModules(entries);
    final selectedIndex = adminNavigationIndexForModule(
      entries,
      _selectedModule,
    );
    Widget page;
    final route = _currentRoute;
    final rid = route.resourceId;
    if (rid.isNotEmpty) {
      final detail = <String, WidgetBuilder>{
        AdminModuleId.users: (_) =>
            UserDetailScreen(api: _api, client: widget.client, userId: rid),
        AdminModuleId.clients: (_) =>
            ClientDetailScreen(api: _api, client: widget.client, clientId: rid),
        AdminModuleId.tenants: (_) =>
            TenantDetailScreen(api: _api, client: widget.client, tenantId: rid),
        AdminModuleId.connections: (_) => ConnectionDetailScreen(
          api: _api,
          client: widget.client,
          connectionId: rid,
        ),
        AdminModuleId.emergencyAccess: (_) =>
            BreakGlassDetailScreen(api: _api, sessionId: rid),
        AdminModuleId.permissions: (_) => PermissionDetailScreen(
          api: _api,
          client: widget.client,
          clientId: rid,
        ),
        AdminModuleId.webhooks: (_) =>
            WebhookDetailScreen(api: _api, client: widget.client, subId: rid),
      };
      final builder = detail[route.module];
      if (builder != null) {
        page = ErrorBoundary(
          key: ValueKey(route.detailIdentity),
          child: builder(context),
        );
      } else {
        page = ErrorBoundary(child: entries[selectedIndex].page);
      }
    } else {
      page = ErrorBoundary(child: entries[selectedIndex].page);
    }
    final destinations = entries
        .map((entry) => entry.destination)
        .toList(growable: false);
    return ResponsiveNavigationScaffold(
      selectedIndex: selectedIndex,
      onDestinationSelected: (index) {
        final module = adminNavigationModuleAt(entries, index);
        if (module == null) return;
        final destinationRoute = AdminRoute(module: module);
        if (_currentRoute == destinationRoute) return;
        // The URL is the source of truth. BrowserNavigation's location-change
        // notification performs the single state update for both rail and
        // drawer navigation.
        AdminRoute.go(module);
      },
      destinations: destinations,
      drawerHeader: 'SSO administration',
      body: page,
      appBar: AppBar(
        title: const Text('SSO Admin'),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const SettingsScreen())),
            icon: const Icon(Icons.settings),
            tooltip: strings.settings,
          ),
          IconButton(
            onPressed: _logout,
            icon: const Icon(Icons.logout),
            tooltip: strings.logout,
          ),
          const SizedBox(width: 8),
        ],
      ),
    );
  }
}
