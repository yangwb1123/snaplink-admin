part of 'access_policies_tab.dart';

extension _AccessPoliciesTabView on _AccessPoliciesTabState {
  Widget _buildAccessPoliciesTab(BuildContext context) {
    if (!_available) {
      return const EmptyState(variant: EmptyStateVariant.notEnabled);
    }
    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminBreadcrumb(),
          AdminListHeader(
            title: AppStrings.of(context).accessPolicies,
            subtitle:
                'Priority-ordered session access decisions; converge applies '
                'them to active sessions.',
            onRefresh: _load,
            actions: [
              if (_canConverge) ...[
                FilledButton.icon(
                  onPressed: _loading || _converging ? null : _converge,
                  icon: _converging
                      ? const SizedBox.square(
                          dimension: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.policy_outlined),
                  label: const LocalizedText('Apply to active sessions'),
                ),
                const SizedBox(width: 4),
              ],
              IconButton(
                onPressed: _loading ? null : _load,
                icon: Icon(Icons.refresh, color: _accent),
                tooltip: context.strings.refresh,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: SearchFilterBar(
              hintText: 'Search...'.localized,
              controller: _searchCtrl,
              debounce: false,
              onSearchChanged: _onSearchChanged,
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                _filterDropdown(
                  value: _verdictFilter,
                  options: const [
                    ('all', 'All'),
                    ('allow', 'Allow'),
                    ('deny', 'Deny'),
                    ('step_up', 'Require step-up'),
                  ],
                  onChanged: _setVerdictFilter,
                ),
                _filterDropdown(
                  value: _statusFilter,
                  options: const [
                    ('all', 'All statuses'),
                    ('enabled', 'Enabled'),
                    ('disabled', 'Disabled'),
                    ('dry_run', 'Dry run'),
                  ],
                  onChanged: _setStatusFilter,
                ),
                if (_searchCtrl.text.isNotEmpty ||
                    _verdictFilter != 'all' ||
                    _statusFilter != 'all')
                  TextButton.icon(
                    onPressed: _clearFilters,
                    icon: const Icon(Icons.filter_alt_off, size: 18),
                    label: const LocalizedText('Clear filter'),
                  ),
              ],
            ),
          ),
          if (!_canConverge)
            const Padding(
              padding: EdgeInsets.only(bottom: 12),
              child: LocalizedText(
                'Active-session convergence is not advertised by this server.',
              ),
            ),
          if (_convergenceError != null)
            _statusCard(_convergenceError!, isError: true),
          if (_convergence != null) _convergenceCard(_convergence!),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SkeletonListTile(itemCount: 3),
            ),
          if (!_loading && _error != null)
            ErrorStateCard(
              message: _error!,
              onRetry: _load,
              margin: EdgeInsets.zero,
            ),
          if (!_loading && _error == null && _policies.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: EmptyState(
                compact: true,
                title: 'No access policies',
                subtitle:
                    'Policies are configured server-side; this page applies them to active sessions.',
              ),
            ),
          if (!_loading && _error == null && _policies.isNotEmpty)
            _visiblePolicies().isEmpty
                ? Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: EmptyState(
                      compact: true,
                      variant: EmptyStateVariant.noMatch,
                      title: 'No matches',
                      actionLabel: 'Clear filter',
                      actionIcon: Icons.filter_alt_off,
                      onAction: _clearFilters,
                    ),
                  )
                : _policiesCard(context, _visiblePolicies()),
        ],
      ),
    );
  }

  Widget _filterDropdown({
    required String value,
    required List<(String, String)> options,
    required ValueChanged<String> onChanged,
  }) => TightDropdownButton<String>(
    value: value,
    options: options,
    maxWidth: 190,
    onChanged: onChanged,
  );

  /// 策略列表卡：组色图标 + SectionHeader + AdminDataTable(compact)。
  Widget _policiesCard(
    BuildContext context,
    List<Map<String, dynamic>> policies,
  ) {
    final pageCount = math.max(
      1,
      (policies.length + _AccessPoliciesTabState._pageSize - 1) ~/
          _AccessPoliciesTabState._pageSize,
    );
    final page = _page.clamp(1, pageCount);
    final pageRows = policies
        .skip((page - 1) * _AccessPoliciesTabState._pageSize)
        .take(_AccessPoliciesTabState._pageSize)
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.policy_outlined, size: 20, color: _accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SectionHeader(
                        'Access Policies',
                        count: policies.length,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                AdminDataTable(
                  density: TableDensity.compact,
                  sortColumn: _sortColumn,
                  sortAscending: _sortAscending,
                  onSort: _onSort,
                  columns: [
                    AdminDataColumn(
                      id: 'policy',
                      label: 'Policy'.localized,
                      width: 220,
                      sortable: true,
                      cardPrimary: true,
                      builder: (_, i) => TableCellText(
                        pageRows[i]['name']?.toString() ?? '',
                        level: DataEmphasisLevel.primary,
                      ),
                    ),
                    AdminDataColumn(
                      id: 'verdict',
                      label: 'Verdict'.localized,
                      width: 170,
                      sortable: true,
                      cardDetail: true,
                      builder: (_, i) =>
                          _verdictChip(accessPolicyVerdict(pageRows[i])),
                    ),
                    AdminDataColumn(
                      id: 'priority',
                      label: 'Priority'.localized,
                      width: 100,
                      sortable: true,
                      cardDetail: true,
                      builder: (_, i) => TableCellText(
                        '${pageRows[i]['priority'] ?? 0}',
                        muted: true,
                      ),
                    ),
                    AdminDataColumn(
                      id: 'conditions',
                      label: 'Conditions'.localized,
                      width: 260,
                      sortable: true,
                      cardDetail: true,
                      builder: (_, i) {
                        final c = accessPolicyConditionLabels(pageRows[i]);
                        return TableCellText(
                          c.isEmpty
                              ? context.tr(
                                  'No conditions (matches every session)',
                                )
                              : c.join(' · '),
                          muted: true,
                          maxLines: 3,
                        );
                      },
                    ),
                    AdminDataColumn(
                      id: 'scope',
                      label: 'Scope ceiling'.localized,
                      width: 220,
                      sortable: true,
                      cardDetail: true,
                      builder: (_, i) {
                        final s = accessPolicyScopeCeiling(pageRows[i]);
                        return TableCellText(
                          s.isEmpty ? '—' : s.join(', '),
                          muted: true,
                          maxLines: 3,
                        );
                      },
                    ),
                    AdminDataColumn(
                      id: 'status',
                      // R52：原先空表头中置列——补 'Flags' 表头并进卡片细节
                      // （dry_run/disabled 标志一目了然）。
                      label: 'Flags'.localized,
                      width: 170,
                      sortable: true,
                      cardDetail: true,
                      builder: (_, i) => _statusFlags(pageRows[i]),
                    ),
                  ],
                  itemCount: pageRows.length,
                  rowBuilder: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
        if (policies.length > _AccessPoliciesTabState._pageSize)
          PaginationControls(
            page: page,
            total: policies.length,
            canGoBack: page > 1,
            canGoNext: page < pageCount,
            onPrevious: _previousPage,
            onNext: _nextPage,
          ),
      ],
    );
  }

  Widget _verdictChip(String verdict) => switch (verdict) {
    'Deny' => StatusChip.failed(label: 'Deny'),
    'Allow' => StatusChip.active(label: 'Allow'),
    _ => StatusChip.info(label: verdict),
  };

  Widget _statusFlags(Map<String, dynamic> policy) {
    final flags = <Widget>[
      if (policy['dry_run'] == true) _flagChip('Dry run'),
      if (policy['enabled'] == true)
        _flagChip('Enabled')
      else
        _flagChip('Disabled'),
    ];
    return flags.isEmpty
        ? const SizedBox.shrink()
        : Wrap(spacing: 4, runSpacing: 4, children: flags);
  }

  Widget _flagChip(String label) => Chip(
    label: LocalizedText(label),
    labelStyle: const TextStyle(fontSize: 11),
    visualDensity: VisualDensity.compact,
    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
  );

  Widget _convergenceCard(Map<String, dynamic> result) => _statusCard(
    'Convergence complete: ${result['scanned'] ?? 0} scanned, '
    '${result['revoked'] ?? 0} revoked, ${result['step_up_marked'] ?? 0} '
    'marked for step-up, ${result['scopes_restricted'] ?? 0} scope ceilings '
    'reduced, ${result['failed'] ?? 0} failed.',
    isError: (result['failed'] as num?)?.toInt() != 0,
  );

  Widget _statusCard(String message, {required bool isError}) => Card(
    color: isError
        ? Theme.of(context).colorScheme.errorContainer
        : Theme.of(context).colorScheme.secondaryContainer,
    child: Padding(padding: const EdgeInsets.all(12), child: Text(message)),
  );
}
