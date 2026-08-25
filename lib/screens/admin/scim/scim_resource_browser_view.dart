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

  Widget _browserHeader(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final title = LocalizedText(
        widget.kind == ScimResourceKind.users ? 'SCIM Users' : 'SCIM Groups',
        style: Theme.of(context).textTheme.titleLarge,
      );
      final actions = Wrap(
        spacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          IconButton(
            onPressed: _loading || _mutating ? null : _load,
            icon: Icon(Icons.refresh, color: _accent),
            tooltip: 'Refresh'.localized,
          ),
          FilledButton.icon(
            onPressed: _mutating ? null : _create,
            icon: const Icon(Icons.add),
            label: LocalizedText(
              'Create ${widget.kind.singular.toLowerCase()}',
            ),
          ),
        ],
      );
      // Keep create/refresh in the normal flow on phones. A trailing Row
      // makes the create affordance overflow before the resource cards do.
      if (constraints.maxWidth < 520) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            title,
            const SizedBox(height: 8),
            Align(alignment: Alignment.centerRight, child: actions),
          ],
        );
      }
      return Row(
        children: [
          Expanded(child: title),
          actions,
        ],
      );
    },
  );

  Widget _queryBar() => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth < 640
        ? _mobileQueryBar()
        : ScimQueryBar(
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
          ),
  );

  /// The shared query bar has deliberately wide desktop controls. Stack the
  /// same filter/sort/page controls on narrow screens instead of making them
  /// part of a second horizontal scroll surface.
  Widget _mobileQueryBar() {
    final busy = _loading || _mutating;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _filterController,
              decoration: InputDecoration(
                labelText: 'SCIM search filter'.localized,
                hintText: widget.kind == ScimResourceKind.users
                    ? 'userName co "alice"'
                    : 'displayName sw "ops"',
                helperText:
                    'RFC 7644 filter; blank returns all resources'.localized,
                prefixIcon: const Icon(Icons.search),
              ),
              onSubmitted: (_) => busy ? null : _applyQuery(),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _startIndexController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: 'Start index'.localized,
                      helperText: '1-based'.localized,
                    ),
                    onSubmitted: (_) => busy ? null : _applyQuery(),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: _count,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Count'.localized,
                      helperText: 'Max 200'.localized,
                    ),
                    items: const [25, 50, 100, 200]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: LocalizedText(
                              '{value}',
                              args: {'value': value},
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: busy
                        ? null
                        : (value) => _setCount(value ?? _count),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<String>(
                    initialValue: _sortBy,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Sort by'.localized,
                      helperText: 'Before pagination'.localized,
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: '',
                        child: LocalizedText('Store order'),
                      ),
                      ...widget.kind.sortAttributes.map(
                        (value) => DropdownMenuItem(
                          value: value,
                          child: Text(value, overflow: TextOverflow.ellipsis),
                        ),
                      ),
                    ],
                    onChanged: busy ? null : (value) => _setSortBy(value ?? ''),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<bool>(
                    initialValue: _descending,
                    isExpanded: true,
                    decoration: InputDecoration(
                      labelText: 'Order'.localized,
                      helperText: 'Case-insensitive'.localized,
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: false,
                        child: LocalizedText('Ascending'),
                      ),
                      DropdownMenuItem(
                        value: true,
                        child: LocalizedText('Descending'),
                      ),
                    ],
                    onChanged: busy
                        ? null
                        : (value) => _setDescending(value ?? false),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: busy ? null : _applyQuery,
              icon: const Icon(Icons.manage_search),
              label: const LocalizedText('Apply filters'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _resourceResults(ScimListPage page) => Expanded(
    child: Column(
      children: [
        if (_loading || _mutating) const LinearProgressIndicator(),
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
