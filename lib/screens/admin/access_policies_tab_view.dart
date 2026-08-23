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
            _policiesCard(context),
        ],
      ),
    );
  }

  /// 策略列表卡：组色图标 + SectionHeader + AdminDataTable(compact)。
  Widget _policiesCard(BuildContext context) {
    final policies = _policies;
    return Card(
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
              columns: [
                AdminDataColumn(
                  id: 'policy',
                  label: 'Policy'.localized,
                  width: 220,
                  cardPrimary: true,
                  builder: (_, i) => TableCellText(
                    policies[i]['name']?.toString() ?? '',
                    level: DataEmphasisLevel.primary,
                  ),
                ),
                AdminDataColumn(
                  id: 'verdict',
                  label: 'Verdict'.localized,
                  width: 170,
                  cardDetail: true,
                  builder: (_, i) =>
                      _verdictChip(accessPolicyVerdict(policies[i])),
                ),
                AdminDataColumn(
                  id: 'priority',
                  label: 'Priority'.localized,
                  width: 100,
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    '${policies[i]['priority'] ?? 0}',
                    muted: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'conditions',
                  label: 'Conditions'.localized,
                  width: 260,
                  cardDetail: true,
                  builder: (_, i) {
                    final c = accessPolicyConditionLabels(policies[i]);
                    return TableCellText(
                      c.isEmpty
                          ? context.tr('No conditions (matches every session)')
                          : c.join(' · '),
                      muted: true,
                      maxLines: 2,
                    );
                  },
                ),
                AdminDataColumn(
                  id: 'scope',
                  label: 'Scope ceiling'.localized,
                  width: 220,
                  cardDetail: true,
                  builder: (_, i) {
                    final s = accessPolicyScopeCeiling(policies[i]);
                    return TableCellText(
                      s.isEmpty ? '—' : s.join(', '),
                      muted: true,
                      maxLines: 2,
                    );
                  },
                ),
                AdminDataColumn(
                  id: 'status',
                  // R52：原先空表头中置列——补 'Flags' 表头并进卡片细节
                  // （dry_run/disabled 标志一目了然）。
                  label: 'Flags'.localized,
                  width: 170,
                  cardDetail: true,
                  builder: (_, i) => _statusFlags(policies[i]),
                ),
              ],
              itemCount: policies.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ],
        ),
      ),
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
      if (policy['enabled'] != true) _flagChip('Disabled'),
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
