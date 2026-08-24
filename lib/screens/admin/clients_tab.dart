import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/batch_action_bar.dart';
import 'package:sso_admin/widgets/batch_feedback.dart';
import 'package:sso_admin/widgets/batch_selection.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/tight_dropdown.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/status_filter_dropdown.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'client_detail_secret_card.dart';
import 'client_form_dialog.dart';
import 'client_secret_lifecycle.dart';
import 'admin_ops_helpers.dart';
import 'list_metrics.dart';

class ClientsTab extends StatefulWidget {
  final SSOAdminClient client;
  final OperatorPersona persona;
  const ClientsTab({
    super.key,
    required this.client,
    this.persona = OperatorPersona.general,
  });
  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab>
    with BatchSelection<ClientsTab>, PaginatedListMixin<ClientsTab> {
  final _filterCtrl = TextEditingController();
  late Future<SSOAdminListPage> _future;
  SSOAdminListPage? _lastPage;
  int _reqSeq = 0; // 过期响应丢弃：仅最新加载写入 _lastPage（R54）。
  var _pageSize = 100, _orderBy = 'id';
  String? _sortColumn = 'id';
  bool _sortAscending = true;
  var _expiringOnly = false, _statusFilter = 'all';

  /// 行内/批量变更进行中：禁行菜单 + 批量栏按钮（防止重复提交，R53）。
  bool _busy = false;
  bool _secretRotationOutcomeUnknown = false;
  late final void Function() _cancelPopState;

  /// 模块强调色（identity 组 indigo-violet）：页内图标统一按组色上色。
  Color get _accent => adminModuleIconColor('clients');
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

  @override
  void dispose() {
    _cancelPopState();
    _filterCtrl.dispose();
    super.dispose();
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'clients') return;
    if (route.isNew) {
      _openDialog();
    } else if (route.isEdit) {
      _openEditForId(route.resourceId);
    }
  }

  Future<void> _openEditForId(String id) async {
    try {
      final client = await widget.client.getClient(id);
      if (!mounted) return;
      await _openDialog(existing: client);
    } catch (e) {
      debugPrint('clients_tab edit error: $e');
    }
    if (mounted) AdminRoute.back('clients');
  }

  Future<SSOAdminListPage> _loadPage() async {
    final seq = ++_reqSeq;
    if (_expiringOnly) {
      // 临期列表是内存整页（无游标分页）：search/status 叠加为 AND 客户端
      // 过滤、orderBy 客户端排序——与普通模式服务端语义对齐，不再静默丢弃（R44）。
      var items = await widget.client.listExpiringClients();
      final text = _filterCtrl.text.trim().toLowerCase();
      if (text.isNotEmpty) {
        items = items
            .where(
              (c) =>
                  (c['id']?.toString() ?? '').toLowerCase().contains(text) ||
                  (c['name']?.toString() ?? '').toLowerCase().contains(text),
            )
            .toList();
      }
      if (_statusFilter != 'all') {
        final active = _statusFilter == 'active';
        items = items.where((c) => (c['active'] == true) == active).toList();
      }
      final desc = _orderBy.startsWith('-');
      final key = desc ? _orderBy.substring(1) : _orderBy;
      items.sort(
        (a, b) =>
            (a[key]?.toString() ?? '').compareTo(b[key]?.toString() ?? ''),
      );
      if (desc) items = items.reversed.toList();
      final page = SSOAdminListPage(
        items: items,
        nextPageToken: null,
        totalSize: items.length,
      );
      if (seq == _reqSeq) _lastPage = page;
      return page;
    }
    final text = _filterCtrl.text.trim();
    final query = _statusFilter == 'all'
        ? text
        : text.isEmpty
        ? 'active:${_statusFilter == 'active'}'
        : '$text and active:${_statusFilter == 'active'}';
    final page = await widget.client.listClients(
      pageToken: currentPageToken,
      pageSize: _pageSize,
      orderBy: _orderBy,
      filter: query,
    );
    if (seq == _reqSeq) _lastPage = page;
    return page;
  }

  /// 列头排序 → 服务端 orderBy（避免只排当前页）；status 列不可排；点击三态。
  void _onSort(String column) {
    if (column == 'status') return;
    setState(() {
      if (_sortColumn != column) {
        _sortColumn = column;
        _sortAscending = true;
      } else if (_sortAscending) {
        _sortAscending = false;
      } else {
        _sortColumn = null; // 三态：清排序，orderBy 回默认 id（下拉保持有效）
        _sortAscending = true;
      }
      _orderBy = (_sortAscending ? '' : '-') + (_sortColumn ?? 'id');
    });
    _reload();
  }

  /// 导出当前页为 CSV（剪贴板；`= + - @` 前缀做公式注入防护）。
  Future<void> _exportCsv(List<Map<String, dynamic>> items) async {
    final sb = StringBuffer('id,name,active,strategy\n');
    for (final c in items) {
      sb.writeln(
        [
          c['id']?.toString() ?? '',
          c['name']?.toString() ?? '',
          c['active'] == true ? 'active' : 'inactive',
          c['tokenStrategy']?.toString() ??
              c['token_strategy']?.toString() ??
              '',
        ].map(_csvCell).join(','),
      );
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    showAppSnackBar(
      context,
      content: LocalizedText(
        'Exported {n} clients as CSV to clipboard',
        args: {'n': items.length},
      ),
    );
  }

  String _csvCell(String value) {
    var cell = value.replaceAll('"', '""');
    if (cell.startsWith(RegExp(r'[=+\-@]'))) cell = "'$cell";
    return '"$cell"';
  }

  /// 刷新语义（R5）：保留筛选、清除选择、重置分页；返回加载 Future 供下拉刷新指示器（R56）。
  Future<void> _reload() {
    clearSelection();
    setState(() {
      resetPagination();
      _future = _loadPage();
    });
    return _future;
  }

  /// 空态“清除筛选”：清空搜索、状态与临期筛选后重载（过滤无结果场景）。
  void _clearFilter() {
    _filterCtrl.clear();
    _statusFilter = 'all';
    _expiringOnly = false;
    _reload();
  }

  void _goPrevious() {
    if (!canGoBack) return;
    setState(() {
      goPrevious();
      _future = _loadPage();
    });
  }

  void _goNext(SSOAdminListPage page) {
    if (page.nextPageToken == null) return;
    setState(() {
      goNext(page.nextPageToken, page: page);
      _future = _loadPage();
    });
  }

  /// 分页失败重试：保留当前页游标重拉本页（不重置回第一页，R46）。
  void _retryPage() {
    setState(() {
      _future = _loadPage();
    });
  }

  Future<void> _openDialog({Map<String, dynamic>? existing}) async {
    final changed = await showDialog<bool>(
      context: context,
      builder: (_) =>
          ClientFormDialog(client: widget.client, existing: existing),
    );
    if (changed == true) _reload();
    if (mounted) AdminRoute.back('clients');
  }

  static const _copy = <String, (String, String, String, String?)>{
    'approve': (
      'Approve client?',
      'Approve {clientId} for use on this authorization server?',
      'Approve',
      'Client {id} approved.',
    ),
    'reject': (
      'Reject client?',
      'Reject the pending client registration for {clientId}?',
      'Reject',
      'Client {id} rejected.',
    ),
    'delete': (
      'Delete client?',
      'Delete {clientId} permanently? Existing tokens and integrations may stop working.',
      'Delete permanently',
      'Client {id} deleted.',
    ),
  };

  /// 单客户端动作公共骨架：确认（破坏性需输入 ID）→ 调用 → 报告 → 刷新。
  /// 进行中 [_busy] 禁行全部行菜单（防重入，与批量一致）。
  Future<void> _clientAction(Map<String, dynamic> c, String kind) async {
    final id = c['id']?.toString() ?? '';
    if (id.isEmpty || _busy) return;
    final (titleKey, msgKey, confirm, snack) = _copy[kind]!;
    final destructive = kind != 'approve';
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr(titleKey),
      message: context.tr(msgKey, {'clientId': id}),
      confirmLabel: confirm,
      destructive: destructive,
      confirmText: destructive ? id : null,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      await switch (kind) {
        'approve' => widget.client.approveClient(id),
        'reject' => widget.client.rejectClient(id),
        _ => widget.client.deleteClient(id),
      };
      if (!mounted) return;
      if (snack != null) {
        showAppSnackBar(
          context,
          content: LocalizedText(snack, args: {'id': id}),
        );
      }
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      showAppSnackBar(
        context,
        content: Text(e.toString()),
        kind: AppSnackBarKind.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _rotateSecret(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    if (id.isEmpty || _busy || _secretRotationOutcomeUnknown) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr('Rotate client secret?'),
      message: context.tr(
        'The current secret for {clientId} remains valid for 24 hours. Update every integration with the new one-time value before that window closes.',
        {'clientId': id},
      ),
      confirmLabel: 'Rotate secret',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final rotation = await widget.client.rotateClientSecretWithPolicy(id);
      if (!mounted) return;
      final secret = rotation['secret']?.toString() ?? '';
      if (secret.isEmpty) {
        setState(() => _secretRotationOutcomeUnknown = true);
        showAppSnackBar(
          context,
          content: LocalizedText(
            'The secret was rotated, but its one-time value was not returned. Reconcile client state before retrying.',
          ),
          kind: AppSnackBarKind.error,
        );
        await _reload();
        return;
      }
      await showRotatedClientSecret(
        context,
        secret,
        expiryLabel: clientSecretExpiryLabel(context, rotation),
      );
      _reload(); // 轮换已落库：SECRET 列过期时间需要按服务端最新值重绘。
    } on SSOError catch (e) {
      if (!mounted) return;
      final unknown = AdminOpsHelpers.isAmbiguousWriteStatus(e.status);
      if (unknown) {
        setState(() => _secretRotationOutcomeUnknown = true);
        showAppSnackBar(
          context,
          content: LocalizedText(
            'Secret rotation result is unknown. Reconcile client state before retrying.',
          ),
          kind: AppSnackBarKind.error,
        );
      } else {
        showAppSnackBar(
          context,
          content: Text(e.toString()),
          kind: AppSnackBarKind.error,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() => _secretRotationOutcomeUnknown = true);
      showAppSnackBar(
        context,
        content: LocalizedText(
          'Secret rotation result is unknown. Reconcile client state before retrying.',
        ),
        kind: AppSnackBarKind.error,
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _acknowledgeSecretRotation() async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Client secret state reconciled?',
      message:
          'Confirm only after checking the client and its integrations in a safe read. This unlocks secret rotation; it does not prove the previous request failed.',
      confirmLabel: 'Unlock secret rotation',
      destructive: true,
      confirmText: 'RECONCILED',
    );
    if (!confirmed || !mounted) return;
    setState(() => _secretRotationOutcomeUnknown = false);
  }

  /// 批量执行：确认影响数量 → 并行执行 → 报告成功/失败明细 → 刷新。
  /// 进行中 [_busy] 禁用动作按钮；部分失败时 SnackBar 提供明细入口。
  Future<void> _runBatch(
    String action,
    Future<void> Function(String) run,
  ) async {
    final ids = selected.toList();
    if (ids.isEmpty) return;
    final approve = action == 'Approve';
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr(
        approve ? 'Approve {n} clients?' : 'Reject {n} clients?',
        {'n': ids.length},
      ),
      message: context.tr(
        approve
            ? 'This will approve {n} selected clients in one operation.'
            : 'This will reject {n} selected clients in one operation.',
        {'n': ids.length},
      ),
      confirmLabel: action,
    );
    if (!confirmed) return;
    setState(() => _busy = true);
    try {
      final results = await Future.wait(
        ids.map((id) async {
          try {
            await run(id);
            return null;
          } catch (e) {
            return '$id: $e';
          }
        }),
      );
      final failures = results.whereType<String>().toList();
      final ok = ids.length - failures.length;
      if (!mounted) return;
      clearSelection();
      final message = failures.isEmpty
          ? context.tr('{action} completed for {n} of {total} clients.', {
              'action': action,
              'n': ok,
              'total': ids.length,
            })
          : context.tr('{action}: {n} succeeded, {failed} failed. {details}', {
              'action': action,
              'n': ok,
              'failed': failures.length,
              'details': failures.take(3).join('; '),
            });
      showBatchResultSnackBar(context, message: message, failures: failures);
      _reload();
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// 批量操作栏：已选数量 + Approve/Reject 双动作 + 退出选择（共享组件，
  /// 图标用身份组强调色；确认弹窗语义保留在 [_runBatch]）。
  Widget _batchBar(BuildContext context) => BatchActionBar(
    selectedCount: selected.length,
    accent: _accent,
    isLoading: _busy,
    actions: [
      BatchAction(
        label: 'Approve',
        icon: Icons.check_circle_outline,
        onPressed: () =>
            _runBatch('Approve', (id) => widget.client.approveClient(id)),
      ),
      BatchAction(
        label: 'Reject',
        icon: Icons.cancel_outlined,
        onPressed: () =>
            _runBatch('Reject', (id) => widget.client.rejectClient(id)),
      ),
    ],
    onClearSelection: clearSelection,
  );
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).clients,
          subtitle: 'Manage OAuth clients, secrets and expiring credentials.',
          createTooltip: 'Create client',
          onCreate: () => AdminRoute.go('clients', action: 'new'),
          onRefresh: _reload,
        ),
        if (_secretRotationOutcomeUnknown)
          AdminOpsHelpers.unknownOutcomeCard(
            context,
            onAcknowledge: _busy ? null : _acknowledgeSecretRotation,
          ),
        _filterBar(context),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<SSOAdminListPage>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                if (snap.hasError) {
                  return ErrorStateView(
                    message: '${snap.error}',
                    onRetry: _retryPage,
                  );
                }
                return const SkeletonListTile(
                  itemCount: 6,
                  delay: Duration(milliseconds: 150),
                );
              }
              final page = snap.data!;
              final items = [...page.items];
              return _listBody(
                context,
                page,
                items,
                ClientMetrics(
                  items: items,
                  totalSize: page.totalSize,
                  persona: widget.persona,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  /// 带刷新语义的通用下拉（排序/每页条数共用）。R29：改用
  /// [TightDropdownButton]——字体缩放（1.5x/2.0x）下宽度封顶 + 标签
  /// 省略号，不再横向溢出（原 DropdownButton 在有界 Wrap 内溢出）。
  Widget _menu<T>(
    T value,
    List<(T, String)> options,
    ValueChanged<T> onPicked,
  ) => TightDropdownButton<T>(
    value: value,
    options: options,
    maxWidth: 240,
    onChanged: (v) {
      setState(() => onPicked(v));
      _reload();
    },
  );
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
        _menu<String>(
          _orderBy,
          const [
            ('id', 'ID ascending'),
            ('-id', 'ID descending'),
            ('name', 'Name ascending'),
            ('-name', 'Name descending'),
          ],
          (v) {
            _orderBy = v;
            _sortAscending = !v.startsWith('-');
            _sortColumn = v.endsWith('name') ? 'name' : 'id';
          },
        ),
        IconButton(
          tooltip: 'Export CSV'.localized,
          icon: Icon(Icons.file_download_outlined, color: _accent),
          onPressed: _lastPage == null || _lastPage!.items.isEmpty
              ? null
              : () => _exportCsv(_lastPage!.items),
        ),
        StatusFilterDropdown(
          value: _statusFilter,
          options: const {
            'all': 'All statuses',
            'active': 'Active only',
            'inactive': 'Inactive only',
          },
          onChanged: (value) {
            setState(() => _statusFilter = value);
            _reload();
          },
        ),
        _menu<int>(_pageSize, const [
          (25, '25 per page'),
          (100, '100 per page'),
          (250, '250 per page'),
        ], (v) => _pageSize = v),
        FilterChip(
          label: const LocalizedText('Expiring within 30 days'),
          selected: _expiringOnly,
          onSelected: (value) {
            _expiringOnly = value;
            _reload();
          },
        ),
      ],
    ),
  );

  Widget _listBody(
    BuildContext context,
    SSOAdminListPage page,
    List<Map<String, dynamic>> items,
    Widget metrics,
  ) {
    final filtered =
        _filterCtrl.text.trim().isNotEmpty ||
        _statusFilter != 'all' ||
        _expiringOnly;
    final Widget? emptyState = items.isEmpty
        ? (onFirstPage
              ? EmptyState(
                  variant: filtered
                      ? EmptyStateVariant.noMatch
                      : EmptyStateVariant.empty,
                  icon: filtered ? null : Icons.apps,
                  title: 'No clients',
                  subtitle: filtered
                      ? 'No clients match the current filter.'
                      : 'Create your first client to get started.',
                  actionLabel: filtered ? 'Clear filter' : 'Create client',
                  actionIcon: filtered ? Icons.filter_alt_off : null,
                  onAction: filtered
                      ? _clearFilter
                      : () => AdminRoute.go('clients', action: 'new'),
                )
              : EmptyPageState(onBackToFirst: _reload))
        : null;
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
        // R29：阈值随字体缩放（1.5x/2.0x 下指标带+分页高度增长，固定 380
        // 会在窄高容器溢出）——文本放大时提前切到整页滚动，不截断不溢出。
        final list =
            emptyState ??
            (constraints.maxWidth < 640
                ? _mobileList(items)
                : _dataTable(context, items));
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final short = constraints.maxHeight < 380 * scale;
        final content = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (selecting) ...[_batchBar(context), const SizedBox(height: 8)],
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
  }

  /// Narrow layouts keep each client as one touch target instead of forcing a
  /// wide relational table into horizontal scrolling. The ID remains copyable,
  /// while the secret column is represented as a label/value in the card.
  Widget _mobileList(List<Map<String, dynamic>> items) {
    String cid(int i) => items[i]['id']?.toString() ?? '';

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      itemCount: items.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (context, i) {
        final c = items[i];
        final id = cid(i);
        final name = c['name']?.toString() ?? '';
        final expiry = clientSecretExpiryLabel(context, c);
        return Card(
          margin: EdgeInsets.zero,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => selecting
                ? toggleSelect(id)
                : AdminRoute.go('clients', resourceId: id),
            onLongPress: selecting ? null : () => toggleSelect(id),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: 48,
                    child: Checkbox(
                      value: selected.contains(id),
                      onChanged: _busy ? null : (_) => toggleSelect(id),
                    ),
                  ),
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 4),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: Text(
                                  name,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              c['active'] == true
                                  ? StatusChip.active()
                                  : StatusChip.inactive(),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            AppStrings.of(context).clientId,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          CopyableCell(
                            text: id,
                            contextProvider: () => context,
                            enabled: !selecting,
                          ),
                          const SizedBox(height: 4),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                AppStrings.of(context).clientSecret,
                                style: Theme.of(context).textTheme.labelSmall,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  expiry,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: Theme.of(context).textTheme.bodySmall
                                      ?.copyWith(
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                  _clientActions(c),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _clientActions(Map<String, dynamic> c) => PopupMenuButton<String>(
    enabled: !_busy,
    onSelected: (value) => switch (value) {
      'edit' => AdminRoute.go(
        'clients',
        action: 'edit',
        resourceId: c['id']?.toString() ?? '',
      ),
      'rotate' => _rotateSecret(c),
      'approve' => _clientAction(c, 'approve'),
      'reject' => _clientAction(c, 'reject'),
      'delete' => _clientAction(c, 'delete'),
      _ => null,
    },
    itemBuilder: (context) => [
      const PopupMenuItem(value: 'edit', child: LocalizedText('Edit')),
      PopupMenuItem(
        value: 'rotate',
        enabled: !_secretRotationOutcomeUnknown,
        child: const LocalizedText('Rotate secret'),
      ),
      const PopupMenuItem(value: 'approve', child: LocalizedText('Approve')),
      const PopupMenuItem(value: 'reject', child: LocalizedText('Reject')),
      const PopupMenuItem(value: 'delete', child: LocalizedText('Delete')),
    ],
  );

  Widget _dataTable(
    BuildContext context,
    List<Map<String, dynamic>> items,
  ) {
    String cid(int i) => items[i]['id']?.toString() ?? '';
    return AdminDataTable(
      scrollable: true,
      minWidth: 980,
      sortColumn: _sortColumn,
      sortAscending: _sortAscending,
      onSort: _onSort,
      onRowTap: selecting
          ? (i) => toggleSelect(cid(i))
          : (i) => AdminRoute.go('clients', resourceId: cid(i)),
      onRowLongPress: selecting ? null : (i) => toggleSelect(cid(i)),
      columns: [
        if (selecting)
          AdminDataColumn(
            id: 'select',
            label: '',
            width: 44,
            builder: (context, i) => Checkbox(
              value: selected.contains(cid(i)),
              onChanged: _busy ? null : (_) => toggleSelect(cid(i)),
            ),
          ),
        AdminDataColumn(
          id: 'id',
          label: AppStrings.of(context).clientId,
          width: 190,
          sortable: true,
          builder: (context, i) => CopyableCell(
            text: cid(i),
            contextProvider: () => context,
            enabled: !selecting,
          ),
        ),
        AdminDataColumn(
          id: 'name',
          label: 'NAME',
          width: 180,
          sortable: true,
          builder: (context, i) => TableCellText(
            items[i]['name']?.toString() ?? '',
            bold: true,
            maxLines: 2,
          ),
        ),
        AdminDataColumn(
          id: 'status',
          label: 'STATUS',
          width: 160,
          builder: (context, i) => items[i]['active'] == true
              ? StatusChip.active()
              : StatusChip.inactive(),
        ),
        // R52：TOKEN（token_strategy）列为冗余——客户端详情页已展示
        // 'Token strategy'（client_detail_screen.dart），列表收进 6 列内。
        AdminDataColumn(
          id: 'expiry',
          label: AppStrings.of(context).clientSecret,
          width: 170,
          builder: (context, i) => TableCellText(
            clientSecretExpiryLabel(context, items[i]),
            muted: true,
          ),
        ),
        AdminDataColumn(
          id: 'actions',
          label: '',
          width: 60,
          builder: (context, i) => _clientActions(items[i]),
        ),
      ],
      itemCount: items.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );
  }
}
