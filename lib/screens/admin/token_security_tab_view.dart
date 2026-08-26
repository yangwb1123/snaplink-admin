part of 'token_security_tab.dart';

extension _TokenSecurityTabView on _TokenSecurityTabState {
  /// 模块强调色（security 组 rose）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.tokenSecurity);

  SectionDef _def(String id, String label, IconData icon) =>
      SectionDef(id, label, icon, color: _accent);

  List<SectionDef> get _sectionDefinitions => [
    _def('all', 'All', Icons.dashboard_outlined),
    if (_supports('GET', _TokenSecurityTabState._paths['portfolio']!))
      _def('portfolio', 'Portfolio', Icons.account_balance_wallet),
    if (_supports('GET', _TokenSecurityTabState._paths['suspicious']!))
      _def('suspicious', 'Anomalies', Icons.warning_amber_outlined),
    if (_supports('GET', _TokenSecurityTabState._paths['sessions']!))
      _def('sessions', 'Sessions', Icons.devices_outlined),
    if (_supports('GET', _TokenSecurityTabState._paths['expiring']!))
      _def('expiring', 'Expiring', Icons.timer),
    if (_supportsTempToken) _def('temp', 'Temp Token', Icons.key_outlined),
    if (_supportsSingleRevoke ||
        _supportsBulkRevoke ||
        _supportsAdminTokenRevoke)
      _def('revoke', 'Revoke', Icons.remove_circle),
  ];

  bool _shows(String section) =>
      _currentSection == 'all' || _currentSection == section;

  List<Map<String, dynamic>> _list(String key, String valueKey) {
    final values = _data[key]?[valueKey];
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((v) => Map<String, dynamic>.from(v))
        .toList(growable: false);
  }

  Widget _buildTokenSecurityTab(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const AdminBreadcrumb(),
            Row(
              children: [
                // R33：标题放入 Expanded（窄屏/字号缩放下换行而非溢出），刷新仍贴右。
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      AppStrings.of(context).tokenSessionSecurity,
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(
                            fontWeight: FontWeight.w600,
                            letterSpacing: -0.3,
                          ),
                    ),
                  ),
                ),
                IconButton(
                  onPressed: _loading ? null : _load,
                  tooltip: context.strings.refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 4),
            LocalizedText(
              'Token issuance, lifetimes and rotation policies across clients.',
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            SectionSelector(
              sections: _sections,
              current: _currentSection,
              onSelected: _selectSection,
            ),
          ],
        ),
      ),
      Expanded(
        child: PullToRefresh(
          onRefresh: _load,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_mutationOutcomeUnknown)
                AdminOpsHelpers.unknownOutcomeCard(
                  context,
                  onAcknowledge: _mutating ? null : _acknowledgeUnknownOutcome,
                ),
              if (_error != null)
                ErrorStateCard(
                  message: _error!,
                  onRetry: _load,
                  margin: EdgeInsets.zero,
                ),
              if (_loading)
                const Padding(
                  padding: EdgeInsets.only(top: 16),
                  child: SkeletonListTile(itemCount: 3),
                )
              else if (_data.isEmpty)
                const EmptyState(
                  compact: true,
                  variant: EmptyStateVariant.empty,
                  title: 'No token data available.',
                )
              else ...[
                _securitySummary(context),
                if (_shows('portfolio') && _data.containsKey('portfolio'))
                  _portfolioCard(),
                if (_shows('suspicious') && _data.containsKey('suspicious'))
                  _listCard('suspicious'),
                if (_shows('sessions') && _data.containsKey('sessions'))
                  _listCard('sessions'),
                if (_shows('revoke') && _data.containsKey('tokens'))
                  _listCard('tokens'),
                if (_shows('expiring') && _data.containsKey('expiring'))
                  _listCard('expiring'),
                if (_shows('revoke') && _supportsBulkRevoke) _bulkRevokeCard(),
                if (_shows('temp') && _supportsTempToken) _tempTokenCard(),
                if (_shows('revoke') && _supportsSingleRevoke)
                  _revokeTokenCard(),
              ],
            ],
          ),
        ),
      ),
    ],
  );

  /// 统一卡片容器：组色图标 + SectionHeader 标题（SectionHeader 惯例）。
  Widget _card(String title, IconData icon, List<Widget> children) => Card(
    margin: const EdgeInsets.only(top: 20),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(icon, size: 20, color: _accent),
              const SizedBox(width: 8),
              Expanded(child: SectionHeader(title)),
            ],
          ),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    ),
  );

  /// 列表卡：空态 EmptyState(compact)（X8），非空 AdminDataTable(compact)（X6）。
  Widget _tableCard({
    required String title,
    required IconData icon,
    required List<Map<String, dynamic>> rows,
    required String emptyText,
    required List<AdminDataColumn> columns,
    Widget? header,
  }) => _card(title, icon, [
    if (header != null) ...[header, const SizedBox(height: 12)],
    if (rows.isEmpty)
      EmptyState(
        compact: true,
        variant: EmptyStateVariant.empty,
        title: emptyText,
      )
    else
      AdminDataTable(
        density: TableDensity.compact,
        columns: columns,
        itemCount: rows.length,
        rowBuilder: (_, _) => const SizedBox.shrink(),
      ),
  ]);

  /// 单行文本单元格（API 值走 TableCellText/Text，不参与 i18n 查表）。
  AdminDataColumn _cell(
    List<Map<String, dynamic>> rows,
    String id,
    String label,
    String Function(Map<String, dynamic>) value, {
    bool primary = false,
    bool muted = false,
  }) => AdminDataColumn(
    id: id,
    label: label,
    cardPrimary: primary,
    cardDetail: !primary,
    builder: (_, i) => TableCellText(
      value(rows[i]),
      level: primary ? DataEmphasisLevel.primary : null,
      muted: muted,
    ),
  );

  Widget _listCard(String key) {
    final rows = switch (key) {
      'sessions' => _list(
        'sessions',
        'sessions',
      ).take(100).toList(growable: false),
      'suspicious' => _list('suspicious', 'findings'),
      'tokens' => _list('tokens', 'tokens'),
      _ => _list('expiring', 'tokens'),
    };
    final (title, icon, empty, header, columns) = switch (key) {
      'suspicious' => (
        'Detected token anomalies',
        Icons.warning_amber_outlined,
        'No anomaly findings.',
        null,
        _anomalyColumns(rows),
      ),
      'sessions' => (
        'Active sessions',
        Icons.devices_other_outlined,
        'No sessions recorded.',
        LocalizedText(
          'Total: {total}',
          args: {'total': _data['sessions']?['total'] ?? rows.length},
        ),
        _sessionColumns(rows),
      ),
      'tokens' => (
        'Administrator bearer tokens',
        Icons.admin_panel_settings_outlined,
        'No administrator tokens found.',
        null,
        _adminTokenColumns(rows),
      ),
      _ => (
        'Refresh tokens expiring soon',
        Icons.timer_outlined,
        'No refresh-token expiry records.',
        null,
        _expiringColumns(rows),
      ),
    };
    return _tableCard(
      title: title,
      icon: icon,
      rows: rows,
      emptyText: empty,
      header: header,
      columns: columns,
    );
  }

  List<AdminDataColumn> _anomalyColumns(List<Map<String, dynamic>> rows) => [
    AdminDataColumn(
      id: 'finding',
      label: 'Finding',
      cardPrimary: true,
      builder: (_, i) {
        final f = rows[i], critical = f['severity'] == 'critical';
        return Row(
          children: [
            Icon(
              critical ? Icons.warning_amber_outlined : Icons.info_outline,
              size: 16,
              color: critical ? AppColors.danger : AppColors.warning,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${f['type'] ?? ''} · ${f['subject_id'] ?? ''}',
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        );
      },
    ),
    _cell(
      rows,
      'detail',
      'Detail',
      (r) => r['detail']?.toString() ?? '',
      muted: true,
    ),
  ];

  List<AdminDataColumn> _sessionColumns(List<Map<String, dynamic>> rows) => [
    _cell(
      rows,
      'session',
      'Session ID',
      (r) => r['id']?.toString() ?? '',
      primary: true,
    ),
    _cell(
      rows,
      'user',
      'User · IP',
      (r) => '${r['user_id'] ?? r['userId'] ?? ''} · ${r['ip'] ?? ''}',
      muted: true,
    ),
  ];

  List<AdminDataColumn> _adminTokenColumns(List<Map<String, dynamic>> rows) => [
    AdminDataColumn(
      id: 'token',
      label: 'Token',
      cardPrimary: true,
      builder: (_, i) {
        final t = rows[i];
        return Row(
          children: [
            Expanded(
              child: TableCellText(
                t['label']?.toString() ?? t['id']?.toString() ?? '',
                level: DataEmphasisLevel.primary,
              ),
            ),
            if (_supportsAdminTokenRevoke)
              TextButton(
                onPressed: _mutating
                    ? null
                    : () => _revokeAdminToken(t['id']?.toString() ?? ''),
                style: TextButton.styleFrom(
                  // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
                  foregroundColor: AppColors.semanticFor(
                    Theme.of(context).brightness,
                    AppColors.danger,
                  ),
                ),
                child: const LocalizedText('Revoke'),
              ),
          ],
        );
      },
    ),
    _cell(
      rows,
      'meta',
      'Admin · Scopes',
      (r) =>
          '${r['admin_id'] ?? ''} · ${(r['scopes'] as List? ?? const []).join(' ')}',
      muted: true,
    ),
  ];

  List<AdminDataColumn> _expiringColumns(List<Map<String, dynamic>> rows) => [
    _cell(
      rows,
      'subject',
      'Subject',
      (r) => r['subject']?.toString() ?? '',
      primary: true,
    ),
    _cell(
      rows,
      'meta',
      'Client · Expires',
      (r) => '${r['client_id'] ?? ''} · ${r['expires_at'] ?? ''}',
      muted: true,
    ),
  ];
}
