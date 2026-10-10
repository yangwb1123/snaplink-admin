import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/admin_paths.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/services/browser_navigation.dart';
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
  int _reqSeq = 0;
  late final void Function() _cancelPopState;

  static const _tabs = [
    ('roles', 'Roles', Icons.shield_outlined),
    ('assignments', 'Assignments', Icons.assignment_outlined),
  ];

  @override
  void initState() {
    super.initState();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (!mounted) return;
      final previous = _tabIndex;
      _handleRoute();
      if (previous != _tabIndex) _load();
    });
    _load();
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'permissions' || route.resourceId != widget.clientId) {
      return;
    }
    setState(() => _tabIndex = route.subresource == 'assignments' ? 1 : 0);
  }

  @override
  void dispose() {
    _cancelPopState();
    super.dispose();
  }

  Future<void> _load() async {
    final seq = ++_reqSeq;
    final roles = _tabIndex == 0;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await widget.api.get(
        roles
            ? AdminPaths.permissionRoles(widget.clientId)
            : AdminPaths.permissionAssignments(widget.clientId),
        forceRefresh: true,
      );
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        if (roles) {
          _roles = result;
        } else {
          _assignments = result;
        }
        _loading = false;
      });
    } catch (e) {
      if (mounted && seq == _reqSeq) {
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
    _load();
  }

  @override
  Widget build(BuildContext context) {
    final accent = adminModuleIconColor('permissions');
    return Scaffold(
      appBar: AppBar(
        title: Semantics(
          container: true,
          header: true,
          child: LocalizedText(
            'Permissions: {widget_clientId}',
            args: {'widget_clientId': widget.clientId},
          ),
        ),
        leading: IconButton(
          tooltip: 'Back'.localized,
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AdminRoute.back('permissions'),
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
    final items = (_roles?['roles'] as List? ?? const []).whereType<Map>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
          ? [const EmptyState(compact: true, title: 'No roles defined')]
          : items
                .map(
                  (r) =>
                      _roleCard(context, Map<String, dynamic>.from(r), accent),
                )
                .toList(),
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
    final items = (_assignments?['assignments'] as List? ?? const [])
        .whereType<Map>();
    return ListView(
      padding: const EdgeInsets.all(16),
      children: items.isEmpty
          ? [const EmptyState(compact: true, title: 'No assignments')]
          : items
                .map(
                  (a) => _assignmentCard(
                    context,
                    Map<String, dynamic>.from(a),
                    accent,
                  ),
                )
                .toList(),
    );
  }

  Widget _assignmentCard(
    BuildContext context,
    Map<String, dynamic> a,
    Color accent,
  ) {
    final roles = a['roles'];
    final role = roles is List
        ? roles.map((value) => value.toString()).join(', ')
        : a['role']?.toString() ?? a['role_id']?.toString() ?? '';
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
            'subject': a['subject'] ?? a['user_id'] ?? a['group_id'] ?? '',
          },
        ),
      ),
    );
  }
}
