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

part 'users_tab_view.dart';

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
    with BatchSelection<UsersTab>, PaginatedListMixin<UsersTab>, _UsersTabView {
  @override
  final _filterCtrl = TextEditingController();
  @override
  late Future<SSOAdminListPage> _future;
  SSOAdminListPage? _lastPage;
  int _reqSeq = 0;
  @override
  var _pageSize = 100, _orderBy = 'id';
  @override
  String? _sortColumn = 'user';
  @override
  bool _sortAscending = true;
  @override
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
  void dispose() {
    _cancelPopState();
    _filterCtrl.dispose();
    super.dispose();
  }

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
    } catch (e) {
      debugPrint('users_tab edit error: $e');
    }
    if (mounted) AdminRoute.back('users');
  }

  Future<SSOAdminListPage> _loadPage() async {
    final seq = ++_reqSeq;
    final page = await widget.client.listUsers(
      pageToken: currentPageToken,
      pageSize: _pageSize,
      orderBy: _orderBy,
      filter: _filterCtrl.text.trim(),
    );
    if (seq == _reqSeq) _lastPage = page;
    return page;
  }

  @override
  Future<void> _reload() {
    clearSelection();
    setState(() {
      resetPagination();
      _future = _loadPage();
    });
    return _future;
  }

  @override
  void _clearFilter() {
    _filterCtrl.clear();
    _reload();
  }

  @override
  void _goPrevious() {
    if (!canGoBack) return;
    goPrevious();
    setState(() => _future = _loadPage());
  }

  @override
  void _goNext(SSOAdminListPage page) {
    if (page.nextPageToken == null) return;
    goNext(page.nextPageToken, page: page);
    setState(() => _future = _loadPage());
  }

  @override
  void _retryPage() => setState(() => _future = _loadPage());
  @override
  void _onSort(String column) {
    if (column != 'user' && column != 'provider') return;
    setState(() {
      if (_sortColumn != column) {
        _sortColumn = column;
        _sortAscending = true;
      } else if (_sortAscending) {
        _sortAscending = false;
      } else {
        _sortColumn = null;
        _sortAscending = true;
      }
      _orderBy =
          (_sortAscending ? '' : '-') +
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
      message: context.tr('This will delete {n} selected users.', {
        'n': ids.length,
      }),
      confirmLabel: 'Delete users',
      destructive: true,
    );
    if (!confirmed) return;
    setState(() => _busyId = '');
    final failures = (await Future.wait(
      ids.map(_deleteResult),
    )).whereType<String>().toList();
    if (!mounted) return;
    setState(() => _busyId = null);
    clearSelection();
    final ok = ids.length - failures.length;
    final message = failures.isEmpty
        ? context.tr('Deleted {n} of {total} users.', {
            'n': ok,
            'total': ids.length,
          })
        : context.tr('{action}: {n} succeeded, {failed} failed. {details}', {
            'action': 'Delete',
            'n': ok,
            'failed': failures.length,
            'details': failures.take(3).join('; '),
          });
    showBatchResultSnackBar(context, message: message, failures: failures);
    await _reload();
  }

  @override
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
      if (mounted) {
        showAppSnackBar(context, content: LocalizedText('User deleted.'));
      }
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
    if (deleted && mounted) await _reload();
  }

  @override
  Widget _batchBar() => BatchActionBar(
    selectedCount: selected.length,
    accent: _accent,
    isLoading: _busyId != null,
    actions: [
      BatchAction(
        label: 'Delete',
        icon: Icons.delete_outline,
        destructive: true,
        onPressed: _batchDelete,
      ),
    ],
    onClearSelection: clearSelection,
  );

  @override
  void _setOrder(String value) {
    setState(() {
      _orderBy = value;
      _sortAscending = !value.startsWith('-');
      _sortColumn = value.endsWith('provider')
          ? 'provider'
          : value.endsWith('id')
          ? 'user'
          : null;
    });
    _reload();
  }

  @override
  void _setPageSize(int value) {
    setState(() => _pageSize = value);
    _reload();
  }

  @override
  String _id(Map<String, dynamic> user) => user['id']?.toString() ?? '';

  @override
  bool _hasStatus(List<Map<String, dynamic>> items) => items.any(
    (user) => user['status']?.toString().trim().isNotEmpty ?? false,
  );
}
