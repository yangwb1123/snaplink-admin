import 'package:sso_admin/widgets/batch_selection.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';

import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_route.dart';
import 'user_form_dialog.dart';
import 'package:sso_admin/i18n/app_strings.dart';

class UsersTab extends StatefulWidget {
  final SSOAdminClient client;
  const UsersTab({super.key, required this.client});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab>
    with BatchSelection<UsersTab> {
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
    final results = await Future.wait(ids.map((id) async {
      try {
        await widget.client.deleteUser(id);
        return null;
      } catch (e) {
        return '$id: $e';
      }
    }));
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

  /// 批量操作栏。
  Widget _batchBar(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            LocalizedText('${selected.length} selected'),
            const Spacer(),
            TextButton.icon(
              onPressed: _busyId == null ? _batchDelete : null,
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const LocalizedText('Delete'),
            ),
            IconButton(
              tooltip: 'Clear selection'.localized,
              icon: const Icon(Icons.close, size: 18),
              onPressed: clearSelection,
            ),
          ],
        ),
      ),
    );
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
          createTooltip: 'Create user',
          onCreate: () => AdminRoute.go('users', action: 'new'),
          onRefresh: _reload,
        ),
        if (selecting) ...[
          _batchBar(context),
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
                child: TextField(
                  controller: _filterCtrl,
                  onSubmitted: (_) => _reload(),
                  decoration: InputDecoration(
                    labelText: 'Filter'.localized,
                    hintText: 'e.g. email:example.test'.localized,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: 'Apply filter'.localized,
                      onPressed: _reload,
                    ),
                  ),
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
                return const Center(child: CircularProgressIndicator());
              }
              if (snap.hasError) {
                return Center(child: LocalizedText('Error: ${snap.error}'));
              }
              final page = snap.data!;
              final items = page.items;
              return Column(
                children: [
                  Expanded(
                    child: items.isEmpty
                        ? EmptyState(
                            icon: Icons.person,
                            title: 'No users',
                            subtitle: 'No users match the current filter.',
                            actionLabel: 'Create user',
                            onAction: () =>
                                AdminRoute.go('users', action: 'new'),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final u = items[i];
                              final uid = u['id']?.toString() ?? '';
                              return ListTile(
                                onTap: selecting
                                    ? () => toggleSelect(uid)
                                    : () => AdminRoute.go(
                                          'users',
                                          resourceId: uid,
                                        ),
                                onLongPress: () => toggleSelect(uid),
                                leading: selecting
                                    ? Checkbox(
                                        value: selected.contains(uid),
                                        onChanged: (_) => toggleSelect(uid),
                                      )
                                    : const Icon(Icons.person),
                                title: Text(u['id']?.toString() ?? '?'),
                                subtitle: LocalizedText(
                                  'provider: ${u['provider'] ?? '?'}',
                                ),
                                trailing: selecting
                                    ? null
                                    : Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      u['externalId']?.toString() ??
                                          u['external_id']?.toString() ??
                                          '',
                                    ),
                                    PopupMenuButton<String>(
                                      enabled: _busyId == null,
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          AdminRoute.go(
                                            'users',
                                            action: 'edit',
                                            resourceId:
                                                u['id']?.toString() ?? '',
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
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
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
          ),
        ),
      ],
    );
  }
}
