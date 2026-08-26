part of 'client_detail_screen.dart';

extension _ClientDetailScreenView on _ClientDetailScreenState {
  Widget _buildClientDetail(BuildContext context) {
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
          : _error != null && !_secretRotationOutcomeUnknown
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
                        if (_secretRotationOutcomeUnknown)
                          AdminOpsHelpers.unknownOutcomeCard(
                            context,
                            onAcknowledge: _mutating
                                ? null
                                : _acknowledgeSecretRotation,
                          ),
                        if (_error != null) ErrorStateCard(message: _error!),
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
    final scopes =
        ((_client?['allowed_scopes'] ?? _client?['scopes']) as List? ??
                const [])
            .length;
    final secretExpiry = clientSecretExpiryUnix(_client);
    final remaining = secretExpiry <= 0
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            secretExpiry * 1000,
            isUtc: true,
          ).toLocal().difference(DateTime.now());
    final cards = <KeyMetricCard>[
      KeyMetricCard(
        label: 'Grant types',
        value: grantTypes,
        icon: Icons.tune,
        color: AppColors.accentBlue,
      ),
      KeyMetricCard(
        label: 'Scopes',
        value: scopes,
        icon: Icons.lock_open_outlined,
        color: AppColors.primary,
      ),
      if (remaining == null)
        KeyMetricCard(
          label: 'Secret expiry',
          value: 0,
          caption: 'Never expires',
          icon: Icons.schedule_outlined,
          color: AppColors.muted,
        )
      else
        KeyMetricCard(
          label: 'Secret expiry',
          value: remaining.isNegative ? 0 : remaining.inDays,
          icon: Icons.schedule_outlined,
          color: AppColors.warning,
        ),
    ];
    return MetricStrip(
      cards: [
        for (final metric in clientDetailMetricOrder(widget.persona))
          cards[metric.index],
      ],
    );
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
                    Text(
                      _client?['name']?.toString() ?? widget.clientId,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    LocalizedText(
                      'ID: {id}',
                      args: {'id': _client?['id'] ?? widget.clientId},
                    ),
                  ],
                ),
              ),
              _statusChip(),
            ],
          ),
          const Divider(),
          InfoRow(
            label: 'Client ID',
            value:
                _client?['id']?.toString() ??
                _client?['client_id']?.toString() ??
                widget.clientId,
            level: DataEmphasisLevel.secondary,
            // R36：激活 InfoRow 内置复制按钮（与表格 CopyableCell / DCR
            // CopyableDcrValue 同数据同能力）。
            copyValue:
                _client?['id']?.toString() ??
                _client?['client_id']?.toString() ??
                widget.clientId,
          ),
          InfoRow(
            label: 'Redirect URIs',
            value: (_client?['redirect_uris'] as List?)?.join(', ') ?? '—',
            level: DataEmphasisLevel.tertiary,
          ),
          InfoRow(
            label: 'Login page URI',
            value:
                _client?['login_page_uri']?.toString() ??
                _client?['loginPageUri']?.toString() ??
                '—',
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
            value:
                ((_client?['allowed_scopes'] ?? _client?['scopes']) as List?)
                    ?.join(', ') ??
                '—',
            level: DataEmphasisLevel.tertiary,
          ),
          InfoRow(
            label: 'Authenticators',
            value:
                (_client?['allowed_authenticators'] as List?)?.join(', ') ??
                'Any',
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
    final status =
        _client?['status']?.toString() ??
        (_client?['active'] == true ? 'active' : 'inactive');
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
          LocalizedText(
            'Actions',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              if (_client?['status'] == 'pending')
                _actionButton(
                  icon: Icons.check_circle_outline,
                  label: 'Approve',
                  color: AppColors.success,
                  primary: true,
                  onPressed: () => _doAction('approve'),
                ),
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
              _actionButton(
                icon: Icons.key,
                label: 'Rotate Secret',
                color: AppColors.warning,
                primary: true,
                onPressed: () => _rotateSecret(context),
              ),
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
      final onColor = color.computeLuminance() > 0.5
          ? Colors.black87
          : Colors.white;
      return FilledButton.icon(
        onPressed: _mutating || _secretRotationOutcomeUnknown
            ? null
            : onPressed,
        icon: Icon(icon),
        label: LocalizedText(label),
        style: FilledButton.styleFrom(
          backgroundColor: color,
          foregroundColor: onColor,
        ),
      );
    }
    return OutlinedButton.icon(
      onPressed: _mutating || _secretRotationOutcomeUnknown ? null : onPressed,
      icon: Icon(icon),
      label: LocalizedText(label),
      style: OutlinedButton.styleFrom(foregroundColor: color),
    );
  }
}
