import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';

/// Crypto keys inventory and rotation management tab.
/// URLs: /admin/crypto-keys, /admin/crypto-keys/rotate
class CryptoKeysTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const CryptoKeysTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<CryptoKeysTab> createState() => _CryptoKeysTabState();
}

class _CryptoKeysTabState extends State<CryptoKeysTab> {
  static const _keysPath = '/api/v1/admin/crypto/keys';
  static const _rotatePath = '/api/v1/admin/keys/rotate';
  List<Map<String, dynamic>> _keys = const [];
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  late final void Function() _cancelPopState;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.cryptoKeys);

  bool get _available => widget.capabilities.hasAnyPathPrefix(_keysPath);
  bool get _canRotate =>
      widget.capabilities.has('POST', _rotatePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_rotatePath);

  /// 首个命中的字段值（兼容新旧字段命名；API 值一律走 Text，X1/X10）。
  String _value(int i, List<String> keys) {
    final map = _keys[i];
    for (final key in keys) {
      final v = map[key];
      if (v != null) return v.toString();
    }
    return '';
  }

  @override
  void initState() {
    super.initState();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(_onPopState);
    if (_available) _load();
  }

  @override
  void dispose() {
    _cancelPopState();
    super.dispose();
  }

  Future<void> _load() async {
    if (!_available) return;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.get(_keysPath);
      final items = data['keys'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _keys = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load crypto keys.'; _loading = false; });
    }
  }

  Future<void> _compromise(String id) async {
    final reason = await _compromiseReason(id);
    if (reason == null) return;
    setState(() { _mutating = true; _error = null; });
    try {
      final response = await widget.api.post(
        '$_keysPath/${Uri.encodeComponent(id)}/compromise',
        {'reason': reason},
      );
      if (!mounted) return;
      final retirement =
          (response['key'] as Map?)?['retirement_status']?.toString() ??
          'not reported';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: LocalizedText(
          'Key marked as compromised. Source retirement: {retirement}.',
          args: {'retirement': retirement},
        ),
      ));
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _rotate() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Rotate signing key?',
      message: 'Trigger signing-key rotation across the cluster?',
      confirmLabel: 'Rotate',
      destructive: true,
      confirmText: 'ROTATE SIGNING KEY',
    );
    if (!confirmed) return;
    setState(() { _mutating = true; _error = null; });
    try {
      final response = await widget.api.post(_rotatePath);
      if (!mounted) return;
      final keyClass = response['key_class']?.toString() ?? 'unknown';
      final rollout = response['rollout_state']?.toString() ?? 'unknown';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: LocalizedText(
          'Rotation completed for {keyClass}. Rollout: {rollout}.',
          args: {'keyClass': keyClass, 'rollout': rollout},
        ),
      ));
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<String?> _compromiseReason(String id) async {
    final reason = TextEditingController();
    final confirm = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LocalizedText('Mark key as compromised?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LocalizedText(
              'The response will report whether source retirement completed, '
              'failed, is unsupported, or still needs verification.',
            ),
            const SizedBox(height: 8),
            LocalizedText('Type {id} and provide an incident reference.', args: {'id': id}),
            const SizedBox(height: 12),
            TextField(controller: reason, decoration: InputDecoration(labelText: 'Reason / incident reference'.localized)),
            const SizedBox(height: 8),
            TextField(controller: confirm, decoration: InputDecoration(labelText: id)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const LocalizedText('Cancel'),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([reason, confirm]),
            builder: (_, _) => FilledButton(
              onPressed: reason.text.trim().isNotEmpty && confirm.text.trim() == id
                  ? () => Navigator.pop(dialogContext, reason.text.trim())
                  : null,
              child: const LocalizedText('Compromise'),
            ),
          ),
        ],
      ),
    );
    reason.dispose();
    confirm.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const EmptyState(variant: EmptyStateVariant.notEnabled, title: 'Crypto key management is not enabled on this replica.');
    final rotating = AdminRoute.current().subresource == 'rotate';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).cryptoKeys,
          subtitle: 'Signing and encryption keys protecting authentication flows.',
          onRefresh: _load,
          actions: [
            if (_canRotate && !rotating)
              OutlinedButton.icon(
                onPressed: _mutating ? null : () => AdminRoute.go('crypto-keys', subresource: 'rotate'),
                icon: const Icon(Icons.vpn_key_outlined, size: 18),
                label: const LocalizedText('Rotate signing key'),
              ),
            const SizedBox(width: 4),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh, color: _accent),
              tooltip: context.strings.refresh,
            ),
          ],
        ),
        if (rotating) _buildRotateConfirm(context),
        if (!_loading && _error != null)
          ErrorStateCard(message: _error!, onRetry: _load, margin: EdgeInsets.zero),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 16),
            child: SkeletonListTile(itemCount: 3),
          ),
        if (!_loading && _error == null && _keys.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 8),
            child: EmptyState(compact: true, title: 'No keys found.'),
          ),
        if (!_loading && _error == null && _keys.isNotEmpty)
          _keysCard(context),
      ],
    );
  }

  /// 密钥列表卡：组色密钥图标 + SectionHeader（计数）+ AdminDataTable(compact)。
  Widget _keysCard(BuildContext context) {
    final keys = _keys;
    return Card(
      margin: const EdgeInsets.only(top: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(children: [
              Icon(Icons.vpn_key_outlined, size: 20, color: _accent),
              const SizedBox(width: 8),
              Expanded(child: SectionHeader(AppStrings.of(context).cryptoKeys, count: keys.length)),
            ]),
            const SizedBox(height: 12),
            AdminDataTable(
              density: TableDensity.compact,
              minWidth: 920,
              columns: [
                AdminDataColumn(
                  id: 'id', label: 'Key ID'.localized, width: 200, cardPrimary: true,
                  builder: (_, i) => TableCellText(_value(i, ['id', 'kid']), level: DataEmphasisLevel.primary),
                ),
                AdminDataColumn(
                  id: 'keyClass', label: 'Key class'.localized, cardDetail: true,
                  builder: (_, i) => TableCellText(_value(i, ['key_class', 'class']), muted: true),
                ),
                AdminDataColumn(
                  id: 'algorithm', label: 'Algorithm'.localized, cardDetail: true,
                  builder: (_, i) => TableCellText(_value(i, ['algorithm', 'alg']), muted: true),
                ),
                AdminDataColumn(
                  id: 'created', label: 'Created'.localized, cardDetail: true,
                  builder: (_, i) => TableCellText(_value(i, ['created_at', 'createdAt']), muted: true, maxLines: 2),
                ),
                AdminDataColumn(
                  id: 'status', label: 'Status'.localized,
                  builder: (_, i) => _statusChip(context, _value(i, ['status'])),
                ),
                AdminDataColumn(
                  id: 'actions', label: '', width: 120,
                  builder: (_, i) {
                    final status = _value(i, ['status']);
                    final id = _value(i, ['id', 'kid']);
                    if (status == 'compromised' || status == 'expired') {
                      return const SizedBox.shrink();
                    }
                    return TextButton(
                      onPressed: _mutating ? null : () => _compromise(id),
                      style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                      child: const LocalizedText('Compromise'),
                    );
                  },
                ),
              ],
              itemCount: keys.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _statusChip(BuildContext context, String status) => switch (status) {
    '' || 'active' => StatusChip.active(label: context.tr('Active')),
    'compromised' => StatusChip.failed(label: context.tr('Compromised')),
    'expired' => StatusChip.degraded(label: context.tr('Expired')),
    _ => StatusChip.unknown(label: status),
  };

  Widget _buildRotateConfirm(BuildContext context) => Card(
    color: AppColors.warning.withValues(alpha: 0.05),
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(children: [
            Icon(Icons.vpn_key_outlined, size: 20, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: LocalizedText(
                'Rotate the signing key?',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
              ),
            ),
          ]),
          const SizedBox(height: 8),
          const LocalizedText(
            'This endpoint rotates the active signing key; it does not rotate '
            'every encryption or credential key. Services may briefly reload '
            'the signing-key set.',
          ),
          const SizedBox(height: 12),
          OverflowBar(
            children: [
              OutlinedButton(
                onPressed: () => AdminRoute.go('crypto-keys'),
                child: const LocalizedText('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _mutating ? null : _rotate,
                child: const LocalizedText('Confirm rotation'),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  void _onPopState() {
    if (mounted) _handleRoute();
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'crypto-keys') return;
    if (route.subresource == 'rotate' && !_mutating) _rotate();
  }
}

