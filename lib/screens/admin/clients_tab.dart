import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_route.dart';
import 'client_form_dialog.dart';
import 'client_secret_lifecycle.dart';

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
  var _expiringOnly = false;
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
    } catch (e) {
      debugPrint('clients_tab edit error: $e');
    }
    if (mounted) AdminRoute.go('clients');
  }

  @override
  void dispose() {
    _cancelPopState();
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<SSOAdminListPage> _loadPage() async {
    if (_expiringOnly) {
      final items = await widget.client.listExpiringClients();
      return SSOAdminListPage(
        items: items,
        nextPageToken: null,
        totalSize: items.length,
      );
    }
    return widget.client.listClients(
      pageToken: _pageTokens[_pageIndex],
      pageSize: _pageSize,
      orderBy: _orderBy,
      filter: _filterCtrl.text,
    );
  }

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
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Approve client?',
      message: 'Approve $id for use on this authorization server?',
      confirmLabel: 'Approve',
    );
    if (!confirmed) return;
    try {
      await widget.client.approveClient(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LocalizedText('Client $id approved.')));
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _rejectClient(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Reject client?',
      message: 'Reject the pending client registration for $id?',
      confirmLabel: 'Reject',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    try {
      await widget.client.rejectClient(id);
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LocalizedText('Client $id rejected.')));
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  Future<void> _confirmDelete(Map<String, dynamic> c) async {
    final id = c['id']?.toString() ?? '';
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete client?',
      message:
          'Delete $id permanently? Existing tokens and integrations may '
          'stop working.',
      confirmLabel: 'Delete permanently',
      confirmText: id,
      destructive: true,
    );
    if (!confirmed) return;
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
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Rotate client secret?',
      message:
          'The current secret for $id remains valid for 24 hours. Update every '
          'integration with the new one-time value before that window closes.',
      confirmLabel: 'Rotate secret',
      confirmText: id,
      destructive: true,
    );
    if (!confirmed) return;
    Map<String, dynamic> rotation;
    try {
      rotation = await widget.client.rotateClientSecretWithPolicy(id);
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
      return;
    }
    if (!mounted) return;
    final secret = rotation['secret']?.toString() ?? '';
    if (secret.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText(
            'The secret was rotated, but its one-time value was not returned.',
          ),
        ),
      );
      return;
    }
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const LocalizedText('New client secret'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const LocalizedText('This secret will not be shown again.'),
            LocalizedText(clientSecretExpiryLabel(rotation)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: SelectableText(secret)),
                IconButton(
                  icon: const Icon(Icons.copy),
                  tooltip: 'Copy to clipboard'.localized,
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: secret));
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: LocalizedText('Copied to clipboard'),
                        ),
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
            child: const LocalizedText('I have saved it'),
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
        AdminListHeader(
          title: AppStrings.of(context).clients,
          createTooltip: 'Create client',
          onCreate: () => AdminRoute.go('clients', action: 'new'),
          onRefresh: _reload,
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
                    labelText: 'Filter'.localized,
                    hintText: 'e.g. name:portal or active:true'.localized,
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
                    value: 'name',
                    child: LocalizedText('Name ascending'),
                  ),
                  DropdownMenuItem(
                    value: '-name',
                    child: LocalizedText('Name descending'),
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
                            icon: Icons.apps,
                            title: 'No clients',
                            subtitle:
                                'Create your first client to get started.',
                            actionLabel: 'Create client',
                            onAction: () =>
                                AdminRoute.go('clients', action: 'new'),
                          )
                        : ListView.separated(
                            itemCount: items.length,
                            separatorBuilder: (_, _) =>
                                const Divider(height: 1),
                            itemBuilder: (context, i) {
                              final c = items[i];
                              final active = c['active'] == true;
                              return ListTile(
                                onTap: () => AdminRoute.go(
                                  'clients',
                                  resourceId: c['id']?.toString() ?? '',
                                ),
                                leading: Icon(
                                  Icons.apps,
                                  color: active
                                      ? Colors.greenAccent
                                      : Colors.grey,
                                ),
                                title: Text(c['id']?.toString() ?? '?'),
                                subtitle: Text(
                                  '${c['name']?.toString() ?? ''} · '
                                  '${clientSecretExpiryLabel(c)}',
                                ),
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
                                            AdminRoute.go(
                                              'clients',
                                              action: 'edit',
                                              resourceId:
                                                  c['id']?.toString() ?? '',
                                            );
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
                                          child: LocalizedText('Edit'),
                                        ),
                                        PopupMenuItem(
                                          value: 'rotate',
                                          child: LocalizedText('Rotate secret'),
                                        ),
                                        PopupMenuItem(
                                          value: 'approve',
                                          child: LocalizedText('Approve'),
                                        ),
                                        PopupMenuItem(
                                          value: 'reject',
                                          child: LocalizedText('Reject'),
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
