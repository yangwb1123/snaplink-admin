import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/status_filter_dropdown.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/distribution_bar.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'admin_route.dart';
import 'package:sso_admin/i18n/app_strings.dart';

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
        if (_hasSubscriptions) widget.api.get(_subsPath),
        if (_hasDeadLetters) widget.api.get(_deadPath),
      ]);
      if (!mounted) return;
      var idx = 0;
      setState(() {
        if (_hasSubscriptions) {
          final items = results[idx++]['subscriptions'] as List? ?? [];
          _subscriptions = items
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        if (_hasDeadLetters) {
          final items =
              results[idx]['deadletters'] as List? ??
              results[idx]['messages'] as List? ??
              [];
          _deadLetters = items
              .map((e) => Map<String, dynamic>.from(e as Map))
              .toList();
        }
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'Could not load webhooks.';
        _loading = false;
      });
    }
  }

  Future<void> _create() async {
    if (_urlCtrl.text.trim().isEmpty) {
      setState(() => _error = 'URL is required.');
      return;
    }
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await widget.api.post(_subsPath, {
        'url': _urlCtrl.text.trim(),
        if (_eventsCtrl.text.trim().isNotEmpty)
          'event_types': _eventsCtrl.text
              .trim()
              .split(',')
              .map((e) => e.trim())
              .where((e) => e.isNotEmpty)
              .toList(),
        if (_secretCtrl.text.trim().isNotEmpty)
          'secret': _secretCtrl.text.trim(),
        'active': _active,
      });
      if (!mounted) return;
      _urlCtrl.clear();
      _eventsCtrl.clear();
      _secretCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Webhook subscription created.')),
      );
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
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete subscription?',
      message: 'Delete webhook subscription $id?',
      confirmLabel: 'Delete',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await widget.api.delete('$_subsPath/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: LocalizedText('Subscription deleted.')),
      );
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _replay(String id) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Replay dead letter?',
      message: 'Replay this failed delivery?',
      confirmLabel: 'Replay',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      final response = await widget.api.post(
        '$_deadPath/${Uri.encodeComponent(id)}/replay',
      );
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
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        title: 'Webhook management is not enabled on this replica.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminBreadcrumb(),
        Text(
          AppStrings.of(context).webhooks,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const LocalizedText(
          'Manage event notification webhook subscriptions and dead letters.',
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: StatusFilterDropdown(
            value: _statusFilter,
            options: const {
              'all': 'All statuses',
              'active': 'Active only',
              'inactive': 'Inactive only',
            },
            onChanged: (value) => setState(() => _statusFilter = value),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Text(
                  _error!,
                  style: const TextStyle(color: AppColors.danger),
                ),
              ),
              TextButton.icon(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                label: const LocalizedText('Retry'),
              ),
            ],
          ),
        ],
        if (_hasSubscriptions) ...[
          _createCard(context),
          const SizedBox(height: 16),
          _subscriptionsCard(context),
          const SizedBox(height: 16),
        ],
        if (_hasDeadLetters) _deadLettersCard(context),
      ],
    );
  }

  Widget _createCard(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            'New subscription',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          _field(_urlCtrl, label: 'Webhook URL', hint: 'https://hooks.example.com/events'),
          const SizedBox(height: 12),
          _field(
            _eventsCtrl,
            label: 'Event types (comma-separated)',
            hint: 'user.created, session.revoked',
          ),
          const SizedBox(height: 12),
          _field(_secretCtrl, label: 'Signing secret (optional)', obscure: true),
          const SizedBox(height: 12),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const LocalizedText('Active'),
            value: _active,
            onChanged: (v) => setState(() => _active = v),
          ),
          FilledButton(
            onPressed: () => AdminRoute.go('webhooks', action: 'new'),
            child: const LocalizedText('Create subscription'),
          ),
        ],
      ),
    ),
  );

  Widget _field(
    TextEditingController controller, {
    required String label,
    String? hint,
    bool obscure = false,
  }) => TextField(
    controller: controller,
    obscureText: obscure,
    decoration: InputDecoration(
      labelText: label.localized,
      hintText: hint?.localized,
    ),
  );

  /// 按状态筛选后的订阅列表（本地过滤；分页不存在，语义正确）。
  List<Map<String, dynamic>> get _visibleSubscriptions {
    if (_statusFilter == 'all') return _subscriptions;
    final active = _statusFilter == 'active';
    return _subscriptions
        .where((s) => (s['active'] == true) == active)
        .toList();
  }

  /// 订阅健康摘要：占比条 + 计数（活跃占比一眼可见）。
  Widget _subscriptionsHealth(BuildContext context) {
    final total = _visibleSubscriptions.length;
    final active = _visibleSubscriptions
        .where((s) => s['active'] == true)
        .length;
    final activeFraction = total == 0 ? 0.0 : active / total;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              LocalizedText(
                'Subscriptions health',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '$active of $total active',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: activeFraction >= 0.7
                      ? AppColors.success
                      : activeFraction >= 0.4
                      ? AppColors.warning
                      : AppColors.danger,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          DistributionBar(
            segments: [
              DistributionSegment(label: 'Active', value: active, color: AppColors.success),
              DistributionSegment(label: 'Inactive', value: total - active, color: AppColors.muted),
            ],
            showLegend: false,
          ),
        ],
      ),
    );
  }

  Widget _subscriptionsCard(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader(
        'Subscriptions',
        action: IconButton(
          onPressed: _loading ? null : _load,
          icon: const Icon(Icons.refresh),
          tooltip: 'Refresh'.localized,
        ),
      ),
      if (_loading) const SkeletonListTile(itemCount: 3),
      if (!_loading && _visibleSubscriptions.isNotEmpty) ...[
        _subscriptionsHealth(context),
        const SizedBox(height: 8),
        AdminDataTable(
          density: TableDensity.compact,
          minWidth: 560,
          columns: [
            AdminDataColumn(
              id: 'status',
              label: 'STATUS',
              // Ahem 测试字体下 'Inactive' 12px×8 很宽，列宽留足。 
              width: 170,
              builder: (context, i) => _visibleSubscriptions[i]['active'] == true
                  ? StatusChip.active(label: context.tr('Active'))
                  : StatusChip.inactive(label: context.tr('Inactive')),
            ),
            AdminDataColumn(
              id: 'url',
              label: 'URL',
              width: 240,
              cardPrimary: true,
              builder: (context, i) => TableCellText(
                _visibleSubscriptions[i]['url']?.toString() ?? '',
                bold: true,
              ),
            ),
            AdminDataColumn(
              id: 'events',
              label: 'ID · EVENTS',
              width: 300,
              builder: (context, i) => TableCellText(
                '${_visibleSubscriptions[i]['id'] ?? ''} · events: '
                '${(_visibleSubscriptions[i]['event_types'] as List?)?.join(', ') ?? 'all'}',
                muted: true,
              ),
            ),
            AdminDataColumn(
              id: 'actions',
              label: '',
              width: 90,
              builder: (context, i) => TextButton(
                onPressed: _mutating
                    ? null
                    : () => _delete(
                        _visibleSubscriptions[i]['id']?.toString() ?? '',
                      ),
                style: TextButton.styleFrom(foregroundColor: AppColors.danger),
                child: const LocalizedText('Delete'),
              ),
            ),
          ],
          itemCount: _visibleSubscriptions.length,
          rowBuilder: (context, i) => const SizedBox.shrink(),
          onRowTap: (i) => AdminRoute.go(
            'webhooks',
            resourceId: _visibleSubscriptions[i]['id']?.toString() ?? '',
          ),
        ),
      ],
      if (!_loading && _visibleSubscriptions.isEmpty)
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No subscriptions.',
          compact: true,
        ),
    ],
  );

  Widget _deadLettersCard(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SectionHeader('Dead letters', count: _deadLetters.length),
      if (_loading) const SkeletonListTile(itemCount: 3),
      if (!_loading && _deadLetters.isEmpty)
        const EmptyState(
          variant: EmptyStateVariant.empty,
          title: 'No dead letters.',
          compact: true,
        ),
      if (!_loading && _deadLetters.isNotEmpty)
        AdminDataTable(
          density: TableDensity.compact,
          minWidth: 560,
          columns: [
            AdminDataColumn(
              id: 'event',
              label: 'EVENT',
              width: 220,
              cardPrimary: true,
              builder: (context, i) => TableCellText(
                _deadLetters[i]['event_type']?.toString() ??
                    _deadLetters[i]['type']?.toString() ??
                    'Unknown',
                bold: true,
              ),
            ),
            AdminDataColumn(
              id: 'id',
              label: 'ID',
              width: 140,
              builder: (context, i) => TableCellText(
                _deadLetters[i]['id']?.toString() ?? '',
                muted: true,
              ),
            ),
            AdminDataColumn(
              id: 'error',
              label: 'ERROR',
              width: 280,
              builder: (context, i) => TableCellText(
                _deadLetters[i]['error']?.toString() ?? '',
                muted: true,
                maxLines: 2,
              ),
            ),
            AdminDataColumn(
              id: 'actions',
              label: '',
              width: 90,
              builder: (context, i) => TextButton(
                onPressed: _mutating
                    ? null
                    : () => _replay(_deadLetters[i]['id']?.toString() ?? ''),
                child: const LocalizedText('Replay'),
              ),
            ),
          ],
          itemCount: _deadLetters.length,
          rowBuilder: (context, i) => const SizedBox.shrink(),
        ),
    ],
  );
}
