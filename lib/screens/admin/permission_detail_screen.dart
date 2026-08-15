import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'admin_module_groups.dart';
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

  static const _tabs = [
    ('roles', 'Roles', Icons.shield_outlined),
    ('assignments', 'Assignments', Icons.assignment_outlined),
  ];

  @override
  void initState() {
    super.initState();
    final route = AdminRoute.current();
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].$1 == route.subresource) {
        _tabIndex = i;
        break;
      }
    }
    _load();
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
  Widget build(BuildContext context) {
    final accent = adminModuleIconColor('permissions');
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          container: true,
          header: true,
          child: LocalizedText('Permissions: {widget_clientId}', args: {
            'widget_clientId': widget.clientId,
          }),
        ),
        leading: IconButton(
          tooltip: 'Back'.localized,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AdminRoute.go('permissions'),
        ),
      ),
      body: _loading
          ? const SkeletonListTile(itemCount: 6)
          : _error != null
          ? ErrorStateView(message: _error!, onRetry: _load)
          : Column(
              children: [
                AdminBreadcrumb(),
                SizedBox(
                  height: 48,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _tabChips(accent),
                  ),
                ),
                Expanded(child: _tabContent(context, accent)),
              ],
            ),
    );
  }

  List<Widget> _tabChips(Color accent) => [
    for (var i = 0; i < _tabs.length; i++)
      Padding(
        padding: const EdgeInsets.only(right: 8),
        child: ChoiceChip(
          avatar: Icon(_tabs[i].$3, size: 16, color: accent),
          label: LocalizedText(_tabs[i].$2),
          selected: _tabIndex == i,
          onSelected: (_) => _selectTab(i, _tabs[i].$1),
        ),
      ),
  ];

  Widget _tabContent(BuildContext context, Color accent) {
    if (_tabIndex == 0) return _rolesList(context, accent);
    return _assignmentList(context, accent);
  }

  Widget _rolesList(BuildContext context, Color accent) {
    final items = _roles?.values.first as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
          ? [const EmptyState(compact: true, title: 'No roles defined')]
          : items.map((r) => _roleCard(context, r, accent)).toList(),
    );
  }

  Widget _roleCard(BuildContext context, Map<String, dynamic> r, Color accent) {
    final code = r['code']?.toString() ?? r['name']?.toString() ?? '';
    final count = (r['permissions'] as List?)?.length ?? 0;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.shield_outlined, size: 20, color: accent),
        ),
        title: Text(code),
        subtitle: r['description']?.toString().isNotEmpty == true
            ? Text(r['description'].toString())
            : null,
        trailing: Chip(
          avatar: Icon(Icons.key_outlined, size: 14, color: accent),
          label: LocalizedText('{n} permissions', args: {'n': count}),
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  Widget _assignmentList(BuildContext context, Color accent) {
    final items = _assignments?.values.first as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
          ? [const EmptyState(compact: true, title: 'No assignments')]
          : items.map((a) => _assignmentCard(context, a, accent)).toList(),
    );
  }

  Widget _assignmentCard(
    BuildContext context,
    Map<String, dynamic> a,
    Color accent,
  ) {
    final role = a['role']?.toString() ?? a['role_id']?.toString() ?? '';
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: Theme.of(context).colorScheme.primaryContainer,
          child: Icon(Icons.assignment_outlined, size: 20, color: accent),
        ),
        title: Text(role),
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
    );
  }
}
