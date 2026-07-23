import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../i18n/app_strings.dart';
import '../../session.dart';
import '../../sso_client.dart';
import '../settings_screen.dart';
import 'admin_overview_tab.dart';
import 'admin_live_events_tab.dart';
import 'admin_operations_tab.dart';
import 'clients_tab.dart';
import 'connections_tab.dart';
import 'governance_tab.dart';
import 'permissions_tab.dart';
import 'snaplink_admin_api.dart';
import 'tenant_organizations_tab.dart';
import 'token_security_tab.dart';
import 'user_support_tab.dart';
import 'users_tab.dart';
import 'tenants_tab.dart';

class DashboardScreen extends StatefulWidget {
  final SSOAdminClient client;
  const DashboardScreen({super.key, required this.client});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  late final SnaplinkAdminApi _api;
  List<SnaplinkAdminEndpoint> _endpoints = const [];
  Object? _capabilitiesError;

  @override
  void initState() {
    super.initState();
    _api = SnaplinkAdminApi(
      baseUrl: widget.client.baseUrl,
      accessToken: Session.read() ?? '',
      onUnauthorized: _localLogout,
    );
    _refreshCapabilities();
  }

  Future<void> _refreshCapabilities() async {
    setState(() => _capabilitiesError = null);
    try {
      final endpoints = await _api.listEndpoints();
      if (!mounted) return;
      setState(() {
        _endpoints = endpoints;
        if (_index > _destinationCount - 1) _index = 0;
      });
    } catch (error) {
      if (mounted) setState(() => _capabilitiesError = error);
    }
  }

  bool get _supportsOrganizations {
    final capabilities = SnaplinkAdminCapabilities(_endpoints);
    return capabilities.hasAnyPathPrefix('/api/v1/admin/tenants/:id/members') ||
        capabilities.hasAnyPathPrefix(
          '/api/v1/admin/tenants/:id/invitations',
        ) ||
        capabilities.hasAnyPathPrefix('/api/v1/admin/tenants/:id/export') ||
        SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(
          '/api/v1/admin/tenants/:id/members',
        );
  }

  bool get _supportsUserSupport => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/users/:id');

  bool get _supportsPermissions {
    final capabilities = SnaplinkAdminCapabilities(_endpoints);
    return capabilities.has('GET', '/api/v1/admin/authz/policy-bundle') ||
        capabilities.hasAnyPathPrefix('/api/v1/admin/permissions/');
  }

  bool get _supportsConnections => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/connections');

  // Current Snaplink inventories report only a representative subset of the
  // gRPC-gateway governance routes. Keep the dedicated page reachable and let
  // its documented, route-level requests report disabled optional features.
  bool get _supportsGovernance => true;

  int get _destinationCount =>
      7 +
      (_supportsUserSupport ? 1 : 0) +
      (_supportsOrganizations ? 1 : 0) +
      (_supportsPermissions ? 1 : 0) +
      (_supportsConnections ? 1 : 0) +
      (_supportsGovernance ? 1 : 0);

  void _localLogout() {
    widget.client.logout();
    Session.clear();
    // A real navigation, not Navigator — matches every other transition in
    // this auth flow, and guarantees no stale in-memory state survives.
    web.window.location.href = '/login/';
  }

  Future<void> _logout() async {
    try {
      await _api.post('/api/v1/admin/logout');
    } catch (_) {
      // Local cleanup still protects the browser session when this deployment
      // does not wire Snaplink's optional AdminTokenStore.
    }
    _localLogout();
  }

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final capabilities = SnaplinkAdminCapabilities(_endpoints);
    final entries = <(NavigationRailDestination, Widget)>[
      (
        const NavigationRailDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: Text('Overview'),
        ),
        AdminOverviewTab(
          endpoints: _endpoints,
          loadError: _capabilitiesError,
          onRefresh: _refreshCapabilities,
        ),
      ),
      (
        NavigationRailDestination(
          icon: const Icon(Icons.apps),
          label: Text(strings.clients),
        ),
        ClientsTab(client: widget.client),
      ),
      (
        NavigationRailDestination(
          icon: const Icon(Icons.people),
          label: Text(strings.users),
        ),
        UsersTab(client: widget.client),
      ),
      if (_supportsPermissions)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.admin_panel_settings_outlined),
            label: Text('Permissions'),
          ),
          PermissionsTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsConnections)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.hub_outlined),
            label: Text('Connections'),
          ),
          ConnectionsTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsUserSupport)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.support_agent_outlined),
            label: Text('User support'),
          ),
          UserSupportTab(api: _api, capabilities: capabilities),
        ),
      (
        const NavigationRailDestination(
          icon: Icon(Icons.sensors_outlined),
          label: Text('Live activity'),
        ),
        AdminLiveEventsTab(api: _api, endpoints: _endpoints),
      ),
      (
        const NavigationRailDestination(
          icon: Icon(Icons.shield_outlined),
          label: Text('Token security'),
        ),
        TokenSecurityTab(api: _api, capabilities: capabilities),
      ),
      (
        NavigationRailDestination(
          icon: const Icon(Icons.business),
          label: Text(strings.tenants),
        ),
        TenantsTab(client: widget.client),
      ),
      if (_supportsOrganizations)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.groups_outlined),
            label: Text('Organizations'),
          ),
          TenantOrganizationsTab(api: _api, capabilities: capabilities),
        ),
      (
        const NavigationRailDestination(
          icon: Icon(Icons.terminal_outlined),
          label: Text('Operations'),
        ),
        AdminOperationsTab(api: _api, endpoints: _endpoints),
      ),
      if (_supportsGovernance)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.verified_user_outlined),
            label: Text('Governance'),
          ),
          GovernanceTab(api: _api, capabilities: capabilities),
        ),
    ];
    final selectedIndex = _index.clamp(0, entries.length - 1);
    final page = entries[selectedIndex].$2;
    return Scaffold(
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
      body: Row(
        children: [
          NavigationRail(
            selectedIndex: selectedIndex,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            destinations: entries
                .map((entry) => entry.$1)
                .toList(growable: false),
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ],
      ),
    );
  }
}
