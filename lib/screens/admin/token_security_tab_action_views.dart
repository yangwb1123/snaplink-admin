part of 'token_security_tab.dart';

extension _TokenSecurityTabActionViews on _TokenSecurityTabState {
  Widget _portfolioCard() {
    final portfolio = _data['portfolio']?['portfolio'] as Map? ?? const {};
    num metric(String k) => (portfolio[k] as num?) ?? 0;
    return _card('Token portfolio', Icons.account_balance_wallet_outlined, [
      MetricStrip(
        cards: [
          KeyMetricCard(
            label: 'Issued',
            value: metric('issued_total'),
            icon: Icons.token_outlined,
            color: _accent,
          ),
          KeyMetricCard(
            label: 'Introspections',
            value: metric('introspections'),
            icon: Icons.search_outlined,
            color: _accent,
          ),
          KeyMetricCard(
            label: 'Userinfo calls',
            value: metric('userinfo'),
            icon: Icons.person_outline,
            color: _accent,
          ),
        ],
      ),
    ]);
  }

  Widget _bulkRevokeCard() => _card(
    'Bounded refresh-token revocation',
    Icons.delete_sweep_outlined,
    [
      const LocalizedText(
        'Supply at least one boundary. Snaplink rejects an unscoped revoke and may require confirmation for large batches.',
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('bulk-revoke-subject'),
        controller: _subjectCtrl,
        decoration: InputDecoration(labelText: 'Subject (optional)'.localized),
      ),
      const SizedBox(height: 12),
      TextField(
        key: const Key('bulk-revoke-client'),
        controller: _clientCtrl,
        decoration: InputDecoration(
          labelText: 'Client ID (optional)'.localized,
        ),
      ),
      const SizedBox(height: 12),
      OutlinedButton(
        key: const Key('bulk-revoke-submit'),
        onPressed: _mutating || _mutationOutcomeUnknown ? null : _bulkRevoke,
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.semanticFor(
            Theme.of(context).brightness,
            AppColors.danger,
          ),
          side: BorderSide(
            color: AppColors.semanticFor(
              Theme.of(context).brightness,
              AppColors.danger,
            ),
          ),
        ),
        child: const LocalizedText('Bulk revoke refresh tokens'),
      ),
    ],
  );

  Widget _tempTokenCard() =>
      _card('Create temporary token', Icons.key_outlined, [
        TextField(
          key: const Key('temp-token-user-id'),
          controller: _createUserCtrl,
          decoration: InputDecoration(labelText: 'User ID'.localized),
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _createScopesCtrl,
          decoration: InputDecoration(
            labelText: 'Scopes (space-separated)'.localized,
          ),
        ),
        const SizedBox(height: 12),
        FilledButton(
          key: const Key('temp-token-submit'),
          onPressed: _mutating || _mutationOutcomeUnknown
              ? null
              : _createTempToken,
          child: const LocalizedText('Create temp token'),
        ),
        if (_tempToken != null) ...[
          const SizedBox(height: 8),
          const LocalizedText(
            'Save this token now. It will not be shown again.',
            style: TextStyle(color: AppColors.warning, fontSize: 12),
          ),
          SelectableText(
            _tempToken!,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              // ignore: invalid_use_of_protected_member
              onPressed: () => setState(() => _tempToken = null),
              child: const LocalizedText('I have saved it — clear token'),
            ),
          ),
        ],
      ]);

  Widget _revokeTokenCard() =>
      _card('Revoke token or session', Icons.remove_circle_outline, [
        // R31：2 项短枚举 → SegmentedButton（替代 Credential type 下拉）。
        SegmentedButton<String>(
          segments: const [
            ButtonSegment(
              value: 'session_id',
              label: LocalizedText('Session ID'),
            ),
            ButtonSegment(value: 'token', label: LocalizedText('Raw token')),
          ],
          selected: {_revokeKind},
          showSelectedIcon: false,
          onSelectionChanged: _mutating || _mutationOutcomeUnknown
              ? null
              : (selection) {
                  // ignore: invalid_use_of_protected_member
                  setState(() => _revokeKind = selection.first);
                },
        ),
        const SizedBox(height: 12),
        TextField(
          key: const Key('single-revoke-value'),
          controller: _revokeTokenCtrl,
          obscureText: _revokeKind == 'token',
          enableSuggestions: false,
          autocorrect: false,
          decoration: InputDecoration(
            labelText:
                (_revokeKind == 'token' ? 'Raw token' : 'Session ID').localized,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const Key('single-revoke-submit'),
          onPressed: _mutating || _mutationOutcomeUnknown ? null : _revokeToken,
          style: OutlinedButton.styleFrom(
            foregroundColor: AppColors.semanticFor(
              Theme.of(context).brightness,
              AppColors.danger,
            ),
            side: BorderSide(
              color: AppColors.semanticFor(
                Theme.of(context).brightness,
                AppColors.danger,
              ),
            ),
          ),
          child: const LocalizedText('Revoke token'),
        ),
      ]);

  /// 安全摘要（异常优先）：可疑/临期计数大数字，第一时间看到风险量级。
  Widget _securitySummary(BuildContext context) {
    final suspicious = _list('suspicious', 'findings').length;
    final expiring = _list('expiring', 'tokens').length;
    final sessions = (_data['sessions']?['total'] as num?) ?? 0;
    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 12),
      child: MetricStrip(
        cards: [
          KeyMetricCard(
            label: 'Anomalies',
            value: suspicious,
            icon: Icons.warning_amber_outlined,
            color: suspicious > 0 ? AppColors.danger : AppColors.muted,
          ),
          KeyMetricCard(
            label: 'Expiring',
            value: expiring,
            icon: Icons.timer_outlined,
            color: expiring > 0 ? AppColors.warning : AppColors.muted,
          ),
          KeyMetricCard(
            label: 'Sessions',
            value: sessions,
            icon: Icons.devices_outlined,
            color: AppColors.muted,
          ),
        ],
      ),
    );
  }
}
