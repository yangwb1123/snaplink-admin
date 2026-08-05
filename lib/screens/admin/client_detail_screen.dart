import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_route.dart';
import 'client_detail_secret_card.dart';
import 'client_form_dialog.dart';
import 'client_secret_lifecycle.dart';

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

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant ClientDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.clientId != widget.clientId) {
      _client = null;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.client.getClient(widget.clientId);
      if (!context.mounted) return;
      setState(() {
        _client = result as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: LocalizedText('Client: ${widget.clientId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AdminRoute.go('clients'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit client'.localized,
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
                  const Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Colors.redAccent,
                  ),
                  const SizedBox(height: 16),
                  LocalizedText(
                    'Failed to load',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(
                      _error!,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.grey.shade600,
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const LocalizedText('Retry'),
                  ),
                ],
              ),
            )
          : Column(
              children: [
                AdminBreadcrumb(),
                Expanded(child: _buildContent(context)),
              ],
            ),
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
      ],
    ),
  );

  Widget _infoCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.app_registration, size: 40),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _client?['name']?.toString() ?? widget.clientId,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    LocalizedText('ID: ${_client?['id'] ?? widget.clientId}'),
                  ],
                ),
              ),
              _statusChip(),
            ],
          ),
          const Divider(),
          _infoRow(
            'Client ID',
            _client?['id']?.toString() ??
                _client?['client_id']?.toString() ??
                widget.clientId,
          ),
          _infoRow(
            'Redirect URIs',
            (_client?['redirect_uris'] as List?)?.join(', ') ?? '—',
          ),
          _infoRow(
            'Login page URI',
            _client?['login_page_uri']?.toString() ??
                _client?['loginPageUri']?.toString() ??
                '—',
          ),
          if (_client?['grant_types'] is List)
            _infoRow(
              'Grant types',
              (_client!['grant_types'] as List).join(', '),
            ),
          _infoRow(
            'Allowed scopes',
            ((_client?['allowed_scopes'] ?? _client?['scopes']) as List?)?.join(
                  ', ',
                ) ??
                '—',
          ),
          _infoRow(
            'Authenticators',
            (_client?['allowed_authenticators'] as List?)?.join(', ') ?? 'Any',
          ),
          _infoRow(
            'Token strategy',
            _client?['token_strategy']?.toString() ?? '—',
          ),
          _infoRow('Client secret', clientSecretExpiryLabel(_client)),
        ],
      ),
    ),
  );

  Widget _statusChip() {
    final status =
        _client?['status']?.toString() ??
        (_client?['active'] == true ? 'active' : 'inactive');
    return Chip(
      label: LocalizedText(status),
      backgroundColor: status == 'active'
          ? Colors.green.shade100
          : status == 'pending'
          ? Colors.orange.shade100
          : Colors.grey.shade200,
    );
  }

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 120,
          child: LocalizedText(
            label,
            style: const TextStyle(fontWeight: FontWeight.w500),
          ),
        ),
        Expanded(child: Text(value.isEmpty ? '—' : value)),
      ],
    ),
  );

  Widget _actionsCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText(
            'Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
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
    label: LocalizedText(label),
    style: OutlinedButton.styleFrom(foregroundColor: color),
  );

  Future<void> _rotateSecret(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Rotate client secret?',
      message:
          'The current secret remains valid for 24 hours. Update all integrations before that overlap window closes.',
      destructive: true,
      confirmText: widget.clientId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      final rotation = await widget.client.rotateClientSecretWithPolicy(
        widget.clientId,
      );
      final newSecret = rotation['secret']?.toString() ?? '';
      if (!context.mounted) return;
      if (newSecret.isEmpty) {
        setState(
          () => _error =
              'The secret was rotated, but the server did not return its '
              'one-time value.',
        );
      } else {
        await showClientDetailSecret(
          context,
          newSecret,
          expiresAt: clientSecretExpiryUnix(rotation),
        );
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: LocalizedText('Secret rotated.')),
        );
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LocalizedText('Error: $e')));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _doAction(String action) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '${action[0].toUpperCase()}${action.substring(1)} client?',
      message: '${action[0].toUpperCase()}${action.substring(1)} this client?',
      destructive: true,
      confirmText: widget.clientId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.post(
        '/api/v1/admin/clients/${Uri.encodeComponent(widget.clientId)}/$action',
        {},
      );
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LocalizedText('Client ${action}ed')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LocalizedText('Error: $e')));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _editClient(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ClientFormDialog(client: widget.client, existing: _client),
    );
    if (result == true) _load();
  }
}
