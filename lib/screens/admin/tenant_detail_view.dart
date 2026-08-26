part of 'tenant_detail_screen.dart';

mixin _TenantDetailScreenView on State<TenantDetailScreen> {
  Map<String, dynamic>? get _tenant;
  List<dynamic> get _members;
  List<dynamic> get _invitations;
  Map<String, dynamic>? get _usage;
  Map<String, String> get _sectionErrors;
  String? get _error;
  bool get _loading;
  int get _tabIndex;
  Color get _accent;
  List<(String, String, IconData)> get _tabs;

  Future<void> _load();
  void _selectTab(int index, String subresource);
  Future<void> _removeMember(String userId);
  Future<void> _resendInvitation(Map<String, dynamic> invitation);
  Future<void> _revokeInvitation(String email);
  Future<void> _editTenant(BuildContext context);

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Semantics(
        container: true,
        header: true,
        child: LocalizedText(
          'Tenant: {widget_tenantId}',
          args: {'widget_tenantId': widget.tenantId},
        ),
      ),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        tooltip: 'Back'.localized,
        onPressed: () => AdminRoute.back('tenants'),
      ),
      actions: [
        IconButton(
          icon: Icon(Icons.edit_outlined, color: _accent),
          tooltip: 'Edit tenant'.localized,
          onPressed: () => _editTenant(context),
        ),
      ],
    ),
    body: _loading
        ? const SkeletonListTile(itemCount: 6)
        : _error != null
        ? _errorState(_error!)
        : Column(
            children: [
              AdminBreadcrumb(),
              Expanded(child: _buildContent(context)),
            ],
          ),
  );

  /// 加载失败三态之一：统一 ErrorStateView（图标 + 标题 + 明细 + 重试）。
  Widget _errorState(String error) =>
      ErrorStateView(message: error, onRetry: _load);

  Widget _buildContent(BuildContext context) => Column(
    children: [
      _tenantHeader(context),
      if (_tenant != null) ...[const SizedBox(height: 4), _miniStrip(context)],
      _tabBar(context),
      Expanded(child: _tabContent(context)),
    ],
  );

  /// Real-value mini strip (members / invitations / residency region)
  /// ordered per `tenantDetailMetricOrder(persona)` (design §4.9 T-07).
  /// The Members card renders only when the members tab is capability-gated
  /// in; remaining cards keep their relative order. No arrows.
  Widget _miniStrip(BuildContext context) {
    final showMembers = _tabs.any((tab) => tab.$1 == 'members');
    final homeRegion = _tenant?['home_region']?.toString().trim() ?? '';
    final cardByMetric = <TenantDetailMetric, KeyMetricCard>{
      if (showMembers)
        TenantDetailMetric.members: KeyMetricCard(
          label: 'Members',
          value: _members.length,
          icon: Icons.people_outline,
          color: AppColors.primary,
        ),
      TenantDetailMetric.invitations: KeyMetricCard(
        label: 'Invitations',
        value: _invitations.length,
        icon: Icons.mail_outline,
        color: AppColors.accentBlue,
      ),
      TenantDetailMetric.residencyRegion: KeyMetricCard(
        label: 'Home region',
        value: homeRegion.isEmpty ? 0 : 1,
        caption: homeRegion.isEmpty ? '—' : homeRegion,
        icon: Icons.public,
        color: AppColors.success,
      ),
    };
    return MetricStrip(
      cards: [
        for (final metric in tenantDetailMetricOrder(widget.persona))
          if (cardByMetric.containsKey(metric)) cardByMetric[metric]!,
      ],
    );
  }

  Widget _tenantHeader(BuildContext context) =>
      TenantResidencySummary(tenant: _tenant, fallbackId: widget.tenantId);

  Widget _tabBar(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (var i = 0; i < _tabs.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: Icon(_tabs[i].$3, size: 16, color: _accent),
              label: Text('${context.tr(_tabs[i].$2)} (${_countForTab(i)})'),
              selected: _tabIndex == i,
              onSelected: (_) => _selectTab(i, _tabs[i].$1),
            ),
          ),
      ],
    ),
  );

  String _countForTab(int i) => switch (_tabs[i].$1) {
    'members' => '${_members.length}',
    'invitations' => '${_invitations.length}',
    _ => '',
  };

  Widget _tabContent(BuildContext context) {
    switch (_tabs[_tabIndex].$1) {
      case 'members':
        return TenantMembersTab(
          members: _members,
          error: _sectionErrors['members'],
          onRetry: _load,
          onRemove: _removeMember,
        );
      case 'invitations':
        return TenantInvitationsTab(
          invitations: _invitations,
          error: _sectionErrors['invitations'],
          onRetry: _load,
          onResend: _resendInvitation,
          onRevoke: _revokeInvitation,
        );
      case 'usage':
        return TenantUsageTab(
          usage: _usage ?? const {},
          error: _sectionErrors['usage'],
          onRetry: _load,
        );
      case 'branding':
        return TenantBrandingTab(api: widget.api, tenantId: widget.tenantId);
      default:
        return const Center(child: LocalizedText('Select a tab'));
    }
  }
}
