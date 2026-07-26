
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_route.dart';
import 'client_form_dialog.dart';

/// Client detail screen with actions (rotate-secret, approve, reject).
/// URL: /admin/clients/{id}[/{action}]
class ClientDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SSOAdminClient client;
  final String clientId;

  const ClientDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.clientId,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  Map<String, dynamic>? _client;
  String? _error;
  bool _loading = true;
  bool _mutating = false;
  bool _showSecret = false;
  String? _revealedSecret;

  @override
  void initState() {
    super.initState();
    _handleRoute();
    web.window.addEventListener('popstate', _onPopState.toJS);
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await widget.client.getClient(widget.clientId);
      if (!mounted) return;
      setState(() { _client = result as Map<String, dynamic>?; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Client: ${widget.clientId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AdminRoute.go('clients'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit client',
            onPressed: () => _editClient(context),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text('Failed to load', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(_error!, textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(children: [
              AdminBreadcrumb(),
              Expanded(child: _buildContent(context)),
            ]),
    );
  }

  Widget _buildContent(BuildContext context) => SingleChildScrollView(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _infoCard(context),
        const SizedBox(height: 16),
        _actionsCard(context),
        const SizedBox(height: 16),
        if (_revealedSecret != null) _secretCard(context),
      ],
    ),
  );

  Widget _infoCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.app_registration, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_client?['name']?.toString() ?? widget.clientId,
                  style: Theme.of(context).textTheme.titleMedium),
                Text('ID: ${_client?['id'] ?? widget.clientId}'),
              ],
            )),
            _statusChip(),
          ]),
          const Divider(),
          _infoRow('Client ID', _client?['client_id']?.toString() ?? '—'),
          _infoRow('Redirect URIs', (_client?['redirect_uris'] as List?)?.join(', ') ?? '—'),
          _infoRow('Grant Types', (_client?['grant_types'] as List?)?.join(', ') ?? '—'),
          _infoRow('Scopes', (_client?['scopes'] as List?)?.join(', ') ?? '—'),
        ],
      ),
    ),
  );

  Widget _statusChip() {
    final status = _client?['status']?.toString() ?? 'active';
    return Chip(
      label: Text(status),
      backgroundColor: status == 'active'
        ? Colors.green.shade100
        : status == 'pending' ? Colors.orange.shade100 : Colors.grey.shade200,
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
      Expanded(child: Text(value.isEmpty ? '—' : value)),
    ]),
  );

  Widget _actionsCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (_client?['status'] == 'pending')
                _actionButton(
                  icon: Icons.check_circle_outline,
                  label: 'Approve',
                  color: Colors.green,
                  onPressed: () => _doAction('approve'),
                ),
              if (_client?['status'] == 'pending')
                _actionButton(
                  icon: Icons.cancel_outlined,
                  label: 'Reject',
                  color: Colors.redAccent,
                  onPressed: () => _doAction('reject'),
                ),
              _actionButton(
                icon: Icons.key,
                label: 'Rotate Secret',
                color: Colors.orange,
                onPressed: () => _rotateSecret(context),
              ),
              _actionButton(
                icon: Icons.visibility,
                label: _showSecret ? 'Hide Secret' : 'Reveal Secret',
                color: Colors.blueGrey,
                onPressed: () => _toggleSecret(),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _actionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onPressed,
  }) => OutlinedButton.icon(
    onPressed: _mutating ? null : onPressed,
    icon: Icon(icon),
    label: Text(label),
    style: OutlinedButton.styleFrom(foregroundColor: color),
  );

  Widget _secretCard(BuildContext context) => Card(
    color: Colors.amber.shade50,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber_rounded),
            const SizedBox(width: 8),
            Text('Client Secret', style: Theme.of(context).textTheme.titleSmall),
          ]),
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(4),
            ),
            child: SelectableText(_revealedSecret ?? ''),
          ),
          const SizedBox(height: 8),
          Text('Store this securely — it will not be shown again.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.red.shade700)),
        ],
      ),
    ),
  );

  Future<void> _rotateSecret(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(context,
      title: 'Rotate client secret?',
      message: 'This will invalidate the current secret. All integrations using this secret will stop working until updated.',
      destructive: true);
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      final result = await widget.api.post(
        '/api/v1/admin/clients/${Uri.encodeComponent(widget.clientId)}/rotate-secret', {});
      if (!mounted) return;
      final newSecret = (result as Map<String, dynamic>?)?
        ['client_secret']?.toString() ?? (result as Map?)?.values.first?.toString() ?? 'Secret rotated';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(newSecret.startsWith('Secret') ? newSecret : 'Secret rotated')));
      setState(() { _revealedSecret = newSecret; _showSecret = true; });
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { if (mounted) setState(() => _mutating = false); }
  }

  void _toggleSecret() {
    if (_showSecret) {
      setState(() { _showSecret = false; _revealedSecret = null; });
    } else {
      setState(() => _showSecret = true);
    }
  }

  Future<void> _doAction(String action) async {
    final confirmed = await ConfirmDialog.show(context,
      title: '${action[0].toUpperCase()}${action.substring(1)} client?',
      message: '${action[0].toUpperCase()}${action.substring(1)} this client?',
      destructive: action == 'reject');
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.post(
        '/api/v1/admin/clients/${Uri.encodeComponent(widget.clientId)}/$action', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Client ${action}ed')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally { if (mounted) setState(() => _mutating = false); }
  }

  Future<void> _editClient(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ClientFormDialog(client: widget.client, existing: _client),
    );
    if (result == true) _load();
  }

  void _handleRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    if (route.module != 'clients') return;
  }
  void _onPopState() { if (mounted) _handleRoute(); }

}
