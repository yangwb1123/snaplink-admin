part of 'audit_log_tab.dart';

extension _AuditLogTabView on _AuditLogTabState {
  Widget _buildAuditLogTab(BuildContext context) {
    // 空态语义：筛选后无可见行（含搜索/outcome 过滤排空）也算“无结果”。
    final showEmpty =
        _displayed.isEmpty && !_loading && _error == null && !_notEnabled;
    return PullToRefresh(
      onRefresh: _refresh,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: _auditPageChildren(context, showEmpty),
      ),
    );
  }

  List<Widget> _auditPageChildren(BuildContext context, bool showEmpty) => [
    const AdminBreadcrumb(),
    _header(context),
    if (_notEnabled)
      const Padding(
        padding: EdgeInsets.only(top: 24),
        child: EmptyState(variant: EmptyStateVariant.notEnabled),
      )
    else if (_error != null)
      Padding(padding: const EdgeInsets.only(top: 8), child: _errorCard())
    else
      ..._loadedAuditWidgets(context, showEmpty),
  ];

  List<Widget> _loadedAuditWidgets(BuildContext context, bool showEmpty) => [
    AuditMetrics(rows: _rows, persona: widget.persona),
    const SizedBox(height: 8),
    _auditFilters(),
    const SizedBox(height: 16),
    SectionHeader('Recent events', count: _rows.length),
    const SizedBox(height: 8),
    _auditResults(context, showEmpty),
  ];

  Widget _auditFilters() => Wrap(
    spacing: 12,
    runSpacing: 8,
    crossAxisAlignment: WrapCrossAlignment.center,
    children: [
      SizedBox(
        width: 300,
        // 本地过滤即时生效；网络刷新由 300ms debounce 合并。
        child: SearchFilterBar(
          debounce: false,
          hintText: 'Search...'.localized,
          controller: _searchCtrl,
          onSearchChanged: _onSearchChanged,
        ),
      ),
      StatusFilterDropdown(
        value: _outcomeFilter,
        options: const {
          'ALL': 'All',
          'success': 'success',
          'failure': 'failure',
        },
        onChanged: _onOutcomeFilterChanged,
      ),
    ],
  );

  Widget _auditResults(BuildContext context, bool showEmpty) {
    if (_loading) return const SkeletonListTile(itemCount: 4);
    if (showEmpty) {
      return _searchCtrl.text.trim().isNotEmpty || _outcomeFilter != 'ALL'
          ? EmptyState(
              variant: EmptyStateVariant.noMatch,
              title: 'No matching events.',
              actionLabel: 'Clear filter',
              actionIcon: Icons.filter_alt_off,
              onAction: _clearFilters,
            )
          : const EmptyState(
              variant: EmptyStateVariant.empty,
              title: 'No audit events returned by the server yet.',
            );
    }
    return _auditTable(context);
  }

  Widget _auditTable(BuildContext context) => AdminDataTable(
    density: TableDensity.compact,
    sortColumn: _sortColumn,
    sortAscending: _sortAscending,
    onSort: _onSort,
    minWidth: 900,
    columns: [
      AdminDataColumn(
        id: 'time',
        label: 'TIME',
        width: 180,
        sortable: true,
        builder: (cellContext, index) => TableCellText(
          _formatTime(cellContext, _displayed[index].timestamp),
          muted: true,
        ),
      ),
      AdminDataColumn(
        id: 'type',
        label: 'EVENT',
        width: 220,
        sortable: true,
        builder: (_, index) =>
            TableCellText(_displayed[index].type, bold: true),
      ),
      AdminDataColumn(
        id: 'outcome',
        label: 'OUTCOME',
        width: 160,
        sortable: true,
        builder: (_, index) => _outcomeCell(_displayed[index]),
      ),
      AdminDataColumn(
        id: 'actor',
        label: 'ACTOR',
        width: 140,
        builder: (cellContext, index) => _displayed[index].actorId.isEmpty
            ? const TableCellText('-')
            : CopyableCell(
                text: _displayed[index].actorId,
                contextProvider: () => cellContext,
              ),
      ),
      AdminDataColumn(
        id: 'tenant',
        label: 'TENANT',
        width: 140,
        builder: (cellContext, index) => _displayed[index].tenantId.isEmpty
            ? const TableCellText('-')
            : CopyableCell(
                text: _displayed[index].tenantId,
                contextProvider: () => cellContext,
              ),
      ),
    ],
    itemCount: _displayed.length,
    rowBuilder: (_, _) => const SizedBox.shrink(),
  );

  Widget _outcomeCell(AuditEventRow row) {
    if (row.outcome.isEmpty) return const TableCellText('-', muted: true);
    // Server vocabulary rendered verbatim (machine data, like EVENT).
    return StatusChip(
      label: row.outcome,
      color: row.outcome == 'success' ? AppColors.success : AppColors.danger,
      icon: row.outcome == 'success'
          ? Icons.check_circle_outline
          : Icons.error_outline,
    );
  }

  /// 错误区：统一 ErrorStateCard（图标 + 明细 + Retry）；错误文本动态 Text（FM-1）。
  Widget _errorCard() =>
      ErrorStateCard(message: _error ?? '', onRetry: _refresh);

  // Relative labels only — date fallback and '--' stay verbatim.
  String _formatTime(BuildContext context, DateTime? value) {
    if (value == null) return '--';
    final diff = DateTime.now().difference(value);
    if (diff.inSeconds < 60) return context.tr('just now');
    if (diff.inMinutes < 60) {
      return context.tr('{count}m ago', {'count': diff.inMinutes});
    }
    if (diff.inHours < 24) {
      return context.tr('{count}h ago', {'count': diff.inHours});
    }
    return '${value.month}/${value.day} '
        '${value.hour}:${value.minute.toString().padLeft(2, '0')}';
  }
}
