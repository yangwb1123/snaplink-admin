import 'package:flutter/material.dart';
import '../../i18n/app_strings.dart';
import '../../i18n/localized_text.dart';
import 'admin_route.dart';
import '../../session.dart';
import '../../sso_client.dart';
import '../settings_screen.dart';
import 'package:sso_admin/widgets/brand_logo.dart';
import 'package:sso_admin/widgets/page_transition.dart';
import 'admin_module_groups.dart';
import 'package:sso_admin/widgets/section_selector.dart';
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
import 'commerce/commerce_tab.dart';
import 'commerce/commerce_api.dart';

class DashboardScreen extends StatefulWidget {
  final SSOAdminClient client;
  const DashboardScreen({super.key, required this.client});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _selectedModule = AdminModuleId.overview;
  AdminRoute _currentRoute = const AdminRoute(module: AdminModuleId.overview);

  /// 每组最后访问的模块（切组回来记住位置，Linear/Supabase 行为）。
  final Map<String, String> _groupLastModule = <String, String>{};
  List<String> _visibleModules = const [
    AdminModuleId.overview,
    AdminModuleId.clients,
    AdminModuleId.users,
  ];
  late final SnaplinkAdminApi _api;
  List<SnaplinkAdminEndpoint> _endpoints = const [];
  Object? _capabilitiesError;
  bool _commerceAvailable = false;
  Object? _commerceProbeError;
  late final void Function() _cancelLocationChange;

  @override
  void initState() {
    super.initState();
    _api = SnaplinkAdminApi(
      baseUrl: widget.client.baseUrl,
      accessToken: Session.read() ?? '',
      onUnauthorized: _localLogout,
    );
    _currentRoute = AdminRoute.current();
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
    final nextRoute = AdminRoute.current();
    if (nextRoute == _currentRoute) return;
    setState(() {
      _currentRoute = nextRoute;
      _selectedModule = nextRoute.module;
    });
  }

  Future<void> _refreshCapabilities() async {
    setState(() => _capabilitiesError = null);
    final commerceProbe = _probeCommerce();
    try {
      final endpoints = await _api.listEndpoints();
      if (!mounted) return;
      setState(() {
        _endpoints = endpoints;
      });
    } catch (error) {
      if (mounted) setState(() => _capabilitiesError = error);
    }
    await commerceProbe;
  }

  Future<void> _probeCommerce() async {
    try {
      await _api.get('/api/v1/admin/commerce/plans', forceRefresh: true);
      if (mounted) {
        setState(() {
          _commerceAvailable = true;
          _commerceProbeError = null;
        });
      }
    } on SnaplinkAdminApiError catch (error) {
      if (!mounted) return;
      final unavailable =
          commerceProbeState(error) == CommerceProbeState.unavailable;
      setState(() {
        _commerceAvailable = !unavailable;
        _commerceProbeError = unavailable ? null : error;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _commerceAvailable = true;
          _commerceProbeError = error;
        });
      }
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

  Map<String, String> _moduleLabels(
    List<AdminNavigationEntry<NavigationRailDestination, Widget>> entries,
  ) => {
    for (final entry in entries) entry.module: _labelOf(entry.destination.label),
  };

  String _labelOf(Widget label) {
    if (label is Text) return label.data ?? '';
    if (label is LocalizedText) return label.data;
    return '';
  }

  IconData _iconOf(
    String module,
    List<AdminNavigationEntry<NavigationRailDestination, Widget>> entries,
  ) {
    for (final entry in entries) {
      if (entry.module != module) continue;
      final icon = entry.destination.icon;
      if (icon is Icon) return icon.icon ?? Icons.circle_outlined;
    }
    return Icons.circle_outlined;
  }

  Widget _buildBody(BuildContext context, AppStrings strings) {
    final navigation = AdminNavigationCapabilities(_endpoints);
    final capabilities = navigation.capabilities;
    final entries = <AdminNavigationEntry<NavigationRailDestination, Widget>>[
      AdminNavigationEntry(
        module: AdminModuleId.overview,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.dashboard_outlined),
          selectedIcon: const Icon(Icons.dashboard),
          label: Text(strings.overview),
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
          destination: NavigationRailDestination(
            icon: const Icon(Icons.password_outlined),
            selectedIcon: const Icon(Icons.password),
            label: Text(strings.localUsers),
          ),
          page: LocalUsersTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsScimDirectory)
        AdminNavigationEntry(
          module: AdminModuleId.scimDirectory,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.account_tree_outlined),
            selectedIcon: const Icon(Icons.account_tree),
            label: Text(strings.scimDirectory),
          ),
          page: ScimDirectoryTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsPermissions)
        AdminNavigationEntry(
          module: AdminModuleId.permissions,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.admin_panel_settings_outlined),
            selectedIcon: const Icon(Icons.admin_panel_settings),
            label: Text(strings.permissions),
          ),
          page: PermissionsTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsConnections)
        AdminNavigationEntry(
          module: AdminModuleId.connections,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.hub_outlined),
            selectedIcon: const Icon(Icons.hub),
            label: Text(strings.connections),
          ),
          page: ConnectionsTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsUserSupport)
        AdminNavigationEntry(
          module: AdminModuleId.userSupport,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.support_agent_outlined),
            selectedIcon: const Icon(Icons.support_agent),
            label: Text(strings.userSupport),
          ),
          page: UserSupportTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsDeviceSecurity)
        AdminNavigationEntry(
          module: AdminModuleId.deviceSecurity,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.devices_other_outlined),
            selectedIcon: const Icon(Icons.devices_other),
            label: Text(strings.deviceSecurity),
          ),
          page: DeviceSecurityTab(api: _api),
        ),
      AdminNavigationEntry(
        module: AdminModuleId.liveActivity,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.sensors_outlined),
          selectedIcon: const Icon(Icons.sensors),
          label: Text(strings.liveActivity),
        ),
        page: AdminLiveEventsTab(api: _api, endpoints: _endpoints),
      ),
      AdminNavigationEntry(
        module: AdminModuleId.tokenSecurity,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.shield_outlined),
          selectedIcon: const Icon(Icons.shield),
          label: Text(strings.tokenSecurity),
        ),
        page: TokenSecurityTab(api: _api, capabilities: capabilities),
      ),
      if (navigation.supportsUsageAnalytics)
        AdminNavigationEntry(
          module: AdminModuleId.usageAnalytics,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.insights_outlined),
            selectedIcon: const Icon(Icons.insights),
            label: Text(strings.usageInsights),
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
      if (_commerceAvailable)
        AdminNavigationEntry(
          module: AdminModuleId.commerce,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.payments_outlined),
            selectedIcon: const Icon(Icons.payments),
            label: const LocalizedText('Subscriptions & Billing'),
          ),
          page: CommerceTab(api: _api, availabilityError: _commerceProbeError),
        ),
      if (navigation.supportsOrganizations)
        AdminNavigationEntry(
          module: AdminModuleId.organizations,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.groups_outlined),
            selectedIcon: const Icon(Icons.groups),
            label: Text(strings.organizations),
          ),
          page: TenantOrganizationsTab(api: _api, capabilities: capabilities),
        ),
      AdminNavigationEntry(
        module: AdminModuleId.operations,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.terminal_outlined),
          selectedIcon: const Icon(Icons.terminal),
          label: Text(strings.operations),
        ),
        page: AdminOperationsTab(api: _api, endpoints: _endpoints),
      ),
      if (navigation.supportsCryptoKeys)
        AdminNavigationEntry(
          module: AdminModuleId.cryptoKeys,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.vpn_key_outlined),
            selectedIcon: const Icon(Icons.vpn_key),
            label: Text(strings.cryptoKeys),
          ),
          page: CryptoKeysTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsCredentials)
        AdminNavigationEntry(
          module: AdminModuleId.credentials,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.verified_user_outlined),
            selectedIcon: const Icon(Icons.verified_user),
            label: Text(strings.credentials),
          ),
          page: CredentialsTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsTokenPolicies)
        AdminNavigationEntry(
          module: AdminModuleId.tokenPolicies,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.policy_outlined),
            selectedIcon: const Icon(Icons.policy),
            label: Text(strings.tokenPolicies),
          ),
          page: TokenPoliciesTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsTokenExchange)
        AdminNavigationEntry(
          module: AdminModuleId.tokenExchange,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.swap_horiz_outlined),
            selectedIcon: const Icon(Icons.swap_horiz),
            label: Text(strings.tokenExchange),
          ),
          page: TokenExchangeTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsAuthzChecks)
        AdminNavigationEntry(
          module: AdminModuleId.authzChecks,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.verified_outlined),
            selectedIcon: const Icon(Icons.verified),
            label: Text(strings.authzChecks),
          ),
          page: AuthzCheckTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsDomains)
        AdminNavigationEntry(
          module: AdminModuleId.domains,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.language_outlined),
            selectedIcon: const Icon(Icons.language),
            label: Text(strings.domains),
          ),
          page: DomainsTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsNetworkPolicies)
        AdminNavigationEntry(
          module: AdminModuleId.networkPolicies,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.lan_outlined),
            selectedIcon: const Icon(Icons.lan),
            label: Text(strings.networkPolicies),
          ),
          page: NetworkPoliciesTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsAccessPolicies)
        AdminNavigationEntry(
          module: AdminModuleId.accessPolicies,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.verified_user_outlined),
            selectedIcon: const Icon(Icons.verified_user),
            label: Text(strings.accessPolicies),
          ),
          page: AccessPoliciesTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsDrMode)
        AdminNavigationEntry(
          module: AdminModuleId.drMode,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.monitor_heart_outlined),
            selectedIcon: const Icon(Icons.monitor_heart),
            label: Text(strings.drMode),
          ),
          page: DRModeTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsThreatPolicies)
        AdminNavigationEntry(
          module: AdminModuleId.threatPolicies,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.warning_amber_outlined),
            selectedIcon: const Icon(Icons.warning_amber),
            label: Text(strings.threatPolicies),
          ),
          page: ThreatPoliciesTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsWebhooks)
        AdminNavigationEntry(
          module: AdminModuleId.webhooks,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.webhook_outlined),
            selectedIcon: const Icon(Icons.webhook),
            label: Text(strings.webhooks),
          ),
          page: WebhooksTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsEmergencyAccess)
        AdminNavigationEntry(
          module: AdminModuleId.emergencyAccess,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.emergency_outlined),
            selectedIcon: const Icon(Icons.emergency),
            label: Text(strings.emergencyAccess),
          ),
          page: BreakGlassTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsChangeApprovals)
        AdminNavigationEntry(
          module: AdminModuleId.changeApprovals,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.approval_outlined),
            selectedIcon: const Icon(Icons.approval),
            label: Text(strings.changeApprovals),
          ),
          page: ChangeApprovalsTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsRecoveryReleases)
        AdminNavigationEntry(
          module: AdminModuleId.recoveryReleases,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.settings_backup_restore_outlined),
            selectedIcon: const Icon(Icons.settings_backup_restore),
            label: Text(strings.recoveryReleases),
          ),
          page: RecoveryReleasesTab(api: _api, capabilities: capabilities),
        ),
      if (navigation.supportsPrivacyCompliance)
        AdminNavigationEntry(
          module: AdminModuleId.privacyCompliance,
          destination: NavigationRailDestination(
            icon: const Icon(Icons.privacy_tip_outlined),
            selectedIcon: const Icon(Icons.privacy_tip),
            label: Text(strings.privacyRetention),
          ),
          page: PrivacyComplianceTab(api: _api, capabilities: capabilities),
        ),
      AdminNavigationEntry(
        module: AdminModuleId.governance,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.verified_user_outlined),
          selectedIcon: const Icon(Icons.verified_user),
          label: Text(strings.governance),
        ),
        page: GovernanceTab(api: _api, capabilities: capabilities),
      ),
      AdminNavigationEntry(
        module: AdminModuleId.auditLog,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.receipt_long_outlined),
          selectedIcon: const Icon(Icons.receipt_long),
          label: Text(strings.auditLog),
        ),
        page: AuditLogTab(api: _api),
      ),
      AdminNavigationEntry(
        module: AdminModuleId.health,
        destination: NavigationRailDestination(
          icon: const Icon(Icons.monitor_heart_outlined),
          selectedIcon: const Icon(Icons.monitor_heart),
          label: Text(strings.health),
        ),
        page: HealthTab(api: _api),
      ),
    ];
    _visibleModules = adminNavigationModules(entries);
    Widget page;
    final route = _currentRoute;
    final rid = route.resourceId;
    if (rid.isNotEmpty) {
      final detail = <String, WidgetBuilder>{
        AdminModuleId.users: (_) => UserDetailScreen(
          api: _api,
          client: widget.client,
          userId: rid,
          capabilities: capabilities,
        ),
        AdminModuleId.clients: (_) =>
            ClientDetailScreen(api: _api, client: widget.client, clientId: rid),
        AdminModuleId.tenants: (_) => TenantDetailScreen(
          api: _api,
          client: widget.client,
          tenantId: rid,
          capabilities: capabilities,
        ),
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
        page = ErrorBoundary(
          child: entries[adminNavigationIndexForModule(entries, _selectedModule)]
              .page,
        );
      }
    } else {
      page = ErrorBoundary(
        child: entries[adminNavigationIndexForModule(entries, _selectedModule)]
            .page,
      );
    }
    // 一级导航 = 分组（≤6）；组内模块用壳层 SectionSelector 切换。
    final visibleGroups = [
      for (final group in adminModuleGroups)
        if (adminGroupVisibleModules(group, _visibleModules).isNotEmpty) group,
    ];
    final currentGroupId = adminGroupForModule(_selectedModule);
    var selectedGroupIndex = visibleGroups.indexWhere(
      (group) => group.id == currentGroupId,
    );
    if (selectedGroupIndex < 0) selectedGroupIndex = 0;
    final groupDestinations = [
      for (final group in visibleGroups)
        NavigationRailDestination(
          icon: Icon(group.icon),
          selectedIcon: Icon(group.selectedIcon),
          label: adminGroupLabel(group),
        ),
    ];
    final groupModules = adminGroupVisibleModules(
      visibleGroups[selectedGroupIndex],
      _visibleModules,
    );
    final moduleLabels = _moduleLabels(entries);
    final sectionDefs = [
      for (final module in groupModules)
        SectionDef(
          module,
          moduleLabels[module] ?? module,
          _iconOf(module, entries),
        ),
    ];
    return ResponsiveNavigationScaffold(
      selectedIndex: selectedGroupIndex,
      onDestinationSelected: (index) {
        if (index < 0 || index >= visibleGroups.length) return;
        final group = visibleGroups[index];
        var module = _groupLastModule[group.id];
        final visible = adminGroupVisibleModules(group, _visibleModules);
        if (module == null || !visible.contains(module)) {
          module = visible.isEmpty ? null : visible.first;
        }
        if (module == null) return;
        final destinationRoute = AdminRoute(module: module);
        if (_currentRoute == destinationRoute) return;
        // The URL is the source of truth. BrowserNavigation's location-change
        // notification performs the single state update for both rail and
        // drawer navigation.
        AdminRoute.go(module);
      },
      destinations: groupDestinations,
      drawerHeader: strings.ssoAdmin,
      body: PageTransition(
        pageKey: ValueKey(_selectedModule),
        child: page,
      ),
      appBar: AppBar(
        // 左上角：品牌 logo 图片（渐变盾牌）；点击开抽屉（窄视口）。
        leading: Padding(
          padding: const EdgeInsets.only(left: 8),
          child: BrandLogo(
            onTap: () {
              final scaffold = Scaffold.of(context);
              if (scaffold.hasDrawer) scaffold.openDrawer();
            },
          ),
        ),
        // 子菜单与设置/登出同一行，靠左（AppBar title 区）。
        titleSpacing: 8,
        title: groupModules.length > 1
            ? Padding(
                padding: const EdgeInsets.only(right: 8),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: SectionSelector(
                    sections: sectionDefs,
                    current: _selectedModule,
                    onSelected: (module) {
                      if (module == _selectedModule) return;
                      _groupLastModule[currentGroupId] = module;
                      AdminRoute.go(module);
                    },
                  ),
                ),
              )
            : null,
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
