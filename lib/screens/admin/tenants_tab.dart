import 'package:flutter/material.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/batch_selection.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/status_filter_dropdown.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';
import 'list_metrics.dart';
import 'tenant_form_dialog.dart';
import 'tenant_lifecycle_copy.dart';

/// 租户列表页：光标分页 + 排序/每页条数 + 状态筛选 + 批量挂起/激活
/// + 单行生命周期（suspend/delete 撤销报告），对齐参考页 clients。
class TenantsTab extends StatefulWidget {
  final SSOAdminClient client;

  /// Persona emphasis (default = no emphasis).
  final OperatorPersona persona;

  const TenantsTab({
    super.key,
    required this.client,
    this.persona = OperatorPersona.general,
  });

  @override
  State<TenantsTab> createState() => _TenantsTabState();
}

class _TenantsTabState extends State<TenantsTab>
    with BatchSelection<TenantsTab> {
  final _filterCtrl = TextEditingController();
  var _statusFilter = 'all';
  final _pageTokens = <String?>[null];
  late Future<SSOAdminListPage> _future;
  String? _busyId;
  var _pageIndex = 0;
  var _pageSize = 100;
  var _orderBy = 'id';
  late final void Function() _cancelPopState;

  static const _orderOptions = [
    ('id', 'ID ascending'),
    ('-id', 'ID descending'),
    ('slug', 'Slug ascending'),
    ('-slug', 'Slug descending'),
    ('name', 'Name ascending'),
    ('-name', 'Name descending'),
  ];
  static const _sizeOptions = [
    (25, '25 per page'),
    (100, '100 per page'),
    (250, '250 per page'),
  ];

  /// 模块强调色（tenants 组 amber）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.tenants);

  @override
  void initState() {
    super.initState();
    _future = _loadPage();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'tenants') return;
    if (route.isNew) {
      _openForm();
    } else if (route.isEdit) {
      _openEditForId(route.resourceId);
    }
  }

  Future<void> _openEditForId(String id) async {
    try {
      final tenant = await widget.client.getTenant(id);
      if (mounted) await _openForm(existing: tenant);
    } catch (e) {
      debugPrint('tenants_tab edit error: $e');
    }
    if (mounted) AdminRoute.go('tenants');
  }

  @override
  void dispose() {
    _cancelPopState();
    _filterCtrl.dispose();
    super.dispose();
  }

  String get _filterQuery {
    final text = _filterCtrl.text.trim();
    if (_statusFilter == 'all') return text;
    return text.isEmpty
        ? 'status:$_statusFilter'
        : '$text and status:$_statusFilter';
  }

  Future<SSOAdminListPage> _loadPage() => widget.client.listTenants(
    pageToken: _pageTokens[_pageIndex],
    pageSize: _pageSize,
    orderBy: _orderBy,
    filter: _filterQuery,
  );

  void _reload() {
    setState(() {
      _pageTokens
        ..clear()
        ..add(null);
      _pageIndex = 0;
      _future = _loadPage();
    });
  }

  void _goPrevious() {
    if (_pageIndex == 0) return;
    setState(() {
      _pageIndex--;
      _future = _loadPage();
    });
  }

  void _goNext(SSOAdminListPage page) {
    final next = page.nextPageToken;
    if (next == null) return;
    setState(() {
      _pageTokens.removeRange(_pageIndex + 1, _pageTokens.length);
      _pageTokens.add(next);
      _pageIndex++;
      _future = _loadPage();
    });
  }

  /// 批量切换选中租户状态（suspend 或 activate）；逐项汇总失败明细。
  Future<void> _batchSetStatus(String next) async {
    final ids = selected.toList();
    if (ids.isEmpty) return;
    final suspending = next == 'suspended';
    final n = ids.length;
    final confirmed = await ConfirmDialog.show(
      context,
      title: suspending
          ? context.tr('Suspend {n} tenants?', {'n': n})
          : context.tr('Activate {n} tenants?', {'n': n}),
      message: context.tr(
        suspending
            ? 'This will suspend {n} selected tenants in one operation.'
            : 'This will activate {n} selected tenants in one operation.',
        {'n': n},
      ),
      confirmLabel: suspending
          ? context.tr('Suspend tenants')
          : context.tr('Activate tenants'),
      destructive: suspending,
    );
    if (!confirmed) return;
    final results = await Future.wait(
      ids.map((id) async {
        try {
          await widget.client.setTenantStatus(id, next);
          return null;
        } catch (e) {
          return '$id: $e';
        }
      }),
    );
    if (!mounted) return;
    final failures = results.whereType<String>().toList();
    final ok = results.length - failures.length;
    clearSelection();
    final message = context.tr(
      failures.isEmpty
          ? suspending
                ? 'Suspended {ok} of {total} tenants.'
                : 'Activated {ok} of {total} tenants.'
          : suspending
          ? 'Suspend: {ok} succeeded, {failed} failed. {detail}'
          : 'Activate: {ok} succeeded, {failed} failed. {detail}',
      {
        'ok': ok,
        'total': n,
        'failed': failures.length,
        'detail': failures.take(3).join('; '),
      },
    );
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _reload();
  }

  /// 批量操作栏：已选数量 + 批量挂起/激活 + 退出选择。批量语义是挂起/激活
  /// （非删除），BatchActionBar 的固定 delete 语义不适用；沿用此栏但图标
  /// 统一使用租户组强调色（X7）。
  Widget _batchBar(BuildContext context) => Material(
    color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: 0.4),
    borderRadius: BorderRadius.circular(12),
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Row(
        children: [
          LocalizedText('{count} selected', args: {'count': selected.length}),
          const Spacer(),
          TextButton.icon(
            onPressed: () => _batchSetStatus('suspended'),
            icon: Icon(Icons.pause_circle_outline, size: 18, color: _accent),
            label: const LocalizedText('Suspend'),
          ),
          const SizedBox(width: 4),
          TextButton.icon(
            onPressed: () => _batchSetStatus('active'),
            icon: Icon(Icons.play_circle_outline, size: 18, color: _accent),
            label: const LocalizedText('Activate'),
          ),
          IconButton(
            tooltip: 'Clear selection'.localized,
            icon: const Icon(Icons.close, size: 18),
            onPressed: () => clearSelection(),
          ),
        ],
      ),
    ),
  );

  /// 单条生命周期入口：type-to-confirm → 执行 → 撤销报告（suspend/delete）
  /// 或激活提示 → 刷新。文案与撤销报告语义逐字保留。
  Future<void> _runLifecycle({
    required String id,
    required String title,
    required String confirmLabel,
    required String confirmMessage,
    required bool destructive,
    required String successCopy,
    required bool report,
    String? confirmText,
    required Future<Map<String, dynamic>> Function() op,
  }) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: title,
      message: confirmMessage,
      confirmLabel: confirmLabel,
      destructive: destructive,
      confirmText: confirmText,
    );
    if (!confirmed) return;
    setState(() => _busyId = id);
    try {
      final response = await op();
      if (mounted) {
        final content = report
            ? LocalizedText(
                TenantLifecycleCopy.result(context.tr(successCopy), response),
              )
            : const LocalizedText('Tenant activated.');
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: content));
      }
      _reload();
    } on SSOError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: LocalizedText('Failed: {e}', args: {'e': e})),
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  void _toggleStatus(String id, String currentStatus) {
    final next = currentStatus == 'suspended' ? 'active' : 'suspended';
    final suspending = next == 'suspended';
    _runLifecycle(
      id: id,
      title: suspending
          ? context.tr('Suspend tenant?')
          : context.tr('Activate tenant?'),
      confirmLabel: suspending
          ? context.tr('Suspend tenant')
          : context.tr('Activate tenant'),
      confirmMessage: TenantLifecycleCopy.confirmation(id, next),
      destructive: suspending,
      successCopy: suspending ? 'Tenant suspended.' : 'Tenant activated.',
      report: suspending,
      confirmText: suspending ? id : null,
      op: () => widget.client.setTenantStatus(id, next),
    );
  }

  void _delete(String id, String label) {
    _runLifecycle(
      id: id,
      title: context.tr('Delete tenant?'),
      confirmLabel: context.tr('Delete tenant'),
      confirmMessage: TenantLifecycleCopy.deletion(id, label),
      destructive: true,
      successCopy: 'Tenant deleted.',
      report: true,
      confirmText: id,
      op: () => widget.client.deleteTenant(id),
    );
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          TenantFormDialog(client: widget.client, existing: existing),
    );
    if (saved == true) {
      _reload();
      if (mounted) AdminRoute.go('tenants');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).tenants,
          subtitle: 'Manage tenant lifecycle, status and residency.',
          createTooltip: 'Create tenant',
          onCreate: () => AdminRoute.go('tenants', action: 'new'),
          onRefresh: _reload,
        ),
        if (selecting) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _batchBar(context),
          ),
          const SizedBox(height: 8),
        ],
        _filterBar(context),
        const SizedBox(height: 8),
        Expanded(child: _listArea(context)),
      ],
    );
  }

  Widget _filterBar(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(
          width: 280,
          child: SearchFilterBar(
            labelText: 'Filter'.localized,
            controller: _filterCtrl,
            debounce: false,
            onSearchChanged: (_) {},
            onSubmitted: (_) => _reload(),
          ),
        ),
        const SizedBox(width: 12),
        StatusFilterDropdown(
          value: _statusFilter,
          options: const {
            'all': 'All statuses',
            'active': 'Active only',
            'suspended': 'Suspended only',
          },
          onChanged: (value) {
            setState(() => _statusFilter = value);
            _reload();
          },
        ),
        DropdownButton<String>(
          value: _orderBy,
          items: [
            for (final (value, label) in _orderOptions)
              DropdownMenuItem(value: value, child: LocalizedText(label)),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _orderBy = value);
            _reload();
          },
        ),
        DropdownButton<int>(
          value: _pageSize,
          items: [
            for (final (size, label) in _sizeOptions)
              DropdownMenuItem(value: size, child: LocalizedText(label)),
          ],
          onChanged: (value) {
            if (value == null) return;
            setState(() => _pageSize = value);
            _reload();
          },
        ),
      ],
    ),
  );

  Widget _listArea(BuildContext context) => FutureBuilder<SSOAdminListPage>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const SkeletonListTile(itemCount: 6);
      }
      if (snap.hasError) {
        return _errorState(context, '${snap.error}');
      }
      final page = snap.data!;
      final items = page.items;
      final metrics = TenantMetrics(
        items: items,
        totalSize: page.totalSize,
        persona: widget.persona,
      );
      final list = items.isEmpty ? _emptyState() : _tenantTable(items);
      final pagination = PaginationControls(
        page: _pageIndex + 1,
        total: page.totalSize,
        canGoBack: _pageIndex > 0,
        canGoNext: page.nextPageToken != null,
        onPrevious: _goPrevious,
        onNext: () => _goNext(page),
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          final short = constraints.maxHeight < 380;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              metrics,
              if (short) SizedBox(height: 280, child: list) else Expanded(child: list),
              pagination,
            ],
          );
          return short ? SingleChildScrollView(child: content) : content;
        },
      );
    },
  );

  Widget _errorState(BuildContext context, String error) => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        LocalizedText('Error: {snap_error}', args: {'snap_error': error}),
        const SizedBox(height: 12),
        OutlinedButton.icon(onPressed: _reload, icon: const Icon(Icons.refresh), label: const LocalizedText('Retry')),
      ],
    ),
  );

  Widget _emptyState() {
    final filtering = _filterCtrl.text.isNotEmpty || _statusFilter != 'all';
    return EmptyState(
      variant: filtering ? EmptyStateVariant.noMatch : EmptyStateVariant.empty,
      icon: filtering ? null : Icons.business,
      title: 'No tenants',
      subtitle: 'No tenants match the current filter.',
      actionLabel: 'Create tenant',
      onAction: () => AdminRoute.go('tenants', action: 'new'),
    );
  }

  Widget _tenantTable(List<Map<String, dynamic>> items) => AdminDataTable(
    scrollable: true,
    minWidth: 760,
    density: TableDensity.compact,
    onRowTap: selecting
        ? (i) => toggleSelect(items[i]['id']?.toString() ?? '')
        : (i) => AdminRoute.go(
            'tenants', resourceId: items[i]['id']?.toString() ?? ''),
    onRowLongPress: selecting
        ? null
        : (i) => toggleSelect(items[i]['id']?.toString() ?? ''),
    columns: [
      if (selecting)
        AdminDataColumn(id: 'select', label: '', width: 44, builder: (context, i) {
          final id = items[i]['id']?.toString() ?? '';
          return Checkbox(value: selected.contains(id), onChanged: (_) => setState(() {
            if (!selected.remove(id)) toggleSelect(id);
          }));
        }),
      AdminDataColumn(id: 'name', label: 'TENANT', width: 240, sortable: true, builder: (context, i) => TableCellText(items[i]['name']?.toString() ?? items[i]['id']?.toString() ?? '?', bold: true, maxLines: 2)),
      AdminDataColumn(id: 'slug', label: 'SLUG', width: 140, builder: (context, i) => TableCellText(items[i]['slug']?.toString() ?? '', muted: true)),
      AdminDataColumn(id: 'status', label: 'STATUS', width: 190, sortable: true, builder: (context, i) {
        final status = items[i]['status']?.toString() ?? 'active';
        return status == 'suspended' ? StatusChip.suspended() : StatusChip.active();
      }),
      AdminDataColumn(id: 'actions', label: '', width: 60, builder: (context, i) => _rowActions(items[i])),
    ],
    itemCount: items.length,
    rowBuilder: (context, i) => const SizedBox.shrink(),
  );

  Widget _rowActions(Map<String, dynamic> t) {
    final id = t['id']?.toString() ?? '';
    final status = t['status']?.toString() ?? 'active';
    final suspended = status == 'suspended';
    if (_busyId == id) {
      return const SizedBox(
        height: 18,
        width: 18,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    }
    return PopupMenuButton<String>(
      onSelected: (value) {
        switch (value) {
          case 'toggle':
            _toggleStatus(id, status);
          case 'edit':
            AdminRoute.go('tenants', action: 'edit', resourceId: id);
          case 'delete':
            _delete(id, t['name']?.toString() ?? id);
        }
      },
      itemBuilder: (context) => [
        PopupMenuItem(
          value: 'toggle',
          child: LocalizedText(suspended ? 'Activate' : 'Suspend'),
        ),
        const PopupMenuItem(value: 'edit', child: LocalizedText('Edit')),
        const PopupMenuItem(value: 'delete', child: LocalizedText('Delete')),
      ],
    );
  }
}
