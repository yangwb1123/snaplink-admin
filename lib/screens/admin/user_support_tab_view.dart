part of 'user_support_tab.dart';

mixin _UserSupportTabView on State<UserSupportTab> {
  TextEditingController get _userCtrl;
  TextEditingController get _passwordCtrl;
  TextEditingController get _emailCtrl;
  TextEditingController get _reasonCtrl;
  Map<String, dynamic> get _data;
  String? get _error;
  bool get _loading;
  bool get _mutating;
  String? get _nextLifecycleState;
  set _nextLifecycleState(String? value);
  Color get _accent;
  String? get _userId;
  bool get _canClearAccountLockout;
  bool _has(String suffix);
  String _userPath(String suffix);
  Future<void> _load();
  Future<void> _mutate(
    String title,
    String message,
    Future<Map<String, dynamic>> Function() request, {
    Map<String, Object?>? args,
    String? success,
  });
  List<Map<String, dynamic>> _list(String key, String valueKey);
  DangerAction _dangerAction(
    String label,
    IconData icon,
    String suffix,
    String success,
  );

  @override
  Widget build(BuildContext context) {
    final loaded = _userId != null && !_loading;
    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
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
            ErrorStateCard(
              message: _error!,
              onRetry: _load,
              margin: EdgeInsets.zero,
            ),
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
                    child: LocalizedText(
                      'Enter a user ID to load support data.',
                    ),
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
      ),
    );
  }

  Widget _header(BuildContext context) => Row(
    children: [
      Icon(Icons.support_agent_outlined, color: _accent),
      const SizedBox(width: 8),
      Expanded(
        child: Semantics(
          container: true,
          header: true,
          child: Text(
            AppStrings.of(context).userSupport,
            style: Theme.of(context).textTheme.headlineSmall,
          ),
        ),
      ),
      IconButton(
        onPressed: _loading ? null : _load,
        tooltip: 'Refresh'.localized,
        icon: const Icon(Icons.refresh),
      ),
    ],
  );

  Widget _consentsCard() {
    final consents = _list('consents', 'consents');
    return ConsentsCard(
      consents: consents,
      userId: _userId ?? '',
      mutating: _mutating,
      onRevoke: (clientId) => _mutate(
        'Revoke consent?',
        'Remove this application grant for {userId}?',
        () => widget.api.delete(
          '${_userPath('/consents')}/${Uri.encodeComponent(clientId)}',
        ),
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
        () => widget.api.post(_userPath('/lifecycle'), {
          'state': _nextLifecycleState,
          'reason': _reasonCtrl.text.trim(),
        }),
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
