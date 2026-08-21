import 'package:flutter/material.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/batch_feedback.dart';
import 'package:sso_admin/widgets/batch_selection.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';
import 'list_metrics.dart';
import 'tenant_form_dialog.dart';
import 'tenant_lifecycle_copy.dart';
import 'tenants/tenants_batch_bar.dart';
import 'tenants/tenants_filter_bar.dart';
import 'tenants/tenants_table.dart';

/// 租户列表页：光标分页 + 排序/每页条数 + 状态筛选 + 批量挂起/激活
/// + 单行生命周期（suspend/delete 撤销报告），对齐参考页 clients。
/// 纯 UI 子组件拆在 tenants/ 目录（筛选行/表格+行操作+空态/批量栏）。
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
    with BatchSelection<TenantsTab>, PaginatedListMixin<TenantsTab> {
  final _filterCtrl = TextEditingController();
  var _statusFilter = 'all';
  late Future<SSOAdminListPage> _future;
  SSOAdminListPage? _lastPage;
  int _reqSeq = 0; // 过期响应丢弃：仅最新加载写入 _lastPage（R54）。
  String? _busyId; // 行级/批量状态切换进行中：非空即禁用（批量用 '' 哨兵）。
  var _pageSize = 100;
  var _orderBy = 'id';
  late final void Function() _cancelPopState;

  /// 模块强调色（tenants 组 amber）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.tenants);

  @override
  bool? get canGoNext => _lastPage?.nextPageToken != null;

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
    if (mounted) AdminRoute.back('tenants');
  }

  @override
  void dispose() {
    _cancelPopState();
    _filterCtrl.dispose();
    super.dispose();
  }

  String get _filterQuery {
    final text = _filterCtrl.text.trim();
    return _statusFilter == 'all'
        ? text
        : '${text.isEmpty ? '' : '$text and '}status:$_statusFilter';
  }

  void _clearFilter() {
    _filterCtrl.clear();
    _statusFilter = 'all';
    _reload();
  }

  Future<SSOAdminListPage> _loadPage() async {
    final seq = ++_reqSeq;
    final page = await widget.client.listTenants(
      pageToken: currentPageToken,
      pageSize: _pageSize,
      orderBy: _orderBy,
      filter: _filterQuery,
    );
    if (seq == _reqSeq) _lastPage = page;
    return page;
  }

  Future<void> _reload() {
    clearSelection();
    setState(() {
      resetPagination();
      _future = _loadPage();
    });
    return _future;
  }

  void _goPrevious() {
    if (canGoBack) {
      setState(() {
        goPrevious();
        _future = _loadPage();
      });
    }
  }

  void _goNext(SSOAdminListPage page) {
    if (page.nextPageToken != null) {
      setState(() {
        goNext(page.nextPageToken, page: page);
        _future = _loadPage();
      });
    }
  }

  /// 分页失败重试：保留当前页游标重拉本页（不重置回第一页）。
  void _retryPage() => setState(() => _future = _loadPage());

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
      message: suspending
          ? context.tr(
              'This will suspend {n} selected tenants in one operation.',
              {'n': n},
            )
          : context.tr(
              'This will activate {n} selected tenants in one operation.',
              {'n': n},
            ),
      confirmLabel: suspending
          ? context.tr('Suspend tenants')
          : context.tr('Activate tenants'),
      destructive: suspending,
    );
    if (!confirmed) return;
    setState(() => _busyId = '');
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
    setState(() => _busyId = null);
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
    showBatchResultSnackBar(context, message: message, failures: failures);
    _reload();
  }

  /// 批量操作栏：已选数量 + 批量挂起/激活 + 退出选择（组件拆在 tenants/tenants_batch_bar.dart，确认弹窗语义保留在 [_batchSetStatus]）。
  Widget _batchBar() => TenantsBatchBar(
    selectedCount: selected.length,
    accent: _accent,
    isLoading: _busyId != null,
    onSuspend: () => _batchSetStatus('suspended'),
    onActivate: () => _batchSetStatus('active'),
    onClearSelection: clearSelection,
  );

  /// 单条生命周期入口：type-to-confirm → 执行 → 撤销报告 → 刷新（语义逐字保留）。
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
            ? _lifecycleResult(context.tr(successCopy), response)
            : const LocalizedText('Tenant activated.');
        showAppSnackBar(context, content: content);
      }
      _reload();
    } on SSOError catch (e) {
      if (mounted) {
        showAppSnackBar(
          context,
          content: LocalizedText('Failed: {e}', args: {'e': e}),
          kind: AppSnackBarKind.error,
        );
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Widget _lifecycleResult(String action, Map<String, dynamic> response) {
    final copy = TenantLifecycleCopy.resultCopy(action, response);
    return LocalizedText(copy.key, args: copy.args);
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
      confirmMessage: context.tr(
        suspending
            ? 'Suspend {id}? New access is blocked and Snaplink will report every refresh-token and session revocation result with a stable retry key for any failed item.'
            : 'Return {id} to active service?',
        {'id': id},
      ),
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
      confirmMessage: context.tr(
        'Delete {label} ({id})? This cannot be undone. Snaplink will return the exact refresh-token and session revocation report.',
        {'label': label, 'id': id},
      ),
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
      if (mounted) AdminRoute.back('tenants');
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
            child: _batchBar(),
          ),
          const SizedBox(height: 8),
        ],
        _filterBar(),
        const SizedBox(height: 8),
        Expanded(child: _listArea(context)),
      ],
    );
  }

  /// 筛选行（搜索/状态/排序/每页条数）拆在 tenants/tenants_filter_bar.dart。
  Widget _filterBar() => TenantsFilterBar(
    controller: _filterCtrl,
    statusFilter: _statusFilter,
    orderBy: _orderBy,
    pageSize: _pageSize,
    onSearchSubmitted: _reload,
    onStatusChanged: (value) {
      _statusFilter = value;
      _reload();
    },
    onOrderChanged: (value) {
      _orderBy = value;
      _reload();
    },
    onPageSizeChanged: (value) {
      _pageSize = value;
      _reload();
    },
  );

  Widget _listArea(BuildContext context) => FutureBuilder<SSOAdminListPage>(
    future: _future,
    builder: (context, snap) {
      if (snap.connectionState != ConnectionState.done) {
        return const SkeletonListTile(
          itemCount: 6,
          delay: Duration(milliseconds: 150),
        );
      }
      if (snap.hasError) {
        return ErrorStateView(message: '${snap.error}', onRetry: _retryPage);
      }
      final page = snap.data!;
      final items = page.items;
      final metrics = TenantMetrics(
        items: items,
        totalSize: page.totalSize,
        persona: widget.persona,
      );
      final filtered = _filterCtrl.text.isNotEmpty || _statusFilter != 'all';
      final list = items.isEmpty
          ? onFirstPage
                ? TenantsEmptyState(
                    filtering: filtered,
                    onClearFilter: _clearFilter,
                  )
                : EmptyPageState(onBackToFirst: _reload)
          : _tenantTable(items);
      final pagination = PaginationControls(
        page: currentPage,
        total: page.totalSize,
        canGoBack: canGoBack,
        canGoNext: page.nextPageToken != null,
        onPrevious: _goPrevious,
        onNext: () => _goNext(page),
      );
      return LayoutBuilder(
        builder: (context, constraints) {
          // R29：阈值随字体缩放（1.5x/2.0x 下指标带+分页高度增长）——文本放大时提前切整页滚动。
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final short = constraints.maxHeight < 380 * scale;
          final content = Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              metrics,
              if (short)
                SizedBox(height: 280, child: list)
              else
                Expanded(child: list),
              pagination,
            ],
          );
          return PullToRefresh(
            onRefresh: _reload,
            child: short ? SingleChildScrollView(child: content) : content,
          );
        },
      );
    },
  );

  /// 表格 + 行操作菜单 + 空态拆在 tenants/tenants_table.dart。
  Widget _tenantTable(List<Map<String, dynamic>> items) => TenantsTable(
    items: items,
    selecting: selecting,
    selected: selected,
    busyId: _busyId,
    onRowTap: selecting
        ? (i) => toggleSelect(items[i]['id']?.toString() ?? '')
        : (i) => AdminRoute.go(
            'tenants',
            resourceId: items[i]['id']?.toString() ?? '',
          ),
    onRowLongPress: selecting
        ? null
        : (i) => toggleSelect(items[i]['id']?.toString() ?? ''),
    onToggleSelect: toggleSelect,
    onToggleStatus: _toggleStatus,
    onEdit: (id) => AdminRoute.go('tenants', action: 'edit', resourceId: id),
    onDelete: _delete,
  );
}
