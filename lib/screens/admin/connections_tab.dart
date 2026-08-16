import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'connections/connection_contract.dart';
import 'connections_widgets.dart';
import 'snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'admin_route.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Operates Snaplink enterprise connections for one tenant at a time.
/// Mutations can change home-realm routing or make an outbound request; both require operator confirmation.
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
  VoidCallback? _retry;
  bool _loadingList = false;
  bool _loadingConnection = false;
  bool _mutating = false;
  bool _enabled = true;
  String _type = 'oidc';
  late final void Function() _cancelPopState;
  ConnectionAdminAvailability get _availability =>
      ConnectionAdminAvailability(widget.capabilities);

  @override
  void initState() {
    super.initState();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module == 'connections' && route.isNew) _upsertConnection();
  }

  @override
  void dispose() {
    _cancelPopState();
    _tenantCtrl.dispose();
    _lookupCtrl.dispose();
    _idCtrl.dispose();
    _createTenantCtrl.dispose();
    _displayNameCtrl.dispose();
    _domainsCtrl.dispose();
    _configCtrl.dispose();
    super.dispose();
  }

  void _fail(String message, {VoidCallback? retry}) => setState(() {
    _error = message;
    _retry = retry;
  });

  Future<void> _loadConnections() async {
    widget.api.skipCache();
    final tenantId = _tenantCtrl.text.trim();
    if (tenantId.isEmpty) {
      _fail('Enter a tenant ID to list its connections.');
      return;
    }
    if (!_availability.canList) {
      _fail('Connection listing is not enabled on this replica.');
      return;
    }
    setState(() {
      _loadingList = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(
        ConnectionAdminContract.collection,
        query: {'tenant_id': tenantId},
      );
      if (!mounted) return;
      setState(() {
        _connections =
            (data['connections'] as List?)
                ?.map((e) => Map<String, dynamic>.from(e))
                .toList() ??
            const [];
        _selectedId = null;
        _connection = _health = null;
        _domainClaims = const [];
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) _fail(error.toString(), retry: _loadConnections);
    } catch (_) {
      if (mounted) {
        _fail('Could not load connections.', retry: _loadConnections);
      }
    } finally {
      if (mounted) setState(() => _loadingList = false);
    }
  }

  Future<void> _loadSelected() async {
    final id = _lookupCtrl.text.trim();
    if (id.isEmpty) {
      _fail('Enter a connection ID first.');
      return;
    }
    if (!_availability.canGet) {
      _fail('Connection lookup is not enabled on this replica.');
      return;
    }
    setState(() {
      _loadingConnection = true;
      _error = null;
      _selectedId = id;
      _connection = _health = null;
      _domainClaims = const [];
    });
    final errors = <String>[];
    Map<String, dynamic>? connection;
    Map<String, dynamic>? health;
    List<Map<String, dynamic>> domains = const [];
    try {
      connection = await widget.api.get(ConnectionAdminContract.detail(id));
    } on SnaplinkAdminApiError catch (error) {
      errors.add('Connection: $error');
    }
    if (connection != null && _availability.canReadHealth) {
      try {
        health = await widget.api.get(ConnectionAdminContract.health(id));
      } on SnaplinkAdminApiError catch (error) {
        errors.add('Health: $error');
      }
    }
    if (connection != null && _availability.canListDomains) {
      try {
        final rawDomains =
            (await widget.api.get(
                  ConnectionAdminContract.domains(id),
                ))['domains']
                as List?;
        domains =
            rawDomains?.map((e) => Map<String, dynamic>.from(e)).toList() ??
            const [];
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
      _retry = errors.isEmpty ? null : _loadSelected;
      _loadingConnection = false;
    });
  }

  Future<void> _upsertConnection() async {
    final id = _idCtrl.text.trim();
    final tenantId = _createTenantCtrl.text.trim();
    late final Map<String, String> config;
    try {
      config = decodeConnectionConfiguration(_configCtrl.text);
    } on ConnectionConfigurationNotObject {
      _fail('Connection configuration must be a JSON object.');
      return;
    } on FormatException {
      _fail('Connection configuration is not valid JSON.');
      return;
    }
    if (id.isEmpty || tenantId.isEmpty) {
      _fail('Connection ID and tenant ID are required.');
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
      () => widget.api.post(ConnectionAdminContract.collection, {
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
      confirmText: id,
    )) {
      return;
    }
    await _write(
      () => widget.api.delete(ConnectionAdminContract.detail(id)),
      success: 'Connection deleted.',
      afterSuccess: () async {
        _lookupCtrl.clear();
        if (mounted) {
          setState(() {
            _selectedId = null;
            _connection = _health = null;
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
      () => widget.api.post(ConnectionAdminContract.probe(id)),
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
      () => widget.api.post(ConnectionAdminContract.verifyDomain(id, domain)),
      success: 'DNS verification completed.',
      afterSuccess: _loadSelected,
    );
  }

  Future<void> _write(
    Future<Map<String, dynamic>> Function() request, {
    required String success,
    required Future<void> Function() afterSuccess,
  }) async {
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await request();
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText(success));
      await afterSuccess();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) _fail(error.toString(), retry: _loadSelected);
    } catch (_) {
      if (mounted) _fail('Connection operation failed.', retry: _loadSelected);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String message, {
    required String confirmLabel,
    bool destructive = false,
    String? confirmText,
  }) async => ConfirmDialog.show(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    destructive: destructive,
    confirmText: confirmText,
  );

  @override
  Widget build(BuildContext context) {
    if (!_availability.familyAvailable &&
        !_availability.canList &&
        !_availability.canCreate &&
        !_availability.canGet) {
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        title:
            'Identity connection management is not enabled on this Snaplink replica.',
      );
    }
    return PullToRefresh(onRefresh: _loadConnections, child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        ConnectionWorkspaceHeader(
          title: AppStrings.of(context).identityConnections,
          refreshEnabled: !_loadingList && !_mutating,
          onRefresh: _loadConnections,
        ),
        if (_error != null)
          ConnectionErrorCard(
            error: _error!,
            onRetry: _retry ?? _loadConnections,
          ),
        ConnectionsListCard(
          tenantController: _tenantCtrl,
          lookupController: _lookupCtrl,
          connections: _connections,
          canList: _availability.canList,
          canGet: _availability.canGet,
          loadingList: _loadingList,
          loadingConnection: _loadingConnection,
          mutating: _mutating,
          onLoadList: _loadConnections,
          onLoadSelected: _loadSelected,
          onSelect: (id) => AdminRoute.go('connections', resourceId: id),
        ),
        if (_availability.canCreate)
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
            canProbe: _availability.canProbe,
            canListDomains: _availability.canListDomains,
            canVerifyDomain: _availability.canVerifyDomain,
            canDelete: _availability.canDelete,
            onRefresh: _loadSelected,
            onProbe: () => _probeConnection(id),
            onDelete: () => _deleteConnection(id),
            onVerifyDomain: (domain) => _verifyDomain(id, domain),
          ),
      ],
    ));
  }
}
