part of 'users_tab.dart';

mixin _UsersTabView on State<UsersTab> {
  TextEditingController get _filterCtrl;
  Future<SSOAdminListPage> get _future;
  int get _pageSize;
  String get _orderBy;
  String? get _sortColumn;
  bool get _sortAscending;
  String? get _busyId;
  bool get selecting;
  Set<String> get selected;
  void clearSelection();
  void toggleSelect(String id);
  bool get canGoBack;
  bool get onFirstPage;
  int get currentPage;

  Future<void> _reload();
  void _clearFilter();
  void _goPrevious();
  void _goNext(SSOAdminListPage page);
  void _retryPage();
  void _onSort(String column);
  void _setOrder(String value);
  void _setPageSize(int value);
  Widget _batchBar();
  String _id(Map<String, dynamic> user);
  bool _hasStatus(List<Map<String, dynamic>> items);
  Future<void> _confirmDelete(Map<String, dynamic> user);

  Widget _loaded(SSOAdminListPage page) => _listBody(
    page,
    page.items,
    UserMetrics(
      items: page.items,
      totalSize: page.totalSize,
      persona: widget.persona,
    ),
  );

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AdminBreadcrumb(),
      AdminListHeader(
        title: AppStrings.of(context).users,
        subtitle: 'Directory users across providers.',
        createTooltip: 'Create user',
        onCreate: () => AdminRoute.go('users', action: 'new'),
        onRefresh: _reload,
      ),
      if (selecting) ...[_batchBar(), const SizedBox(height: 8)],
      _filterBar(context),
      const SizedBox(height: 8),
      Expanded(
        child: FutureBuilder<SSOAdminListPage>(
          future: _future,
          builder: (context, snap) => snap.hasError
              ? ErrorStateView(message: '${snap.error}', onRetry: _retryPage)
              : snap.hasData
              ? _loaded(snap.data!)
              : const SkeletonListTile(itemCount: 6),
        ),
      ),
    ],
  );

  Widget _filterBar(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: SearchFilterBar(
            labelText: 'Filter'.localized,
            controller: _filterCtrl,
            debounce: false,
            onSearchChanged: (_) {},
            onSubmitted: (_) => _reload(),
          ),
        ),
        TightDropdownButton<String>(
          value: _orderBy,
          maxWidth: 190,
          options: const [
            ('id', 'ID ascending'),
            ('-id', 'ID descending'),
            ('provider', 'Provider ascending'),
            ('-provider', 'Provider descending'),
            ('created_at', 'Created ascending'),
            ('-created_at', 'Created descending'),
          ],
          onChanged: _setOrder,
        ),
        TightDropdownButton<int>(
          value: _pageSize,
          maxWidth: 150,
          options: const [
            (25, '25 per page'),
            (100, '100 per page'),
            (250, '250 per page'),
          ],
          onChanged: _setPageSize,
        ),
      ],
    ),
  );

  Widget _emptyState(bool filtered) => EmptyState(
    variant: filtered ? EmptyStateVariant.noMatch : EmptyStateVariant.empty,
    icon: filtered ? null : Icons.person,
    title: 'No users',
    // Keep the established empty-state copy for both an empty first page and
    // a filtered no-match response; existing consumers and tests rely on the
    // same explanatory text while the action distinguishes the two states.
    subtitle: 'No users match the current filter.',
    actionLabel: filtered ? 'Clear filter' : 'Create user',
    actionIcon: filtered ? Icons.filter_alt_off : null,
    onAction: filtered
        ? _clearFilter
        : () => AdminRoute.go('users', action: 'new'),
  );

  Widget _listBody(
    SSOAdminListPage page,
    List<Map<String, dynamic>> items,
    Widget metrics,
  ) {
    final filtered = _filterCtrl.text.trim().isNotEmpty;
    final list = items.isNotEmpty
        ? _dataTable(items)
        : onFirstPage
        ? _emptyState(filtered)
        : EmptyPageState(onBackToFirst: _reload);
    final pagination = PaginationControls(
      page: currentPage,
      total: page.totalSize,
      canGoBack: canGoBack,
      canGoNext: page.nextPageToken != null,
      onPrevious: _goPrevious,
      onNext: () => _goNext(page),
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final short =
            constraints.maxHeight <
            380 * MediaQuery.textScalerOf(context).scale(1);
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            metrics,
            if (short)
              SizedBox(height: 280, child: list)
            else
              Expanded(child: list),
            pagination,
          ],
        );
        return PullToRefresh(
          onRefresh: _reload,
          child: short ? SingleChildScrollView(child: content) : content,
        );
      },
    );
  }

  Widget _statusChip(Map<String, dynamic> user) {
    final raw = user['status']?.toString().trim() ?? '';
    return switch (raw.toLowerCase()) {
      'active' => StatusChip.active(label: raw),
      'suspended' => StatusChip.suspended(label: raw),
      'pending' => StatusChip.pending(label: raw),
      'inactive' || 'disabled' || 'revoked' => StatusChip.inactive(label: raw),
      _ => StatusChip.unknown(label: raw.isEmpty ? 'Unknown' : raw),
    };
  }

  Widget _actions(Map<String, dynamic> user) => PopupMenuButton<String>(
    enabled: _busyId == null,
    onSelected: (value) => switch (value) {
      'edit' => AdminRoute.go('users', action: 'edit', resourceId: _id(user)),
      'delete' => _confirmDelete(user),
      _ => null,
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: LocalizedText('Edit')),
      PopupMenuItem(value: 'delete', child: LocalizedText('Delete')),
    ],
  );

  Widget _dataTable(List<Map<String, dynamic>> items) {
    String uid(int i) => _id(items[i]);
    final hasStatus = _hasStatus(items);
    final columns = <AdminDataColumn>[
      if (selecting)
        AdminDataColumn(
          id: 'select',
          label: '',
          width: 44,
          builder: (context, i) => Checkbox(
            value: selected.contains(uid(i)),
            onChanged: _busyId == null ? (_) => toggleSelect(uid(i)) : null,
          ),
        ),
      AdminDataColumn(
        id: 'user',
        label: 'USER',
        width: 260,
        sortable: true,
        cardPrimary: true,
        builder: (context, i) => Row(
          children: [
            UserAvatar(name: uid(i), radius: 14),
            const SizedBox(width: 8),
            Flexible(
              child: CopyableCell(
                text: uid(i),
                contextProvider: () => context,
                enabled: !selecting,
              ),
            ),
          ],
        ),
      ),
      AdminDataColumn(
        id: 'provider',
        label: 'PROVIDER',
        width: 140,
        sortable: true,
        cardDetail: true,
        builder: (context, i) =>
            TableCellText(items[i]['provider']?.toString() ?? '?', muted: true),
      ),
      AdminDataColumn(
        id: 'external',
        label: 'EXTERNAL ID',
        cardDetail: true,
        builder: (context, i) => TableCellText(
          items[i]['externalId']?.toString() ??
              items[i]['external_id']?.toString() ??
              '',
          muted: true,
          maxLines: 1,
        ),
      ),
      if (hasStatus)
        AdminDataColumn(
          id: 'status',
          label: 'STATUS',
          width: 130,
          cardDetail: true,
          builder: (context, i) => _statusChip(items[i]),
        ),
      AdminDataColumn(
        id: 'actions',
        label: '',
        width: 60,
        builder: (context, i) => _actions(items[i]),
      ),
    ];
    return AdminDataTable(
      scrollable: true,
      minWidth: hasStatus ? 860 : 720,
      sortColumn: _sortColumn,
      sortAscending: _sortAscending,
      onSort: _onSort,
      onRowTap: selecting
          ? (i) => toggleSelect(uid(i))
          : (i) => AdminRoute.go('users', resourceId: uid(i)),
      onRowLongPress: selecting ? null : (i) => toggleSelect(uid(i)),
      columns: columns,
      itemCount: items.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );
  }
}
