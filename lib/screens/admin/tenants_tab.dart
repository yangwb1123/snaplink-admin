import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/widgets/batch_selection.dart';
import 'package:sso_admin/widgets/status_filter_dropdown.dart';
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
import 'tenant_form_dialog.dart';
import 'tenant_lifecycle_copy.dart';
import 'package:sso_admin/i18n/app_strings.dart';

class TenantsTab extends StatefulWidget {
  final SSOAdminClient client;
  const TenantsTab({super.key, required this.client});

  @override
  State<TenantsTab> createState() => _TenantsTabState();
}

class _TenantsTabState extends State<TenantsTab>
    with BatchSelection<TenantsTab> {
  final _filterCtrl = TextEditingController();
  var _statusFilter = 'all';
  final _pageTokens = <String?>[null];
  late Future<SSOAdminListPage> _future;
  String? _busyId;
  var _pageIndex = 0;
  var _pageSize = 100;
  var _orderBy = 'id';
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
    if (route.module != 'tenants') return;
    if (route.isNew) {
      _openForm();
    } else if (route.isEdit) {
      _openEditForId(route.resourceId);
    }
  }

  Future<void> _openEditForId(String id) async {
    try {
      final tenant = await widget.client.getTenant(id);
      if (!mounted) return;
      await _openForm(existing: tenant);
    } catch (e) {
      debugPrint('tenants_tab edit error: $e');
    }
    if (mounted) AdminRoute.go('tenants');
  }

  @override
  void dispose() {
    _cancelPopState();
    _filterCtrl.dispose();
    super.dispose();
  }

  Future<SSOAdminListPage> _loadPage() => widget.client.listTenants(
    pageToken: _pageTokens[_pageIndex],
    pageSize: _pageSize,
    orderBy: _orderBy,
    filter: _statusFilter == 'all'
        ? _filterCtrl.text
        : _filterCtrl.text.trim().isEmpty
            ? 'status:$_statusFilter'
            : '${_filterCtrl.text.trim()} and status:$_statusFilter',
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

  /// 批量切换选中租户状态（suspend 或 activate）。
  Future<void> _batchSetStatus(String next) async {
    final ids = selected.toList();
    if (ids.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: next == 'suspended'
          ? 'Suspend ${ids.length} tenants?'
          : 'Activate ${ids.length} tenants?',
      message: 'This will ${next == 'suspended' ? 'suspend' : 'activate'} '
          '${ids.length} selected tenants in one operation.',
      confirmLabel: next == 'suspended' ? 'Suspend tenants' : 'Activate tenants',
      destructive: next == 'suspended',
    );
    if (!confirmed) return;
    final failures = <String>[];
    var ok = 0;
    final results = await Future.wait(ids.map((id) async {
      try {
        await widget.client.setTenantStatus(id, next);
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
        ? '${next == 'suspended' ? 'Suspended' : 'Activated'} $ok of '
              '${ids.length} tenants.'
        : '${next == 'suspended' ? 'Suspend' : 'Activate'}: $ok succeeded, '
              '${failures.length} failed. ${failures.take(3).join('; ')}';
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: LocalizedText(message)));
    _reload();
  }

  /// 批量操作栏：已选数量 + 批量挂起/激活 + 退出选择。
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
              onPressed: () => _batchSetStatus('suspended'),
              icon: const Icon(Icons.pause_circle_outline, size: 18),
              label: const LocalizedText('Suspend'),
            ),
            const SizedBox(width: 4),
            TextButton.icon(
              onPressed: () => _batchSetStatus('active'),
              icon: const Icon(Icons.play_circle_outline, size: 18),
              label: const LocalizedText('Activate'),
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

  Future<void> _toggleStatus(String id, String currentStatus) async {
    final next = currentStatus == 'suspended' ? 'active' : 'suspended';
    final confirmed = await ConfirmDialog.show(
      context,
      title: next == 'suspended' ? 'Suspend tenant?' : 'Activate tenant?',
      message: TenantLifecycleCopy.confirmation(id, next),
      confirmLabel: next == 'suspended' ? 'Suspend tenant' : 'Activate tenant',
      destructive: next == 'suspended',
      confirmText: next == 'suspended' ? id : null,
    );
    if (!confirmed) return;
    setState(() => _busyId = id);
    try {
      final response = await widget.client.setTenantStatus(id, next);
      if (mounted) {
        final message = next == 'suspended'
            ? TenantLifecycleCopy.result('Tenant suspended.', response)
            : 'Tenant activated.';
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: LocalizedText(message)));
      }
      _reload();
    } on SSOError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: LocalizedText('Failed: {e}', args: {'e': e})));
      }
    } finally {
      if (mounted) setState(() => _busyId = null);
    }
  }

  Future<void> _delete(String id, String label) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete tenant?',
      message: TenantLifecycleCopy.deletion(id, label),
      confirmLabel: 'Delete tenant',
      destructive: true,
      confirmText: id,
    );
    if (!confirmed) return;
    setState(() => _busyId = id);
    try {
      final response = await widget.client.deleteTenant(id);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: LocalizedText(
              TenantLifecycleCopy.result('Tenant deleted.', response),
            ),
          ),
        );
      }
      _reload();
    } on SSOError catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: LocalizedText('Failed: {e}', args: {'e': e})));
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
    if (saved == true) {
      _reload();
      if (mounted) AdminRoute.go('tenants');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).tenants,
          subtitle: 'Manage tenant lifecycle, status and residency.',
          createTooltip: 'Create tenant',
          onCreate: () => AdminRoute.go('tenants', action: 'new'),
          onRefresh: _reload,
        ),
        if (selecting) ...[
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _batchBar(context),
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
                child: TextField(
                  controller: _filterCtrl,
                  decoration: InputDecoration(
                    labelText: 'Filter'.localized,
                    hintText: 'e.g. status:active or name:acme'.localized,
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      tooltip: 'Apply filter'.localized,
                      onPressed: _reload,
                    ),
                  ),
                  onSubmitted: (_) => _reload(),
                ),
              ),
              const SizedBox(width: 12),
              StatusFilterDropdown(
                value: _statusFilter,
                options: const {
                  'all': 'All statuses',
                  'active': 'Active only',
                  'suspended': 'Suspended only',
                },
                onChanged: (value) {
                  setState(() => _statusFilter = value);
                  _reload();
                },
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
                    value: 'slug',
                    child: LocalizedText('Slug ascending'),
                  ),
                  DropdownMenuItem(
                    value: '-slug',
                    child: LocalizedText('Slug descending'),
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
                return Center(child: LocalizedText('Error: {snap_error}', args: {'snap_error': snap.error}));
              }
              final page = snap.data!;
              final items = page.items;
              return Column(
                children: [
                  Expanded(
                    child: items.isEmpty
                        ? EmptyState(
                            icon: Icons.business,
                            title: 'No tenants',
                            subtitle: 'No tenants match the current filter.',
                            actionLabel: 'Create tenant',
                            onAction: () =>
                                AdminRoute.go('tenants', action: 'new'),
                          )
                        : AdminDataTable(
                            scrollable: true,
                            minWidth: 760,
                            onRowTap: selecting
                                ? (i) => toggleSelect(
                                    items[i]['id']?.toString() ?? '',
                                  )
                                : (i) => AdminRoute.go(
                                    'tenants',
                                    resourceId: items[i]['id']?.toString() ?? '',
                                  ),
                            onRowLongPress: selecting
                                ? null
                                : (i) => toggleSelect(
                                    items[i]['id']?.toString() ?? '',
                                  ),
                            columns: [
                              if (selecting)
                                AdminDataColumn(
                                  id: 'select',
                                  label: '',
                                  width: 44,
                                  builder: (context, i) {
                                    final id = items[i]['id']?.toString() ?? '';
                                    return Checkbox(
                                      value: selected.contains(id),
                                      onChanged: (_) => setState(() {
                                        if (!selected.remove(id)) {
                                          toggleSelect(id);
                                        }
                                      }),
                                    );
                                  },
                                ),
                              AdminDataColumn(
                                id: 'name',
                                label: 'TENANT',
                                width: 240,
                                sortable: true,
                                builder: (context, i) => TableCellText(
                                  items[i]['name']?.toString() ??
                                      items[i]['id']?.toString() ??
                                      '?',
                                  bold: true,
                                  maxLines: 2,
                                ),
                              ),
                              AdminDataColumn(
                                id: 'slug',
                                label: 'SLUG',
                                width: 140,
                                builder: (context, i) => TableCellText(
                                  items[i]['slug']?.toString() ?? '',
                                  muted: true,
                                ),
                              ),
                              AdminDataColumn(
                                id: 'status',
                                label: 'STATUS',
                                width: 190,
                                sortable: true,
                                builder: (context, i) {
                                  final status =
                                      items[i]['status']?.toString() ?? 'active';
                                  return status == 'suspended'
                                      ? StatusChip.suspended()
                                      : StatusChip.active();
                                },
                              ),
                              AdminDataColumn(
                                id: 'actions',
                                label: '',
                                width: 60,
                                builder: (context, i) {
                                  final t = items[i];
                                  final id = t['id']?.toString() ?? '';
                                  final status =
                                      t['status']?.toString() ?? 'active';
                                  final suspended = status == 'suspended';
                                  final busy = _busyId == id;
                                  return busy
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
                                              case 'edit':
                                                AdminRoute.go(
                                                  'tenants',
                                                  action: 'edit',
                                                  resourceId: id,
                                                );
                                              case 'delete':
                                                _delete(
                                                  id,
                                                  t['name']?.toString() ?? id,
                                                );
                                            }
                                          },
                                          itemBuilder: (context) => [
                                            PopupMenuItem(
                                              value: 'toggle',
                                              child: LocalizedText(
                                                suspended
                                                    ? 'Activate'
                                                    : 'Suspend',
                                              ),
                                            ),
                                            const PopupMenuItem(
                                              value: 'edit',
                                              child: LocalizedText('Edit'),
                                            ),
                                            const PopupMenuItem(
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
