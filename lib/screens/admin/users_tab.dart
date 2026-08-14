import 'package:flutter/material.dart';
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
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/user_avatar.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'list_metrics.dart';
import 'user_form_dialog.dart';

/// Directory user list page: cursor pagination, provider filters, batch
/// delete, create/edit via [UserFormDialog], drill-in to the detail screen.
class UsersTab extends StatefulWidget {
  final SSOAdminClient client;
  final OperatorPersona persona;
  const UsersTab({super.key, required this.client, this.persona = OperatorPersona.general});
  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab>
    with BatchSelection<UsersTab>, PaginatedListMixin<UsersTab> {
  final _filterCtrl = TextEditingController();
  late Future<SSOAdminListPage> _future;
  SSOAdminListPage? _lastPage;
  var _pageSize = 100, _orderBy = 'id';
  String _sortColumn = 'user';
  bool _sortAscending = true;
  String? _busyId;
  late final void Function() _cancelPopState;
  /// 模块强调色（identity 组 indigo-violet）：页内图标统一按组色上色。
  Color get _accent => adminModuleIconColor('users');
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
    if (route.module != 'users') return;
    if (route.isNew) {
      _openDialog();
    } else if (route.isEdit) {
      _openEditForId(route.resourceId);
    }
  }

  Future<void> _openEditForId(String id) async {
    try {
      final user = await widget.client.getUser(id);
      if (!mounted) return;
      await _openDialog(existing: user);
    } catch (e) {
      debugPrint('users_tab edit error: $e');
    }
    if (mounted) AdminRoute.go('users');
  }
  Future<SSOAdminListPage> _loadPage() async => _lastPage =
      await widget.client.listUsers(pageToken: currentPageToken, pageSize: _pageSize, orderBy: _orderBy, filter: _filterCtrl.text);

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

  /// 列头排序 → 服务端 orderBy（与排序下拉保持同步）。
  void _onSort(String column) {
    final field = switch (column) {
      'user' => 'id',
      'provider' => 'provider',
      _ => null,
    };
    if (field == null) return;
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
      _orderBy = (_sortAscending ? '' : '-') + field;
    });
    _reload();
  }

  Future<void> _openDialog({Map<String, dynamic>? existing}) async {
    final changed = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => UserFormDialog(client: widget.client, existing: existing),
    );
    if (changed != null) _reload();
    if (mounted) AdminRoute.go('users');
  }

  /// 批量删除：确认影响数量 → 并行执行 → 明细报告（i18n 键 + args）。
  Future<void> _batchDelete() async {
    final ids = selected.toList();
    if (ids.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr('Delete {n} users?', {'n': ids.length}),
      message: context.tr('This will delete {n} selected users.', {'n': ids.length}),
      confirmLabel: 'Delete users',
      destructive: true,
    );
    if (!confirmed) return;
    final results = await Future.wait(ids.map((id) async {
      try {
        await widget.client.deleteUser(id);
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
        ? context.tr('Deleted {n} of {total} users.', {'n': ok, 'total': ids.length})
        : context.tr('{action}: {n} succeeded, {failed} failed. {details}',
            {'action': 'Delete', 'n': ok, 'failed': failures.length, 'details': failures.take(3).join('; ')});
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
    _reload();
  }

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty || _busyId != null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr('Delete user?'),
      message: context.tr('Delete {id}? Sessions, credentials, and dependent records may stop working. This cannot be undone.', {'id': id}),
      confirmLabel: 'Delete user',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() => _busyId = id);
    try {
      await widget.client.deleteUser(id);
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      AdminBreadcrumb(),
      AdminListHeader(
        title: AppStrings.of(context).users,
        subtitle: 'Directory users across providers.',
        createTooltip: 'Create user',
        onCreate: () => AdminRoute.go('users', action: 'new'),
        onRefresh: _reload,
      ),
      if (selecting) ...[
        BatchActionBar(
          selectedCount: selected.length, accent: _accent, isLoading: _busyId != null,
          actions: [BatchAction(label: 'Delete', icon: Icons.delete_outline, destructive: true, onPressed: _batchDelete)],
          onClearSelection: clearSelection,
        ),
        const SizedBox(height: 8),
      ],
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
            final items = page.items;
            return _listBody(context, page, items, UserMetrics(items: items, totalSize: page.totalSize, persona: widget.persona));
          },
        ),
      ),
    ],
  );

  /// 通用下拉（排序/每页条数共用），箭头按组色上色。
  Widget _menu<T>(T value, List<DropdownMenuItem<T>> items, ValueChanged<T> onPicked) => DropdownButton<T>(
    value: value,
    items: items,
    icon: Icon(Icons.arrow_drop_down, color: _accent),
    onChanged: (v) {
      if (v == null) return;
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
          child: SearchFilterBar(labelText: 'Filter'.localized, controller: _filterCtrl, debounce: false, onSearchChanged: (_) {}, onSubmitted: (_) => _reload()),
        ),
        _menu<String>(_orderBy, const [
          DropdownMenuItem(value: 'id', child: LocalizedText('ID ascending')),
          DropdownMenuItem(value: '-id', child: LocalizedText('ID descending')),
          DropdownMenuItem(value: 'provider', child: LocalizedText('Provider ascending')),
          DropdownMenuItem(value: '-provider', child: LocalizedText('Provider descending')),
          DropdownMenuItem(value: 'created_at', child: LocalizedText('Created ascending')),
          DropdownMenuItem(value: '-created_at', child: LocalizedText('Created descending')),
        ], (v) => _orderBy = v),
        _menu<int>(_pageSize, const [
          DropdownMenuItem(value: 25, child: LocalizedText('25 per page')),
          DropdownMenuItem(value: 100, child: LocalizedText('100 per page')),
          DropdownMenuItem(value: 250, child: LocalizedText('250 per page')),
        ], (v) => _pageSize = v),
      ],
    ),
  );



  Widget _listBody(BuildContext context, SSOAdminListPage page, List<Map<String, dynamic>> items, Widget metrics) {
    final filtered = _filterCtrl.text.isNotEmpty;
    // 空态变体：无筛选 → empty（创建引导）；有筛选 → noMatch（文案被测试钉死）。
    final list = items.isEmpty
        ? EmptyState(
            variant: filtered ? EmptyStateVariant.noMatch : EmptyStateVariant.empty,
            icon: filtered ? null : Icons.person,
            title: 'No users',
            subtitle: 'No users match the current filter.',
            actionLabel: filtered ? null : 'Create user',
            onAction: filtered ? null : () => AdminRoute.go('users', action: 'new'),
          )
        : _dataTable(items);
    final pagination = PaginationControls(page: currentPage, total: page.totalSize, canGoBack: canGoBack, canGoNext: page.nextPageToken != null, onPrevious: _goPrevious, onNext: () => _goNext(page));
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
  }

  Widget _dataTable(List<Map<String, dynamic>> items) {
    String uid(int i) => items[i]['id']?.toString() ?? '';
    return AdminDataTable(
      scrollable: true,
      minWidth: 720,
      sortColumn: _sortColumn,
      sortAscending: _sortAscending,
      onSort: _onSort,
      onRowTap: selecting ? (i) => toggleSelect(uid(i)) : (i) => AdminRoute.go('users', resourceId: uid(i)),
      onRowLongPress: selecting ? null : (i) => toggleSelect(uid(i)),
      columns: [
        if (selecting)
          AdminDataColumn(
            id: 'select',
            label: '',
            width: 44,
            builder: (context, i) => Checkbox(value: selected.contains(uid(i)), onChanged: (_) => toggleSelect(uid(i))),
          ),
        AdminDataColumn(
          id: 'user',
          label: 'USER',
          width: 260,
          sortable: true,
          builder: (context, i) => Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              UserAvatar(name: uid(i), radius: 14),
              const SizedBox(width: 8),
              Flexible(child: TableCellText(uid(i), bold: true, maxLines: 1)),
            ],
          ),
        ),
        AdminDataColumn(
          id: 'provider',
          label: 'PROVIDER',
          width: 140,
          sortable: true,
          builder: (context, i) => TableCellText(items[i]['provider']?.toString() ?? '?', muted: true),
        ),
        AdminDataColumn(
          id: 'external',
          label: 'EXTERNAL ID',
          builder: (context, i) => TableCellText(
            items[i]['externalId']?.toString() ?? items[i]['external_id']?.toString() ?? '',
            muted: true,
            maxLines: 1,
          ),
        ),
        AdminDataColumn(
          id: 'actions',
          label: '',
          width: 60,
          builder: (context, i) {
            final u = items[i];
            return PopupMenuButton<String>(
              enabled: _busyId == null,
              onSelected: (value) {
                if (value == 'edit') {
                  AdminRoute.go('users', action: 'edit', resourceId: u['id']?.toString() ?? '');
                }
                if (value == 'delete') {
                  _confirmDelete(u);
                }
              },
              itemBuilder: (context) => const [
                PopupMenuItem(value: 'edit', child: LocalizedText('Edit')),
                PopupMenuItem(value: 'delete', child: LocalizedText('Delete')),
              ],
            );
          },
        ),
      ],
      itemCount: items.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );
  }
}
