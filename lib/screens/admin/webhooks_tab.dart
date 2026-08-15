import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/distribution_bar.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/status_filter_dropdown.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';

/// Webhook subscriptions and dead letter management tab.
class WebhooksTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const WebhooksTab({super.key, required this.api, required this.capabilities});
  @override
  State<WebhooksTab> createState() => _WebhooksTabState();
}

class _WebhooksTabState extends State<WebhooksTab> {
  static const _subsPath = '/api/v1/admin/webhooks/subscriptions';
  static const _deadPath = '/api/v1/admin/webhooks/deadletters';
  final _urlCtrl = TextEditingController();
  final _eventsCtrl = TextEditingController();
  final _secretCtrl = TextEditingController();
  bool _active = true;
  List<Map<String, dynamic>> _subscriptions = const [];
  List<Map<String, dynamic>> _deadLetters = const [];
  String? _error;
  bool _loading = false;
  var _statusFilter = 'all';
  bool _mutating = false;
  late final void Function() _cancelPopState;

  /// 模块组色（developers → emerald）：页头图标统一上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.webhooks);
  bool get _hasSubscriptions => widget.capabilities.hasAnyPathPrefix(_subsPath);
  bool get _hasDeadLetters => widget.capabilities.hasAnyPathPrefix(_deadPath);

  @override
  void initState() {
    super.initState();
    _handleRoute();
    _load();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'webhooks') return;
    if (route.isNew) _create();
  }

  @override
  void dispose() {
    _cancelPopState();
    _urlCtrl.dispose();
    _eventsCtrl.dispose();
    _secretCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
        setState(() {
          _loading = true;
          _error = null;
        });
        try {
          final results = await Future.wait([
            if (_hasSubscriptions)
              widget.api.getStaleWhileRevalidate(
                _subsPath, onRefresh: _applySubsRefresh),
            if (_hasDeadLetters)
              widget.api.getStaleWhileRevalidate(
                _deadPath, onRefresh: _applyDeadRefresh),
          ]);
          if (!mounted) return;
          var idx = 0;
          setState(() {
            if (_hasSubscriptions) _subscriptions = _maps(results[idx++]['subscriptions']);
            if (_hasDeadLetters) _deadLetters = _maps(results[idx]['deadletters'] ?? results[idx]['messages']);
            _loading = false;
          });
        } on SnaplinkAdminApiError catch (e) {
          _fail(e.toString());
        } catch (_) {
          _fail('Could not load webhooks.');
        }
  }

  void _applySubsRefresh(Map<String, dynamic> fresh) {
    if (mounted) setState(() => _subscriptions = _maps(fresh['subscriptions']));
  }
  void _applyDeadRefresh(Map<String, dynamic> fresh) {
    if (mounted) {
      setState(
        () => _deadLetters = _maps(fresh['deadletters'] ?? fresh['messages']),
      );
    }
  }

  /// API 列表 → 强类型 Map 列表（空/缺省为 []）。
  List<Map<String, dynamic>> _maps(Object? raw) =>
      [for (final e in raw as List? ?? const []) Map<String, dynamic>.from(e as Map)];

  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _error = message;
      _loading = false;
    });
  }

  /// 变更操作壳：mutating + snackbar + 错误回写（delete 共用）。
  Future<void> _mutate(String success, Future<void> Function() run) async {
    setState(() {
      _mutating = true;
      _error = null;
    });    try {
      await run();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: LocalizedText(success)));
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _create() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'URL is required.');
      return;
    }
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final events = _eventsCtrl.text.trim().split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();      await widget.api.post(_subsPath, {
        'url': url,
        if (events.isNotEmpty) 'event_types': events,
        if (_secretCtrl.text.trim().isNotEmpty) 'secret': _secretCtrl.text.trim(),
        'active': _active,
      });
      if (!mounted) return;
      _urlCtrl.clear();
      _eventsCtrl.clear();
      _secretCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: LocalizedText('Webhook subscription created.')));
      if (mounted) AdminRoute.go('webhooks');
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      _secretCtrl.clear();
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _delete(String id) async {
    final confirmed = await ConfirmDialog.show(context, title: 'Delete subscription?', message: 'Delete webhook subscription $id?', confirmLabel: 'Delete', destructive: true, confirmText: id);
    if (!confirmed) return;
    await _mutate('Subscription deleted.', () async {
      await widget.api.delete('$_subsPath/${Uri.encodeComponent(id)}');
      await _load();
    });
  }

  Future<void> _replay(String id) async {
    final confirmed = await ConfirmDialog.show(context, title: 'Replay dead letter?', message: 'Replay this failed delivery?', confirmLabel: 'Replay', destructive: true, confirmText: id);
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final response = await widget.api.post('$_deadPath/${Uri.encodeComponent(id)}/replay');
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final cleanupComplete = response['cleanup_status'] == 'complete';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            cleanupComplete
                ? 'Delivery sent and dead-letter cleanup completed.'
                : 'Delivery succeeded; cleanup remains pending. Retrying this '
                      'entry is cleanup-only and cannot redeliver it.',
          ),
        ),
      );
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_hasSubscriptions && !_hasDeadLetters) {
      return const EmptyState(variant: EmptyStateVariant.notEnabled, title: 'Webhook management is not enabled on this replica.');
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        _header(context),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusFilterDropdown(
            value: _statusFilter,
            options: const {'all': 'All statuses', 'active': 'Active only', 'inactive': 'Inactive only'},
            onChanged: (value) => setState(() => _statusFilter = value),
          ),
        ),
        if (_error != null) ...[const SizedBox(height: 8), _errorCard(context)],
        if (_hasSubscriptions) ...[
          const SizedBox(height: 12),
          _createCard(context),
          const SizedBox(height: 16),
          _subscriptionsCard(context),
          const SizedBox(height: 16),
        ],
        if (_hasDeadLetters) _deadLettersCard(context),
      ],
    );
  }

  /// 页头：模块组色图标 + 标题 + 副标题 + 刷新（X7）。
  Widget _header(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.webhook, color: _accent, size: 28),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(container: true, header: true, child: Text(AppStrings.of(context).webhooks, style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600, letterSpacing: -0.3))),
                const SizedBox(height: 4),
                LocalizedText('Manage event notification webhook subscriptions and dead letters.', style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 12),
          IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh), tooltip: 'Refresh'.localized),
        ],
      ),
    );
  }

  /// 错误区：统一 ErrorStateCard（图标 + 明细 + Retry）；错误文本动态 Text（X10）。
  Widget _errorCard(BuildContext context) => ErrorStateCard(
    message: _error!,
    onRetry: _load,
    retryEnabled: !_loading,
  );

  Widget _createCard(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          LocalizedText('New subscription', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          _field(_urlCtrl, label: 'Webhook URL', hint: 'https://hooks.example.com/events'),
          const SizedBox(height: 12),
          _field(_eventsCtrl, label: 'Event types (comma-separated)', hint: 'user.created, session.revoked'),
          const SizedBox(height: 12),
          _field(_secretCtrl, label: 'Signing secret (optional)', obscure: true),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const LocalizedText('Active'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          FilledButton(onPressed: () => AdminRoute.go('webhooks', action: 'new'), child: const LocalizedText('Create subscription')),
        ],
      ),
    ),
  );

  Widget _field(TextEditingController controller, {required String label, String? hint, bool obscure = false}) => TextField(
    controller: controller,
    obscureText: obscure,
    decoration: InputDecoration(labelText: label.localized, hintText: hint?.localized),
  );

  /// 按状态筛选后的订阅列表（本地过滤；分页不存在，语义正确）。
  List<Map<String, dynamic>> get _visibleSubscriptions {
    if (_statusFilter == 'all') return _subscriptions;
    final active = _statusFilter == 'active';
    return _subscriptions.where((s) => (s['active'] == true) == active).toList();
  }

  /// 订阅健康摘要：占比条 + 计数（活跃占比一眼可见）。
  Widget _subscriptionsHealth(BuildContext context) {
    final visible = _visibleSubscriptions;
    final total = visible.length;
    final active = visible.where((s) => s['active'] == true).length;
    final fraction = total == 0 ? 0.0 : active / total;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          LocalizedText('Subscriptions health', style: Theme.of(context).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600)),
          const Spacer(),
          Text('$active of $total active', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: fraction >= 0.7 ? AppColors.success : fraction >= 0.4 ? AppColors.warning : AppColors.danger)),
        ]),
        const SizedBox(height: 4),
        DistributionBar(segments: [DistributionSegment(label: 'Active', value: active, color: AppColors.success), DistributionSegment(label: 'Inactive', value: total - active, color: AppColors.muted)], showLegend: false),
      ]),
    );
  }

  /// 表格壳：紧凑密度 + 行点击（两表共用）。
  AdminDataTable _table(List<AdminDataColumn> columns, int count, {void Function(int)? onRowTap}) => AdminDataTable(
    density: TableDensity.compact,
    minWidth: 560,
    columns: columns,
    itemCount: count,
    rowBuilder: (context, i) => const SizedBox.shrink(),
    onRowTap: onRowTap,
  );

  /// 订阅状态徽章（状态 = 颜色 + 文字，双表达）。
  Widget _statusChip(Map<String, dynamic> sub) => sub['active'] == true
      ? StatusChip.active(label: context.tr('Active'))
      : StatusChip.inactive(label: context.tr('Inactive'));

  /// 数据区块壳：SectionHeader + loading 骨架 + empty 态（两表共用）。
  Widget _section(String title, List data, Widget empty, Widget table) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(title, count: data.isEmpty ? null : data.length),
      if (_loading) const SkeletonListTile(itemCount: 3),
      if (!_loading && data.isEmpty) empty,
      if (!_loading && data.isNotEmpty) table,
    ],
  );

  Widget _subscriptionsCard(BuildContext context) {
    final visible = _visibleSubscriptions;
    return _section(
      'Subscriptions',
      visible,
      const EmptyState(variant: EmptyStateVariant.empty, title: 'No subscriptions.', compact: true),
      Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        _subscriptionsHealth(context),
        const SizedBox(height: 8),
        _table(
          [
            AdminDataColumn(id: 'status', label: 'STATUS', width: 170, builder: (context, i) => _statusChip(visible[i])),
            AdminDataColumn(id: 'url', label: 'URL', width: 240, cardPrimary: true, builder: (context, i) => TableCellText(visible[i]['url']?.toString() ?? '', bold: true)),
            AdminDataColumn(id: 'events', label: 'ID · EVENTS', width: 300, builder: (context, i) => TableCellText('${visible[i]['id'] ?? ''} · events: ${(visible[i]['event_types'] as List?)?.join(', ') ?? 'all'}', muted: true)),
            AdminDataColumn(id: 'actions', label: '', width: 90, builder: (context, i) => TextButton(onPressed: _mutating ? null : () => _delete(visible[i]['id']?.toString() ?? ''), style: TextButton.styleFrom(foregroundColor: AppColors.danger), child: const LocalizedText('Delete'))),
          ],
          visible.length,
          onRowTap: (i) => AdminRoute.go('webhooks', resourceId: visible[i]['id']?.toString() ?? ''),
        ),
      ]),
    );
  }

  Widget _deadLettersCard(BuildContext context) => _section(
    'Dead letters',
    _deadLetters,
    const EmptyState(variant: EmptyStateVariant.empty, title: 'No dead letters.', compact: true),
    _table(
      [
        AdminDataColumn(id: 'event', label: 'EVENT', width: 220, cardPrimary: true, builder: (context, i) => TableCellText(_deadLetters[i]['event_type']?.toString() ?? _deadLetters[i]['type']?.toString() ?? 'Unknown', bold: true)),
        AdminDataColumn(id: 'id', label: 'ID', width: 140, builder: (context, i) => TableCellText(_deadLetters[i]['id']?.toString() ?? '', muted: true)),
        AdminDataColumn(id: 'error', label: 'ERROR', width: 280, builder: (context, i) => TableCellText(_deadLetters[i]['error']?.toString() ?? '', muted: true, maxLines: 2)),
        AdminDataColumn(id: 'actions', label: '', width: 90, builder: (context, i) => TextButton(onPressed: _mutating ? null : () => _replay(_deadLetters[i]['id']?.toString() ?? ''), child: const LocalizedText('Replay'))),
      ],
      _deadLetters.length,
    ),
  );
}
