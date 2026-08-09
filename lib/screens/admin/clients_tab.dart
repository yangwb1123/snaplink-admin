import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/batch_selection.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/status_filter_dropdown.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'admin_route.dart';
import 'client_form_dialog.dart';
import 'client_secret_lifecycle.dart';
import 'list_metrics.dart';

class ClientsTab extends StatefulWidget {
  final SSOAdminClient client;

  /// Persona emphasis (default = no emphasis).
  final OperatorPersona persona;

  const ClientsTab({
    super.key,
    required this.client,
    this.persona = OperatorPersona.general,
  });
  @override
  State<ClientsTab> createState() => _ClientsTabState();
}

class _ClientsTabState extends State<ClientsTab>
    with BatchSelection<ClientsTab> {
  final _filterCtrl = TextEditingController();
  final _pageTokens = <String?>[null];
  late Future<SSOAdminListPage> _future;
  var _pageIndex = 0;
  var _pageSize = 100;
  String _sortColumn = 'id';
  bool _sortAscending = true;
  var _orderBy = 'id';
  var _expiringOnly = false;
  var _statusFilter = 'all';
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

  SSOAdminListPage? _lastPage;

  Future<SSOAdminListPage> _loadPage() async {
    if (_expiringOnly) {
      final items = await widget.client.listExpiringClients();
      final page = SSOAdminListPage(
        items: items,
        nextPageToken: null,
        totalSize: items.length,
      );
      _lastPage = page;
      return page;
    }
    final page = await widget.client.listClients(
      pageToken: _pageTokens[_pageIndex],
      pageSize: _pageSize,
      orderBy: _orderBy,
      filter: _statusFilter == 'all'
          ? _filterCtrl.text
          : _filterCtrl.text.trim().isEmpty
          ? 'active:${_statusFilter == 'active'}'
          : '${_filterCtrl.text.trim()} and active:${_statusFilter == 'active'}',
    );
    _lastPage = page;
    return page;
  }

  /// 导出当前页客户端为 CSV（剪贴板；公式注入防护）。
  void _sortItems(List<Map<String, dynamic>> items) {
    final column = _sortColumn;
    items.sort((a, b) {
      int cmp;
      switch (column) {
        case 'name':
          cmp = (a['name']?.toString() ?? '').toLowerCase().compareTo(
            (b['name']?.toString() ?? '').toLowerCase(),
          );
        case 'status':
          cmp = (a['active'] == true ? 0 : 1) - (b['active'] == true ? 0 : 1);
        default:
          cmp = (a['id']?.toString() ?? '').compareTo(
            b['id']?.toString() ?? '',
          );
      }
      return _sortAscending ? cmp : -cmp;
    });
  }

  void _onSort(String column) {
    setState(() {
      if (_sortColumn == column) {
        _sortAscending = !_sortAscending;
      } else {
        _sortColumn = column;
        _sortAscending = true;
      }
    });
  }

  Future<void> _exportCsv(List<Map<String, dynamic>> items) async {
    final sb = StringBuffer('id,name,active,strategy\n');
    for (final c in items) {
      final cells = [
        c['id']?.toString() ?? '',
        c['name']?.toString() ?? '',
        c['active'] == true ? 'active' : 'inactive',
        c['tokenStrategy']?.toString() ?? c['token_strategy']?.toString() ?? '',
      ].map(_csvCell).join(',');
      sb.writeln(cells);
    }
    await Clipboard.setData(ClipboardData(text: sb.toString()));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            'Exported ${items.length} clients as CSV to clipboard',
          ),
        ),
      );
    }
  }

  /// CSV 单元格转义 + 公式注入防护（= + - @ 前缀）。
  String _csvCell(String value) {
    var cell = value.replaceAll('"', '""');
    if (cell.startsWith(RegExp(r'[=+\-@]'))) {
      cell = "'$cell";
    }
    return '"$cell"';
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText('Client {id} approved.', args: {'id': id}),
        ),
      );
      _reload();
    } on SSOError catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  /// 批量批准选中的客户端（interaction-patterns: 选择→确认→执行→明细报告）。
  Future<void> _batchApprove() async {
    await _runBatch('Approve', (id) => widget.client.approveClient(id));
  }

  Future<void> _batchReject() async {
    await _runBatch('Reject', (id) => widget.client.rejectClient(id));
  }

  /// 批量执行：确认影响数量 → 并行执行 → 报告成功/失败明细 → 刷新。
  Future<void> _runBatch(
    String action,
    Future<void> Function(String) run,
  ) async {
    final ids = selected.toList();
    if (ids.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: '$action ${ids.length} clients?',
      message:
          'This will $action ${ids.length} selected clients in one operation.',
      confirmLabel: action,
    );
    if (!confirmed) return;
    final failures = <String>[];
    var ok = 0;
    final results = await Future.wait(
      ids.map((id) async {
        try {
          await run(id);
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
        ? '$action completed for $ok of ${ids.length} clients.'
        : '$action: $ok succeeded, ${failures.length} failed. '
              '${failures.take(3).join('; ')}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: LocalizedText(message)));
    _reload();
  }

  /// 批量操作栏：已选数量 + 批量动作 + 退出选择。
  Widget _batchBar(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: theme.colorScheme.secondaryContainer.withValues(alpha: 0.4),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Row(
          children: [
            LocalizedText('{count} selected', args: {'count': selected.length}),
            const Spacer(),
            TextButton.icon(
              onPressed: _batchApprove,
              icon: const Icon(Icons.check_circle_outline, size: 18),
              label: const LocalizedText('Approve'),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: _batchReject,
              icon: const Icon(Icons.cancel_outlined, size: 18),
              label: const LocalizedText('Reject'),
            ),
            IconButton(
              tooltip: 'Clear selection'.localized,
              icon: const Icon(Icons.close, size: 18),
              onPressed: () => clearSelection(),
            ),
          ],
        ),
      ),
    );
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
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText('Client {id} rejected.', args: {'id': id}),
        ),
      );
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
          subtitle: 'Manage OAuth clients, secrets and expiring credentials.',
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
              const SizedBox(width: 12),
              IconButton(
                tooltip: 'Export CSV'.localized,
                icon: const Icon(Icons.file_download_outlined),
                onPressed: _lastPage == null || _lastPage!.items.isEmpty
                    ? null
                    : () => _exportCsv(_lastPage!.items),
              ),
              StatusFilterDropdown(
                value: _statusFilter,
                options: const {
                  'all': 'All statuses',
                  'active': 'Active only',
                  'inactive': 'Inactive only',
                },
                onChanged: (value) {
                  setState(() => _statusFilter = value);
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
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      LocalizedText(
                        'Error: {detail}',
                        args: {'detail': snap.error},
                      ),
                      const SizedBox(height: 12),
                      FilledButton.tonal(
                        onPressed: _reload,
                        child: const LocalizedText('Retry'),
                      ),
                    ],
                  ),
                );
              }
              final page = snap.data!;
              final items = [...page.items];
              _sortItems(items);
              final metrics = ClientMetrics(
                items: items,
                totalSize: page.totalSize,
                persona: widget.persona,
              );
              final list = items.isEmpty
                  ? (_filterCtrl.text.isNotEmpty || _statusFilter != 'all')
                        ? EmptyState(
                            variant: EmptyStateVariant.noMatch,
                            title: 'No clients',
                            subtitle: 'No clients match the current filter.',
                          )
                        : EmptyState(
                            icon: Icons.apps,
                            title: 'No clients',
                            subtitle:
                                'Create your first client to get started.',
                            actionLabel: 'Create client',
                            onAction: () =>
                                AdminRoute.go('clients', action: 'new'),
                          )
                  : AdminDataTable(
                      scrollable: true,
                      minWidth: 980,
                      sortColumn: _sortColumn,
                      sortAscending: _sortAscending,
                      onSort: _onSort,
                      onRowTap: selecting
                          ? (i) =>
                                toggleSelect(items[i]['id']?.toString() ?? '')
                          : (i) => AdminRoute.go(
                              'clients',
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
                              final cid = items[i]['id']?.toString() ?? '';
                              return Checkbox(
                                value: selected.contains(cid),
                                onChanged: (_) => setState(() {
                                  if (!selected.remove(cid)) {
                                    toggleSelect(cid);
                                  }
                                }),
                              );
                            },
                          ),
                        AdminDataColumn(
                          id: 'id',
                          label: 'CLIENT ID',
                          width: 190,
                          builder: (context, i) => CopyableCell(
                            text: items[i]['id']?.toString() ?? '?',
                            contextProvider: () => context,
                            enabled: !selecting,
                          ),
                        ),
                        AdminDataColumn(
                          id: 'name',
                          label: 'NAME',
                          width: 180,
                          builder: (context, i) => TableCellText(
                            items[i]['name']?.toString() ?? '',
                            bold: true,
                            maxLines: 2,
                          ),
                        ),
                        AdminDataColumn(
                          id: 'status',
                          label: 'STATUS',
                          width: 160,
                          builder: (context, i) {
                            final active = items[i]['active'] == true;
                            return active
                                ? StatusChip.active()
                                : StatusChip.inactive();
                          },
                        ),
                        AdminDataColumn(
                          id: 'strategy',
                          label: 'TOKEN',
                          width: 110,
                          builder: (context, i) => TableCellText(
                            items[i]['tokenStrategy']?.toString() ??
                                items[i]['token_strategy']?.toString() ??
                                '',
                            muted: true,
                          ),
                        ),
                        AdminDataColumn(
                          id: 'expiry',
                          label: 'SECRET',
                          width: 170,
                          builder: (context, i) => TableCellText(
                            clientSecretExpiryLabel(items[i]),
                            muted: true,
                          ),
                        ),
                        AdminDataColumn(
                          id: 'actions',
                          label: '',
                          width: 60,
                          builder: (context, i) {
                            final c = items[i];
                            return PopupMenuButton<String>(
                              onSelected: (value) {
                                switch (value) {
                                  case 'edit':
                                    AdminRoute.go(
                                      'clients',
                                      action: 'edit',
                                      resourceId: c['id']?.toString() ?? '',
                                    );
                                  case 'rotate':
                                    _rotateSecret(c);
                                  case 'approve':
                                    _approveClient(c);
                                  case 'reject':
                                    _rejectClient(c);
                                  case 'delete':
                                    _confirmDelete(c);
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
                          if (selecting) ...[
                            _batchBar(context),
                            const SizedBox(height: 8),
                          ],
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
                      if (selecting) ...[
                        _batchBar(context),
                        const SizedBox(height: 8),
                      ],
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
