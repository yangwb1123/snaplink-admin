import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'user_support_cards.dart';

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

class _UserSupportTabState extends State<UserSupportTab> {
  static const _accountLockoutPath = '/api/v1/admin/account-lockout/clear';
  final _userCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  Map<String, dynamic> _data = const {};
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  String? _nextLifecycleState;

  /// 模块组色（system → indigo）：页头图标按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.userSupport);

  String? get _userId {
    final value = _userCtrl.text.trim();
    return value.isEmpty ? null : value;
  }

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

  bool get _canClearAccountLockout => _hasOperation('POST', _accountLockoutPath);

  String _userPath(String suffix) =>
      '/api/v1/admin/users/${Uri.encodeComponent(_userId!)}$suffix';

  @override
  void initState() {
    super.initState();
    // 输入即重建：凭据恢复卡的按钮可用态随输入实时刷新。
    _passwordCtrl.addListener(_onSupportFieldChanged);
    _emailCtrl.addListener(_onSupportFieldChanged);
  }
  void _onSupportFieldChanged() => setState(() {});
  @override
  void dispose() {
    _passwordCtrl.removeListener(_onSupportFieldChanged);
    _emailCtrl.removeListener(_onSupportFieldChanged);
    _userCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }
  Future<Map<String, dynamic>> _get(String suffix) =>
      widget.api.get(_userPath(suffix));

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
    final entries = await Future.wait(spec.map((item) async {
      try {
        return (key: item.$1, data: await _get(item.$2), error: null);
      } catch (error) {
        return (key: item.$1, data: null, error: error);
      }
    }));
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: LocalizedText(success ?? 'Operation completed.')),
      );
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } finally {
      _passwordCtrl.clear();
      if (mounted) setState(() => _mutating = false);
    }
  }
  List<Map<String, dynamic>> _list(String key, String valueKey) {
    final values = _data[key]?[valueKey];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
  }
  /// 构建“撤销 XXX”危险操作：DELETE 目标路径 + 确认文案模板。
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
  @override
  Widget build(BuildContext context) {
    final loaded = _userId != null && !_loading;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        _header(context),
        const SizedBox(height: 12),
        TextField(
          key: const Key('support-user-id'),
          controller: _userCtrl,
          decoration: InputDecoration(labelText: 'User ID'.localized),
          onSubmitted: (_) => _load(),
        ),
        const SizedBox(height: 12),
        FilledButton.icon(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.search),
          label: const LocalizedText('Load account support data'),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          ErrorStateCard(message: _error!, onRetry: _load, margin: EdgeInsets.zero),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: SkeletonListTile(itemCount: 3),
          ),
        if (_userId == null && !_loading)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: Row(
              children: [
                Icon(Icons.support_agent_outlined, size: 18, color: _accent),
                const SizedBox(width: 8),
                const Expanded(
                  child: LocalizedText('Enter a user ID to load support data.'),
                ),
              ],
            ),
          ),
        if (_canClearAccountLockout) AccountLockoutCard(api: widget.api),
        if (loaded) ...[
          if (_has('users/:id/sessions'))
            SessionsCard(sessions: _list('sessions', 'sessions')),
          if (_has('users/:id/consents')) _consentsCard(),
          if (_has('users/:id/mfa')) _mfaCard(),
          if (_has('users/:id/lifecycle')) _lifecycleCard(),
          _credentialRecoveryCard(),
        ],
      ],
    );
  }

  Widget _header(BuildContext context) => Row(children: [
    Icon(Icons.support_agent_outlined, color: _accent),
    const SizedBox(width: 8),
    Expanded(child: Semantics(container: true, header: true, child: Text(AppStrings.of(context).userSupport, style: Theme.of(context).textTheme.headlineSmall))),
    IconButton(onPressed: _loading ? null : _load, tooltip: 'Refresh'.localized, icon: const Icon(Icons.refresh)),
  ]);

  Widget _consentsCard() {
    final consents = _list('consents', 'consents');
    return ConsentsCard(
      consents: consents,
      userId: _userId ?? '',
      mutating: _mutating,
      onRevoke: (clientId) => _mutate(
        'Revoke consent?',
        'Remove this application grant for {userId}?',
        () => widget.api.delete('${_userPath('/consents')}/${Uri.encodeComponent(clientId)}'),
        args: {'userId': _userId!},
        success: 'Consent revoked.',
      ),
    );
  }

  Widget _mfaCard() {
    final factors = _list('mfa', 'factors');
    return MfaFactorsCard(
      factors: factors,
      mutating: _mutating,
      canResetRecoveryCodes: _has('users/:id/mfa/recovery-codes'),
      onRemove: (factorId) => _mutate(
        'Remove second factor?',
        'The user will no longer be able to use this factor.',
        () => widget.api.delete('${_userPath('/mfa')}/${Uri.encodeComponent(factorId)}'),
        success: 'Second factor removed.',
      ),
      onResetRecoveryCodes: () => _mutate(
        'Reset recovery codes?',
        'All remaining recovery codes will be invalidated.',
        () => widget.api.post(_userPath('/mfa/recovery-codes')),
      ),
    );
  }

  Widget _lifecycleCard() {
    final lifecycle = _data['lifecycle'] ?? const <String, dynamic>{};
    return LifecycleCard(
      lifecycleData: lifecycle,
      mutating: _mutating,
      nextState: _nextLifecycleState,
      onStateChanged: (state) => setState(() => _nextLifecycleState = state),
      reasonController: _reasonCtrl,
      onApply: () => _mutate(
        'Change lifecycle state?',
        'Transition {userId} to {state}?',
        () => widget.api.post(_userPath('/lifecycle'), {'state': _nextLifecycleState, 'reason': _reasonCtrl.text.trim()}),
        args: {'userId': _userId!, 'state': _nextLifecycleState ?? ''},
      ),
    );
  }

  Widget _credentialRecoveryCard() {
    final dangerActions = <DangerAction>[
      if (_has('users/:id/refresh-tokens'))
        _dangerAction(
          'Revoke all refresh tokens',
          Icons.loop_outlined,
          '/refresh-tokens',
          'Refresh tokens revoked.',
        ),
      if (_has('users/:id/device-secrets'))
        _dangerAction(
          'Revoke device secrets',
          Icons.phonelink_lock_outlined,
          '/device-secrets',
          'Device secrets revoked.',
        ),
      if (_has('users/:id/password-reset-tokens'))
        _dangerAction(
          'Revoke password reset links',
          Icons.password_outlined,
          '/password-reset-tokens',
          'Password reset links revoked.',
        ),
      if (_has('users/:id/email-change-tokens'))
        _dangerAction(
          'Revoke email change links',
          Icons.alternate_email_outlined,
          '/email-change-tokens',
          'Email change links revoked.',
        ),
    ];
    return CredentialRecoveryCard(
      passwordResetData: _data['passwordReset'],
      emailChangeData: _data['emailChange'],
      mutating: _mutating,
      canSetPassword: _has('users/:id/password'),
      canSetEmail: _has('users/:id/email'),
      passwordController: _passwordCtrl,
      emailController: _emailCtrl,
      onSetPassword: () => _mutate(
        'Set a new password?',
        'This immediately replaces the user password.',
        () => widget.api.post(_userPath('/password'), {
          'new_password': _passwordCtrl.text,
        }),
        success: 'Password reset.',
      ),
      onSetEmail: () => _mutate(
        'Force-set email?',
        'This bypasses the self-service email verification flow.',
        () => widget.api.post(_userPath('/email'), {
          'email': _emailCtrl.text.trim(),
        }),
      ),
      dangerActions: dangerActions,
    );
  }
}

