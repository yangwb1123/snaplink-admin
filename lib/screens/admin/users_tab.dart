import 'dart:js_interop';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';

import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'admin_route.dart';
import 'user_form_dialog.dart';

class UsersTab extends StatefulWidget {
  final SSOAdminClient client;
  const UsersTab({super.key, required this.client});

  @override
  State<UsersTab> createState() => _UsersTabState();
}

class _UsersTabState extends State<UsersTab> {
  final _filterCtrl = TextEditingController();
  final _pageTokens = <String?>[null];
  late Future<SSOAdminListPage> _future;
  var _pageIndex = 0;
  var _pageSize = 100;
  var _orderBy = 'id';

  @override
  void initState() {
    super.initState();
    _future = _loadPage();
    _handleRoute();
    void popListener() { if (mounted) _handleRoute(); }
    web.window.addEventListener('popstate', popListener.toJS);
  }

  void _handleRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    if (route.module != 'users') return;
    if (route.isNew) { _openCreateDialog(); }
    else if (route.isEdit) { _openEditForId(route.resourceId); }
  }

  Future<void> _openEditForId(String id) async {
    try {
      final user = await widget.client.getUser(id);
      if (!mounted) return;
      await _openEditDialog(user);
    } catch (e) { debugPrint("users_tab edit error: \$e"); }
    if (mounted) AdminRoute.go('users');
  }

  @override
  void dispose() {
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
    if (result != null) { _reload(); if (mounted) AdminRoute.go('users'); }
  }

  Future<void> _openEditDialog(Map<String, dynamic> user) async {
    final result = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (context) =>
          UserFormDialog(client: widget.client, existing: user),
    );
    if (result != null) { _reload(); if (mounted) AdminRoute.go('users'); }
  }

  Future<void> _confirmDelete(Map<String, dynamic> user) async {
    final id = user['id']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete user?'),
        content: Text('Delete $id? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.deleteUser(id);
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
        AdminBreadcrumb(),
                      Text('Users', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton(
                onPressed: () => AdminRoute.go('users', action: 'new'),
                icon: const Icon(Icons.add),
              ),
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
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
                    labelText: 'Filter',
                    hintText: 'e.g. email:example.test',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: 'Apply filter',
                      onPressed: _reload,
                    ),
                  ),
                ),
              ),
              DropdownButton<String>(
                value: _orderBy,
                items: const [
                  DropdownMenuItem(value: 'id', child: Text('ID ascending')),
                  DropdownMenuItem(value: '-id', child: Text('ID descending')),
                  DropdownMenuItem(
                    value: 'provider',
                    child: Text('Provider ascending'),
                  ),
                  DropdownMenuItem(
                    value: '-provider',
                    child: Text('Provider descending'),
                  ),
                  DropdownMenuItem(
                    value: 'created_at',
                    child: Text('Created ascending'),
                  ),
                  DropdownMenuItem(
                    value: '-created_at',
                    child: Text('Created descending'),
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
                  DropdownMenuItem(value: 25, child: Text('25 per page')),
                  DropdownMenuItem(value: 100, child: Text('100 per page')),
                  DropdownMenuItem(value: 250, child: Text('250 per page')),
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
                return Center(child: Text('Error: ${snap.error}'));
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
                            onAction: () => AdminRoute.go('users', action: 'new'),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final u = items[i];
                              return ListTile(
                                leading: const Icon(Icons.person),
                                title: Text(u['id']?.toString() ?? '?'),
                                onTap: () => AdminRoute.go('users', resourceId: u['id']?.toString() ?? ''),
                                subtitle: Text(
                                  'provider: ${u['provider'] ?? '?'}',
                                ),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      u['externalId']?.toString() ??
                                          u['external_id']?.toString() ??
                                          '',
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        if (value == 'edit') {
                                          AdminRoute.go('users', action: 'edit', resourceId: u['id']?.toString() ?? '');
                                        }
                                        if (value == 'delete') {
                                          _confirmDelete(u);
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'delete',
                                          child: Text('Delete'),
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


