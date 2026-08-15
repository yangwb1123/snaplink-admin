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
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
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

  /// 模块强调色（security 组 rose）：页内图标统一按组色上色。
  Color get _accent => adminModuleIconColor('domains');

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
    _cancelPopState();
    _sub.cancel();
    _hostCtrl.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    setState(() => _showForm = route.isNew);
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await widget.api.getStaleWhileRevalidate(
        _path,
        onRefresh: _applyRefresh,
      );
      if (!mounted) return;
      setState(() {
        _applyDomains(data);
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

  /// 缓存先渲染：命中时立即展示缓存行，后台刷新到位后再次渲染（R2）。
  void _applyDomains(Map<String, dynamic> data) {
    final items = data['domains'] as List? ?? [];
    _domains = items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
    _filterDomains();
  }

  void _applyRefresh(Map<String, dynamic> fresh) {
    if (!mounted) return;
    setState(() => _applyDomains(fresh));
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

  /// 空态“清除筛选”：清空搜索框后重载（过滤无结果场景）。
  void _clearSearch() {
    _searchCtrl.clear();
    _onSearchChanged('');
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
        const AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).domains,
          subtitle: 'Manage email domains for home-realm discovery.',
          createTooltip: 'Add domain',
          onCreate: _showForm
              ? null
              : () => AdminRoute.go('domains', action: 'new'),
          onRefresh: _load,
        ),
        if (_error != null) ...[
          ErrorStateCard(message: _error!, onRetry: _load, margin: EdgeInsets.zero),
          const SizedBox(height: 12),
        ],
        if (_showForm) _buildForm(context),
        if (_domains.isNotEmpty) ...[
          const SizedBox(height: 8),
          SectionHeader(
            'Registered domains',
            count: _filteredDomains.length,
            action: IconButton(
              icon: Icon(Icons.download, color: _accent),
              tooltip: 'Export CSV'.localized,
              onPressed: () =>
                  ExportService.exportCsv(_filteredDomains, 'domains.csv'),
            ),
          ),
          const SizedBox(height: 8),
          SearchFilterBar(
            hintText: 'Search domains...'.localized,
            controller: _searchCtrl,
            onSearchChanged: _onSearchChanged,
            onRefresh: _load,
          ),
        ],
        const SizedBox(height: 12),
        if (_loading)
          const SkeletonListTile(itemCount: 3)
        else if (_filteredDomains.isEmpty && !_showForm)
          EmptyState(
            variant: _searchQuery.isEmpty
                ? EmptyStateVariant.empty
                : EmptyStateVariant.noMatch,
            title: _searchQuery.isEmpty ? 'No domains registered.' : null,
            actionLabel: _searchQuery.isEmpty ? null : 'Clear filter',
            actionIcon: Icons.filter_alt_off,
            onAction: _searchQuery.isEmpty ? null : _clearSearch,
          )
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
    );
  }

  /// 域名表格：四列（hostname/id/状态/删除）。
  Widget _buildTable(BuildContext context) {
    return AdminDataTable(
      minWidth: 720,
      density: TableDensity.compact,
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
                ? StatusChip.active(label: context.tr('Verified'))
                : StatusChip.pending(label: context.tr('Pending'));
          },
        ),
        AdminDataColumn(
          id: 'actions',
          label: '',
          width: 110,
          builder: (_, i) {
            final hostname = _filteredDomains[i]['hostname']?.toString() ?? '';
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
    );
  }

  Widget _buildForm(BuildContext context) => Card(
    margin: const EdgeInsets.only(top: 8),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.language, size: 20, color: _accent),
              const SizedBox(width: 8),
              LocalizedText(
                'Add domain',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
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

