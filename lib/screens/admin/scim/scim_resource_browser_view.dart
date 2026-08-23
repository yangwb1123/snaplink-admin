part of 'scim_resource_browser.dart';

extension _ScimResourceBrowserView on _ScimResourceBrowserState {
  Widget _buildScimResourceBrowser(BuildContext context) {
    if (_unavailable) {
      return ScimUnavailable(kind: widget.kind, onRetry: _load);
    }
    final page = _page;
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _browserHeader(context),
          const SizedBox(height: 8),
          _queryBar(),
          if (_error != null) _errorCard(),
          if (_loading && page == null)
            const Expanded(
              child: SkeletonListTile(
                itemCount: 6,
                delay: Duration(milliseconds: 150),
              ),
            )
          else if (page != null)
            _resourceResults(page),
        ],
      ),
    );
  }

  Widget _browserHeader(BuildContext context) => Row(
    children: [
      // R33：标题 Expanded（窄屏/字号缩放换行而非溢出），操作区仍贴右。
      Expanded(
        child: LocalizedText(
          widget.kind == ScimResourceKind.users ? 'SCIM Users' : 'SCIM Groups',
          style: Theme.of(context).textTheme.titleLarge,
        ),
      ),
      IconButton(
        onPressed: _loading || _mutating ? null : _load,
        icon: Icon(Icons.refresh, color: _accent),
        tooltip: 'Refresh'.localized,
      ),
      const SizedBox(width: 8),
      FilledButton.icon(
        onPressed: _mutating ? null : _create,
        icon: const Icon(Icons.add),
        label: LocalizedText('Create ${widget.kind.singular.toLowerCase()}'),
      ),
    ],
  );

  Widget _queryBar() => ScimQueryBar(
    kind: widget.kind,
    filterController: _filterController,
    startIndexController: _startIndexController,
    count: _count,
    sortBy: _sortBy,
    descending: _descending,
    busy: _loading || _mutating,
    onCountChanged: _setCount,
    onSortChanged: _setSortBy,
    onDescendingChanged: _setDescending,
    onApply: _applyQuery,
  );

  Widget _resourceResults(ScimListPage page) => Expanded(
    child: Column(
      children: [
        if (_loading) const LinearProgressIndicator(),
        Expanded(
          child: page.resources.isEmpty
              ? _emptyState()
              : ScimResourceTable(
                  kind: widget.kind,
                  resources: page.resources,
                  enabled: !_mutating,
                  onOpen: _showDetail,
                ),
        ),
        _pagination(page),
      ],
    ),
  );

  /// 光标语义：page 传 null（无“Page null”胶囊），汇总文案与现运行格式
  /// 完全同形（U+2013 en-dash）。
  Widget _pagination(ScimListPage page) => PaginationControls(
    page: null,
    total: null,
    summaryLabel: page.totalResults == 0
        ? '0 results'
        : '{start}–{end} of {total}',
    summaryArgs: page.totalResults == 0
        ? null
        : {
            'start': '${page.startIndex}',
            'end':
                '${page.itemsPerPage == 0 ? page.startIndex : page.startIndex + page.itemsPerPage - 1}',
            'total': '${page.totalResults}',
          },
    canGoBack: page.hasPrevious && !(_loading || _mutating),
    canGoNext: page.hasNext && !(_loading || _mutating),
    onPrevious: () => _load(startIndex: max(1, page.startIndex - _count)),
    onNext: () => _load(startIndex: page.startIndex + page.itemsPerPage),
  );

  /// 查询空态：有查询 → noMatch + 清除筛选；无查询 → 空数据。
  Widget _emptyState() {
    final querying = _filterController.text.trim().isNotEmpty;
    if ((_page?.startIndex ?? 1) > 1) {
      return EmptyPageState(onBackToFirst: () => _load(startIndex: 1));
    }
    return EmptyState(
      variant: querying ? EmptyStateVariant.noMatch : EmptyStateVariant.empty,
      title: querying
          ? 'No resources match this query.'
          : 'No resources found.',
      actionLabel: querying ? 'Clear filter' : null,
      actionIcon: Icons.filter_alt_off,
      onAction: querying ? _clearFilter : null,
    );
  }

  /// 错误区：统一 ErrorStateCard（图标 + 明细 + Retry）。
  Widget _errorCard() =>
      ErrorStateCard(message: _error!, onRetry: _load, retryEnabled: !_loading);
}
