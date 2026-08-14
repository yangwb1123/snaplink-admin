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
import 'package:sso_admin/widgets/batch_action_bar.dart';
import 'package:sso_admin/widgets/batch_selection.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/status_filter_dropdown.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'client_detail_secret_card.dart';
import 'client_form_dialog.dart';
import 'client_secret_lifecycle.dart';
import 'list_metrics.dart';
class ClientsTab extends StatefulWidget {
  final SSOAdminClient client;
  final OperatorPersona persona;
  const ClientsTab({super.key, required this.client, this.persona = OperatorPersona.general});
  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab>
    with BatchSelection<ClientsTab>, PaginatedListMixin<ClientsTab> {
  final _filterCtrl = TextEditingController();
  late Future<SSOAdminListPage> _future;
  SSOAdminListPage? _lastPage;
  var _pageSize = 100, _orderBy = 'id';
  String _sortColumn = 'id';
  bool _sortAscending = true;
  var _expiringOnly = false, _statusFilter = 'all';
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
    if (mounted) AdminRoute.go('clients');
  }
  Future<SSOAdminListPage> _loadPage() async {
    if (_expiringOnly) {
      final items = await widget.client.listExpiringClients();
      return _lastPage = SSOAdminListPage(items: items, nextPageToken: null, totalSize: items.length);
    }
    final query = _statusFilter == 'all'
        ? _filterCtrl.text
        : _filterCtrl.text.trim().isEmpty
        ? 'active:${_statusFilter == 'active'}'
        : '${_filterCtrl.text.trim()} and active:${_statusFilter == 'active'}';
    return _lastPage = await widget.client.listClients(
      pageToken: currentPageToken,
      pageSize: _pageSize,
      orderBy: _orderBy,
      filter: query,
    );
  }
  /// 列头排序 → 服务端 orderBy（避免只排当前页）；status 列不可排。
  void _onSort(String column) {
    if (column == 'status') return;
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _orderBy = (_sortAscending ? '' : '-') + column;
    });
    _reload();
  }
  /// 导出当前页为 CSV（剪贴板；`= + - @` 前缀做公式注入防护）。
  Future<void> _exportCsv(List<Map<String, dynamic>> items) async {
    final sb = StringBuffer('id,name,active,strategy\n');
    for (final c in items) {
      sb.writeln([
        c['id']?.toString() ?? '',
        c['name']?.toString() ?? '',
        c['active'] == true ? 'active' : 'inactive',
        c['tokenStrategy']?.toString() ?? c['token_strategy']?.toString() ?? '',
      ].map(_csvCell).join(','));
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: LocalizedText('Exported {n} clients as CSV to clipboard', args: {'n': items.length})));
  }
  String _csvCell(String value) {
    var cell = value.replaceAll('"', '""');
    if (cell.startsWith(RegExp(r'[=+\-@]'))) cell = "'$cell";
    return '"$cell"';
  }
  void _reload() => setState(() {
    resetPagination();
    _future = _loadPage();
  });
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
      goNext(page.nextPageToken);
      _future = _loadPage();
    });
  }
  Future<void> _openDialog({Map<String, dynamic>? existing}) async {
    final changed = await showDialog<bool>(context: context, builder: (_) => ClientFormDialog(client: widget.client, existing: existing));
    if (changed == true) _reload();
    if (mounted) AdminRoute.go('clients');
  }
  static const _copy = <String, (String, String, String, String?)>{
    'approve': ('Approve client?', 'Approve {clientId} for use on this authorization server?', 'Approve', 'Client {id} approved.'),
    'reject': ('Reject client?', 'Reject the pending client registration for {clientId}?', 'Reject', 'Client {id} rejected.'),
    'delete': ('Delete client?', 'Delete {clientId} permanently? Existing tokens and integrations may stop working.', 'Delete permanently', null),
  };
  /// 单客户端动作公共骨架：确认（破坏性需输入 ID）→ 调用 → 报告 → 刷新。
  Future<void> _clientAction(Map<String, dynamic> c, String kind) async {
    final id = c['id']?.toString() ?? '';
    final (titleKey, msgKey, confirm, snack) = _copy[kind]!;
    final destructive = kind != 'approve';
    final confirmed = await ConfirmDialog.show(context, title: context.tr(titleKey), message: context.tr(msgKey, {'clientId': id}), confirmLabel: confirm, destructive: destructive, confirmText: destructive ? id : null);
    if (!confirmed) return;
    try {
      await switch (kind) {
        'approve' => widget.client.approveClient(id),
        'reject' => widget.client.rejectClient(id),
        _ => widget.client.deleteClient(id),
      };
      if (!mounted) return;
      if (snack != null) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: LocalizedText(snack, args: {'id': id})));
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
  Future<void> _rotateSecret(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    final confirmed = await ConfirmDialog.show(context, title: context.tr('Rotate client secret?'), message: context.tr('The current secret for {clientId} remains valid for 24 hours. Update every integration with the new one-time value before that window closes.', {'clientId': id}), confirmLabel: 'Rotate secret', destructive: true, confirmText: id);
    if (!confirmed) return;
    try {
      final rotation = await widget.client.rotateClientSecretWithPolicy(id);
      if (!mounted) return;
      final secret = rotation['secret']?.toString() ?? '';
      if (secret.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: LocalizedText('The secret was rotated, but its one-time value was not returned.')));
        return;
      }
      await showRotatedClientSecret(context, secret, expiryLabel: clientSecretExpiryLabel(context, rotation));
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
  /// 批量执行：确认影响数量 → 并行执行 → 报告成功/失败明细 → 刷新。
  Future<void> _runBatch(String action, Future<void> Function(String) run) async {
    final ids = selected.toList();
    if (ids.isEmpty) return;
    final approve = action == 'Approve';
    final confirmed = await ConfirmDialog.show(context, title: context.tr(approve ? 'Approve {n} clients?' : 'Reject {n} clients?', {'n': ids.length}), message: context.tr(approve ? 'This will approve {n} selected clients in one operation.' : 'This will reject {n} selected clients in one operation.', {'n': ids.length}), confirmLabel: action);
    if (!confirmed) return;
    final results = await Future.wait(ids.map((id) async {
      try {
        await run(id);
        return null;
      } catch (e) {
        return '$id: $e';
      }
    }));
    final failures = results.whereType<String>().toList();
    final ok = ids.length - failures.length;
    if (!mounted) return;
    clearSelection();
    final message = failures.isEmpty
        ? context.tr('{action} completed for {n} of {total} clients.', {'action': action, 'n': ok, 'total': ids.length})
        : context.tr('{action}: {n} succeeded, {failed} failed. {details}', {'action': action, 'n': ok, 'failed': failures.length, 'details': failures.take(3).join('; ')});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _reload();
  }
  /// 批量操作栏：已选数量 + Approve/Reject 双动作 + 退出选择（共享组件，
  /// 图标用身份组强调色；确认弹窗语义保留在 [_runBatch]）。
  Widget _batchBar(BuildContext context) => BatchActionBar(
    selectedCount: selected.length,
    accent: _accent,
    actions: [
      BatchAction(label: 'Approve', icon: Icons.check_circle_outline, onPressed: () => _runBatch('Approve', (id) => widget.client.approveClient(id))),
      BatchAction(label: 'Reject', icon: Icons.cancel_outlined, onPressed: () => _runBatch('Reject', (id) => widget.client.rejectClient(id))),
    ],
    onClearSelection: clearSelection,
  );
  @override

  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminBreadcrumb(),
        AdminListHeader(title: AppStrings.of(context).clients, subtitle: 'Manage OAuth clients, secrets and expiring credentials.', createTooltip: 'Create client', onCreate: () => AdminRoute.go('clients', action: 'new'), onRefresh: _reload),
        _filterBar(context),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<SSOAdminListPage>(
            future: _future,
            builder: (context, snap) {
              if (!snap.hasData) {
                if (snap.hasError) {
                  return ErrorStateView(message: '${snap.error}', onRetry: _reload);
                }
                return const SkeletonListTile(itemCount: 6);
              }
              final page = snap.data!;
              final items = [...page.items];
              return _listBody(context, page, items, ClientMetrics(items: items, totalSize: page.totalSize, persona: widget.persona));
            },
          ),
        ),
      ],
    );
  }
  /// 带刷新语义的通用下拉（排序/每页条数共用）。
  Widget _menu<T>(T value, List<DropdownMenuItem<T>> items, ValueChanged<T> onPicked) => DropdownButton<T>(value: value, items: items, onChanged: (v) {
    if (v == null) return;
    setState(() => onPicked(v));
    _reload();
  });
  Widget _filterBar(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center, children: [
      SizedBox(width: 280, child: SearchFilterBar(labelText: 'Filter'.localized, controller: _filterCtrl, debounce: false, onSearchChanged: (_) {}, onSubmitted: (_) => _reload())),
      _menu<String>(_orderBy, const [
        DropdownMenuItem(value: 'id', child: LocalizedText('ID ascending')),
        DropdownMenuItem(value: '-id', child: LocalizedText('ID descending')),
        DropdownMenuItem(value: 'name', child: LocalizedText('Name ascending')),
        DropdownMenuItem(value: '-name', child: LocalizedText('Name descending')),
      ], (v) => _orderBy = v),
      IconButton(
        tooltip: 'Export CSV'.localized,
        icon: Icon(Icons.file_download_outlined, color: _accent),
        onPressed: _lastPage == null || _lastPage!.items.isEmpty ? null : () => _exportCsv(_lastPage!.items),
      ),
      StatusFilterDropdown(value: _statusFilter, options: const {'all': 'All statuses', 'active': 'Active only', 'inactive': 'Inactive only'}, onChanged: (value) {
        setState(() => _statusFilter = value);
        _reload();
      }),
      _menu<int>(_pageSize, const [
        DropdownMenuItem(value: 25, child: LocalizedText('25 per page')),
        DropdownMenuItem(value: 100, child: LocalizedText('100 per page')),
        DropdownMenuItem(value: 250, child: LocalizedText('250 per page')),
      ], (v) => _pageSize = v),
      FilterChip(label: const LocalizedText('Expiring within 30 days'), selected: _expiringOnly, onSelected: (value) {
        _expiringOnly = value;
        _reload();
      }),
    ]),
  );

  Widget _listBody(BuildContext context, SSOAdminListPage page, List<Map<String, dynamic>> items, Widget metrics) {
    final filtered = _filterCtrl.text.isNotEmpty || _statusFilter != 'all';
    final list = items.isEmpty
        ? EmptyState(
            variant: filtered ? EmptyStateVariant.noMatch : EmptyStateVariant.empty,
            icon: filtered ? null : Icons.apps,
            title: 'No clients',
            subtitle: filtered ? 'No clients match the current filter.' : 'Create your first client to get started.',
            actionLabel: filtered ? null : 'Create client',
            onAction: filtered ? null : () => AdminRoute.go('clients', action: 'new'),
          )
        : _dataTable(items);
    final pagination = PaginationControls(page: currentPage, total: page.totalSize, canGoBack: canGoBack, canGoNext: page.nextPageToken != null, onPrevious: _goPrevious, onNext: () => _goNext(page));
    return LayoutBuilder(
      builder: (context, constraints) {
        final short = constraints.maxHeight < 380;
        final content = Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          if (selecting) ...[_batchBar(context), const SizedBox(height: 8)],
          metrics,
          if (short) SizedBox(height: 280, child: list) else Expanded(child: list),
          pagination,
        ]);
        return short ? SingleChildScrollView(child: content) : content;
      },
    );
  }

  Widget _dataTable(List<Map<String, dynamic>> items) {
    String cid(int i) => items[i]['id']?.toString() ?? '';
    return AdminDataTable(
      scrollable: true,
      minWidth: 980,
      sortColumn: _sortColumn,
      sortAscending: _sortAscending,
      onSort: _onSort,
      onRowTap: selecting ? (i) => toggleSelect(cid(i)) : (i) => AdminRoute.go('clients', resourceId: cid(i)),
      onRowLongPress: selecting ? null : (i) => toggleSelect(cid(i)),
      columns: [
        if (selecting)
          AdminDataColumn(id: 'select', label: '', width: 44, builder: (context, i) => Checkbox(
            value: selected.contains(cid(i)),
            onChanged: (_) {
              if (!selected.remove(cid(i))) toggleSelect(cid(i));
            },
          )),
        AdminDataColumn(id: 'id', label: 'CLIENT ID', width: 190, sortable: true, builder: (context, i) => CopyableCell(text: cid(i), contextProvider: () => context, enabled: !selecting)),
        AdminDataColumn(id: 'name', label: 'NAME', width: 180, sortable: true, builder: (context, i) => TableCellText(items[i]['name']?.toString() ?? '', bold: true, maxLines: 2)),
        AdminDataColumn(id: 'status', label: 'STATUS', width: 160, builder: (context, i) => items[i]['active'] == true ? StatusChip.active() : StatusChip.inactive()),
        AdminDataColumn(id: 'strategy', label: 'TOKEN', width: 110, builder: (context, i) => TableCellText(items[i]['tokenStrategy']?.toString() ?? items[i]['token_strategy']?.toString() ?? '', muted: true)),
        AdminDataColumn(id: 'expiry', label: 'SECRET', width: 170, builder: (context, i) => TableCellText(clientSecretExpiryLabel(context, items[i]), muted: true)),
        AdminDataColumn(id: 'actions', label: '', width: 60, builder: (context, i) {
          final c = items[i];
          return PopupMenuButton<String>(
            onSelected: (value) => switch (value) {
              'edit' => AdminRoute.go('clients', action: 'edit', resourceId: c['id']?.toString() ?? ''),
              'rotate' => _rotateSecret(c),
              'approve' => _clientAction(c, 'approve'),
              'reject' => _clientAction(c, 'reject'),
              'delete' => _clientAction(c, 'delete'),
              _ => null,
            },
            itemBuilder: (context) => const [
              PopupMenuItem(value: 'edit', child: LocalizedText('Edit')),
              PopupMenuItem(value: 'rotate', child: LocalizedText('Rotate secret')),
              PopupMenuItem(value: 'approve', child: LocalizedText('Approve')),
              PopupMenuItem(value: 'reject', child: LocalizedText('Reject')),
              PopupMenuItem(value: 'delete', child: LocalizedText('Delete')),
            ],
          );
        }),
      ],
      itemCount: items.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );
  }
}
