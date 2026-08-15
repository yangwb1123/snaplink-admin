import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/widgets/info_row.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_module_groups.dart';
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

  /// Persona emphasis (derived by the dashboard; default = no emphasis).
  final OperatorPersona persona;

  const ClientDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.clientId,
    this.persona = OperatorPersona.general,
  });

  @override
  State<ClientDetailScreen> createState() => _ClientDetailScreenState();
}

class _ClientDetailScreenState extends State<ClientDetailScreen> {
  Map<String, dynamic>? _client;
  String? _error;
  bool _loading = true;
  bool _mutating = false;

  /// 模块强调色（identity 组 indigo-violet）：详情页图标统一按组色上色。
  Color get _accent => adminModuleIconColor('clients');

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
        title: Semantics(
          container: true,
          header: true,
          child: LocalizedText('Client: {id}', args: {'id': widget.clientId}),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          tooltip: 'Back'.localized,
          onPressed: () => AdminRoute.back('clients'),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.edit_outlined, color: _accent),
            tooltip: 'Edit client'.localized,
            onPressed: () => _editClient(context),
          ),
        ],
      ),
      body: _loading
          ? const SkeletonListTile(itemCount: 6)
          : _error != null
          ? _errorState(_error!)
          : Column(
              children: [
                AdminBreadcrumb(),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _infoCard(context),
                        if (_client != null) ...[
                          const SizedBox(height: 16),
                          _miniStrip(context),
                        ],
                        const SizedBox(height: 16),
                        _actionsCard(context),
                      ],
                    ),
                  ),
                ),
              ],
            ),
    );
  }

  /// 加载失败三态之一：统一 ErrorStateView（图标 + 标题 + 明细 + 重试）。
  Widget _errorState(String error) =>
      ErrorStateView(message: error, onRetry: _load);

  /// 真实值 mini strip（grant types / scopes / secret expiry），顺序按
  /// `clientDetailMetricOrder(persona)`（设计 §4.9 T-06）。无箭头。
  Widget _miniStrip(BuildContext context) {
    final grantTypes = ((_client?['grant_types'] as List?) ?? const []).length;
    final scopes = ((_client?['allowed_scopes'] ?? _client?['scopes']) as List? ?? const []).length;
    final secretExpiry = clientSecretExpiryUnix(_client);
    final remaining = secretExpiry <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(secretExpiry * 1000, isUtc: true)
              .toLocal()
              .difference(DateTime.now());
    final cards = <KeyMetricCard>[
      KeyMetricCard(label: 'Grant types', value: grantTypes, icon: Icons.tune, color: AppColors.accentBlue),
      KeyMetricCard(label: 'Scopes', value: scopes, icon: Icons.lock_open_outlined, color: AppColors.primary),
      if (remaining == null)
        KeyMetricCard(label: 'Secret expiry', value: 0, caption: 'Never expires', icon: Icons.schedule_outlined, color: AppColors.muted)
      else
        KeyMetricCard(label: 'Secret expiry', value: remaining.isNegative ? 0 : remaining.inDays, icon: Icons.schedule_outlined, color: AppColors.warning),
    ];
    return MetricStrip(cards: [
      for (final metric in clientDetailMetricOrder(widget.persona)) cards[metric.index],
    ]);
  }

  Widget _infoCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.app_registration, size: 40, color: _accent),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(_client?['name']?.toString() ?? widget.clientId, style: Theme.of(context).textTheme.titleMedium),
                    LocalizedText('ID: {id}', args: {'id': _client?['id'] ?? widget.clientId}),
                  ],
                ),
              ),
              _statusChip(),
            ],
          ),
          const Divider(),
          InfoRow(
            label: 'Client ID',
            value: _client?['id']?.toString() ?? _client?['client_id']?.toString() ?? widget.clientId,
            level: DataEmphasisLevel.secondary,
            // R36：激活 InfoRow 内置复制按钮（与表格 CopyableCell / DCR
            // CopyableDcrValue 同数据同能力）。
            copyValue: _client?['id']?.toString() ?? _client?['client_id']?.toString() ?? widget.clientId,
          ),
          InfoRow(
            label: 'Redirect URIs',
            value: (_client?['redirect_uris'] as List?)?.join(', ') ?? '—',
            level: DataEmphasisLevel.tertiary,
          ),
          InfoRow(
            label: 'Login page URI',
            value: _client?['login_page_uri']?.toString() ?? _client?['loginPageUri']?.toString() ?? '—',
            level: DataEmphasisLevel.tertiary,
          ),
          if (_client?['grant_types'] is List)
            InfoRow(
              label: 'Grant types',
              value: (_client!['grant_types'] as List).join(', '),
              level: DataEmphasisLevel.tertiary,
            ),
          InfoRow(
            label: 'Allowed scopes',
            value: ((_client?['allowed_scopes'] ?? _client?['scopes']) as List?)?.join(', ') ?? '—',
            level: DataEmphasisLevel.tertiary,
          ),
          InfoRow(
            label: 'Authenticators',
            value: (_client?['allowed_authenticators'] as List?)?.join(', ') ?? 'Any',
            level: DataEmphasisLevel.tertiary,
          ),
          InfoRow(
            label: 'Token strategy',
            value: _client?['token_strategy']?.toString() ?? '—',
            level: DataEmphasisLevel.secondary,
          ),
          InfoRow(
            label: 'Client secret',
            value: clientSecretExpiryLabel(context, _client),
            level: DataEmphasisLevel.tertiary,
          ),
        ],
      ),
    ),
  );

  Widget _statusChip() {
    final status = _client?['status']?.toString() ?? (_client?['active'] == true ? 'active' : 'inactive');
    // Labels pass through context.tr(status): lowercase keys preserve the
    // EN pins (test/admin_detail_screens_test.dart:85) and the existing ZH
    // renderings (活跃/待处理); 'inactive' is a new admin-UX catalog key.
    return switch (status) {
      'active' => StatusChip.active(label: context.tr('active')),
      'pending' => StatusChip.pending(label: context.tr('pending')),
      _ => StatusChip.inactive(label: context.tr('inactive')),
    };
  }

  Widget _actionsCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          LocalizedText('Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (_client?['status'] == 'pending')
                _actionButton(icon: Icons.check_circle_outline, label: 'Approve', color: AppColors.success, primary: true, onPressed: () => _doAction('approve')),
              if (_client?['status'] == 'pending')
                _actionButton(
                  icon: Icons.cancel_outlined,
                  label: 'Reject',
                  // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
                  color: AppColors.semanticFor(
                    Theme.of(context).brightness,
                    AppColors.danger,
                  ),
                  onPressed: () => _doAction('reject'),
                ),
              _actionButton(icon: Icons.key, label: 'Rotate Secret', color: AppColors.warning, primary: true, onPressed: () => _rotateSecret(context)),
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
    bool primary = false,
  }) {
    if (primary) {
      final onColor = color.computeLuminance() > 0.5 ? Colors.black87 : Colors.white;
      return FilledButton.icon(
        onPressed: _mutating ? null : onPressed,
        icon: Icon(icon),
        label: LocalizedText(label),
        style: FilledButton.styleFrom(backgroundColor: color, foregroundColor: onColor),
      );
    }
    return OutlinedButton.icon(
      onPressed: _mutating ? null : onPressed,
      icon: Icon(icon),
      label: LocalizedText(label),
      style: OutlinedButton.styleFrom(foregroundColor: color),
    );
  }

  Future<void> _rotateSecret(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Rotate client secret?',
      message:
          'The current secret remains valid for 24 hours. Update all integrations before that overlap window closes.',
      confirmLabel: 'Rotate secret',
      destructive: true,
      confirmText: widget.clientId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      final rotation = await widget.client.rotateClientSecretWithPolicy(widget.clientId);
      final newSecret = rotation['secret']?.toString() ?? '';
      if (!context.mounted) return;
      if (newSecret.isEmpty) {
        setState(
          () => _error =
              'The secret was rotated, but the server did not return its one-time value.',
        );
      } else {
        await showClientDetailSecret(context, newSecret, expiresAt: clientSecretExpiryUnix(rotation));
        if (!context.mounted) return;
        showAppSnackBar(context, content: LocalizedText('Secret rotated.'));
      }
    } catch (e) {
      if (!context.mounted) return;
      showAppSnackBar(context, content: LocalizedText('Error: {detail}', args: {'detail': e}), kind: AppSnackBarKind.error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _doAction(String action) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: '${action[0].toUpperCase()}${action.substring(1)} client?',
      message: '${action[0].toUpperCase()}${action.substring(1)} this client?',
      confirmLabel: '${action[0].toUpperCase()}${action.substring(1)}',
      destructive: true,
      confirmText: widget.clientId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.post('/api/v1/admin/clients/${Uri.encodeComponent(widget.clientId)}/$action', {});
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText('Client {action}ed', args: {'action': action}));
      _load();
    } catch (e) {
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText('Error: {detail}', args: {'detail': e}), kind: AppSnackBarKind.error);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _editClient(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => ClientFormDialog(client: widget.client, existing: _client),
    );
    if (result == true) _load();
  }
}
