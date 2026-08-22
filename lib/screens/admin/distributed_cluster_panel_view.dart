part of 'distributed_cluster_panel.dart';

extension _DistributedClusterPanelView on _PanelState {
  Widget _buildClusterPanel(BuildContext context) {
    final keys = _signingKeys;
    final active = keys.where((key) => key['state'] == 'active').toList();
    final verifyOnly = keys
        .where((key) => key['state'] != 'active' && key['kid'] != null)
        .toList();
    final checks = (_readyz?['checks'] as Map?) ?? const {};
    final modules = (_status?['modules'] as Map?) ?? const {};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _clusterOverviewCard(
          context,
          keys: keys,
          active: active,
          verifyOnly: verifyOnly,
          checks: checks,
          modules: modules,
        ),
        const SizedBox(height: 12),
        _clusterSelfTestCard(context),
      ],
    );
  }

  Widget _clusterOverviewCard(
    BuildContext context, {
    required List<Map<String, dynamic>> keys,
    required List<Map<String, dynamic>> active,
    required List<Map<String, dynamic>> verifyOnly,
    required Map<dynamic, dynamic> checks,
    required Map<dynamic, dynamic> modules,
  }) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.hub,
                size: 24,
                color: adminModuleIconColor(AdminModuleId.health),
              ),
              const SizedBox(width: 8),
              LocalizedText(
                'Distributed Cluster',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
          const Divider(),
          ..._signingKeyWidgets(
            keys: keys,
            active: active,
            verifyOnly: verifyOnly,
          ),
          const Divider(),
          _row(
            _t('Control Plane'),
            _t('Distributed control plane (etcd bus / key registry)'),
          ),
          const SizedBox(height: 8),
          _readyzWrap(context, checks),
          if (modules.isNotEmpty) ...[
            const Divider(),
            _row(_t('Backend Modules'), '${modules.length} module(s)'),
            const SizedBox(height: 8),
            _modulesWrap(context, modules),
          ],
        ],
      ),
    ),
  );

  List<Widget> _signingKeyWidgets({
    required List<Map<String, dynamic>> keys,
    required List<Map<String, dynamic>> active,
    required List<Map<String, dynamic>> verifyOnly,
  }) => [
    _row(
      _t('Replica keys'),
      _t('{n} replica keys (1 active, {m} verify-only)', {
        'n': keys.length,
        'm': verifyOnly.length,
      }),
    ),
    if (active.isNotEmpty)
      Padding(
        padding: const EdgeInsets.only(bottom: 4),
        child: _kidChip(_t('Active key'), active.first, true),
      ),
    if (verifyOnly.isNotEmpty) ...[
      const Padding(
        padding: EdgeInsets.only(top: 4, bottom: 4),
        child: LocalizedText(
          'Adopted peer keys (verify-only)',
          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
      ),
      _verifyOnlyWrap(verifyOnly),
    ],
    if (_jwksKids.isNotEmpty) ...[
      const SizedBox(height: 8),
      _row(
        _t('JWKS union'),
        '${_jwksKids.length} kid(s): ${_jwksKids.join(', ')}',
      ),
    ],
  ];

  Widget _clusterSelfTestCard(BuildContext context) {
    final results = _testResults;
    final passed = results?.where((result) => result.passed).length ?? 0;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.science_outlined,
                  size: 24,
                  color: adminModuleIconColor(AdminModuleId.health),
                ),
                const SizedBox(width: 8),
                Flexible(
                  child: LocalizedText(
                    'Cluster Self-Test',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const Spacer(),
                FilledButton.icon(
                  onPressed: _testing ? null : _runSelfTest,
                  icon: _testing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.play_arrow, size: 18),
                  label: LocalizedText(
                    _testing ? 'Running...' : 'Run Cluster Self-Test',
                  ),
                ),
              ],
            ),
            if (results != null) ...[
              const Divider(),
              ..._selfTestResultWidgets(results, passed),
            ],
          ],
        ),
      ),
    );
  }

  List<Widget> _selfTestResultWidgets(
    List<_ClusterCheck> results,
    int passed,
  ) => [
    for (final result in results)
      ListTile(
        dense: true,
        contentPadding: EdgeInsets.zero,
        leading: Icon(
          result.passed ? Icons.check_circle : Icons.cancel,
          color: result.passed ? AppColors.success : AppColors.danger,
        ),
        title: Text(result.label),
        subtitle: Text(result.detail),
      ),
    Text(
      passed == results.length
          ? _t('All {n} checks passed', {'n': results.length})
          : _t('{passed} of {n} checks passed', {
              'passed': passed,
              'n': results.length,
            }),
      style: TextStyle(
        fontWeight: FontWeight.w600,
        color: passed == results.length ? AppColors.success : AppColors.danger,
      ),
    ),
  ];
}
