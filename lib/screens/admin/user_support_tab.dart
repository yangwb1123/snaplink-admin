import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'user_support_cards.dart';

part 'user_support_tab_view.dart';

/// Helpdesk controls for a Snaplink user account: destructive controls are
/// scoped to one subject, type-to-confirm with the user ID, and gated by the
/// runtime inventory. Lockout clearing stays keyed by client + identifier.
class UserSupportTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const UserSupportTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<UserSupportTab> createState() => _UserSupportTabState();
}

class _UserSupportTabState extends State<UserSupportTab>
    with _UserSupportTabView {
  static const _accountLockoutPath = '/api/v1/admin/account-lockout/clear';
  @override
  final _userCtrl = TextEditingController();
  @override
  final _passwordCtrl = TextEditingController();
  @override
  final _emailCtrl = TextEditingController();
  @override
  final _reasonCtrl = TextEditingController();
  @override
  Map<String, dynamic> _data = const {};
  @override
  String? _error;
  @override
  bool _loading = false;
  @override
  bool _mutating = false;
  @override
  String? _nextLifecycleState;

  /// 模块组色（system → indigo）：页头图标按组色上色（X7）。
  @override
  Color get _accent => adminModuleIconColor(AdminModuleId.userSupport);

  @override
  String? get _userId {
    final value = _userCtrl.text.trim();
    return value.isEmpty ? null : value;
  }

  @override
  bool _has(String suffix) {
    final prefix = '/api/v1/admin/$suffix';
    return widget.capabilities.hasAnyPathPrefix(prefix) ||
        SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(prefix);
  }

  bool _hasOperation(String method, String path) =>
      widget.capabilities.has(method, path) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (endpoint) => endpoint.method == method && endpoint.path == path,
      );

  @override
  bool get _canClearAccountLockout =>
      _hasOperation('POST', _accountLockoutPath);

  @override
  String _userPath(String suffix) =>
      '/api/v1/admin/users/${Uri.encodeComponent(_userId!)}$suffix';

  @override
  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _userCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<Map<String, dynamic>> _get(String suffix) =>
      widget.api.get(_userPath(suffix));

  @override
  Future<void> _load() async {
    if (_userId == null) {
      setState(() => _error = context.tr('Enter a user ID first.'));
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    // 可选的用户支持数据源：部分失败仅标记不可用，不阻断其余卡片。
    final spec = <(String, String)>[
      if (_has('users/:id/sessions')) ('sessions', '/sessions'),
      if (_has('users/:id/consents')) ('consents', '/consents'),
      if (_has('users/:id/mfa')) ('mfa', '/mfa'),
      if (_has('users/:id/lifecycle')) ('lifecycle', '/lifecycle'),
      if (_has('users/:id/password-reset-tokens'))
        ('passwordReset', '/password-reset-tokens'),
      if (_has('users/:id/email-change-tokens'))
        ('emailChange', '/email-change-tokens'),
    ];
    final entries = await Future.wait(
      spec.map((item) async {
        try {
          return (key: item.$1, data: await _get(item.$2), error: null);
        } catch (error) {
          return (key: item.$1, data: null, error: error);
        }
      }),
    );
    if (!mounted) return;
    final unavailable = entries
        .where((entry) => entry.error != null)
        .map((entry) => entry.key)
        .join(', ');
    setState(() {
      _data = {
        for (final entry in entries)
          if (entry.data != null) entry.key: entry.data!,
      };
      _error = unavailable.isEmpty
          ? null
          : context.tr('Some support data is unavailable: {sources}', {
              'sources': unavailable,
            });
      _loading = false;
    });
  }

  /// 危险操作统一走：类型确认弹窗（confirmText = 用户 ID）→ 请求 →
  /// SnackBar → 重载。带 {…} 占位符的文案在调用处先翻译（二次 tr 原样回退）。
  @override
  Future<void> _mutate(
    String title,
    String message,
    Future<Map<String, dynamic>> Function() request, {
    Map<String, Object?>? args,
    String? success,
  }) async {
    final userId = _userId;
    if (userId == null) return;
    final affected = context.tr('Affected user: {userId}', {'userId': userId});
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr(title),
      message: '${context.tr(message, args ?? const {})}\n\n$affected',
      confirmLabel: context.tr('Confirm for user'),
      destructive: true,
      confirmText: userId,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await request();
      if (!mounted) return;
      showAppSnackBar(
        context,
        content: LocalizedText(success ?? 'Operation completed.'),
      );
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _passwordCtrl.clear();
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  List<Map<String, dynamic>> _list(String key, String valueKey) {
    final values = _data[key]?[valueKey];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
  }

  /// 构建“撤销 XXX”危险操作：DELETE 目标路径 + 确认文案模板。
  @override
  DangerAction _dangerAction(
    String label,
    IconData icon,
    String suffix,
    String success,
  ) => DangerAction(
    label: label,
    confirmTitle: '$label?',
    confirmMessage: 'This action is immediate and cannot be undone.',
    icon: icon,
    onConfirmed: () => _mutate(
      '$label?',
      'This action is immediate and cannot be undone.',
      () => widget.api.delete(_userPath(suffix)),
      success: success,
    ),
  );
}
