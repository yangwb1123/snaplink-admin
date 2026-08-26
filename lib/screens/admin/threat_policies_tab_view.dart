part of 'threat_policies_tab.dart';

mixin _ThreatPoliciesTabView on State<ThreatPoliciesTab> {
  GlobalKey<FormState> get _formKey;
  List<Map<String, dynamic>> get _policies;
  String? get _error;
  bool get _loading;
  bool get _mutating;
  bool get _editing;
  bool get _creating;
  TextEditingController get _nameCtrl;
  TextEditingController get _descCtrl;
  TextEditingController get _rulesCtrl;
  Color get _accent;
  bool get _available;

  Future<void> _load();
  Future<void> _save();
  Future<void> _delete(String id);

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const EmptyState(variant: EmptyStateVariant.notEnabled);
    }
    if (_creating || _editing) return _buildForm(context);
    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminBreadcrumb(),
          AdminListHeader(
            title: AppStrings.of(context).threatPolicies,
            subtitle:
                'Realtime threat detection rules protecting authentication flows.',
            onRefresh: _load,
            actions: [
              FilledButton.icon(
                onPressed: () =>
                    AdminRoute.go('threat-policies', action: 'new'),
                icon: const Icon(Icons.add, size: 18),
                label: const LocalizedText('Add policy'),
              ),
              const SizedBox(width: 4),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: Icon(Icons.refresh, color: _accent),
                tooltip: context.strings.refresh,
              ),
            ],
          ),
          if (!_loading && _error != null)
            ErrorStateCard(
              message: _error!,
              onRetry: _load,
              margin: EdgeInsets.zero,
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SkeletonListTile(itemCount: 3),
            ),
          if (!_loading && _error == null && _policies.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: EmptyState(
                compact: true,
                title: 'No threat policies configured.',
                actionLabel: 'Add policy',
                onAction: () => AdminRoute.go('threat-policies', action: 'new'),
              ),
            ),
          if (!_loading && _error == null && _policies.isNotEmpty)
            _policiesCard(context),
        ],
      ),
    );
  }

  /// 策略列表卡：组色盾牌图标 + SectionHeader（计数）+ AdminDataTable(compact)。
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
                Icon(Icons.shield_outlined, size: 20, color: _accent),
                const SizedBox(width: 8),
                Expanded(
                  child: SectionHeader(
                    AppStrings.of(context).threatPolicies,
                    count: policies.length,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            AdminDataTable(
              density: TableDensity.compact,
              minWidth: 920,
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
                  id: 'description',
                  label: 'Description'.localized,
                  width: 260, // R52：两行描述列 260 才合理（ID 窄、描述宽）。
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    policies[i]['description']?.toString() ?? '',
                    muted: true,
                    maxLines: 2,
                  ),
                ),
                AdminDataColumn(
                  id: 'id',
                  label: 'ID'.localized,
                  width: 150,
                  builder: (_, i) => CopyableCell(
                    text: policies[i]['id']?.toString() ?? '',
                    contextProvider: () => context,
                  ),
                ),
                AdminDataColumn(
                  id: 'status',
                  label: 'Status'.localized,
                  cardDetail: true, // R52：启用/禁用状态卡片必备（原先被漏）。
                  builder: (_, i) => policies[i]['enabled'] == true
                      ? StatusChip.active(label: 'Enabled')
                      : StatusChip.inactive(label: 'Disabled'),
                ),
                AdminDataColumn(
                  id: 'actions',
                  label: '',
                  width: 100,
                  builder: (_, i) => TextButton(
                    onPressed: _mutating
                        ? null
                        : () => _delete(policies[i]['name']?.toString() ?? ''),
                    style: TextButton.styleFrom(
                      // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
                      foregroundColor: AppColors.semanticFor(
                        Theme.of(context).brightness,
                        AppColors.danger,
                      ),
                    ),
                    child: const LocalizedText('Delete'),
                  ),
                ),
              ],
              itemCount: policies.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
              onRowTap: (i) => AdminRoute.go(
                'threat-policies',
                resourceId: policies[i]['name']?.toString() ?? '',
                action: 'edit',
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildForm(BuildContext context) => Form(
    key: _formKey,
    autovalidateMode: AutovalidateMode.onUserInteraction,
    child: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        Row(
          children: [
            Icon(Icons.shield_outlined, size: 22, color: _accent),
            const SizedBox(width: 8),
            Expanded(
              child: LocalizedText(
                _editing ? 'Edit policy' : 'Add policy',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        TextFormField(
          controller: _nameCtrl,
          decoration: InputDecoration(labelText: 'Name'.localized),
          validator: (value) => value?.trim().isEmpty == true
              ? 'Enter a policy name.'.localized
              : null,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _descCtrl,
          decoration: InputDecoration(labelText: 'Description'.localized),
          maxLines: 2,
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _rulesCtrl,
          decoration: InputDecoration(labelText: 'Rules / Config'.localized),
          maxLines: 4,
        ),
        const SizedBox(height: 16),
        OverflowBar(
          children: [
            OutlinedButton(
              onPressed: () => AdminRoute.go('threat-policies'),
              child: const LocalizedText('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _mutating ? null : _save,
              child: LocalizedText(_editing ? 'Update' : 'Create'),
            ),
          ],
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: LocalizedText(
              _error!,
              // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
              style: TextStyle(
                color: AppColors.semanticFor(
                  Theme.of(context).brightness,
                  AppColors.danger,
                ),
              ),
            ),
          ),
      ],
    ),
  );
}
