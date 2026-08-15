import 'package:flutter/material.dart';
import '../../app_settings.dart';
import '../../i18n/app_strings.dart';
import '../../session.dart';
import '../../sso_client.dart';
import '../settings_screen.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/services/shortcut_service.dart';
import 'package:sso_admin/widgets/brand_logo.dart';
import 'package:sso_admin/widgets/command_palette.dart';
import 'package:sso_admin/widgets/offline_banner.dart';
import 'package:sso_admin/widgets/page_transition.dart';
import 'package:sso_admin/widgets/responsive_navigation_scaffold.dart';
import 'package:sso_admin/widgets/section_selector.dart';
import 'package:sso_admin/widgets/shortcuts_dialog.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_overview_tab.dart';
import 'admin_route.dart';
import 'audit_log_tab.dart';
import 'clients_tab.dart';
import 'commerce/commerce_api.dart';
import 'dashboard_navigation_entries.dart';
import 'dashboard_page_resolution.dart';
import 'snaplink_admin_api.dart';
import 'tenants_tab.dart';
import 'users_tab.dart';

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

  Widget _buildBody(BuildContext context, AppStrings strings) {
    // Capability gating + locale-sensitive navigation entries (rail
    // destinations and page widgets) are constructed in one pure pass;
    // the mode filter and operator persona run below on the resulting list.
    final navigation = buildDashboardNavigationEntries(
      client: widget.client,
      api: _api,
      endpoints: _endpoints,
      capabilitiesError: _capabilitiesError,
      onRefresh: _refreshCapabilities,
      strings: strings,
      commerceAvailable: _commerceAvailable,
      commerceProbeError: _commerceProbeError,
    );
    final entries = navigation.entries;
    final capabilities = navigation.capabilities;
    // Admin navigation mode (settings): normal shows only the core trio;
    // professional shows EVERY capability-enabled module and submenu.
    // Capability gating above runs FIRST — a capability-gated-off module is absent from entries and
    // therefore invisible in both modes. entries itself is never mutated,
    // so deep links and page resolution stay intact.
    _visibleModules = adminNavigationModules(entries);
    _visibleModules = AdminHotModules.visibleForMode(
      _visibleModules,
      AppSettings.instance.adminNavMode,
    );
    // Operator persona: derived purely from the POST-GATING module set and
    // the commerce probe (design §3.3). Never reads the token; only
    // emphasizes, never gates.
    final persona = deriveOperatorPersona(
      enabledModules: _visibleModules.toSet(),
      commerceAvailable: _commerceProbeError == null,
    );
    // The wave-1 entries were constructed with their default (general)
    // persona; rebind them in place now that the persona exists
    // (module/destination preserved — rail order and nav pins untouched).
    void rebindPersona(
      String module,
      Widget Function(OperatorPersona) buildPage,
    ) {
      final i = entries.indexWhere((e) => e.module == module);
      if (i < 0) return;
      entries[i] = AdminNavigationEntry(
        module: entries[i].module,
        destination: entries[i].destination,
        page: buildPage(persona),
      );
    }

    rebindPersona(
      AdminModuleId.overview,
      (p) => AdminOverviewTab(
        endpoints: _endpoints,
        loadError: _capabilitiesError,
        onRefresh: _refreshCapabilities,
        persona: p,
        commerceAvailable: _commerceAvailable,
        commerceProbeError: _commerceProbeError,
      ),
    );
    rebindPersona(
      AdminModuleId.clients,
      (p) => ClientsTab(client: widget.client, persona: p),
    );
    rebindPersona(
      AdminModuleId.users,
      (p) => UsersTab(client: widget.client, persona: p),
    );
    rebindPersona(
      AdminModuleId.tenants,
      (p) => TenantsTab(client: widget.client, persona: p),
    );
    rebindPersona(
      AdminModuleId.auditLog,
      (p) => AuditLogTab(api: _api, capabilities: capabilities, persona: p),
    );
    final page = resolveDashboardPage(
      route: _currentRoute,
      entries: entries,
      selectedModule: _selectedModule,
      api: _api,
      client: widget.client,
      capabilities: capabilities,
      persona: persona,
    );
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
          icon: Icon(group.icon, color: group.iconColor),
          selectedIcon: Icon(group.selectedIcon, color: group.iconColor),
          label: adminGroupLabel(group),
        ),
    ];
    final groupModules = adminGroupVisibleModules(
      visibleGroups[selectedGroupIndex],
      _visibleModules,
    );
    final moduleLabels = dashboardModuleLabels(entries);
    final sectionDefs = [
      for (final module in groupModules)
        SectionDef(
          module,
          moduleLabels[module] ?? module,
          dashboardModuleIcon(module, entries),
          color: adminModuleIconColor(module),
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
      body: PageTransition(pageKey: ValueKey(_selectedModule), child: page),
      appBar: AppBar(
        // 左上角：品牌 logo 图片（渐变盾牌）；点击开抽屉（窄视口）。
        // leadingWidth = NavigationRail 宽度（80）：logo 中心与侧边栏
        // 图标中心同一条垂直对齐线；左缘与 rail 左缘同线。
        leadingWidth: 80,
        leading: Center(
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
            ? ConstrainedBox(
                // 首次布局即给 bounded 宽度（NavigationToolbar 首帧以无界
                // 测量 title，SCSV 会取内容全宽导致子菜单文字超出屏幕；
                // 二次布局才修正——这里提前固定上限消除闪动）。
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width - 190,
                ),
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
