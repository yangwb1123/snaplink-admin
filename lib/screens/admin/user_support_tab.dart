import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'user_support_cards.dart';
import 'package:sso_admin/i18n/app_strings.dart';

/// Helpdesk controls for a Snaplink user account.
///
/// Every destructive control is scoped to one subject, requires a confirmation
/// dialog, and appears only when the related optional Snaplink feature is
/// present in the runtime inventory.
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

  bool get _canClearAccountLockout =>
      _hasOperation('POST', _accountLockoutPath);
  String _userPath(String suffix) =>
      '/api/v1/admin/users/${Uri.encodeComponent(_userId!)}$suffix';
  @override
  void dispose() {
    _userCtrl.dispose();
    _passwordCtrl.dispose();
    _emailCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    if (_userId == null) {
      setState(() => _error = 'Enter a user ID first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    final requests = <String, Future<Map<String, dynamic>>>{
      if (_has('users/:id/sessions'))
        'sessions': widget.api.get(_userPath('/sessions')),
      if (_has('users/:id/consents'))
        'consents': widget.api.get(_userPath('/consents')),
      if (_has('users/:id/mfa')) 'mfa': widget.api.get(_userPath('/mfa')),
      if (_has('users/:id/lifecycle'))
        'lifecycle': widget.api.get(_userPath('/lifecycle')),
      if (_has('users/:id/password-reset-tokens'))
        'passwordReset': widget.api.get(_userPath('/password-reset-tokens')),
      if (_has('users/:id/email-change-tokens'))
        'emailChange': widget.api.get(_userPath('/email-change-tokens')),
    };
    final entries = await Future.wait(
      requests.entries.map((entry) async {
        try {
          return (key: entry.key, data: await entry.value, error: null);
        } catch (error) {
          return (key: entry.key, data: null, error: error);
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
          : 'Some support data is unavailable: $unavailable.';
      _loading = false;
    });
  }

  Future<void> _mutate(
    String title,
    String message,
    Future<Map<String, dynamic>> Function() request, {
    String? success,
  }) async {
    final userId = _userId;
    if (userId == null ||
        !await ConfirmDialog.show(
          context,
          title: title,
          message: '$message\n\nAffected user: $userId',
          confirmLabel: 'Confirm for user',
          destructive: true,
          confirmText: userId,
        )) {
      return;
    }
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await request();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(success ?? 'Operation completed.')),
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

  @override
  Widget build(BuildContext context) {
    final loaded = _userId != null && !_loading;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminBreadcrumb(),
        Row(
          children: [
            Text(
              AppStrings.of(context).userSupport,
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('support-user-id'),
          controller: _userCtrl,
          decoration: const InputDecoration(labelText: 'User ID'),
          onSubmitted: (_) => _load(),
        ),
        const SizedBox(height: 12),
        FilledButton(
          onPressed: _loading ? null : _load,
          child: const Text('Load account support data'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_canClearAccountLockout) AccountLockoutCard(api: widget.api),
        if (loaded) ...[
          if (_has('users/:id/sessions')) _sessionsCard(context),
          if (_has('users/:id/consents')) _consentsCard(context),
          if (_has('users/:id/mfa')) _mfaCard(context),
          if (_has('users/:id/lifecycle')) _lifecycleCard(context),
          _credentialRecoveryCard(context),
        ],
      ],
    );
  }

  Widget _sessionsCard(BuildContext context) {
    final sessions = _list('sessions', 'sessions');
    return SessionsCard(sessions: sessions);
  }

  Widget _consentsCard(BuildContext context) {
    final consents = _list('consents', 'consents');
    return ConsentsCard(
      consents: consents,
      userId: _userId ?? '',
      mutating: _mutating,
      onRevoke: (clientId) => _mutate(
        'Revoke consent?',
        'Remove this application grant for ${_userId!}?',
        () => widget.api.delete(
          '${_userPath('/consents')}/${Uri.encodeComponent(clientId)}',
        ),
        success: 'Consent revoked.',
      ),
    );
  }

  Widget _mfaCard(BuildContext context) {
    final factors = _list('mfa', 'factors');
    return MfaFactorsCard(
      factors: factors,
      mutating: _mutating,
      canResetRecoveryCodes: _has('users/:id/mfa/recovery-codes'),
      onRemove: (factorId) => _mutate(
        'Remove second factor?',
        'The user will no longer be able to use this factor.',
        () => widget.api.delete(
          '${_userPath('/mfa')}/${Uri.encodeComponent(factorId)}',
        ),
        success: 'Second factor removed.',
      ),
      onResetRecoveryCodes: () => _mutate(
        'Reset recovery codes?',
        'All remaining recovery codes will be invalidated.',
        () => widget.api.post(_userPath('/mfa/recovery-codes')),
      ),
    );
  }

  Widget _lifecycleCard(BuildContext context) {
    final lifecycle = _data['lifecycle'] ?? const <String, dynamic>{};
    return LifecycleCard(
      lifecycleData: lifecycle,
      mutating: _mutating,
      nextState: _nextLifecycleState,
      onStateChanged: (state) => setState(() => _nextLifecycleState = state),
      reasonController: _reasonCtrl,
      onApply: () => _mutate(
        'Change lifecycle state?',
        'Transition ${_userId!} to $_nextLifecycleState?',
        () => widget.api.post(_userPath('/lifecycle'), {
          'state': _nextLifecycleState,
          'reason': _reasonCtrl.text.trim(),
        }),
      ),
    );
  }

  Widget _credentialRecoveryCard(BuildContext context) {
    final dangerActions = <DangerAction>[
      if (_has('users/:id/refresh-tokens'))
        DangerAction(
          label: 'Revoke all refresh tokens',
          confirmTitle: 'Revoke all refresh tokens?',
          confirmMessage: 'This action is immediate and cannot be undone.',
          onConfirmed: () => _mutate(
            'Revoke all refresh tokens?',
            'This action is immediate and cannot be undone.',
            () => widget.api.delete(_userPath('/refresh-tokens')),
            success: 'Refresh tokens revoked.',
          ),
        ),
      if (_has('users/:id/device-secrets'))
        DangerAction(
          label: 'Revoke device secrets',
          confirmTitle: 'Revoke device secrets?',
          confirmMessage: 'This action is immediate and cannot be undone.',
          onConfirmed: () => _mutate(
            'Revoke device secrets?',
            'This action is immediate and cannot be undone.',
            () => widget.api.delete(_userPath('/device-secrets')),
            success: 'Device secrets revoked.',
          ),
        ),
      if (_has('users/:id/password-reset-tokens'))
        DangerAction(
          label: 'Revoke password reset links',
          confirmTitle: 'Revoke password reset links?',
          confirmMessage: 'This action is immediate and cannot be undone.',
          onConfirmed: () => _mutate(
            'Revoke password reset links?',
            'This action is immediate and cannot be undone.',
            () => widget.api.delete(_userPath('/password-reset-tokens')),
            success: 'Password reset links revoked.',
          ),
        ),
      if (_has('users/:id/email-change-tokens'))
        DangerAction(
          label: 'Revoke email change links',
          confirmTitle: 'Revoke email change links?',
          confirmMessage: 'This action is immediate and cannot be undone.',
          onConfirmed: () => _mutate(
            'Revoke email change links?',
            'This action is immediate and cannot be undone.',
            () => widget.api.delete(_userPath('/email-change-tokens')),
            success: 'Email change links revoked.',
          ),
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
      onSetPassword: _passwordCtrl.text.isEmpty
          ? null
          : () => _mutate(
              'Set a new password?',
              'This immediately replaces the user password.',
              () => widget.api.post(_userPath('/password'), {
                'new_password': _passwordCtrl.text,
              }),
              success: 'Password reset.',
            ),
      onSetEmail: _emailCtrl.text.trim().isEmpty
          ? null
          : () => _mutate(
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
