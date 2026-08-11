import 'package:sso_admin/widgets/batch_selection.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';

import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/user_avatar.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/batch_action_bar.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'admin_route.dart';
import 'user_form_dialog.dart';
import 'list_metrics.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/i18n/app_strings.dart';

class UsersTab extends StatefulWidget {
  final SSOAdminClient client;

  /// Persona emphasis (default = no emphasis).
  final OperatorPersona persona;

  const UsersTab({
    super.key,
    required this.client,
    this.persona = OperatorPersona.general,
  });

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> with BatchSelection<UsersTab> {
  final _filterCtrl = TextEditingController();
  final _pageTokens = <String?>[null];
  late Future<SSOAdminListPage> _future;
  var _pageIndex = 0;
  var _pageSize = 100;
  var _orderBy = 'id';
  String? _busyId;
  late final void Function() _cancelPopState;

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
    if (route.module != 'users') return;
    if (route.isNew) {
      _openCreateDialog();
    } else if (route.isEdit) {
      _openEditForId(route.resourceId);
    }
  }

  Future<void> _openEditForId(String id) async {
    try {
      final user = await widget.client.getUser(id);
      if (!mounted) return;
      await _openEditDialog(user);
    } catch (e) {
      debugPrint('users_tab edit error: $e');
    }
    if (mounted) AdminRoute.go('users');
  }

  @override
  void dispose() {
    _cancelPopState();
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<SSOAdminListPage> _loadPage() => widget.client.listUsers(
    pageToken: _pageTokens[_pageIndex],
    pageSize: _pageSize,
    orderBy: _orderBy,
    filter: _filterCtrl.text,
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

  Future<void> _openCreateDialog() async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) => UserFormDialog(client: widget.client),
    );
    if (result != null) {
      _reload();
      if (mounted) AdminRoute.go('users');
    }
  }

  Future<void> _openEditDialog(Map<String, dynamic> user) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          UserFormDialog(client: widget.client, existing: user),
    );
    if (result != null) {
      _reload();
      if (mounted) AdminRoute.go('users');
    }
  }

  /// 批量删除用户（确认影响数量 → 并行执行 → 明细报告）。
  Future<void> _batchDelete() async {
    final ids = selected.toList();
    if (ids.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete ${ids.length} users?',
      message: 'This will delete ${ids.length} selected users.',
      confirmLabel: 'Delete users',
      destructive: true,
    );
    if (!confirmed) return;
    final failures = <String>[];
    var ok = 0;
    final results = await Future.wait(
      ids.map((id) async {
        try {
          await widget.client.deleteUser(id);
          return null;
        } catch (e) {
          return '$id: $e';
        }
      }),
    );
    for (final failure in results) {
      if (failure == null) {
        ok++;
      } else {
        failures.add(failure);
      }
    }
    if (!mounted) return;
    clearSelection();
    final message = failures.isEmpty
        ? 'Deleted $ok of ${ids.length} users.'
        : 'Delete: $ok succeeded, ${failures.length} failed. '
              '${failures.take(3).join('; ')}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: LocalizedText(message)));
    _reload();
  }

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    if (id.isEmpty || _busyId != null) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete user?',
      message:
          'Delete $id? Sessions, credentials, and dependent records may stop '
          'working. This cannot be undone.',
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
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
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
            selectedCount: selected.length,
            onDelete: _batchDelete,
            onClearSelection: clearSelection,
            isLoading: _busyId != null,
          ),
          const SizedBox(height: 8),
        ],
        Padding(
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
              DropdownButton<String>(
                value: _orderBy,
                items: const [
                  DropdownMenuItem(
                    value: 'id',
                    child: LocalizedText('ID ascending'),
                  ),
                  DropdownMenuItem(
                    value: '-id',
                    child: LocalizedText('ID descending'),
                  ),
                  DropdownMenuItem(
                    value: 'provider',
                    child: LocalizedText('Provider ascending'),
                  ),
                  DropdownMenuItem(
                    value: '-provider',
                    child: LocalizedText('Provider descending'),
                  ),
                  DropdownMenuItem(
                    value: 'created_at',
                    child: LocalizedText('Created ascending'),
                  ),
                  DropdownMenuItem(
                    value: '-created_at',
                    child: LocalizedText('Created descending'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _orderBy = value);
                  _reload();
                },
              ),
              DropdownButton<int>(
                value: _pageSize,
                items: const [
                  DropdownMenuItem(
                    value: 25,
                    child: LocalizedText('25 per page'),
                  ),
                  DropdownMenuItem(
                    value: 100,
                    child: LocalizedText('100 per page'),
                  ),
                  DropdownMenuItem(
                    value: 250,
                    child: LocalizedText('250 per page'),
                  ),
                ],
                onChanged: (value) {
                  if (value == null) return;
                  setState(() => _pageSize = value);
                  _reload();
                },
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: FutureBuilder<SSOAdminListPage>(
            future: _future,
            builder: (context, snap) {
              if (snap.connectionState != ConnectionState.done) {
                return const SkeletonListTile(itemCount: 6);
              }
              if (snap.hasError) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.error_outline,
                        size: 48,
                        color: AppColors.danger,
                      ),
                      const SizedBox(height: 16),
                      LocalizedText(
                        'Failed to load',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 32),
                        child: LocalizedText(
                          'Error: {snap_error}',
                          args: {'snap_error': snap.error},
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 16),
                      OutlinedButton.icon(
                        onPressed: _reload,
                        icon: const Icon(Icons.refresh),
                        label: const LocalizedText('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final page = snap.data!;
              final items = page.items;
              final metrics = UserMetrics(
                items: items,
                totalSize: page.totalSize,
                persona: widget.persona,
              );
              final list = items.isEmpty
                  ? (_filterCtrl.text.isNotEmpty
                        ? EmptyState(
                            variant: EmptyStateVariant.noMatch,
                            title: 'No users',
                            subtitle: 'No users match the current filter.',
                            actionLabel: 'Create user',
                            onAction: () =>
                                AdminRoute.go('users', action: 'new'),
                          )
                        : EmptyState(
                            variant: EmptyStateVariant.empty,
                            icon: Icons.person,
                            title: 'No users',
                            subtitle: 'No users match the current filter.',
                            actionLabel: 'Create user',
                            onAction: () =>
                                AdminRoute.go('users', action: 'new'),
                          ))
                  : AdminDataTable(
                      scrollable: true,
                      minWidth: 720,
                      onRowTap: selecting
                          ? (i) =>
                                toggleSelect(items[i]['id']?.toString() ?? '')
                          : (i) => AdminRoute.go(
                              'users',
                              resourceId: items[i]['id']?.toString() ?? '',
                            ),
                      onRowLongPress: selecting
                          ? null
                          : (i) =>
                                toggleSelect(items[i]['id']?.toString() ?? ''),
                      columns: [
                        if (selecting)
                          AdminDataColumn(
                            id: 'select',
                            label: '',
                            width: 44,
                            builder: (context, i) {
                              final uid = items[i]['id']?.toString() ?? '';
                              return Checkbox(
                                value: selected.contains(uid),
                                onChanged: (_) => toggleSelect(uid),
                              );
                            },
                          ),
                        AdminDataColumn(
                          id: 'user',
                          label: 'USER',
                          width: 260,
                          sortable: true,
                          builder: (context, i) => Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              UserAvatar(
                                name: items[i]['id']?.toString() ?? '?',
                                radius: 14,
                              ),
                              const SizedBox(width: 8),
                              Flexible(
                                child: TableCellText(
                                  items[i]['id']?.toString() ?? '?',
                                  bold: true,
                                  maxLines: 1,
                                ),
                              ),
                            ],
                          ),
                        ),
                        AdminDataColumn(
                          id: 'provider',
                          label: 'PROVIDER',
                          width: 140,
                          sortable: true,
                          builder: (context, i) => TableCellText(
                            items[i]['provider']?.toString() ?? '?',
                            muted: true,
                          ),
                        ),
                        AdminDataColumn(
                          id: 'external',
                          label: 'EXTERNAL ID',
                          builder: (context, i) => TableCellText(
                            items[i]['externalId']?.toString() ??
                                items[i]['external_id']?.toString() ??
                                '',
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
                                  AdminRoute.go(
                                    'users',
                                    action: 'edit',
                                    resourceId: u['id']?.toString() ?? '',
                                  );
                                }
                                if (value == 'delete') {
                                  _confirmDelete(u);
                                }
                              },
                              itemBuilder: (context) => const [
                                PopupMenuItem(
                                  value: 'edit',
                                  child: LocalizedText('Edit'),
                                ),
                                PopupMenuItem(
                                  value: 'delete',
                                  child: LocalizedText('Delete'),
                                ),
                              ],
                            );
                          },
                        ),
                      ],
                      itemCount: items.length,
                      rowBuilder: (context, i) => const SizedBox.shrink(),
                    );
              return LayoutBuilder(
                builder: (context, constraints) {
                  if (constraints.maxHeight < 380) {
                    // Short viewport: the page scrolls; the table keeps its
                    // own internal scroll area (no overflow).
                    return SingleChildScrollView(
                      child: Column(
                        children: [
                          metrics,
                          SizedBox(height: 280, child: list),
                          PaginationControls(
                            page: _pageIndex + 1,
                            total: page.totalSize,
                            canGoBack: _pageIndex > 0,
                            canGoNext: page.nextPageToken != null,
                            onPrevious: _goPrevious,
                            onNext: () => _goNext(page),
                          ),
                        ],
                      ),
                    );
                  }
                  return Column(
                    children: [
                      metrics,
                      Expanded(child: list),
                      PaginationControls(
                        page: _pageIndex + 1,
                        total: page.totalSize,
                        canGoBack: _pageIndex > 0,
                        canGoNext: page.nextPageToken != null,
                        onPrevious: _goPrevious,
                        onNext: () => _goNext(page),
                      ),
                    ],
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}
