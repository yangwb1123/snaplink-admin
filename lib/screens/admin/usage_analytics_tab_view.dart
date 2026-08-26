part of 'usage_analytics_tab.dart';

extension _UsageAnalyticsTabView on _UsageAnalyticsTabState {
  Widget _buildUsageAnalyticsTab(BuildContext context) => PullToRefresh(
    onRefresh: _load,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        Row(
          children: [
            Icon(Icons.insights_outlined, color: _accent),
            const SizedBox(width: 8),
            // R33：标题 Expanded，窄屏/字号缩放换行而非溢出；刷新仍贴右。
            Expanded(
              child: Semantics(
                container: true,
                header: true,
                child: LocalizedText(
                  'Usage and session insights',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
              ),
            ),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
              tooltip: 'Refresh'.localized,
            ),
          ],
        ),
        const SizedBox(height: 4),
        const LocalizedText(
          'Operational telemetry is aggregated and may lag live authentication traffic slightly.',
        ),
        const SizedBox(height: 12),
        _filters(context),
        if (_error != null) ...[const SizedBox(height: 8), _errorCard(context)],
        if (_loading) ...[
          const SizedBox(height: 20),
          const SkeletonListTile(
            itemCount: 3,
            variant: SkeletonVariant.card,
            delay: Duration(milliseconds: 150),
          ),
        ],
        if (!_loading) ...[
          const SizedBox(height: 12),
          _metricStrip(context),
          const SizedBox(height: 12),
          _tenantLeaderboard(context),
          const SizedBox(height: 12),
          _tokenBuckets(context),
        ],
        const SizedBox(height: 12),
        _subjectInspector(context),
      ],
    ),
  );

  Widget _filters(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          // R31：2 项短枚举 → SegmentedButton（紧凑筛选条，替代下拉）。
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'day', label: LocalizedText('Day')),
              ButtonSegment(value: 'month', label: LocalizedText('Month')),
            ],
            selected: {_period},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              // ignore: invalid_use_of_protected_member
              setState(() => _period = selection.first);
            },
          ),
          SizedBox(
            width: 180,
            child: TextField(
              controller: _startCtrl,
              decoration: InputDecoration(
                labelText: 'Start date'.localized,
                hintText: 'YYYY-MM-DD'.localized,
              ),
            ),
          ),
          SizedBox(
            width: 220,
            child: TextField(
              controller: _clientCtrl,
              decoration: InputDecoration(
                labelText: 'Client ID filter'.localized,
              ),
            ),
          ),
          FilledButton(
            onPressed: _loading ? null : _load,
            child: const LocalizedText('Apply filters'),
          ),
        ],
      ),
    ),
  );

  /// 错误区：统一 ErrorStateCard（图标 + 明细 + Retry）。
  Widget _errorCard(BuildContext context) =>
      ErrorStateCard(message: _error!, onRetry: _load, retryEnabled: !_loading);

  /// 页头指标卡：缺失字段不求和、不虚构总量；出错时整条隐藏（数据诚实）。
  Widget _metricStrip(BuildContext context) {
    if (_error != null) return const SizedBox.shrink();
    final tenants = ((_topTenants?['tenants'] as List?) ?? const [])
        .whereType<Map>()
        .toList();
    final cards = <KeyMetricCard>[
      if (_tokenUsage?['total'] is num)
        KeyMetricCard(
          label: 'Token requests',
          value: _tokenUsage!['total'] as num,
          icon: Icons.electric_bolt_outlined,
          color: _accent,
        ),
      if (tenants.isNotEmpty)
        for (final (field, label, icon) in const [
          ('logins', 'Logins', Icons.login),
          ('tokens_issued', 'Tokens issued', Icons.token_outlined),
          ('active_users', 'Active users', Icons.people_outline),
        ])
          KeyMetricCard(
            label: label,
            value: sumTenantMetric(tenants, field),
            caption: 'Across top tenants',
            icon: icon,
            color: _accent,
          ),
    ];
    if (cards.isEmpty) return const SizedBox.shrink();
    return MetricStrip(cards: cards);
  }

  Widget _tenantLeaderboard(BuildContext context) {
    final metrics = ((_topTenants?['tenants'] as List?) ?? const [])
        .whereType<Map>()
        .toList();
    final maxLogins = metrics.fold<num>(0, (max, t) {
      final v = t['logins'];
      return v is num && v > max ? v : max;
    });
    return _section(context, 'Top tenants', [
      if (metrics.isEmpty)
        _empty('Tenant usage metering is unavailable or has no data.')
      else
        _table(
          minWidth: 720,
          itemCount: metrics.length,
          columns: [
            AdminDataColumn(
              id: 'rank',
              label: 'RANK',
              width: 56,
              builder: (context, i) => TableCellText('${i + 1}', muted: true),
            ),
            AdminDataColumn(
              id: 'tenant',
              label: 'TENANT',
              width: 220,
              cardPrimary: true,
              builder: (context, i) => TableCellText(
                metrics[i]['tenant_name']?.toString() ??
                    metrics[i]['tenant_id']?.toString() ??
                    'Tenant',
                bold: true,
              ),
            ),
            AdminDataColumn(
              id: 'metrics',
              label: 'METRICS',
              width: 260,
              cardDetail: true,
              builder: (context, i) => TableCellText(
                formatUsageMetricSummary(metrics[i]),
                muted: true,
                maxLines: 2,
              ),
            ),
            AdminDataColumn(
              id: 'usage',
              label: 'LOGIN SHARE',
              width: 180,
              builder: (context, i) => maxLogins <= 0
                  ? const SizedBox.shrink()
                  : DistributionBar(
                      segments: [
                        DistributionSegment(
                          label: 'logins',
                          value: (metrics[i]['logins'] as num? ?? 0).toInt(),
                          color: _accent,
                        ),
                      ],
                      total: maxLogins.toInt(),
                      showLegend: false,
                      height: 4,
                    ),
            ),
          ],
        ),
    ], icon: Icons.business_outlined);
  }

  Widget _tokenBuckets(BuildContext context) {
    final buckets = _tokenUsage?['buckets'] as List? ?? const [];
    final rows = buckets.take(50).whereType<Map>().toList();
    return _section(context, 'Token traffic', [
      if (buckets.isEmpty)
        _empty('Token usage telemetry is unavailable or has no data.')
      else ...[
        if (buckets.length >= 3)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Sparkline(
              data: [
                ...buckets
                    .take(30)
                    .map((raw) => ((raw as Map)['count'] as num?) ?? 0),
              ],
              height: 36,
            ),
          ),
        _table(
          minWidth: 680,
          itemCount: rows.length,
          columns: [
            AdminDataColumn(
              id: 'token',
              label: 'CLIENT · KIND',
              width: 260,
              cardPrimary: true,
              builder: (context, i) {
                final row = rows[i];
                final peak = i < 3 && ((row['count'] as num?) ?? 0) > 0;
                return TableCellText(
                  '${row['client_id'] ?? 'unknown client'} · ${row['kind'] ?? 'token'}',
                  bold: peak,
                  color: peak ? AppColors.danger : null,
                );
              },
            ),
            AdminDataColumn(
              id: 'detail',
              label: 'ENDPOINT · MINUTE',
              width: 280,
              cardDetail: true,
              builder: (context, i) => TableCellText(
                '${rows[i]['endpoint'] ?? ''} · ${rows[i]['minute'] ?? ''}',
                muted: true,
                maxLines: 2,
              ),
            ),
            AdminDataColumn(
              id: 'count',
              label: 'COUNT',
              width: 140,
              cardDetail: true,
              builder: (context, i) => _tokenCountCell(rows[i], i),
            ),
          ],
        ),
        if (buckets.length > 50)
          LocalizedText(
            '{count} additional buckets omitted.',
            args: {'count': formatCount(buckets.length - 50)},
          ),
      ],
    ], icon: Icons.electric_bolt_outlined);
  }

  Widget _tokenCountCell(Map row, int index) {
    final count = (row['count'] as num?) ?? 0;
    final peak = index < 3 && count > 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (peak)
          StatusChip(
            label: 'Peak',
            color: AppColors.danger,
            icon: Icons.local_fire_department,
          ),
        const SizedBox(width: 8),
        Text(formatCount(count)),
      ],
    );
  }

  Widget _subjectInspector(
    BuildContext context,
  ) => _section(context, 'Subject investigation', [
    const LocalizedText(
      'Inspect active refresh-token counts and linked OIDC/SAML session legs without exposing credential values.',
    ),
    const SizedBox(height: 12),
    Row(
      children: [
        Expanded(
          child: TextField(
            controller: _subjectCtrl,
            decoration: InputDecoration(labelText: 'Subject'.localized),
            onSubmitted: (_) => _inspectSubject(),
          ),
        ),
        const SizedBox(width: 12),
        FilledButton(
          onPressed: _subjectLoading ? null : _inspectSubject,
          child: const LocalizedText('Inspect'),
        ),
      ],
    ),
    if (_subjectLoading) ...[
      const SizedBox(height: 12),
      const LinearProgressIndicator(),
    ],
    if (_subjectTokens != null) ...[
      const SizedBox(height: 12),
      _jsonResult('Active token count', _subjectTokens!),
    ],
    if (_linkedSessions != null) ...[
      const SizedBox(height: 12),
      _jsonResult('Cross-protocol sessions', _linkedSessions!),
    ],
  ], icon: Icons.manage_search);

  Widget _table({
    required double minWidth,
    required int itemCount,
    required List<AdminDataColumn> columns,
  }) => AdminDataTable(
    density: TableDensity.compact,
    minWidth: minWidth,
    columns: columns,
    itemCount: itemCount,
    rowBuilder: (context, i) => const SizedBox.shrink(),
  );

  Widget _empty(String title) =>
      EmptyState(variant: EmptyStateVariant.empty, compact: true, title: title);

  Widget _section(
    BuildContext context,
    String title,
    List<Widget> children, {
    IconData? icon,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: _accent),
                const SizedBox(width: 8),
              ],
              LocalizedText(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const Divider(),
          ...children,
        ],
      ),
    ),
  );

  Widget _jsonResult(String title, Map<String, dynamic> value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      LocalizedText(title, style: const TextStyle(fontWeight: FontWeight.w600)),
      SelectableText(
        const JsonEncoder.withIndent('  ').convert(value),
        style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
      ),
    ],
  );
}
