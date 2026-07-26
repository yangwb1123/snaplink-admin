
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
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

  static const _tabs = [
    ('roles', 'Roles', Icons.shield),
    ('assignments', 'Assignments', Icons.assignment),
  ];

  @override
  void initState() {
    super.initState();
    _handleRoute();
    final p = () { if (mounted) _handleRoute(); };
    web.window.addEventListener('popstate', p.toJS);
    _handleRoute();
    _load();
    final route = AdminRoute.fromUri(Uri.base);
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].$1 == route.subresource) {
        _tabIndex = i;
        break;
      }
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
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
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  void _selectTab(int index, String subresource) {
    setState(() => _tabIndex = index);
    AdminRoute.go('permissions', resourceId: widget.clientId, subresource: subresource);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Permissions: ${widget.clientId}'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => AdminRoute.go('permissions'),
      ),
    ),
    body: _loading
      ? const Center(child: CircularProgressIndicator())
      : _error != null
        ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text('Failed to load', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(_error!, textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(children: [
            AdminBreadcrumb(),
            SizedBox(
              height: 48,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  for (var i = 0; i < _tabs.length; i++)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(_tabs[i].$2),
                        selected: _tabIndex == i,
                        onSelected: (_) => _selectTab(i, _tabs[i].$1),
                      ),
                    ),
                ],
              ),
            ),
            Expanded(child: _tabContent(context)),
          ]),
  );

  Widget _tabContent(BuildContext context) {
    if (_tabIndex == 0) return _rolesList(context);
    return _assignmentList(context);
  }

  Widget _rolesList(BuildContext context) {
    final items = _roles?.values.first as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
        ? [const Center(child: Text('No roles defined'))]
        : items.map((r) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.shield),
              title: Text(r['code']?.toString() ?? r['name']?.toString() ?? ''),
              subtitle: Text(r['description']?.toString() ?? ''),
              trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                if (r['permissions'] != null)
                  Chip(label: Text('${(r['permissions'] as List?)?.length ?? 0} perms')),
              ]),
            ),
          )).toList(),
    );
  }

  Widget _assignmentList(BuildContext context) {
    final items = _assignments?.values.first as List? ?? [];
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
        ? [const Center(child: Text('No assignments'))]
        : items.map((a) => Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: const Icon(Icons.assignment_ind),
              title: Text(a['role']?.toString() ?? ''),
              subtitle: Text('Subject: ${a['subject'] ?? a['user_id'] ?? a['group_id'] ?? ''}'),
            ),
          )).toList(),
    );
  }

  void _handleRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    if (route.module != 'permissions') return;
  }
}

