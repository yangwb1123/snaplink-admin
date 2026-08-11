import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_route.dart';
import 'package:sso_admin/i18n/app_strings.dart';

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

  bool get _available => widget.capabilities.hasAnyPathPrefix(_keysPath);
  bool get _canRotate =>
      widget.capabilities.has('POST', _rotatePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_rotatePath);

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
    widget.api.skipCache();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_keysPath);
      final items = data['keys'] as List? ?? [];
      if (!mounted) return;
      setState(() {
        _keys = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load crypto keys.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _compromise(String id) async {
    final reason = await _compromiseReason(id);
    if (reason == null) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final response = await widget.api.post(
        '$_keysPath/${Uri.encodeComponent(id)}/compromise',
        {'reason': reason},
      );
      if (!mounted) return;
      final key = response['key'] as Map?;
      final retirement =
          key?['retirement_status']?.toString() ?? 'not reported';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            'Key marked as compromised. Source retirement: $retirement.',
          ),
        ),
      );
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
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final response = await widget.api.post(_rotatePath);
      if (!mounted) return;
      final keyClass = response['key_class']?.toString() ?? 'unknown';
      final rollout = response['rollout_state']?.toString() ?? 'unknown';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            'Rotation completed for $keyClass. Rollout: $rollout.',
          ),
        ),
      );
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<String?> _compromiseReason(String id) async {
    final reason = TextEditingController();
    final confirmation = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const LocalizedText('Mark key as compromised?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LocalizedText(
              'The response will report whether source retirement completed, '
              'failed, is unsupported, or still needs verification. Type $id '
              'and provide an incident reference.',
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              decoration: InputDecoration(
                labelText: 'Reason / incident reference'.localized,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirmation,
              decoration: InputDecoration(labelText: id),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const LocalizedText('Cancel'),
          ),
          ListenableBuilder(
            listenable: Listenable.merge([reason, confirmation]),
            builder: (_, _) => FilledButton(
              onPressed:
                  reason.text.trim().isNotEmpty &&
                      confirmation.text.trim() == id
                  ? () => Navigator.pop(dialogContext, reason.text.trim())
                  : null,
              child: const LocalizedText('Compromise'),
            ),
          ),
        ],
      ),
    );
    reason.dispose();
    confirmation.dispose();
    return result;
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const Center(
        child: LocalizedText(
          'Crypto key management is not enabled on this replica.',
        ),
      );
    }
    final route = AdminRoute.current();
    final rotating = route.subresource == 'rotate';
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminBreadcrumb(),
        Row(
          children: [
            Text(
              AppStrings.of(context).cryptoKeys,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh'.localized,
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const LocalizedText('Retry'),
                ),
              ],
            ),
          ),
        if (rotating) _buildRotateConfirm(context),
        if (_canRotate && !rotating)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: OutlinedButton.icon(
              onPressed: _mutating
                  ? null
                  : () => AdminRoute.go('crypto-keys', subresource: 'rotate'),
              icon: const Icon(Icons.refresh),
              label: const LocalizedText('Rotate signing key'),
            ),
          ),
        if (_loading) const SkeletonListTile(itemCount: 4),
        if (!_loading && _keys.isEmpty)
          EmptyState(title: 'No keys found.'),
        if (!_loading && _keys.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: AdminDataTable(
              minWidth: 920,
              columns: [
                AdminDataColumn(
                  id: 'id',
                  label: 'Key ID',
                  width: 220,
                  cardPrimary: true,
                  builder: (_, i) => TableCellText(
                    _keys[i]['id']?.toString() ??
                        _keys[i]['kid']?.toString() ??
                        '',
                    level: DataEmphasisLevel.primary,
                  ),
                ),
                AdminDataColumn(
                  id: 'algorithm',
                  label: 'Algorithm',
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    _keys[i]['algorithm']?.toString() ??
                        _keys[i]['alg']?.toString() ??
                        '',
                    muted: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'created',
                  label: 'Created',
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    _keys[i]['created_at']?.toString() ??
                        _keys[i]['createdAt']?.toString() ??
                        '',
                    muted: true,
                    maxLines: 2,
                  ),
                ),
                AdminDataColumn(
                  id: 'status',
                  label: 'Status',
                  builder: (_, i) {
                    final status = _keys[i]['status']?.toString() ?? 'active';
                    return switch (status) {
                      'compromised' => StatusChip.failed(label: 'Compromised'),
                      'expired' => StatusChip.degraded(label: 'Expired'),
                      'active' => StatusChip.active(label: 'Active'),
                      _ => StatusChip.unknown(label: status),
                    };
                  },
                ),
                AdminDataColumn(
                  id: 'actions',
                  label: '',
                  width: 120,
                  builder: (_, i) {
                    final status = _keys[i]['status']?.toString() ?? 'active';
                    final id = _keys[i]['id']?.toString() ??
                        _keys[i]['kid']?.toString() ??
                        '';
                    if (status == 'compromised' || status == 'expired') {
                      return const SizedBox.shrink();
                    }
                    return TextButton(
                      onPressed: _mutating ? null : () => _compromise(id),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      child: const LocalizedText('Compromise'),
                    );
                  },
                ),
              ],
              itemCount: _keys.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
      ],
    );
  }

  Widget _buildRotateConfirm(BuildContext context) => Card(
    color: AppColors.warning.withValues(alpha: 0.05),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          const LocalizedText(
            'Rotate the signing key?',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
          ),
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
    if (route.subresource == 'rotate' && !_mutating) {
      _rotate();
    }
  }
}
