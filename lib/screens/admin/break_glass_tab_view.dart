part of 'break_glass_tab.dart';

mixin _BreakGlassTabView on State<BreakGlassTab> {
  TextEditingController get _targetCtrl;
  TextEditingController get _reasonCtrl;
  String get _scope;
  set _scope(String value);
  set _ttl(String? value);
  bool get _requireApproval;
  set _requireApproval(bool value);
  List<Map<String, dynamic>> get _sessions;
  String? get _loadError;
  String? get _actionError;
  bool get _loading;
  bool get _mutating;
  bool get _mutationOutcomeUnknown;
  Color get _accent;
  bool get _available;

  Future<void> _load();
  Future<void> _approve(String id);
  Future<void> _revoke(String id);
  Future<void> _impersonate(String id);
  Future<void> _acknowledgeUnknownOutcome();

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        title: 'Break-glass access is not enabled on this replica.',
      );
    }
    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminBreadcrumb(),
          AdminListHeader(
            title: AppStrings.of(context).emergencyAccess,
            subtitle:
                'Create audited, time-bound emergency access to user accounts.',
            onRefresh: _load,
            actions: [
              IconButton(
                onPressed: _loading ? null : _load,
                icon: Icon(Icons.refresh, color: _accent),
                tooltip: context.strings.refresh,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.secondaryContainer,
              borderRadius: BorderRadius.circular(8),
            ),
            child: const LocalizedText(
              'Requests are time-bound and reason-required; every request and session is recorded.',
            ),
          ),
          const SizedBox(height: 12),
          BreakGlassRequestCard(
            targetController: _targetCtrl,
            reasonController: _reasonCtrl,
            scope: _scope,
            requireApproval: _requireApproval,
            mutating: _mutating || _mutationOutcomeUnknown,
            accent: _accent,
            formError: _actionError,
            onScopeChanged: (value) => setState(() => _scope = value),
            onTtlChanged: (value) => _ttl = value,
            onRequireApprovalChanged: (value) =>
                setState(() => _requireApproval = value),
            onCreate: () => AdminRoute.go('emergency-access', action: 'new'),
          ),
          const SizedBox(height: 16),
          if (_mutationOutcomeUnknown)
            AdminOpsHelpers.unknownOutcomeCard(
              context,
              onAcknowledge: _mutating ? null : _acknowledgeUnknownOutcome,
            ),
          if (_mutationOutcomeUnknown) const SizedBox(height: 12),
          if (_loadError != null)
            ErrorStateCard(
              message: _loadError!,
              onRetry: _load,
              margin: EdgeInsets.zero,
            )
          else
            BreakGlassSessionsList(
              sessions: _sessions,
              loading: _loading,
              mutating: _mutating || _mutationOutcomeUnknown,
              accent: _accent,
              onRefresh: _load,
              onOpen: (id) => AdminRoute.go('emergency-access', resourceId: id),
              onApprove: _approve,
              onImpersonate: _impersonate,
              onRevoke: _revoke,
            ),
        ],
      ),
    );
  }
}
