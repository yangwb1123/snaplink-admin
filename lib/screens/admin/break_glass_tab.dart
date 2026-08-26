import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'admin_navigation.dart';
import 'admin_ops_helpers.dart';
import 'break_glass_widgets.dart';

part 'break_glass_tab_view.dart';

/// Break Glass (emergency access) management tab.
///
/// Allows operators to create, list, approve, revoke, and impersonate
/// break-glass sessions for emergency support access.
class BreakGlassTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const BreakGlassTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<BreakGlassTab> createState() => _BreakGlassTabState();
}

class _BreakGlassTabState extends State<BreakGlassTab> with _BreakGlassTabView {
  static const _basePath = '/api/v1/admin/break-glass';

  @override
  final _targetCtrl = TextEditingController();
  @override
  final _reasonCtrl = TextEditingController();
  @override
  String _scope = 'readonly';
  @override
  String? _ttl;
  @override
  bool _requireApproval = false;
  String? _tenantId;

  @override
  List<Map<String, dynamic>> _sessions = const [];
  @override
  String? _loadError; // 加载错误 → 带 Retry 的横幅（X4）
  @override
  String? _actionError; // 校验/提交错误 → 表单内联提示
  @override
  bool _loading = false;
  @override
  bool _mutating = false;
  @override
  bool _mutationOutcomeUnknown = false;

  /// 请求序号：快速连续刷新时丢弃过期响应（R12 竞态防护）。
  int _reqSeq = 0;
  late final void Function() _cancelPopState;

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  @override
  Color get _accent => adminModuleIconColor(AdminModuleId.emergencyAccess);

  @override
  bool get _available => widget.capabilities.hasAnyPathPrefix(_basePath);

  @override
  void initState() {
    super.initState();
    _handleRoute();
    _load();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    // The dashboard mounts this tab under the "emergency-access" module id;
    // the API base path is /api/v1/admin/break-glass.
    if (route.module != AdminModuleId.emergencyAccess) return;
    if (route.isNew) {
      _create();
    }
  }

  @override
  void dispose() {
    _cancelPopState();
    _targetCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  @override
  Future<void> _load() async {
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final data = await widget.api.get(_basePath);
      final items =
          data['sessions'] ??
          data['grants'] ??
          data['items'] ??
          data['break_glass'] ??
          [];
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _sessions = (items as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _loading = false;
      });
    } catch (e) {
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _loadError = e is SnaplinkAdminApiError
            ? e.toString()
            : 'Could not load break-glass sessions.';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    if (_mutationOutcomeUnknown) return;
    final target = _targetCtrl.text.trim();
    final reason = _reasonCtrl.text.trim();
    if (target.isEmpty || reason.isEmpty) {
      setState(() => _actionError = 'Target user and reason are required.');
      return;
    }
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Create emergency-access grant?',
      message: context.tr(
        'Create a {scope} break-glass grant for {target}. {approval} Reason: {reason}',
        {
          'scope': _scope,
          'target': target,
          'approval': context.tr(
            _requireApproval
                ? 'Requires independent approval.'
                : 'May become active immediately.',
          ),
          'reason': reason,
        },
      ),
      confirmLabel: 'Create grant',
      destructive: true,
      confirmText: target,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _actionError = null;
    });
    try {
      await widget.api.post(_basePath, {
        'target_user_id': target,
        'reason': reason,
        'scope': _scope,
        if (_ttl != null && _ttl!.isNotEmpty)
          'ttl_seconds': int.tryParse(_ttl!),
        if (_requireApproval) 'require_approval': true,
        if (_tenantId != null && _tenantId!.isNotEmpty) 'tenant_id': _tenantId,
      });
      if (!mounted) return;
      _targetCtrl.clear();
      _reasonCtrl.clear();
      showAppSnackBar(
        context,
        content: LocalizedText('Break-glass session created.'),
      );
      if (mounted) AdminRoute.back('emergency-access');
      await _load();
    } catch (e) {
      _recordMutationError(e);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Future<void> _approve(String id) async {
    if (_mutationOutcomeUnknown) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Approve?',
      message: 'Approve this break-glass request?',
      confirmLabel: 'Approve',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _actionError = null;
    });
    try {
      await widget.api.post('$_basePath/${Uri.encodeComponent(id)}/approve');
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText('Break-glass approved.'));
      await _load();
    } catch (e) {
      _recordMutationError(e);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Future<void> _revoke(String id) async {
    if (_mutationOutcomeUnknown) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke?',
      message: BreakGlassRevocationCopy.confirmation,
      confirmLabel: 'Revoke',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _actionError = null;
    });
    try {
      final response = await widget.api.delete(
        '$_basePath/${Uri.encodeComponent(id)}',
      );
      if (!mounted) return;
      final copy = BreakGlassRevocationCopy.resultCopy(response);
      showAppSnackBar(
        context,
        content: LocalizedText(copy.key, args: copy.args),
      );
      await _load();
    } catch (e) {
      _recordMutationError(e);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Future<void> _impersonate(String id) async {
    if (_mutationOutcomeUnknown) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Impersonate?',
      message: 'Impersonate the target user? This action is audited.',
      confirmLabel: 'Impersonate',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _actionError = null;
    });
    try {
      final data = await widget.api.post(
        '$_basePath/${Uri.encodeComponent(id)}/impersonate',
      );
      if (!mounted) return;
      final token =
          data['access_token']?.toString() ?? data['token']?.toString() ?? '';
      if (token.isNotEmpty) {
        // 一次性展示：仅此对话框持有 token，控制台不保留。
        await showDialog<void>(
          context: context,
          barrierDismissible: false,
          builder: (c) => AlertDialog(
            icon: Icon(Icons.emergency_outlined, color: _accent, size: 32),
            title: const LocalizedText('Impersonation token'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LocalizedText(
                  'This bearer is shown once and is not retained by the console.',
                ),
                const SizedBox(height: 12),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Theme.of(c).colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    token,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(c),
                child: const LocalizedText('I have saved it'),
              ),
            ],
          ),
        );
      } else {
        setState(() {
          _mutationOutcomeUnknown = true;
          _actionError = context.tr(
            'Snaplink accepted the impersonation request but did not return a bearer. Do not retry until server state is verified.',
          );
        });
      }
      await _load();
    } catch (e) {
      _recordMutationError(e);
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _recordMutationError(Object error) {
    if (!mounted) return;
    final unknown =
        error is! SnaplinkAdminApiError ||
        AdminOpsHelpers.isAmbiguousWriteStatus(error.status);
    setState(() {
      _mutationOutcomeUnknown = _mutationOutcomeUnknown || unknown;
      _actionError = unknown
          ? context.tr(
              'The break-glass write result is unknown. Reconcile the session state before retrying.',
            )
          : error.toString();
    });
  }

  @override
  Future<void> _acknowledgeUnknownOutcome() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Break-glass state reconciled?',
      message:
          'Confirm only after checking the emergency-access session in a safe read. This unlocks break-glass writes; it does not prove the previous request failed.',
      confirmLabel: 'Unlock break-glass writes',
      destructive: true,
      confirmText: 'RECONCILED',
    );
    if (!confirmed || !mounted) return;
    setState(() {
      _mutationOutcomeUnknown = false;
      _actionError = context.tr(
        'Break-glass reconciliation acknowledged. Review the target before sending another write.',
      );
    });
  }
}
