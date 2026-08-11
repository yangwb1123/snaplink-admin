import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'admin_route.dart';

/// Permission roles/assignments for a specific client.
/// URL: /admin/permissions/{clientId}[/roles|assignments]
class PermissionDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SSOAdminClient client;
  final String clientId;

  const PermissionDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.clientId,
  });

  @override
  State<PermissionDetailScreen> createState() => _PermissionDetailScreenState();
}

class _PermissionDetailScreenState extends State<PermissionDetailScreen> {
  Map<String, dynamic>? _roles;
  Map<String, dynamic>? _assignments;
  String? _error;
  bool _loading = true;
  int _tabIndex = 0;
  late final void Function() _cancelPopState;

  static const _tabs = [
    ('roles', 'Roles', Icons.shield),
    ('assignments', 'Assignments', Icons.assignment),
  ];

  @override
  void initState() {
    super.initState();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(_onPopState);
    _handleRoute();
    _load();
    final route = AdminRoute.current();
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].$1 == route.subresource) {
        _tabIndex = i;
        break;
      }
    }
  }

  @override
  void dispose() {
    _cancelPopState();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cid = Uri.encodeComponent(widget.clientId);
      final results = await Future.wait([
        widget.api.get('/api/v1/admin/permissions/$cid/roles'),
        widget.api.get('/api/v1/admin/permissions/$cid/assignments'),
      ]);
      if (!mounted) return;
      setState(() {
        _roles = results[0] as Map<String, dynamic>?;
        _assignments = results[1] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  void _selectTab(int index, String subresource) {
    setState(() => _tabIndex = index);
    AdminRoute.go(
      'permissions',
      resourceId: widget.clientId,
      subresource: subresource,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: LocalizedText('Permissions: {widget_clientId}', args: {'widget_clientId': widget.clientId}),
      leading: IconButton(
        tooltip: 'Back'.localized,
          icon: const Icon(Icons.arrow_back),
        onPressed: () => AdminRoute.go('permissions'),
      ),
    ),
    body: _loading
        ? const SkeletonListTile(itemCount: 6)
        : _error != null
        ? Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: AppColors.danger,
                ),
                const SizedBox(height: 16),
                LocalizedText(
                  'Failed to load',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const LocalizedText('Retry'),
                ),
              ],
            ),
          )
        : Column(
            children: [
              AdminBreadcrumb(),
              SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _tabChips(),
                ),
              ),
              Expanded(child: _tabContent(context)),
            ],
          ),
  );

  List<Widget> _tabChips() => [
    for (var i = 0; i < _tabs.length; i++)
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          label: LocalizedText(_tabs[i].$2),
          selected: _tabIndex == i,
          onSelected: (_) => _selectTab(i, _tabs[i].$1),
        ),
      ),
  ];

  Widget _tabContent(BuildContext context) {
    if (_tabIndex == 0) return _rolesList(context);
    return _assignmentList(context);
  }

  Widget _rolesList(BuildContext context) {
    final items = _roles?.values.first as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
          ? [const EmptyState(compact: true, title: 'No roles defined')]
          : items.map((r) => _roleCard(r)).toList(),
    );
  }

  Widget _roleCard(Map<String, dynamic> r) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: const Icon(Icons.shield),
        title: Text(
          r['code']?.toString() ?? r['name']?.toString() ?? '',
        ),
        subtitle: Text(r['description']?.toString() ?? ''),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (r['permissions'] != null)
              Chip(
                label: Text(
                  '${(r['permissions'] as List?)?.length ?? 0} perms',
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _assignmentList(BuildContext context) {
    final items = _assignments?.values.first as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
          ? [const EmptyState(compact: true, title: 'No assignments')]
          : items
                .map(
                  (a) => Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      leading: const Icon(Icons.assignment_ind),
                      title: Text(a['role']?.toString() ?? ''),
                      subtitle: LocalizedText(
                        'Subject: {subject}',
                        args: {
                          'subject':
                              a['subject'] ??
                              a['user_id'] ??
                              a['group_id'] ??
                              '',
                        },
                      ),
                    ),
                  ),
                )
                .toList(),
    );
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'permissions') return;
  }

  void _onPopState() {
    if (mounted) _handleRoute();
  }
}
