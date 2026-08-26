part of 'webhooks_tab.dart';

extension _WebhooksTabSections on _WebhooksTabState {
  /// 按状态筛选后的订阅列表（本地过滤；分页不存在，语义正确）。
  List<Map<String, dynamic>> get _visibleSubscriptions {
    if (_statusFilter == 'all') return _subscriptions;
    final active = _statusFilter == 'active';
    return _subscriptions
        .where((s) => (s['active'] == true) == active)
        .toList();
  }

  /// 订阅健康摘要：占比条 + 计数（活跃占比一眼可见）。
  Widget _subscriptionsHealth(BuildContext context) {
    final visible = _visibleSubscriptions;
    final total = visible.length;
    final active = visible.where((s) => s['active'] == true).length;
    final fraction = total == 0 ? 0.0 : active / total;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              // R33：标签 Expanded（窄屏/字号缩放换行而非溢出），计数仍贴右。
              Expanded(
                child: LocalizedText(
                  'Subscriptions health',
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
                ),
              ),
              LocalizedText(
                '{active} of {total} active',
                args: {'active': active, 'total': total},
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: fraction >= 0.7
                      ? AppColors.success
                      : fraction >= 0.4
                      ? AppColors.warning
                      : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          DistributionBar(
            segments: [
              DistributionSegment(
                label: 'Active',
                value: active,
                color: AppColors.success,
              ),
              DistributionSegment(
                label: 'Inactive',
                value: total - active,
                color: AppColors.muted,
              ),
            ],
            showLegend: false,
          ),
        ],
      ),
    );
  }

  /// 表格壳：紧凑密度 + 行点击（两表共用）。
  AdminDataTable _table(
    List<AdminDataColumn> columns,
    int count, {
    void Function(int)? onRowTap,
  }) => AdminDataTable(
    density: TableDensity.compact,
    minWidth: 560,
    columns: columns,
    itemCount: count,
    rowBuilder: (context, i) => const SizedBox.shrink(),
    onRowTap: onRowTap,
  );

  /// 订阅状态徽章（状态 = 颜色 + 文字，双表达）。
  Widget _statusChip(Map<String, dynamic> sub) => sub['active'] == true
      ? StatusChip.active(label: context.tr('Active'))
      : StatusChip.inactive(label: context.tr('Inactive'));

  /// 数据区块壳：SectionHeader + loading 骨架 + empty 态（两表共用）。
  Widget _section(String title, List data, Widget empty, Widget table) =>
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionHeader(title, count: data.isEmpty ? null : data.length),
          if (_loading) const SkeletonListTile(itemCount: 3),
          if (!_loading && data.isEmpty) empty,
          if (!_loading && data.isNotEmpty) table,
        ],
      );

  Widget _subscriptionsCard(BuildContext context) {
    final visible = _visibleSubscriptions;
    return _section(
      'Subscriptions',
      visible,
      _statusFilter == 'all'
          ? const EmptyState(
              variant: EmptyStateVariant.empty,
              title: 'No subscriptions.',
              compact: true,
            )
          : EmptyState(
              variant: EmptyStateVariant.noMatch,
              compact: true,
              actionLabel: 'Clear filter',
              actionIcon: Icons.filter_alt_off,
              onAction: () {
                // ignore: invalid_use_of_protected_member
                setState(() => _statusFilter = 'all');
              },
            ),
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _subscriptionsHealth(context),
          const SizedBox(height: 8),
          _table(
            [
              // R52：URL 为订阅业务主字段，置于首位（状态/ID·事件随其后）。
              AdminDataColumn(
                id: 'url',
                label: 'URL',
                width: 240,
                cardPrimary: true,
                builder: (context, i) => TableCellText(
                  visible[i]['url']?.toString() ?? '',
                  bold: true,
                ),
              ),
              AdminDataColumn(
                id: 'status',
                label: 'STATUS',
                width: 170,
                cardDetail: true,
                builder: (context, i) => _statusChip(visible[i]),
              ),
              AdminDataColumn(
                id: 'events',
                label: 'ID · EVENTS',
                width: 300,
                cardDetail: true,
                builder: (context, i) {
                  final eventTypes =
                      (visible[i]['event_types'] as List?)
                          ?.whereType<Object>()
                          .map((event) => event.toString())
                          .toList() ??
                      const <String>[];
                  return TableCellText(
                    context.tr('{id} · events: {events}', {
                      'id': visible[i]['id'] ?? '',
                      'events': eventTypes.isEmpty
                          ? context.tr('all')
                          : eventTypes.join(', '),
                    }),
                    muted: true,
                  );
                },
              ),
              AdminDataColumn(
                id: 'actions',
                label: '',
                width: 90,
                builder: (context, i) => TextButton(
                  onPressed: _mutating
                      ? null
                      : () => _delete(visible[i]['id']?.toString() ?? ''),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.danger,
                  ),
                  child: const LocalizedText('Delete'),
                ),
              ),
            ],
            visible.length,
            onRowTap: (i) => AdminRoute.go(
              'webhooks',
              resourceId: visible[i]['id']?.toString() ?? '',
            ),
          ),
        ],
      ),
    );
  }

  Widget _deadLettersCard(BuildContext context) => _section(
    'Dead letters',
    _deadLetters,
    const EmptyState(
      variant: EmptyStateVariant.empty,
      title: 'No dead letters.',
      compact: true,
    ),
    _table([
      AdminDataColumn(
        id: 'event',
        label: 'EVENT',
        width: 220,
        cardPrimary: true,
        builder: (context, i) => TableCellText(
          _deadLetters[i]['event_type']?.toString() ??
              _deadLetters[i]['type']?.toString() ??
              'Unknown',
          bold: true,
        ),
      ),
      AdminDataColumn(
        id: 'id',
        label: 'ID',
        width: 140,
        cardDetail: true,
        builder: (context, i) {
          final id = _deadLetters[i]['id']?.toString() ?? '';
          return id.isEmpty
              ? const TableCellText('')
              : CopyableCell(text: id, contextProvider: () => context);
        },
      ),
      AdminDataColumn(
        id: 'error',
        label: 'ERROR',
        width: 280,
        cardDetail: true,
        builder: (context, i) => TableCellText(
          _deadLetters[i]['error']?.toString() ?? '',
          muted: true,
          maxLines: 2,
        ),
      ),
      AdminDataColumn(
        id: 'actions',
        label: '',
        width: 90,
        builder: (context, i) => TextButton(
          onPressed: _mutating
              ? null
              : () => _replay(_deadLetters[i]['id']?.toString() ?? ''),
          child: const LocalizedText('Replay'),
        ),
      ),
    ], _deadLetters.length),
  );
}
