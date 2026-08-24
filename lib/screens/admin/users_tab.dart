import 'package:flutter/material.dart';
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
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/tight_dropdown.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/user_avatar.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'list_metrics.dart';
import 'user_form_dialog.dart';
/// Federated directory users: cursor paging, provider search, CRUD and detail drill-in.
class UsersTab extends StatefulWidget {
  final SSOAdminClient client;
  final OperatorPersona persona;
  const UsersTab({
    super.key,
    required this.client,
    this.persona = OperatorPersona.general,
  });
  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab>
    with BatchSelection<UsersTab>, PaginatedListMixin<UsersTab> {
  final _filterCtrl = TextEditingController();
  late Future<SSOAdminListPage> _future;
  SSOAdminListPage? _lastPage;
  int _reqSeq = 0;
  var _pageSize = 100, _orderBy = 'id';
  String? _sortColumn = 'user';
  bool _sortAscending = true;
  String? _busyId;
  late final void Function() _cancelPopState;
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
  void dispose() { _cancelPopState(); _filterCtrl.dispose(); super.dispose(); }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'users') return;
    if (route.isNew) _openDialog();
    if (route.isEdit) _openEditForId(route.resourceId);
  }

  Future<void> _openEditForId(String id) async {
    try {
      final user = await widget.client.getUser(id);
      if (mounted) await _openDialog(existing: user);
    } catch (e) { debugPrint('users_tab edit error: $e'); }
    if (mounted) AdminRoute.back('users');
  }

  Future<SSOAdminListPage> _loadPage() async {
    final seq = ++_reqSeq;
    final page = await widget.client.listUsers(
      pageToken: currentPageToken, pageSize: _pageSize,
      orderBy: _orderBy, filter: _filterCtrl.text.trim(),
    );
    if (seq == _reqSeq) _lastPage = page;
    return page;
  }

  Future<void> _reload() {
    clearSelection();
    setState(() { resetPagination(); _future = _loadPage(); });
    return _future;
  }

  void _clearFilter() { _filterCtrl.clear(); _reload(); }
  void _goPrevious() {
    if (!canGoBack) return;
    goPrevious(); setState(() => _future = _loadPage());
  }
  void _goNext(SSOAdminListPage page) {
    if (page.nextPageToken == null) return;
    goNext(page.nextPageToken, page: page);
    setState(() => _future = _loadPage());
  }
  void _retryPage() => setState(() => _future = _loadPage());
  void _onSort(String column) {
    if (column != 'user' && column != 'provider') return;
    setState(() {
      if (_sortColumn != column) {
        _sortColumn = column; _sortAscending = true;
      } else if (_sortAscending) {
        _sortAscending = false;
      } else {
        _sortColumn = null; _sortAscending = true;
      }
      _orderBy = (_sortAscending ? '' : '-') +
          (_sortColumn == 'provider' ? 'provider' : 'id');
    });
    _reload();
  }
  Future<void> _openDialog({Map<String, dynamic>? existing}) async {
    final changed = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          UserFormDialog(client: widget.client, existing: existing),
    );
    if (changed != null) _reload();
    if (mounted) AdminRoute.back('users');
  }
  Future<String?> _deleteResult(String id) async {
    try {
      await widget.client.deleteUser(id);
      return null;
    } catch (e) {
      return '$id: $e';
    }
  }

  void _showError(Object error) {
    if (mounted) {
      showAppSnackBar(
        context,
        content: Text('$error'),
        kind: AppSnackBarKind.error,
      );
    }
  }
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
    setState(() => _busyId = '');
    final failures = (await Future.wait(ids.map(_deleteResult)))
        .whereType<String>()
        .toList();
    if (!mounted) return;
    setState(() => _busyId = null);
    clearSelection();
    final ok = ids.length - failures.length;
    final message = failures.isEmpty
        ? context.tr('Deleted {n} of {total} users.', {'n': ok, 'total': ids.length})
        : context.tr('{action}: {n} succeeded, {failed} failed. {details}', {
            'action': 'Delete',
            'n': ok,
            'failed': failures.length,
            'details': failures.take(3).join('; '),
          });
    showBatchResultSnackBar(context, message: message, failures: failures);
    await _reload();
  }
  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty || _busyId != null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: context.tr('Delete user?'),
      message: context.tr(
        'Delete {id}? Sessions, credentials, and dependent records may stop working. This cannot be undone.',
        {'id': id},
      ),
      confirmLabel: 'Delete user',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() => _busyId = id);
    var deleted = false;
    try {
      await widget.client.deleteUser(id);
      deleted = true;
      if (mounted) showAppSnackBar(context, content: LocalizedText('User deleted.'));
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
    if (deleted && mounted) await _reload();
  }

  Widget _batchBar() => BatchActionBar(
    selectedCount: selected.length, accent: _accent, isLoading: _busyId != null,
    actions: [BatchAction(
      label: 'Delete', icon: Icons.delete_outline, destructive: true,
      onPressed: _batchDelete,
    )],
    onClearSelection: clearSelection,
  );

  Widget _loaded(SSOAdminListPage page) => _listBody(page, page.items,
    UserMetrics(items: page.items, totalSize: page.totalSize, persona: widget.persona));

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      const AdminBreadcrumb(),
      AdminListHeader(
        title: AppStrings.of(context).users,
        subtitle: 'Directory users across providers.', createTooltip: 'Create user',
        onCreate: () => AdminRoute.go('users', action: 'new'), onRefresh: _reload,
      ),
      if (selecting) ...[_batchBar(), const SizedBox(height: 8)],
      _filterBar(context), const SizedBox(height: 8),
      Expanded(child: FutureBuilder<SSOAdminListPage>(
        future: _future,
        builder: (context, snap) => snap.hasError
            ? ErrorStateView(message: '${snap.error}', onRetry: _retryPage)
            : snap.hasData ? _loaded(snap.data!) :
                const SkeletonListTile(itemCount: 6),
      )),
    ],
  );

  void _setOrder(String value) {
    setState(() {
      _orderBy = value; _sortAscending = !value.startsWith('-');
      _sortColumn = value.endsWith('provider') ? 'provider' :
          value.endsWith('id') ? 'user' : null;
    });
    _reload();
  }

  void _setPageSize(int value) { setState(() => _pageSize = value); _reload(); }

  Widget _filterBar(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: Wrap(
      spacing: 12, runSpacing: 8, crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        SizedBox(width: 280, child: SearchFilterBar(
          labelText: 'Filter'.localized, controller: _filterCtrl, debounce: false,
          onSearchChanged: (_) {}, onSubmitted: (_) => _reload(),
        )),
        TightDropdownButton<String>(
          value: _orderBy, maxWidth: 190,
          options: const [('id', 'ID ascending'), ('-id', 'ID descending'),
            ('provider', 'Provider ascending'), ('-provider', 'Provider descending'),
            ('created_at', 'Created ascending'), ('-created_at', 'Created descending')],
          onChanged: _setOrder,
        ),
        TightDropdownButton<int>(
          value: _pageSize, maxWidth: 150,
          options: const [(25, '25 per page'), (100, '100 per page'), (250, '250 per page')],
          onChanged: _setPageSize,
        ),
      ],
    ),
  );

  Widget _emptyState(bool filtered) => EmptyState(
    variant: filtered ? EmptyStateVariant.noMatch : EmptyStateVariant.empty,
    icon: filtered ? null : Icons.person,
    title: 'No users',
    // Keep the established empty-state copy for both an empty first page and
    // a filtered no-match response; existing consumers and tests rely on the
    // same explanatory text while the action distinguishes the two states.
    subtitle: 'No users match the current filter.',
    actionLabel: filtered ? 'Clear filter' : 'Create user',
    actionIcon: filtered ? Icons.filter_alt_off : null,
    onAction: filtered ? _clearFilter : () => AdminRoute.go('users', action: 'new'),
  );

  Widget _listBody(SSOAdminListPage page, List<Map<String, dynamic>> items, Widget metrics) {
    final filtered = _filterCtrl.text.trim().isNotEmpty;
    final list = items.isNotEmpty
        ? _dataTable(items)
        : onFirstPage
        ? _emptyState(filtered)
        : EmptyPageState(onBackToFirst: _reload);
    final pagination = PaginationControls(
      page: currentPage, total: page.totalSize, canGoBack: canGoBack,
      canGoNext: page.nextPageToken != null, onPrevious: _goPrevious,
      onNext: () => _goNext(page),
    );
    return LayoutBuilder(builder: (context, constraints) {
      final short = constraints.maxHeight <
          380 * MediaQuery.textScalerOf(context).scale(1);
      final content = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [metrics, if (short) SizedBox(height: 280, child: list) else Expanded(child: list), pagination],
      );
      return PullToRefresh(
        onRefresh: _reload,
        child: short ? SingleChildScrollView(child: content) : content,
      );
    });
  }

  String _id(Map<String, dynamic> user) => user['id']?.toString() ?? '';

  bool _hasStatus(List<Map<String, dynamic>> items) => items.any(
    (user) => user['status']?.toString().trim().isNotEmpty ?? false,
  );

  Widget _statusChip(Map<String, dynamic> user) {
    final raw = user['status']?.toString().trim() ?? '';
    return switch (raw.toLowerCase()) {
      'active' => StatusChip.active(label: raw),
      'suspended' => StatusChip.suspended(label: raw),
      'pending' => StatusChip.pending(label: raw),
      'inactive' || 'disabled' || 'revoked' => StatusChip.inactive(label: raw),
      _ => StatusChip.unknown(label: raw.isEmpty ? 'Unknown' : raw),
    };
  }

  Widget _actions(Map<String, dynamic> user) => PopupMenuButton<String>(
    enabled: _busyId == null,
    onSelected: (value) => switch (value) {
      'edit' => AdminRoute.go('users', action: 'edit', resourceId: _id(user)),
      'delete' => _confirmDelete(user),
      _ => null,
    },
    itemBuilder: (_) => const [
      PopupMenuItem(value: 'edit', child: LocalizedText('Edit')),
      PopupMenuItem(value: 'delete', child: LocalizedText('Delete')),
    ],
  );

  Widget _dataTable(List<Map<String, dynamic>> items) {
    String uid(int i) => _id(items[i]);
    final hasStatus = _hasStatus(items);
    final columns = <AdminDataColumn>[
      if (selecting) AdminDataColumn(
        id: 'select', label: '', width: 44,
        builder: (context, i) => Checkbox(
          value: selected.contains(uid(i)),
          onChanged: _busyId == null ? (_) => toggleSelect(uid(i)) : null,
        ),
      ),
      AdminDataColumn(
        id: 'user', label: 'USER', width: 260, sortable: true, cardPrimary: true,
        builder: (context, i) => Row(children: [
          UserAvatar(name: uid(i), radius: 14), const SizedBox(width: 8),
          Flexible(child: CopyableCell(
            text: uid(i), contextProvider: () => context, enabled: !selecting,
          )),
        ]),
      ),
      AdminDataColumn(
        id: 'provider', label: 'PROVIDER', width: 140,
        sortable: true, cardDetail: true,
        builder: (context, i) => TableCellText(items[i]['provider']?.toString() ?? '?', muted: true),
      ),
      AdminDataColumn(
        id: 'external', label: 'EXTERNAL ID', cardDetail: true,
        builder: (context, i) => TableCellText(
          items[i]['externalId']?.toString() ?? items[i]['external_id']?.toString() ?? '',
          muted: true, maxLines: 1,
        ),
      ),
      if (hasStatus) AdminDataColumn(
        id: 'status', label: 'STATUS', width: 130, cardDetail: true,
        builder: (context, i) => _statusChip(items[i]),
      ),
      AdminDataColumn(
        id: 'actions', label: '', width: 60,
        builder: (context, i) => _actions(items[i]),
      ),
    ];
    return AdminDataTable(
      scrollable: true, minWidth: hasStatus ? 860 : 720,
      sortColumn: _sortColumn, sortAscending: _sortAscending, onSort: _onSort,
      onRowTap: selecting ? (i) => toggleSelect(uid(i)) :
          (i) => AdminRoute.go('users', resourceId: uid(i)),
      onRowLongPress: selecting ? null : (i) => toggleSelect(uid(i)),
      columns: columns, itemCount: items.length,
      rowBuilder: (context, i) => const SizedBox.shrink(),
    );
  }
}
