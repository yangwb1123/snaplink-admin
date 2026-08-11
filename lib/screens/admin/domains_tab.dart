import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/search_filter_bar.dart';
import 'package:sso_admin/services/export_service.dart';
import 'package:sso_admin/services/event_bus.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'dart:async';
import 'admin_route.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';

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
  final _hostCtrl = TextEditingController();
  final _searchCtrl = TextEditingController();
  List<Map<String, dynamic>> _domains = const [];
  List<Map<String, dynamic>> _filteredDomains = const [];
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  bool _showForm = false;
  String _searchQuery = '';
  late final void Function() _cancelPopState;

  late final StreamSubscription<DataChangedEvent> _sub;

  bool get _available => widget.capabilities.hasAnyPathPrefix(_path);
  @override
  void dispose() {
    _cancelPopState();
    _sub.cancel();
    _hostCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  void initState() {
    super.initState();
    _load();
    _sub = EventBus().on<DataChangedEvent>().listen((e) {
      if (e.resourceType == 'domains' || e.resourceType == 'domains') {
        _load();
      }
    });
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    setState(() => _showForm = route.isNew);
  }

  Future<void> _load() async {
    widget.api.skipCache();
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.get(_path);
      final items = data['domains'] as List? ?? [];
      if (!mounted) return;
      final domains = items
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList();
      setState(() {
        _domains = domains;
        _filterDomains();
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _error = 'Could not load domains.';
          _loading = false;
        });
      }
    }
  }

  Future<void> _create() async {
    final host = _hostCtrl.text.trim();
    if (host.isEmpty) {
      setState(() => _error = 'Enter a hostname.');
      return;
    }
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await widget.api.post(_path, {'hostname': host});
      if (!mounted) return;
      _hostCtrl.clear();
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: LocalizedText('Domain added.')));
      if (mounted) AdminRoute.go('domains');
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _filterDomains() {
    if (_searchQuery.isEmpty) {
      _filteredDomains = List.from(_domains);
    } else {
      final q = _searchQuery.toLowerCase();
      _filteredDomains = _domains
          .where(
            (d) =>
                (d['hostname']?.toString() ?? '').toLowerCase().contains(q) ||
                (d['id']?.toString() ?? '').toLowerCase().contains(q),
          )
          .toList();
    }
  }

  void _onSearchChanged(String query) {
    setState(() => _searchQuery = query);
    _filterDomains();
  }

  Future<void> _delete(String hostname) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete domain?',
      message: 'Delete $hostname?',
      confirmLabel: 'Delete',
      destructive: true,
      confirmText: hostname,
    );
    if (!confirmed) return;
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await widget.api.delete('$_path/${Uri.encodeComponent(hostname)}');
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: LocalizedText('Domain deleted.')));
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const EmptyState(variant: EmptyStateVariant.notEnabled);
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        AdminBreadcrumb(),
        Text(
          AppStrings.of(context).domains,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        const SizedBox(height: 4),
        const LocalizedText('Manage email domains for home-realm discovery.'),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: AppColors.danger),
                  ),
                ),
                TextButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh, size: 18),
                  label: const LocalizedText('Retry'),
                ),
              ],
            ),
          ),
        if (_showForm) _buildForm(context),
        const SizedBox(height: 16),
        if (_domains.isNotEmpty) ...[
          Row(
            children: [
              LocalizedText(
                'Registered domains',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.download),
                tooltip: 'Export CSV'.localized,
                onPressed: () =>
                    ExportService.exportCsv(_filteredDomains, 'domains.csv'),
              ),
              IconButton(
                onPressed: _loading ? null : _load,
                icon: const Icon(Icons.refresh),
                tooltip: 'Refresh'.localized,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
        if (_loading) const SkeletonListTile(itemCount: 3),
        if (_domains.isNotEmpty)
          SearchFilterBar(
            hintText: 'Search domains...'.localized,
            onSearchChanged: _onSearchChanged,
            onRefresh: _load,
          ),
        const SizedBox(height: 8),
        if (!_loading && _filteredDomains.isEmpty && !_showForm)
          EmptyState(title: 'No domains registered.'),
        if (!_loading && _filteredDomains.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: AdminDataTable(
              minWidth: 720,
              columns: [
                AdminDataColumn(
                  id: 'hostname',
                  label: 'Hostname',
                  width: 260,
                  cardPrimary: true,
                  builder: (_, i) => TableCellText(
                    _filteredDomains[i]['hostname']?.toString() ?? '',
                    level: DataEmphasisLevel.primary,
                  ),
                ),
                AdminDataColumn(
                  id: 'id',
                  label: 'ID',
                  cardDetail: true,
                  builder: (_, i) => TableCellText(
                    _filteredDomains[i]['id']?.toString() ?? '',
                    muted: true,
                  ),
                ),
                AdminDataColumn(
                  id: 'verified',
                  label: 'Status',
                  builder: (_, i) {
                    final verified = _filteredDomains[i]['verified'] == true;
                    return verified
                        ? StatusChip.active(label: 'Verified')
                        : StatusChip.pending(label: 'Pending');
                  },
                ),
                AdminDataColumn(
                  id: 'actions',
                  label: '',
                  width: 110,
                  builder: (_, i) {
                    final hostname =
                        _filteredDomains[i]['hostname']?.toString() ?? '';
                    return TextButton(
                      onPressed: _mutating ? null : () => _delete(hostname),
                      style: TextButton.styleFrom(
                        foregroundColor: AppColors.danger,
                      ),
                      child: const LocalizedText('Delete'),
                    );
                  },
                ),
              ],
              itemCount: _filteredDomains.length,
              rowBuilder: (_, _) => const SizedBox.shrink(),
            ),
          ),
        if (!_showForm)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: OutlinedButton.icon(
              onPressed: () => AdminRoute.go('domains', action: 'new'),
              icon: const Icon(Icons.add),
              label: const LocalizedText('Add domain'),
            ),
          ),
      ],
    );
  }

  Widget _buildForm(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 12),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LocalizedText(
            'Add domain',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _hostCtrl,
            decoration: InputDecoration(
              labelText: 'Hostname'.localized,
              hintText: 'example.com'.localized,
            ),
          ),
          const SizedBox(height: 12),
          OverflowBar(
            children: [
              OutlinedButton(
                onPressed: () => AdminRoute.go('domains'),
                child: const LocalizedText('Cancel'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: _mutating ? null : _create,
                child: const LocalizedText('Add domain'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
