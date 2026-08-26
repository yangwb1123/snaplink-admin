part of 'clients_tab.dart';

extension _ClientsTabView on _ClientsTabState {
  Widget _buildClientsTab(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).clients,
          subtitle: 'Manage OAuth clients, secrets and expiring credentials.',
          createTooltip: 'Create client',
          onCreate: () => AdminRoute.go('clients', action: 'new'),
          onRefresh: _reload,
        ),
        if (_secretRotationOutcomeUnknown)
          AdminOpsHelpers.unknownOutcomeCard(
            context,
            onAcknowledge: _busy ? null : _acknowledgeSecretRotation,
          ),
        _filterBar(context),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<SSOAdminListPage>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                if (snap.hasError) {
                  return ErrorStateView(
                    message: '${snap.error}',
                    onRetry: _retryPage,
                  );
                }
                return const SkeletonListTile(
                  itemCount: 6,
                  delay: Duration(milliseconds: 150),
                );
              }
              final page = snap.data!;
              final items = [...page.items];
              return _listBody(
                context,
                page,
                items,
                ClientMetrics(
                  items: items,
                  totalSize: page.totalSize,
                  persona: widget.persona,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _menu<T>(
    T value,
    List<(T, String)> options,
    ValueChanged<T> onPicked,
  ) => TightDropdownButton<T>(
    value: value,
    options: options,
    maxWidth: 240,
    onChanged: (v) {
      // ignore: invalid_use_of_protected_member
      setState(() => onPicked(v));
      _reload();
    },
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
        _menu<String>(
          _orderBy,
          const [
            ('id', 'ID ascending'),
            ('-id', 'ID descending'),
            ('name', 'Name ascending'),
            ('-name', 'Name descending'),
          ],
          (v) {
            _orderBy = v;
            _sortAscending = !v.startsWith('-');
            _sortColumn = v.endsWith('name') ? 'name' : 'id';
          },
        ),
        IconButton(
          tooltip: 'Export CSV'.localized,
          icon: Icon(Icons.file_download_outlined, color: _accent),
          onPressed: _lastPage == null || _lastPage!.items.isEmpty
              ? null
              : () => _exportCsv(_lastPage!.items),
        ),
        StatusFilterDropdown(
          value: _statusFilter,
          options: const {
            'all': 'All statuses',
            'active': 'Active only',
            'inactive': 'Inactive only',
          },
          onChanged: (value) {
            // ignore: invalid_use_of_protected_member
            setState(() => _statusFilter = value);
            _reload();
          },
        ),
        _menu<int>(_pageSize, const [
          (25, '25 per page'),
          (100, '100 per page'),
          (250, '250 per page'),
        ], (v) => _pageSize = v),
        FilterChip(
          label: const LocalizedText('Expiring within 30 days'),
          selected: _expiringOnly,
          onSelected: (value) {
            _expiringOnly = value;
            _reload();
          },
        ),
      ],
    ),
  );

  Widget _listBody(
    BuildContext context,
    SSOAdminListPage page,
    List<Map<String, dynamic>> items,
    Widget metrics,
  ) {
    final filtered =
        _filterCtrl.text.trim().isNotEmpty ||
        _statusFilter != 'all' ||
        _expiringOnly;
    final Widget? emptyState = items.isEmpty
        ? (onFirstPage
              ? EmptyState(
                  variant: filtered
                      ? EmptyStateVariant.noMatch
                      : EmptyStateVariant.empty,
                  icon: filtered ? null : Icons.apps,
                  title: 'No clients',
                  subtitle: filtered
                      ? 'No clients match the current filter.'
                      : 'Create your first client to get started.',
                  actionLabel: filtered ? 'Clear filter' : 'Create client',
                  actionIcon: filtered ? Icons.filter_alt_off : null,
                  onAction: filtered
                      ? _clearFilter
                      : () => AdminRoute.go('clients', action: 'new'),
                )
              : EmptyPageState(onBackToFirst: _reload))
        : null;
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
        // R29：阈值随字体缩放（1.5x/2.0x 下指标带+分页高度增长，固定 380
        // 会在窄高容器溢出）——文本放大时提前切到整页滚动，不截断不溢出。
        final list =
            emptyState ??
            (constraints.maxWidth < 640
                ? _mobileList(items)
                : _dataTable(context, items));
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final short = constraints.maxHeight < 380 * scale;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selecting) ...[_batchBar(context), const SizedBox(height: 8)],
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

  Widget _batchBar(BuildContext context) => BatchActionBar(
    selectedCount: selected.length,
    accent: _accent,
    isLoading: _busy,
    actions: [
      BatchAction(
        label: 'Approve',
        icon: Icons.check_circle_outline,
        onPressed: () =>
            _runBatch('Approve', (id) => widget.client.approveClient(id)),
      ),
      BatchAction(
        label: 'Reject',
        icon: Icons.cancel_outlined,
        onPressed: () =>
            _runBatch('Reject', (id) => widget.client.rejectClient(id)),
      ),
    ],
    onClearSelection: clearSelection,
  );

  Future<void> _exportCsv(List<Map<String, dynamic>> items) async {
    final sb = StringBuffer('id,name,active,strategy\n');
    for (final c in items) {
      sb.writeln(
        [
          c['id']?.toString() ?? '',
          c['name']?.toString() ?? '',
          c['active'] == true ? 'active' : 'inactive',
          c['tokenStrategy']?.toString() ??
              c['token_strategy']?.toString() ??
              '',
        ].map(_csvCell).join(','),
      );
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    showAppSnackBar(
      context,
      content: LocalizedText(
        'Exported {n} clients as CSV to clipboard',
        args: {'n': items.length},
      ),
    );
  }

  String _csvCell(String value) {
    var cell = value.replaceAll('"', '""');
    if (cell.startsWith(RegExp(r'[=+\-@]'))) cell = "'$cell";
    return '"$cell"';
  }
}
