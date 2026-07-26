import 'dart:convert';
import 'package:flutter/material.dart';
import 'connections_widgets.dart';
import 'snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'dart:js_interop';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:web/web.dart' as web;
import 'admin_route.dart';
/// Operates Snaplink enterprise connections for one tenant at a time.
/// Snaplink indexes connections by tenant, so this screen deliberately never
/// offers a cross-tenant list. Mutations can change home-realm routing or make
/// an outbound request, and therefore each requires an operator confirmation.
class ConnectionsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const ConnectionsTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<ConnectionsTab> createState() => _ConnectionsTabState();
}
class _ConnectionsTabState extends State<ConnectionsTab> {
  static const _connectionsPath = '/api/v1/admin/connections';
  static const _connectionPath = '/api/v1/admin/connections/:id';
  static const _domainsPath = '/api/v1/admin/connections/:id/domains';
  static const _verifyDomainPath =
      '/api/v1/admin/connections/:id/domains/:domain/verify';
  static const _healthPath = '/api/v1/admin/connections/:id/health';
  static const _probePath = '/api/v1/admin/connections/:id/probe';
  final _tenantCtrl = TextEditingController();
  final _lookupCtrl = TextEditingController();
  final _idCtrl = TextEditingController();
  final _createTenantCtrl = TextEditingController();
  final _displayNameCtrl = TextEditingController();
  final _domainsCtrl = TextEditingController();
  final _configCtrl = TextEditingController(text: '{}');
  List<Map<String, dynamic>> _connections = const [];
  List<Map<String, dynamic>> _domainClaims = const [];
  Map<String, dynamic>? _connection;
  Map<String, dynamic>? _health;
  String? _selectedId;
  String? _error;
  bool _loadingList = false;
  bool _loadingConnection = false;
  bool _mutating = false;
  bool _enabled = true;
  String _type = 'oidc';
  // The runtime inventory from older Snaplink replicas can contain just one
  // representative connection route. A wired connection store mounts the full
  // family together; individual requests remain authorized by the server.
  bool get _connectionFamilyAvailable =>
      widget.capabilities.hasAnyPathPrefix(_connectionsPath);
  bool _supports(String method, String path) => _connectionFamilyAvailable ||
      widget.capabilities.has(method, path) ||
      widget.capabilities.has(method, path.replaceAll(':id', '{id}').replaceAll(':domain', '{domain}'));
  bool get _canList => _supports('GET', _connectionsPath);
  bool get _canCreate => _supports('POST', _connectionsPath);
  bool get _canGet => _supports('GET', _connectionPath);
  bool get _canDelete => _supports('DELETE', _connectionPath);
  bool get _canListDomains => _supports('GET', _domainsPath);
  bool get _canVerifyDomain => _supports('POST', _verifyDomainPath);
  bool get _canReadHealth => _supports('GET', _healthPath);
  bool get _canProbe => _supports('POST', _probePath);
  @override
  void initState() {
    super.initState();
    _handleRoute();
    void p() { if (mounted) _handleRoute(); }
    web.window.addEventListener('popstate', p.toJS);
  }

  void _handleRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    if (route.module != 'connections') return;
    if (route.isNew) { _upsertConnection(); }
  }
  @override
  void dispose() {
    _tenantCtrl.dispose();
    _lookupCtrl.dispose();
    _idCtrl.dispose();
    _createTenantCtrl.dispose();
    _displayNameCtrl.dispose();
    _domainsCtrl.dispose();
    _configCtrl.dispose();
    super.dispose();
  }
  String _connectionRoute(String id) => '$_connectionsPath/${Uri.encodeComponent(id)}';
  String _domainsRoute(String id) => '${_connectionRoute(id)}/domains';
  String _verifyDomainRoute(String id, String domain) => '${_domainsRoute(id)}/${Uri.encodeComponent(domain)}/verify';
  String _healthRoute(String id) => '${_connectionRoute(id)}/health';
  String _probeRoute(String id) => '${_connectionRoute(id)}/probe';
  Future<void> _loadConnections() async {
    widget.api.skipCache();
    final tenantId = _tenantCtrl.text.trim();
    if (tenantId.isEmpty) {
      setState(() => _error = 'Enter a tenant ID to list its connections.');
      return;
    }
    if (!_canList) {
      setState(() => _error = 'Connection listing is not enabled on this replica.');
      return;
    }
    setState(() { _loadingList = true; _error = null; });
    try {
      final data = await widget.api.get(
        _connectionsPath,
        query: {'tenant_id': tenantId},
      );
      if (!mounted) return;
      setState(() {
        _connections = (data['connections'] as List?)?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const [];
        _selectedId = null;
        _connection = null;
        _health = null;
        _domainClaims = const [];
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load connections.');
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }
  Future<void> _loadSelected() async {
    final id = _lookupCtrl.text.trim();
    if (id.isEmpty) {
      setState(() => _error = 'Enter a connection ID first.');
      return;
    }
    if (!_canGet) {
      setState(
        () => _error = 'Connection lookup is not enabled on this replica.',
      );
      return;
    }
    setState(() { _loadingConnection = true; _error = null; _selectedId = id; _connection = null; _health = null; _domainClaims = const []; });
    final errors = <String>[];
    Map<String, dynamic>? connection;
    Map<String, dynamic>? health;
    List<Map<String, dynamic>> domains = const [];
    try {
      connection = await widget.api.get(_connectionRoute(id));
    } on SnaplinkAdminApiError catch (error) {
      errors.add('Connection: $error');
    }
    if (connection != null && _canReadHealth) {
      try {
        health = await widget.api.get(_healthRoute(id));
      } on SnaplinkAdminApiError catch (error) {
        errors.add('Health: $error');
      }
    }
    if (connection != null && _canListDomains) {
      try {
        final rawDomains = (await widget.api.get(_domainsRoute(id)))['domains'] as List?; domains = rawDomains?.map((e) => Map<String, dynamic>.from(e)).toList() ?? const [];
      } on SnaplinkAdminApiError catch (error) {
        errors.add('Domains: $error');
      }
    }
    if (!mounted || _selectedId != id) return;
    setState(() {
      _connection = connection;
      _health = health;
      _domainClaims = domains;
      _error = errors.isEmpty ? null : errors.join('\n');
      _loadingConnection = false;
    });
  }
  Future<void> _upsertConnection() async {
    final id = _idCtrl.text.trim();
    final tenantId = _createTenantCtrl.text.trim();
    Map<String, String>? config;
    try {
      final raw = _configCtrl.text.trim();
      if (raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is Map) {
          config = decoded.map((k, v) => MapEntry(k.toString(), v.toString()));
        } else {
          setState(() => _error = 'Connection configuration must be a JSON object.');
          return;
        }
      } else {
        config = const {};
      }
    } on FormatException {
      setState(() => _error = 'Connection configuration is not valid JSON.');
      return;
    }
    if (id.isEmpty || tenantId.isEmpty) {
      setState(() => _error = 'Connection ID and tenant ID are required.');
      return;
    }
    final confirmed = await _confirm(
      'Create or replace connection?',
      'This updates $id and its home-realm domain routing for tenant $tenantId.',
      confirmLabel: 'Save connection',
    );
    if (!confirmed) return;
    final domains = _domainsCtrl.text
        .split(',')
        .map((value) => value.trim())
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    await _write(
      () => widget.api.post(_connectionsPath, {
        'id': id,
        'tenant_id': tenantId,
        'type': _type,
        'display_name': _displayNameCtrl.text.trim(),
        'domains': domains,
        'enabled': _enabled,
        'config': config,
      }),
      success: 'Connection saved.',
      afterSuccess: () async {
        _tenantCtrl.text = tenantId;
        _lookupCtrl.text = id;
        await _loadConnections();
        await _loadSelected();
      },
    );
  }
  Future<void> _deleteConnection(String id) async {
    if (!await _confirm(
      'Delete connection?',
      'Delete $id, including its configured domain routing. This cannot be undone.',
      confirmLabel: 'Delete connection',
      destructive: true,
    )) {
      return;
    }
    await _write(
      () => widget.api.delete(_connectionRoute(id)),
      success: 'Connection deleted.',
      afterSuccess: () async {
        _lookupCtrl.clear();
        if (mounted) {
          setState(() {
            _selectedId = null;
            _connection = null;
            _health = null;
            _domainClaims = const [];
          });
        }
        await _loadConnections();
      },
    );
  }
  Future<void> _probeConnection(String id) async {
    if (!await _confirm(
      'Probe upstream connection?',
      'Snaplink will contact the configured upstream identity provider and record the outcome.',
      confirmLabel: 'Run probe',
    )) {
      return;
    }
    await _write(
      () => widget.api.post(_probeRoute(id)),
      success: 'Reachability probe completed.',
      afterSuccess: _loadSelected,
    );
  }
  Future<void> _verifyDomain(String id, String domain) async {
    if (!await _confirm(
      'Verify $domain?',
      'Snaplink will query the DNS TXT challenge and may promote this connection as the domain owner.',
      confirmLabel: 'Verify domain',
    )) {
      return;
    }
    await _write(
      () => widget.api.post(_verifyDomainRoute(id, domain)),
      success: 'DNS verification completed.',
      afterSuccess: _loadSelected,
    );
  }
  Future<void> _write(Future<Map<String, dynamic>> Function() request, {required String success, required Future<void> Function() afterSuccess}) async {
    setState(() { _mutating = true; _error = null; });
    try {
      await request(); if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(success)));
      await afterSuccess();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (_) {
      if (mounted) setState(() => _error = 'Connection operation failed.');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }
  Future<bool> _confirm(
    String title,
    String message, {
    required String confirmLabel,
    bool destructive = false,
  }) async =>
      ConfirmDialog.show(
        context,
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        destructive: destructive,
      );
  @override
  Widget build(BuildContext context) {
    if (!_connectionFamilyAvailable && !_canList && !_canCreate && !_canGet) {
      return const Center(
        child: Text(
          'Identity connection management is not enabled on this Snaplink replica.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
        AdminBreadcrumb(),
                    Text(
              'Identity connections',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loadingList || _mutating ? null : _loadConnections,
              tooltip: 'Refresh connection list',
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Configure a tenant\'s OIDC or SAML upstream and verify its email-domain routing.',
        ),
        if (_error != null) ConnectionErrorCard(error: _error!),
        ConnectionsListCard(
          tenantController: _tenantCtrl,
          lookupController: _lookupCtrl,
          connections: _connections,
          canList: _canList,
          canGet: _canGet,
          loadingList: _loadingList,
          loadingConnection: _loadingConnection,
          mutating: _mutating,
          onLoadList: _loadConnections,
          onLoadSelected: _loadSelected,
          onSelect: (id) => AdminRoute.go('connections', resourceId: id),
        ),
        if (_canCreate)
          ConnectionCreateCard(
            idController: _idCtrl,
            tenantController: _createTenantCtrl,
            displayNameController: _displayNameCtrl,
            domainsController: _domainsCtrl,
            configController: _configCtrl,
            type: _type,
            enabled: _enabled,
            mutating: _mutating,
            onTypeChanged: (type) => setState(() => _type = type),
            onEnabledChanged: (enabled) => setState(() => _enabled = enabled),
            onSave: _upsertConnection,
          ),
        if (_selectedId case final id?)
          ConnectionDetailsCard(
            id: id,
            connection: _connection,
            health: _health,
            domainClaims: _domainClaims,
            loading: _loadingConnection,
            mutating: _mutating,
            canProbe: _canProbe,
            canListDomains: _canListDomains,
            canVerifyDomain: _canVerifyDomain,
            canDelete: _canDelete,
            onRefresh: _loadSelected,
            onProbe: () => _probeConnection(id),
            onDelete: () => _deleteConnection(id),
            onVerifyDomain: (domain) => _verifyDomain(id, domain),
          ),
      ],
    );
  }
}