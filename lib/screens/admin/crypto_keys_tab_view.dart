part of 'crypto_keys_tab.dart';

mixin _CryptoKeysTabView on State<CryptoKeysTab> {
  List<Map<String, dynamic>> get _keys;
  String? get _error;
  bool get _loading;
  bool get _mutating;
  Color get _accent;
  bool get _available;
  bool get _canRotate;

  String _value(int i, List<String> keys);
  Future<void> _load();
  Future<void> _compromise(String id);
  Future<void> _rotate();

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        title: 'Crypto key management is not enabled on this replica.',
      );
    }
    final rotating = AdminRoute.current().subresource == 'rotate';
    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminBreadcrumb(),
          AdminListHeader(
            title: AppStrings.of(context).cryptoKeys,
            subtitle:
                'Signing and encryption keys protecting authentication flows.',
            onRefresh: _load,
            actions: [
              if (_canRotate && !rotating)
                OutlinedButton.icon(
                  onPressed: _mutating
                      ? null
                      : () =>
                            AdminRoute.go('crypto-keys', subresource: 'rotate'),
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
            ErrorStateCard(
              message: _error!,
              onRetry: _load,
              margin: EdgeInsets.zero,
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SkeletonListTile(itemCount: 3),
            ),
          if (!_loading && _error == null && _keys.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: EmptyState(
                compact: true,
                title: 'No keys found.',
                subtitle:
                    'Signing keys are generated server-side; rotate from the header to start a new generation.'
                        .localized,
              ),
            ),
          if (!_loading && _error == null && _keys.isNotEmpty)
            _keysCard(context),
        ],
      ),
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
            Row(
              children: [
                Icon(Icons.vpn_key_outlined, size: 20, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: SectionHeader(
                    AppStrings.of(context).cryptoKeys,
                    count: keys.length,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AdminDataTable(
              density: TableDensity.compact,
              minWidth: 920,
              columns: [
                AdminDataColumn(
                  id: 'id',
                  label: 'Key ID'.localized,
                  width: 200,
                  cardPrimary: true,
                  builder: (_, i) => CopyableCell(
                    text: _value(i, ['id', 'kid']),
                    contextProvider: () => context,
                  ),
                ),
                AdminDataColumn(
                  id: 'keyClass',
                  label: 'Key class'.localized,
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    _value(i, ['key_class', 'class']),
                    muted: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'algorithm',
                  label: 'Algorithm'.localized,
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    _value(i, ['algorithm', 'alg']),
                    muted: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'created',
                  label: 'Created'.localized,
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    _value(i, ['created_at', 'createdAt']),
                    muted: true,
                    maxLines: 2,
                  ),
                ),
                AdminDataColumn(
                  id: 'status',
                  label: 'Status'.localized,
                  cardDetail: true,
                  builder: (_, i) =>
                      _statusChip(context, _value(i, ['status'])),
                ),
                AdminDataColumn(
                  id: 'actions',
                  label: '',
                  width: 120,
                  builder: (_, i) => _keyAction(context, i),
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

  Widget _keyAction(BuildContext context, int index) {
    final status = _value(index, ['status']);
    final id = _value(index, ['id', 'kid']);
    if (status == 'compromised' || status == 'expired') {
      return const SizedBox.shrink();
    }
    return TextButton(
      onPressed: _mutating ? null : () => _compromise(id),
      // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
      style: TextButton.styleFrom(
        foregroundColor: AppColors.semanticFor(
          Theme.of(context).brightness,
          AppColors.danger,
        ),
      ),
      child: const LocalizedText('Compromise'),
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
          Row(
            children: [
              Icon(Icons.vpn_key_outlined, size: 20, color: _accent),
              const SizedBox(width: 8),
              Expanded(
                child: LocalizedText(
                  'Rotate the signing key?',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
                ),
              ),
            ],
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
}
