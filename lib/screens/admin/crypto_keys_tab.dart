import 'package:flutter/material.dart';
import 'package:sso_admin/api/admin_paths.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';

part 'crypto_keys_tab_view.dart';

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

class _CryptoKeysTabState extends State<CryptoKeysTab> with _CryptoKeysTabView {
  static const _keysPath = AdminPaths.cryptoKeys;
  static const _rotatePath = '/api/v1/admin/keys/rotate';
  @override
  List<Map<String, dynamic>> _keys = const [];
  @override
  String? _error;
  @override
  bool _loading = false;
  @override
  bool _mutating = false;

  /// 请求序号：快速连续刷新时丢弃过期响应（R12 竞态防护）。
  int _reqSeq = 0;
  late final void Function() _cancelPopState;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  @override
  Color get _accent => adminModuleIconColor(AdminModuleId.cryptoKeys);

  @override
  bool get _available => widget.capabilities.hasAnyPathPrefix(_keysPath);
  @override
  bool get _canRotate =>
      widget.capabilities.has('POST', _rotatePath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_rotatePath);

  /// 首个命中的字段值（兼容新旧字段命名；API 值一律走 Text，X1/X10）。
  @override
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

  @override
  Future<void> _load() async {
    if (!_available) return;
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getStaleWhileRevalidate(
        _keysPath,
        onRefresh: (fresh) {
          if (mounted && seq == _reqSeq) {
            setState(() => _applyKeys(fresh));
          }
        },
      );
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _applyKeys(data);
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted && seq == _reqSeq) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && seq == _reqSeq) {
        setState(() {
          _error = 'Could not load crypto keys.';
          _loading = false;
        });
      }
    }
  }

  /// 缓存先渲染：命中时立即展示缓存行，后台刷新到位后再次渲染（R2）。
  void _applyKeys(Map<String, dynamic> data) {
    final items = data['keys'] as List? ?? [];
    _keys = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  @override
  Future<void> _compromise(String id) async {
    final reason = await _compromiseReason(id);
    if (reason == null) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final response = await widget.api.post(
        AdminPaths.cryptoKeyCompromise(id),
        {'reason': reason},
      );
      if (!mounted) return;
      final retirement =
          (response['key'] as Map?)?['retirement_status']?.toString() ??
          'not reported';
      showAppSnackBar(
        context,
        content: LocalizedText(
          'Key marked as compromised. Source retirement: {retirement}.',
          args: {'retirement': retirement},
        ),
      );
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
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
      showAppSnackBar(
        context,
        content: LocalizedText(
          'Rotation completed for {keyClass}. Rollout: {rollout}.',
          args: {'keyClass': keyClass, 'rollout': rollout},
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
    final confirm = TextEditingController();
    final result = await showDialog<String>(
      context: context,
      // 标记密钥受损属破坏性操作：不允许 barrier/Escape 绕过确认。
      barrierDismissible: false,
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
            LocalizedText(
              'Type {id} and provide an incident reference.',
              args: {'id': id},
            ),
            const SizedBox(height: 12),
            TextField(
              controller: reason,
              autofocus: true,
              decoration: InputDecoration(
                labelText: 'Reason / incident reference'.localized,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: confirm,
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
            listenable: Listenable.merge([reason, confirm]),
            builder: (_, _) => FilledButton(
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              onPressed:
                  reason.text.trim().isNotEmpty && confirm.text.trim() == id
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

  void _onPopState() {
    if (mounted) _handleRoute();
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'crypto-keys') return;
    if (route.subresource == 'rotate' && !_mutating) _rotate();
  }
}
