part of 'governance_tab.dart';

extension _GovernanceTabView on _GovernanceTabState {
  Widget _buildGovernanceTab(BuildContext context) => Column(
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
                Icon(Icons.admin_panel_settings_outlined, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Semantics(
                    container: true,
                    header: true,
                    child: Text(
                      AppStrings.of(context).governanceOperations,
                      style: Theme.of(context).textTheme.headlineSmall,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const Spacer(),
                IconButton(
                  onPressed: _loading || _writing ? null : _refresh,
                  tooltip: 'Refresh'.localized,
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SectionSelector(
              sections: _GovernanceTabState._sections,
              current: _currentSection,
              onSelected: _selectSection,
            ),
          ],
        ),
      ),
      Expanded(
        child: PullToRefresh(
          onRefresh: _refresh,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (_error != null)
                GovernanceErrorBanner(error: _error!, onRetry: _refresh),
              if (_loading) const SkeletonListTile(itemCount: 3),
              if (_show('all') || _show('health'))
                _readSection(
                  'Platform health',
                  Icons.monitor_heart_outlined,
                  'health',
                ),
              if (_show('all') || _show('audit')) _auditPanel(context),
              if (_show('all') || _show('compliance'))
                _readSection(
                  'Compliance evidence',
                  Icons.verified_outlined,
                  'compliance',
                ),
              if (_show('all') || _show('configuration'))
                _readSection(
                  'Configuration assurance',
                  Icons.settings_outlined,
                  'configuration',
                ),
              if (_show('all') || _show('lifecycle'))
                _readSection(
                  'Snapshots, releases, and change approvals',
                  Icons.swap_vert,
                  'lifecycle',
                ),
              if (_show('all') || _show('write')) _writePanel(context),
              if (_data.containsKey('lastWrite'))
                GovernanceJsonCard(
                  title: 'Last write response',
                  data: _data['lastWrite']!,
                ),
            ],
          ),
        ),
      ),
    ],
  );

  bool _show(String section) =>
      _currentSection == 'all' || _currentSection == section;

  Widget _readSection(String title, IconData icon, String section) =>
      GovernanceReadSection(
        title: title,
        icon: icon,
        specs: governanceReadSpecs
            .where((spec) => spec.section == section && _has('GET', spec.path))
            .toList(),
        data: _data,
        loading: _loading,
        accent: _accent,
        onRefresh: _read,
      );

  Widget _auditPanel(BuildContext context) => GovernanceAuditPanel(
    queryController: _auditQuery,
    enabled: _has('GET', _GovernanceTabState._auditPath),
    loading: _loading,
    accent: _accent,
    onQuery: _queryAudit,
    result: _data['audit'],
    facets: _data['facets'],
  );

  Widget _writePanel(BuildContext context) => GovernanceWritePanel(
    operations: governanceWriteOperations
        .where((op) => _has(op.method, op.path))
        .toList(),
    writing: _writing,
    accent: _accent,
    onWrite: _submitWrite,
  );
}
