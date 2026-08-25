import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

/// Read-only token policy collection. Usage/subject analytics belong to the
/// usage-analytics module and are deliberately not inferred here.
class TokenPoliciesTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const TokenPoliciesTab({
    super.key,
    required this.api,
    required this.capabilities,
  });
  @override
  State<TokenPoliciesTab> createState() => _TokenPoliciesTabState();
}

class _TokenPoliciesTabState extends State<TokenPoliciesTab> {
  static const _path = '/api/v1/admin/token-policies';
  static const _pageSize = 25;
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _policies = const [];
  String? _error, _sortColumn;
  bool _loading = false, _sortAscending = true;
  int _page = 1, _reqSeq = 0;

  Color get _accent => adminModuleIconColor(AdminModuleId.tokenPolicies);
  bool get _available =>
      widget.capabilities.hasAnyPathPrefix(_path) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_path);

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
      _policies = const [];
      _page = 1;
    });
    try {
      final data = await widget.api.get(_path);
      final raw =
          data['policies'] as List? ?? data['token_policies'] as List? ?? [];
      final policies = raw
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _policies = policies;
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted && seq == _reqSeq) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted && seq == _reqSeq) {
        setState(() {
          _error = 'Could not load token policies.';
          _loading = false;
        });
      }
    }
  }

  List<Map<String, dynamic>> _visible() {
    final query = _searchCtrl.text.trim().toLowerCase();
    final rows = _policies.where((row) {
      if (query.isEmpty) return true;
      return row.values
          .map((v) => v.toString())
          .join(' ')
          .toLowerCase()
          .contains(query);
    }).toList();
    final sort = _sortColumn;
    if (sort != null) {
      rows.sort((a, b) {
        final result = _sortValue(a, sort).compareTo(_sortValue(b, sort));
        return _sortAscending ? result : -result;
      });
    }
    return rows;
  }

  List<Map<String, dynamic>> _pageRows(
    List<Map<String, dynamic>> rows,
    int page,
  ) {
    final start = (page - 1) * _pageSize;
    if (start >= rows.length) return const [];
    return rows.sublist(start, math.min(start + _pageSize, rows.length));
  }

  void _search(String _) => setState(() => _page = 1);

  void _sort(String column) => setState(() {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column;
      _sortAscending = true;
    }
    _page = 1;
  });

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _page = 1);
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const EmptyState(variant: EmptyStateVariant.notEnabled);
    }
    final rows = _visible();
    final error = _error;
    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminBreadcrumb(),
          AdminListHeader(
            title: AppStrings.of(context).tokenPolicies,
            subtitle: 'Token issuance and validation policy configuration.',
            onRefresh: _load,
            actions: [
              IconButton(
                onPressed: _loading ? null : _load,
                icon: Icon(Icons.refresh, color: _accent),
                tooltip: context.strings.refresh,
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: SearchFilterBar(
              labelText: AppStrings.of(context).filter,
              controller: _searchCtrl,
              onSearchChanged: _search,
              onSubmitted: _search,
            ),
          ),
          if (error != null)
            ErrorStateCard(
              message: error,
              onRetry: _load,
              retryEnabled: !_loading,
              margin: EdgeInsets.zero,
            ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.only(top: 16),
              child: SkeletonListTile(itemCount: 3),
            ),
          if (!_loading && error == null && _policies.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: EmptyState(
                compact: true,
                variant: EmptyStateVariant.empty,
                title: 'No token policies configured.',
                subtitle:
                    'Token policies are managed server-side; this page reflects the active policy set.',
              ),
            ),
          if (!_loading &&
              error == null &&
              _policies.isNotEmpty &&
              rows.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: EmptyState(
                compact: true,
                variant: EmptyStateVariant.noMatch,
                title: 'No matches',
                actionLabel: 'Clear filter',
                actionIcon: Icons.filter_alt_off,
                onAction: _clearSearch,
              ),
            ),
          if (!_loading && error == null && rows.isNotEmpty)
            _table(context, rows),
        ],
      ),
    );
  }

  Widget _table(BuildContext context, List<Map<String, dynamic>> rows) {
    final pageCount = math.max(1, (rows.length + _pageSize - 1) ~/ _pageSize);
    final page = _page.clamp(1, pageCount);
    final pageRows = _pageRows(rows, page);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Card(
          margin: const EdgeInsets.only(top: 12),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.policy_outlined, size: 20, color: _accent),
                    const SizedBox(width: 8),
                    Expanded(
                      child: SectionHeader(
                        'Token policies',
                        count: rows.length,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (pageRows.isEmpty)
                  EmptyPageState(onBackToFirst: () => setState(() => _page = 1))
                else
                  AdminDataTable(
                    density: TableDensity.compact,
                    sortColumn: _sortColumn,
                    sortAscending: _sortAscending,
                    onSort: _sort,
                    minWidth: 820,
                    columns: _columns(context, rows, pageRows),
                    itemCount: pageRows.length,
                    rowBuilder: (_, _) => const SizedBox.shrink(),
                  ),
              ],
            ),
          ),
        ),
        if (rows.length > _pageSize)
          PaginationControls(
            page: page,
            total: rows.length,
            canGoBack: page > 1,
            canGoNext: page < pageCount,
            onPrevious: () => setState(() => _page = page - 1),
            onNext: () => setState(() => _page = page + 1),
          ),
      ],
    );
  }

  List<AdminDataColumn> _columns(
    BuildContext context,
    List<Map<String, dynamic>> rows,
    List<Map<String, dynamic>> pageRows,
  ) {
    AdminDataColumn col(
      String id,
      String label,
      double width,
      Widget Function(BuildContext, int) builder, {
      bool primary = false,
    }) => AdminDataColumn(
      id: id,
      label: context.tr(label),
      width: width,
      sortable: true,
      cardPrimary: primary,
      cardDetail: !primary,
      builder: builder,
    );
    final columns = <AdminDataColumn>[
      col(
        'policy',
        'Policy',
        220,
        (_, i) => TableCellText(
          _field(pageRows[i], const ['name', 'id']),
          bold: true,
        ),
        primary: true,
      ),
    ];
    final facets = [
      ('type', 'Type', 140.0, const ['type', 'policy_type']),
      ('status', 'Status', 140.0, const ['status', 'state']),
      ('tenant', 'Tenant', 180.0, const ['tenant_id', 'tenant']),
    ];
    for (final (id, label, width, keys) in facets) {
      if (!_has(rows, keys)) continue;
      columns.add(
        col(
          id,
          label,
          width,
          (_, i) => id == 'status'
              ? _status(pageRows[i])
              : TableCellText(_field(pageRows[i], keys), muted: true),
        ),
      );
    }
    columns.addAll([
      col('effect', 'Effect', 170, (c, i) => _effect(c, pageRows[i])),
      col(
        'description',
        'Description',
        260,
        (_, i) => TableCellText(
          _field(pageRows[i], const ['description']),
          muted: true,
          maxLines: 2,
        ),
      ),
    ]);
    return columns;
  }

  Widget _status(Map<String, dynamic> row) {
    final value = _field(row, const ['status', 'state']);
    return switch (value.toLowerCase()) {
      'active' || 'enabled' => StatusChip.active(label: value),
      'suspended' || 'pending' => StatusChip.pending(label: value),
      'inactive' ||
      'disabled' ||
      'revoked' => StatusChip.inactive(label: value),
      _ => StatusChip.unknown(label: value.isEmpty ? 'Unknown' : value),
    };
  }

  Widget _effect(BuildContext context, Map<String, dynamic> row) {
    final value = (row['effect'] ?? row['action'] ?? 'allow').toString();
    final priority = row['priority']?.toString() ?? '';
    final chip = switch (value.toLowerCase()) {
      'allow' || 'permit' => StatusChip.active(label: value),
      'deny' || 'block' => StatusChip.failed(label: value),
      _ => StatusChip.info(label: value),
    };
    return Row(
      children: [
        chip,
        if (priority.isNotEmpty) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              priority,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ],
    );
  }

  static String _field(Map<String, dynamic> row, List<String> keys) {
    for (final key in keys) {
      final value = row[key]?.toString().trim();
      if (value != null && value.isNotEmpty) return value;
    }
    return '';
  }

  static bool _has(List<Map<String, dynamic>> rows, List<String> keys) =>
      rows.any((row) => _field(row, keys).isNotEmpty);

  static String _sortValue(Map<String, dynamic> row, String column) =>
      switch (column) {
        'policy' => _field(row, const ['name', 'id']),
        'type' => _field(row, const ['type', 'policy_type']),
        'status' => _field(row, const ['status', 'state']),
        'tenant' => _field(row, const ['tenant_id', 'tenant']),
        'effect' => (row['effect'] ?? row['action'] ?? 'allow').toString(),
        'description' => _field(row, const ['description']),
        _ => '',
      }.toLowerCase();
}
