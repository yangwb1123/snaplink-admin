import 'dart:async';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/services/event_bus.dart';
import 'package:sso_admin/services/export_service.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/paginated_list.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';

/// Domain ownership management tab with URL routing.
/// URLs: /admin/domains, /admin/domains/new
class DomainsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const DomainsTab({super.key, required this.api, required this.capabilities});
  @override
  State<DomainsTab> createState() => _DomainsTabState();
}

class _DomainsTabState extends State<DomainsTab> {
  static const _path = '/api/v1/admin/domains';
  static const _pageSize = 25;
  final _formKey = GlobalKey<FormState>();
  final _hostCtrl = TextEditingController(), _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _domains = const [], _filteredDomains = const [];
  String? _error, _statusFilter, _sortColumn;
  bool _sortAscending = true, _loading = false, _mutating = false, _showForm = false;
  String _searchQuery = '';
  int _page = 0, _reqSeq = 0;
  late final void Function() _cancelPopState;
  late final StreamSubscription<DataChangedEvent> _sub;

  bool get _available => widget.capabilities.hasAnyPathPrefix(_path);
  Color get _accent => adminModuleIconColor('domains');
  List<Map<String, dynamic>> get _pageDomains => _filteredDomains
      .skip(_page * _pageSize).take(_pageSize).toList(growable: false);

  @override
  void initState() {
    super.initState();
    _load();
    _sub = EventBus().on<DataChangedEvent>().listen((e) {
      if (e.resourceType == 'domains') _load();
    });
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  @override
  void dispose() {
    _cancelPopState(); _sub.cancel(); _hostCtrl.dispose(); _searchCtrl.dispose();
    super.dispose();
  }

  void _handleRoute() => setState(() => _showForm = AdminRoute.current().isNew);

  void _loadError(String message, int seq) {
    if (mounted && seq == _reqSeq) {
      setState(() { _error = message; _loading = false; });
    }
  }

  Future<void> _load() async {
    final seq = ++_reqSeq;
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.getStaleWhileRevalidate(_path, onRefresh: (fresh) {
        if (mounted && seq == _reqSeq) setState(() => _applyDomains(fresh));
      });
      if (!mounted || seq != _reqSeq) return;
      setState(() { _applyDomains(data); _loading = false; });
    } on SnaplinkAdminApiError catch (e) {
      _loadError(e.toString(), seq);
    } catch (_) {
      _loadError('Could not load domains.', seq);
    }
  }

  void _applyDomains(Map<String, dynamic> data) {
    final items = data['domains'] as List? ?? [];
    _domains = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _page = 0; _filterDomains();
  }

  Future<void> _create() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    final host = _hostCtrl.text.trim();
    setState(() { _mutating = true; _error = null; });
    try {
      await widget.api.post(_path, {'hostname': host});
      if (!mounted) return;
      _hostCtrl.clear();
      showAppSnackBar(context, content: LocalizedText('Domain added.'));
      AdminRoute.go('domains');
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  bool _isVerified(Map<String, dynamic> d) => d['verified'] == true ||
      d['status']?.toString().trim().toLowerCase() == 'verified';

  String _status(Map<String, dynamic> d) {
    final status = d['status']?.toString().trim().toLowerCase();
    return status?.isNotEmpty == true ? status! : _isVerified(d) ? 'verified' : 'pending';
  }

  String _sortValue(Map<String, dynamic> d, String column) => column == 'verified'
      ? (_isVerified(d) ? '1' : '0')
      : column == 'id'
      ? (d['id']?.toString() ?? '').toLowerCase()
      : (d['hostname']?.toString() ?? '').toLowerCase();

  void _filterDomains() {
    final q = _searchQuery;
    _filteredDomains = _domains.where((d) {
      final text = (d['hostname']?.toString() ?? '').toLowerCase().contains(q) ||
          (d['id']?.toString() ?? '').toLowerCase().contains(q);
      final status = _statusFilter == null ||
          (_statusFilter == 'Verified' ? _isVerified(d) : !_isVerified(d));
      return (q.isEmpty || text) && status;
    }).toList();
    final sort = _sortColumn;
    if (sort != null) {
      _filteredDomains.sort((a, b) {
        final result = _sortValue(a, sort).compareTo(_sortValue(b, sort));
        return _sortAscending ? result : -result;
      });
    }
  }

  void _onSearchChanged(String query) => setState(() {
    _searchQuery = query.trim().toLowerCase(); _page = 0; _filterDomains();
  });

  void _onFilterChanged(String? value) => setState(() {
    _statusFilter = value; _page = 0; _filterDomains();
  });

  void _onSort(String column) => setState(() {
    if (_sortColumn == column) {
      _sortAscending = !_sortAscending;
    } else {
      _sortColumn = column; _sortAscending = true;
    }
    _page = 0; _filterDomains();
  });

  void _previousPage() => setState(() { if (_page > 0) _page--; });
  void _nextPage() => setState(() {
    if ((_page + 1) * _pageSize < _filteredDomains.length) _page++;
  });

  void _exportCsv() {
    if (_filteredDomains.isEmpty || !mounted) return;
    ExportService.exportCsv(_filteredDomains, 'domains.csv');
    showAppSnackBar(context, content: LocalizedText(
      'Exported {n} domains as CSV.', args: {'n': _filteredDomains.length},
    ));
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() {
      _searchQuery = ''; _statusFilter = null; _page = 0; _filterDomains();
    });
  }

  Future<void> _delete(String hostname) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete domain?',
      message: context.tr('Delete {hostname}?', {'hostname': hostname}),
      confirmLabel: 'Delete', destructive: true, confirmText: hostname,
    );
    if (!confirmed) return;
    setState(() { _mutating = true; _error = null; });
    try {
      await widget.api.delete('$_path/${Uri.encodeComponent(hostname)}');
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText('Domain deleted.'));
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) return const EmptyState(variant: EmptyStateVariant.notEnabled);
    final hasFilter = _searchQuery.isNotEmpty || _statusFilter != null;
    return PullToRefresh(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const AdminBreadcrumb(),
          AdminListHeader(
            title: AppStrings.of(context).domains,
            subtitle: 'Manage email domains for home-realm discovery.',
            createTooltip: 'Add domain',
            onCreate: _showForm ? null : () => AdminRoute.go('domains', action: 'new'),
            onRefresh: _load, refreshing: _loading,
          ),
          if (_error != null) ...[
            ErrorStateCard(message: _error!, onRetry: _load, margin: EdgeInsets.zero),
            const SizedBox(height: 12),
          ],
          if (_showForm) _buildForm(context),
          if (_domains.isNotEmpty) ...[
            const SizedBox(height: 8),
            SectionHeader('Registered domains', count: _filteredDomains.length,
              action: IconButton(
                icon: Icon(Icons.file_download_outlined, color: _accent),
                tooltip: 'Export CSV'.localized, onPressed: _exportCsv,
              )),
            const SizedBox(height: 8),
            SearchFilterBar(
              hintText: 'Search domains...'.localized, controller: _searchCtrl,
              debounce: false, filterOptions: const ['Verified', 'Pending'],
              selectedFilter: _statusFilter, onSearchChanged: _onSearchChanged,
              onFilterChanged: _onFilterChanged, onRefresh: _load,
            ),
          ],
          const SizedBox(height: 12),
          if (_loading)
            const SkeletonListTile(itemCount: 3)
          else if (_filteredDomains.isEmpty && !_showForm)
            EmptyState(
              variant: hasFilter ? EmptyStateVariant.noMatch : EmptyStateVariant.empty,
              title: hasFilter ? null : 'No domains registered.',
              actionLabel: hasFilter ? 'Clear filter' : null,
              actionIcon: Icons.filter_alt_off, onAction: hasFilter ? _clearSearch : null,
            )
          else if (_filteredDomains.isNotEmpty && _pageDomains.isEmpty)
            EmptyPageState(onBackToFirst: _previousPage)
          else if (_filteredDomains.isNotEmpty)
            _buildTable(context),
          if (!_showForm)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: OutlinedButton.icon(
                onPressed: () => AdminRoute.go('domains', action: 'new'),
                icon: Icon(Icons.add, color: _accent),
                label: const LocalizedText('Add domain'),
              ),
            ),
        ],
      ),
    );
  }

  Widget _statusChip(BuildContext context, Map<String, dynamic> domain) {
    final status = _status(domain);
    if (status == 'verified' || status == 'active') {
      return StatusChip.active(label: context.tr(status == 'active' ? 'Active' : 'Verified'));
    }
    if (status == 'failed' || status == 'error') {
      return StatusChip.failed(label: context.tr('Failed'));
    }
    return StatusChip.pending(label: context.tr('Pending'));
  }

  Widget _deleteButton(BuildContext context, String hostname) => TextButton(
    onPressed: _mutating ? null : () => _delete(hostname),
    style: TextButton.styleFrom(foregroundColor: AppColors.semanticFor(
      Theme.of(context).brightness, AppColors.danger,
    )),
    child: const LocalizedText('Delete'),
  );

  Widget _buildTable(BuildContext context) {
    final rows = _pageDomains;
    return Column(children: [
      AdminDataTable(
        minWidth: 720, density: TableDensity.compact,
        sortColumn: _sortColumn, sortAscending: _sortAscending, onSort: _onSort,
        columns: [
          AdminDataColumn(
            id: 'hostname', label: 'Hostname', width: 260, sortable: true,
            cardPrimary: true,
            builder: (_, i) => TableCellText(
              rows[i]['hostname']?.toString() ?? '', maxLines: 2,
              level: DataEmphasisLevel.primary,
            ),
          ),
          AdminDataColumn(
            id: 'id', label: 'ID', sortable: true, cardDetail: true,
            builder: (_, i) => CopyableCell(
              text: rows[i]['id']?.toString() ?? '', contextProvider: () => context,
            ),
          ),
          AdminDataColumn(
            id: 'verified', label: 'Status', sortable: true, cardDetail: true,
            builder: (_, i) => _statusChip(context, rows[i]),
          ),
          AdminDataColumn(
            id: 'actions', label: '', width: 110,
            builder: (_, i) => _deleteButton(
              context, rows[i]['hostname']?.toString() ?? '',
            ),
          ),
        ],
        itemCount: rows.length, rowBuilder: (_, _) => const SizedBox.shrink(),
      ),
      if (_filteredDomains.length > _pageSize)
        PaginationControls(
          page: _page + 1, total: _filteredDomains.length,
          canGoBack: _page > 0,
          canGoNext: (_page + 1) * _pageSize < _filteredDomains.length,
          onPrevious: _previousPage, onNext: _nextPage,
        ),
    ]);
  }

  Widget _buildForm(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Form(
        key: _formKey, autovalidateMode: AutovalidateMode.onUserInteraction,
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Row(children: [
            Icon(Icons.language, size: 20, color: _accent), const SizedBox(width: 8),
            LocalizedText('Add domain', style: Theme.of(context).textTheme.titleMedium),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _hostCtrl,
            decoration: InputDecoration(
              labelText: 'Hostname'.localized, hintText: 'example.com'.localized,
            ),
            validator: (value) => value?.trim().isEmpty == true
                ? 'Enter a hostname.'.localized : null,
          ),
          const SizedBox(height: 12),
          OverflowBar(children: [
            OutlinedButton(
              onPressed: () => AdminRoute.go('domains'),
              child: const LocalizedText('Cancel'),
            ),
            const SizedBox(width: 8),
            FilledButton(
              onPressed: _mutating ? null : _create,
              child: const LocalizedText('Add domain'),
            ),
          ]),
        ]),
      ),
    ),
  );
}
