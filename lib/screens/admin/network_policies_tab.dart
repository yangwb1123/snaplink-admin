import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';

import 'network_policy_dialog.dart';

/// Advertised network-boundary policies and classifier diagnostics.
class NetworkPoliciesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const NetworkPoliciesTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<NetworkPoliciesTab> createState() => _NetworkPoliciesTabState();
}

class _NetworkPoliciesTabState extends State<NetworkPoliciesTab> {
  static const _basePath = '/api/v1/netpolicy/policies';
  static const _classifyPath = '/api/v1/netpolicy/classify';

  final _remoteCtrl = TextEditingController();
  final _hostCtrl = TextEditingController();
  List<Map<String, dynamic>> _policies = const [];
  Map<String, dynamic>? _classification;
  String? _error;
  bool _loading = false;
  bool _mutating = false;

  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(_basePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_basePath);

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _remoteCtrl.dispose();
    _hostCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_available) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_basePath, forceRefresh: true);
      final values = data['policies'] as List? ?? const [];
      if (!mounted) return;
      setState(() {
        _policies = values
            .whereType<Map>()
            .map((item) => Map<String, dynamic>.from(item))
            .toList(growable: false);
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _edit([Map<String, dynamic>? existing]) async {
    final draft = await showDialog<NetworkPolicyDraft>(
      context: context,
      builder: (_) => NetworkPolicyDialog(existing: existing),
    );
    if (draft == null || !mounted) return;
    await _write(
      () => widget.api.post(_basePath, draft.toJson()),
      existing == null ? 'Network policy created.' : 'Network policy updated.',
    );
  }

  Future<void> _delete(Map<String, dynamic> policy) async {
    final name = policy['name']?.toString() ?? '';
    if (name.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete network policy?',
      message:
          'Delete $name? Requests will immediately fall through to the next matching policy.',
      confirmLabel: 'Delete policy',
      destructive: true,
      confirmText: name,
    );
    if (!confirmed) return;
    await _write(
      () => widget.api.delete('$_basePath/${Uri.encodeComponent(name)}'),
      'Network policy deleted.',
    );
  }

  Future<void> _classify() async {
    final remote = _remoteCtrl.text.trim();
    if (remote.isEmpty) {
      setState(() => _error = 'Enter a remote address to classify.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _classification = null;
    });
    try {
      final data = await widget.api.get(
        _classifyPath,
        query: {
          'remote_addr': remote,
          if (_hostCtrl.text.trim().isNotEmpty) 'host': _hostCtrl.text.trim(),
        },
      );
      if (mounted) setState(() => _classification = data);
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _write(
    Future<Map<String, dynamic>> Function() operation,
    String success,
  ) async {
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await operation();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const Center(
        child: Text('Network policy management is not enabled.'),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        Row(
          children: [
            Text(
              'Network policies',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading || _mutating ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh',
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _mutating ? null : _edit,
              icon: const Icon(Icons.add),
              label: const Text('Add policy'),
            ),
          ],
        ),
        const SizedBox(height: 4),
        const Text(
          'Map trusted CIDRs and hostnames to advertised endpoints. Higher priority wins; hostname matches win over CIDRs.',
        ),
        const SizedBox(height: 12),
        AsyncView<List<Map<String, dynamic>>>(
          loading: _loading,
          error: _error,
          data: _policies,
          onRetry: _load,
          emptyTitle: 'No network policies',
          emptySubtitle: 'Unclassified requests use the deployment defaults.',
          dataBuilder: (policies) => Column(
            children: [
              for (final policy in policies) _policyCard(context, policy),
            ],
          ),
        ),
        const SizedBox(height: 16),
        _classifierCard(context),
      ],
    );
  }

  Widget _policyCard(BuildContext context, Map<String, dynamic> policy) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    child: ListTile(
      leading: const Icon(Icons.lan_outlined),
      title: Text(policy['name']?.toString() ?? ''),
      subtitle: Text(
        'Priority ${policy['priority'] ?? 0}\n'
        'CIDRs: ${(policy['cidrs'] as List? ?? const []).join(', ')}\n'
        'Hosts: ${(policy['hostnames'] as List? ?? const []).join(', ')}',
      ),
      isThreeLine: true,
      onTap: () => _edit(policy),
      trailing: IconButton(
        onPressed: _mutating ? null : () => _delete(policy),
        icon: const Icon(Icons.delete_outline),
        tooltip: 'Delete',
      ),
    ),
  );

  Widget _classifierCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Policy classifier',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          const Text('Test a network tuple before changing edge routing.'),
          const SizedBox(height: 12),
          TextField(
            controller: _remoteCtrl,
            decoration: const InputDecoration(
              labelText: 'Remote address',
              hintText: '10.0.0.5:54321',
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _hostCtrl,
            decoration: const InputDecoration(
              labelText: 'Host (optional)',
              hintText: 'api.internal.example.com',
            ),
          ),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _loading ? null : _classify,
            child: const Text('Classify request'),
          ),
          if (_classification != null) ...[
            const SizedBox(height: 12),
            SelectableText(
              const JsonEncoder.withIndent('  ').convert(_classification),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
}
