import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import '../../i18n/app_strings.dart';
import 'admin_route.dart';
import '../../session.dart';
import '../../sso_client.dart';
import '../settings_screen.dart';
import 'package:sso_admin/widgets/offline_banner.dart';
import 'admin_overview_tab.dart';
import 'admin_live_events_tab.dart';
import 'admin_operations_tab.dart';
import 'client_detail_screen.dart';
import 'clients_tab.dart';
import 'connection_detail_screen.dart';
import 'connections_tab.dart';
import 'audit_log_tab.dart';
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
class DashboardScreen extends StatefulWidget {
  final SSOAdminClient client;
  const DashboardScreen({super.key, required this.client});
  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}
class _DashboardScreenState extends State<DashboardScreen> {
  int _index = 0;
  late final SnaplinkAdminApi _api;
  static const _tabNames = [
    '', 'clients', 'users', 'permissions', 'connections',
    'user-support', 'live-activity', 'token-security', 'tenants',
    'organizations', 'operations', 'crypto-keys', 'credentials',
    'token-policies', 'token-exchange', 'authz-checks', 'domains',
    'access-policies', 'dr-mode', 'threat-policies', 'webhooks',
    'emergency-access', 'governance', 'audit-log',
  ];
  int _indexFromPath() {
    final route = AdminRoute.fromUri(Uri.base);
    final idx = _tabNames.indexOf(route.module);
    return idx >= 0 ? idx : 0;
  }
  void _navigateToTab(int index) {
    if (index >= 0 && index < _tabNames.length) {
      AdminRoute.go(_tabNames[index]);
    }
  }
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
    _index = _indexFromPath();
    _refreshCapabilities();
    void popListener() {
      if (mounted) setState(() { _index = _indexFromPath(); });
    }
    web.window.addEventListener('popstate', popListener.toJS);
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
  bool get _supportsTokenPolicies => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/token-policies');
  bool get _supportsTokenExchange => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/tokenexchange');
  bool get _supportsAuthzCheck => SnaplinkAdminCapabilities(
    _endpoints,
  ).has('POST', '/api/v1/admin/rebac/check') ||
      SnaplinkAdminCapabilities(_endpoints).has('POST', '/api/v1/admin/wasmauthz/check');
  bool get _supportsDomains => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/domains');
  bool get _supportsAccessPolicies => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/access-policies');
  bool get _supportsDRMode => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/dr/mode');
  bool get _supportsThreatPolicies => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/threat-policies');
  bool get _supportsCryptoKeys => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/crypto/keys');
  bool get _supportsCredentials => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/credentials');
  bool get _supportsWebhooks => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/webhooks/subscriptions');
  bool get _supportsBreakGlass => SnaplinkAdminCapabilities(
    _endpoints,
  ).hasAnyPathPrefix('/api/v1/admin/break-glass');
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
  bool get _supportsGovernance => true;
  int get _destinationCount =>
      8 +
      (_supportsUserSupport ? 1 : 0) +
      (_supportsOrganizations ? 1 : 0) +
      (_supportsPermissions ? 1 : 0) +
      (_supportsConnections ? 1 : 0) +
      (_supportsGovernance ? 1 : 0) +
      (_supportsBreakGlass ? 1 : 0) +
      (_supportsCryptoKeys ? 1 : 0) +
      (_supportsCredentials ? 1 : 0) +
      (_supportsWebhooks ? 1 : 0) +
      (_supportsThreatPolicies ? 1 : 0) +
      (_supportsDomains ? 1 : 0) +
      (_supportsAccessPolicies ? 1 : 0) +
      (_supportsDRMode ? 1 : 0) +
      (_supportsTokenPolicies ? 1 : 0) +
      (_supportsTokenExchange ? 1 : 0) +
      (_supportsAuthzCheck ? 1 : 0);
  void _localLogout() {
    widget.client.logout();
    Session.clear();
    web.window.location.href = '/login/';
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
      if (_supportsCryptoKeys)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.vpn_key_outlined),
            label: Text('Crypto keys'),
          ),
          CryptoKeysTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsCredentials)
        (
          NavigationRailDestination(
            icon: const Icon(Icons.verified_user_outlined),
            label: const Text('Credentials'),
          ),
          CredentialsTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsTokenPolicies)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.policy_outlined),
            label: Text('Token policies'),
          ),
          TokenPoliciesTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsTokenExchange)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.swap_horiz_outlined),
            label: Text('Token exchange'),
          ),
          TokenExchangeTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsAuthzCheck)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.verified_outlined),
            label: Text('Authz checks'),
          ),
          AuthzCheckTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsDomains)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.language_outlined),
            label: Text('Domains'),
          ),
          DomainsTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsAccessPolicies)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.verified_user_outlined),
            label: Text('Access policies'),
          ),
          AccessPoliciesTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsDRMode)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.monitor_heart_outlined),
            label: Text('DR mode'),
          ),
          DRModeTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsThreatPolicies)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.warning_amber_outlined),
            label: Text('Threat policies'),
          ),
          ThreatPoliciesTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsWebhooks)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.webhook_outlined),
            label: Text('Webhooks'),
          ),
          WebhooksTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsBreakGlass)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.emergency_outlined),
            label: Text('Emergency access'),
          ),
          BreakGlassTab(api: _api, capabilities: capabilities),
        ),
      if (_supportsGovernance)
        (
          const NavigationRailDestination(
            icon: Icon(Icons.verified_user_outlined),
            label: Text('Governance'),
          ),
          GovernanceTab(api: _api, capabilities: capabilities),
        ),
        (
          const NavigationRailDestination(
            icon: Icon(Icons.receipt_long_outlined),
            label: Text('Audit Log'),
          ),
          const AuditLogTab(),
        ),
    ];
    final selectedIndex = _index.clamp(0, entries.length - 1);
    Widget page;
    final route = AdminRoute.fromUri(Uri.base);
    final rid = route.resourceId;
    if (rid.isNotEmpty) {
      final detail = <String, WidgetBuilder>{
        'users': (_) => UserDetailScreen(api: _api, client: widget.client, userId: rid),
        'clients': (_) => ClientDetailScreen(api: _api, client: widget.client, clientId: rid),
        'tenants': (_) => TenantDetailScreen(api: _api, client: widget.client, tenantId: rid),
        'connections': (_) => ConnectionDetailScreen(api: _api, client: widget.client, connectionId: rid),
        'emergency-access': (_) => BreakGlassDetailScreen(api: _api, client: widget.client, sessionId: rid),
        'permissions': (_) => PermissionDetailScreen(api: _api, client: widget.client, clientId: rid),
        'webhooks': (_) => WebhookDetailScreen(api: _api, client: widget.client, subId: rid),
      };
      final builder = detail[route.module];
      if (builder != null) { page = builder(context); } else { page = entries[selectedIndex].$2; }
    } else {
      page = entries[selectedIndex].$2;
    }
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
            onDestinationSelected: (i) => setState(() { _index = i; _navigateToTab(i); }),
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