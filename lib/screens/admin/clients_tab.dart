import 'dart:js_interop';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:web/web.dart' as web;
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'admin_route.dart';
import 'client_form_dialog.dart';
class ClientsTab extends StatefulWidget {
  final SSOAdminClient client;
  const ClientsTab({super.key, required this.client});
  @override
  State<ClientsTab> createState() => _ClientsTabState();
}
class _ClientsTabState extends State<ClientsTab> {
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
    // Listen for URL changes
    void popListener() {
      if (mounted) _handleRoute();
    }
    web.window.addEventListener('popstate', popListener.toJS);
  }
  void _handleRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    if (route.module != 'clients') return;
    if (route.isNew) {
      _openCreateDialog();
    } else if (route.isEdit) {
      _openEditForId(route.resourceId);
    }
  }
  Future<void> _openEditForId(String id) async {
    try {
      final client = await widget.client.getClient(id);
      if (!mounted) return;
      await _openEditDialog(client);
    } catch (e) { debugPrint("clients_tab edit error: \$e"); }
    if (mounted) AdminRoute.go('clients');
  }
  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }
  Future<SSOAdminListPage> _loadPage() => widget.client.listClients(
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
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => ClientFormDialog(client: widget.client),
    );
    if (created == true) _reload();
    if (mounted) AdminRoute.go('clients');
  }
  Future<void> _openEditDialog(Map<String, dynamic> c) async {
    final updated = await showDialog<bool>(
      context: context,
      builder: (_) => ClientFormDialog(client: widget.client, existing: c),
    );
    if (updated == true) _reload();
    if (mounted) AdminRoute.go('clients');
  }
  Future<void> _approveClient(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    try {
      await widget.client.approveClient(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Client $id approved.')));
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
  Future<void> _rejectClient(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    try {
      await widget.client.rejectClient(id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Client $id rejected.')));
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete client?'),
        content: Text('Delete $id? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await widget.client.deleteClient(id);
      if (!mounted) return;
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }
  Future<void> _rotateSecret(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    String secret;
    try {
      secret = await widget.client.rotateClientSecret(id);
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    await showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('New client secret'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('This secret will not be shown again.'),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: SelectableText(secret)),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy to clipboard',
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: secret));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Copied to clipboard')),
                      );
                    }
                  },
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminBreadcrumb(),
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Clients', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton(
                onPressed: () => AdminRoute.go('clients', action: 'new'),
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
                    hintText: 'e.g. name:portal or active:true',
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
                    value: 'name',
                    child: Text('Name ascending'),
                  ),
                  DropdownMenuItem(
                    value: '-name',
                    child: Text('Name descending'),
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
                            icon: Icons.apps,
                            title: 'No clients',
                            subtitle: 'Create your first client to get started.',
                            actionLabel: 'Create client',
                            onAction: () => AdminRoute.go('clients', action: 'new'),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final c = items[i];
                              final active = c['active'] == true;
                              return ListTile(
                                onTap: () => AdminRoute.go('clients', resourceId: c['id']?.toString() ?? ''),
                                leading: Icon(
                                  Icons.apps,
                                  color: active
                                      ? Colors.greenAccent
                                      : Colors.grey,
                                ),
                                title: Text(c['id']?.toString() ?? '?'),
                                subtitle: Text(c['name']?.toString() ?? ''),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      c['tokenStrategy']?.toString() ??
                                          c['token_strategy']?.toString() ??
                                          '',
                                    ),
                                    PopupMenuButton<String>(
                                      onSelected: (value) {
                                        switch (value) {
                                          case 'edit':
                                            AdminRoute.go('clients', action: 'edit', resourceId: c['id']?.toString() ?? '');
                                            break;
                                          case 'rotate':
                                            _rotateSecret(c);
                                            break;
                                          case 'approve':
                                            _approveClient(c);
                                            break;
                                          case 'reject':
                                            _rejectClient(c);
                                            break;
                                          case 'delete':
                                            _confirmDelete(c);
                                            break;
                                        }
                                      },
                                      itemBuilder: (context) => const [
                                        PopupMenuItem(
                                          value: 'edit',
                                          child: Text('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'rotate',
                                          child: Text('Rotate secret'),
                                        ),
                                        PopupMenuItem(
                                          value: 'approve',
                                          child: Text('Approve'),
                                        ),
                                        PopupMenuItem(
                                          value: 'reject',
                                          child: Text('Reject'),
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