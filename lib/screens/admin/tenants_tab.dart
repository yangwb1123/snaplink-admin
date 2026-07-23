import 'package:flutter/material.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'tenant_form_dialog.dart';

class TenantsTab extends StatefulWidget {
  final SSOAdminClient client;
  const TenantsTab({super.key, required this.client});

  @override
  State<TenantsTab> createState() => _TenantsTabState();
}

class _TenantsTabState extends State<TenantsTab> {
  final _filterCtrl = TextEditingController();
  final _pageTokens = <String?>[null];
  late Future<SSOAdminListPage> _future;
  String? _busyId;
  var _pageIndex = 0;
  var _pageSize = 100;
  var _orderBy = 'id';

  @override
  void initState() {
    super.initState();
    _future = _loadPage();
  }

  @override
  void dispose() {
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<SSOAdminListPage> _loadPage() => widget.client.listTenants(
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

  Future<void> _toggleStatus(String id, String currentStatus) async {
    final next = currentStatus == 'suspended' ? 'active' : 'suspended';
    setState(() => _busyId = id);
    try {
      await widget.client.setTenantStatus(id, next);
      _reload();
    } on SSOError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(String id, String label) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tenant'),
        content: Text('Delete $label? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _busyId = id);
    try {
      await widget.client.deleteTenant(id);
      _reload();
    } on SSOError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _openForm({Map<String, dynamic>? existing}) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (context) =>
          TenantFormDialog(client: widget.client, existing: existing),
    );
    if (saved == true) _reload();
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
              Text('Tenants', style: Theme.of(context).textTheme.headlineSmall),
              const Spacer(),
              IconButton(onPressed: _reload, icon: const Icon(Icons.refresh)),
              IconButton(
                onPressed: () => _openForm(),
                icon: const Icon(Icons.add),
              ),
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
                    hintText: 'e.g. status:active or name:acme',
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
                    value: 'slug',
                    child: Text('Slug ascending'),
                  ),
                  DropdownMenuItem(
                    value: '-slug',
                    child: Text('Slug descending'),
                  ),
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
                        ? const Center(child: Text('No tenants'))
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final t = items[i];
                              final id = t['id']?.toString() ?? '';
                              final status =
                                  t['status']?.toString() ?? 'active';
                              final suspended = status == 'suspended';
                              final busy = _busyId == id;
                              return ListTile(
                                leading: Icon(
                                  Icons.business,
                                  color: suspended
                                      ? Colors.redAccent
                                      : Colors.greenAccent,
                                ),
                                title: Text(t['name']?.toString() ?? id),
                                subtitle: Text('${t['slug'] ?? ''} · $status'),
                                trailing: busy
                                    ? const SizedBox(
                                        height: 18,
                                        width: 18,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                        ),
                                      )
                                    : PopupMenuButton<String>(
                                        onSelected: (value) {
                                          switch (value) {
                                            case 'toggle':
                                              _toggleStatus(id, status);
                                              break;
                                            case 'edit':
                                              _openForm(existing: t);
                                              break;
                                            case 'delete':
                                              _delete(
                                                id,
                                                t['name']?.toString() ?? id,
                                              );
                                              break;
                                          }
                                        },
                                        itemBuilder: (context) => [
                                          PopupMenuItem(
                                            value: 'toggle',
                                            child: Text(
                                              suspended
                                                  ? 'Activate'
                                                  : 'Suspend',
                                            ),
                                          ),
                                          const PopupMenuItem(
                                            value: 'edit',
                                            child: Text('Edit'),
                                          ),
                                          const PopupMenuItem(
                                            value: 'delete',
                                            child: Text('Delete'),
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
