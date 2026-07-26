import 'dart:convert';
import 'dart:js_interop';
import 'package:flutter/material.dart';
import 'package:web/web.dart' as web;
import 'admin_route.dart';
import 'permissions_role_dialog.dart';
import 'permissions_cards.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

/// Client-scoped role definitions, subject assignments, and navigation trees.
/// URL: /admin/permissions/{clientId}[/roles|assignments]
class PermissionsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;
  const PermissionsTab({super.key, required this.api, required this.capabilities});
  @override
  State<PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<PermissionsTab> {
  static const _basePath = '/api/v1/admin/permissions/:client_id';
  static const _rolesPath = '$_basePath/roles';
  static const _rolePath = '$_rolesPath/:role_code';
  static const _assignmentsPath = '$_basePath/assignments';
  static const _unassignPath = '$_assignmentsPath/:user_id/unassign';
  static const _menusPath = '$_basePath/menus';
  static const _policyBundlePath = '/api/v1/admin/authz/policy-bundle';

  final _clientCtrl = TextEditingController();
  final _userCtrl = TextEditingController();
  final _roleCodesCtrl = TextEditingController();
  final _menusCtrl = TextEditingController(text: '[]');

  List<Map<String, dynamic>> _roles = const [];
  List<Map<String, dynamic>> _assignments = const [];
  String? _error;
  bool _loading = false;
  bool _mutating = false;
  String _currentSection = 'all';

  bool get _hasPermissionProvider => widget.capabilities.has('GET', _policyBundlePath);
  bool get _supportsRoles => _hasPermissionProvider || widget.capabilities.hasAnyPathPrefix('$_basePath/roles');
  bool get _supportsAssignments => _hasPermissionProvider || widget.capabilities.hasAnyPathPrefix('$_basePath/assignments');
  bool get _supportsMenus => _hasPermissionProvider || widget.capabilities.has('PUT', _menusPath);
  String? get _clientId => _clientCtrl.text.trim().isEmpty ? null : _clientCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    _handleRoute();
    void p() { if (mounted) _handleRoute(); }
    web.window.addEventListener('popstate', p.toJS);
  }

  void _handleRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    if (route.module != 'permissions') return;
    if (route.resourceId.isNotEmpty && route.resourceId != _clientCtrl.text) {
      _clientCtrl.text = route.resourceId;
    }
    _currentSection = route.subresource.isNotEmpty ? route.subresource : 'all';
    if (_clientId != null) _load();
    if (mounted) setState(() {});
  }

  void _selectSection(String section) {
    setState(() => _currentSection = section);
    final rid = _clientId ?? '';
    if (section == 'all') {
      AdminRoute.go('permissions', resourceId: rid);
    } else {
      AdminRoute.go('permissions', resourceId: rid, subresource: section);
    }
  }

  @override
  void dispose() {
    _clientCtrl.dispose(); _userCtrl.dispose();
    _roleCodesCtrl.dispose(); _menusCtrl.dispose();
    super.dispose();
  }

  String _path(String template, Map<String, String> values) {
    var path = template;
    for (final entry in values.entries) {
      path = path.replaceAll(':${entry.key}', Uri.encodeComponent(entry.value));
    }
    return path;
  }

  List<String> _codes(String text) => text.split(RegExp(r'[,\n]')).map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList();

  List<Map<String, dynamic>> _records(Object? value) {
    if (value is! List) return [];
    return value.whereType<Map>().map((i) => Map<String, dynamic>.from(i)).toList();
  }

  Future<void> _load() async {
    widget.api.skipCache();
    final clientId = _clientId;
    if (clientId == null) { setState(() => _error = 'Enter a client ID first.'); return; }
    setState(() { _loading = true; _error = null; });
    try {
      final jobs = <Future>[];
      if (_supportsRoles) jobs.add(widget.api.get(_path(_rolesPath, {'client_id': clientId})));
      if (_supportsAssignments) jobs.add(widget.api.get(_path(_assignmentsPath, {'client_id': clientId})));
      final results = await Future.wait(jobs);
      var idx = 0;
      final roles = _supportsRoles ? _records(results[idx++]['roles']) : <Map<String, dynamic>>[];
      final assignments = _supportsAssignments ? _records(results[idx]['assignments']) : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() { _roles = roles; _assignments = assignments; });
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() => _error = e.toString()); }
    catch (_) { if (mounted) setState(() => _error = 'Could not load permission data.'); }
    finally { if (mounted) setState(() => _loading = false); }
  }

  Future<void> _editRole([Map<String, dynamic>? existing]) async {
    final role = await showDialog<PermissionsRoleDraft>(context: context, builder: (_) => PermissionsRoleDialog(existing: existing));
    if (role == null || !mounted) return;
    final cid = _clientId;
    if (cid == null) return;
    final editing = existing != null;
    if (!await _confirm(editing ? 'Update role?' : 'Create role?', '${editing ? "Update" : "Add"} role ${role.code} for $cid?')) return;
    await _write(() => editing
        ? widget.api.put(_path(_rolePath, {'client_id': cid, 'role_code': role.code}), role.toJson())
        : widget.api.post(_path(_rolesPath, {'client_id': cid}), role.toJson()),
        editing ? 'Role updated.' : 'Role created.');
  }

  Future<void> _deleteRole(String code) async {
    final cid = _clientId;
    if (cid == null || code.isEmpty) return;
    if (!await _confirm('Delete role?', 'Delete $code from $cid? This cannot be undone.')) return;
    await _write(() => widget.api.delete(_path(_rolePath, {'client_id': cid, 'role_code': code})), 'Role deleted.');
  }

  Future<void> _assign() async {
    final cid = _clientId; final uid = _userCtrl.text.trim();
    if (cid == null || uid.isEmpty) { setState(() => _error = 'Enter a user ID.'); return; }
    final codes = _codes(_roleCodesCtrl.text);
    if (codes.isEmpty) { setState(() => _error = 'Enter at least one role code.'); return; }
    if (!await _confirm('Assign roles?', 'Assign ${codes.join(", ")} to $uid?')) return;
    await _write(() => widget.api.post(_path(_assignmentsPath, {'client_id': cid}), {'user_id': uid, 'roles': codes}), 'Roles assigned.');
  }

  Future<void> _unassign(String uid) async {
    final cid = _clientId;
    if (cid == null) return;
    if (!await _confirm('Unassign user?', 'Remove all role assignments for $uid?', destructive: true)) return;
    await _write(() => widget.api.post(_path(_unassignPath, {'client_id': cid, 'user_id': uid})), 'User unassigned.');
  }

  Future<void> _saveMenus() async {
    final cid = _clientId;
    if (cid == null) return;
    try {
      final menus = jsonDecode(_menusCtrl.text) as List;
      if (!await _confirm('Save menus?', 'Update navigation tree?')) return;
      await _write(() => widget.api.put(_path(_menusPath, {'client_id': cid}), {'menus': menus}), 'Navigation tree updated.');
    } on FormatException { setState(() => _error = 'Invalid JSON in menus field.'); }
  }

  Future<bool> _confirm(String title, String msg, {bool destructive = false}) async =>
      await ConfirmDialog.show(context, title: title, message: msg, confirmLabel: destructive ? 'Delete' : 'Confirm', destructive: destructive);

  Future<void> _write(Future<void> Function() fn, String okMsg) async {
    setState(() => _mutating = true);
    try {
      await fn();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(okMsg)));
      await _load();
    } on SnaplinkAdminApiError catch (e) { if (mounted) setState(() => _error = e.toString()); }
    finally { if (mounted) setState(() => _mutating = false); }
  }

  // ---- BUILD ----

  @override
  Widget build(BuildContext context) {
    final clientId = _clientId;
    return ListView(padding: const EdgeInsets.all(16), children: [
      AdminBreadcrumb(),
      Text('Permissions', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 8),
      Row(children: [
        SizedBox(width: 300, child: TextField(
          controller: _clientCtrl,
          decoration: const InputDecoration(labelText: 'Client ID', hintText: 'Enter client ID and press Search'),
          onSubmitted: (_) { _handleRoute(); },
        )),
        const SizedBox(width: 8),
        ElevatedButton(onPressed: _loading ? null : _load, child: const Text('Search')),
        if (clientId != null) ...[
          const SizedBox(width: 8),
          Text(clientId, style: Theme.of(context).textTheme.titleMedium),
        ],
      ]),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      if (_loading) const SkeletonListTile(itemCount: 3),
      if (clientId != null) _sectionChips(context),
      if (clientId != null && (_currentSection == 'all' || _currentSection == 'roles') && _supportsRoles) ...[
        const SizedBox(height: 12),
        _roleSection(context),
      ],
      if (clientId != null && (_currentSection == 'all' || _currentSection == 'assignments') && _supportsAssignments) ...[
        const SizedBox(height: 12),
        _assignmentSection(context),
      ],
      if (clientId != null && (_currentSection == 'all' || _currentSection == 'menus') && _supportsMenus) ...[
        const SizedBox(height: 12),
        _menuSection(context),
      ],
    ]);
  }

  Widget _sectionChips(BuildContext context) => SizedBox(
    height: 36,
    child: ListView(scrollDirection: Axis.horizontal, children: [
      for (final s in [('all', 'All'), ('roles', 'Roles'), ('assignments', 'Assignments'), ('menus', 'Menus')])
        Padding(padding: const EdgeInsets.only(right: 6), child: ChoiceChip(
          label: Text(s.$2), selected: _currentSection == s.$1,
          onSelected: (_) => _selectSection(s.$1),
        )),
    ]),
  );

  Widget _roleSection(BuildContext context) => RolesCard(
    roles: _roles.map((r) => Map<String, dynamic>.from(r)).toList(),
    mutating: _mutating, clientId: _clientId,
    onCreateRole: () => _editRole(),
    onEditRole: (r) => _editRole(r),
    onDeleteRole: (c) => _deleteRole(c),
  );

  Widget _assignmentSection(BuildContext context) => AssignmentsCard(
    assignments: _assignments.map((a) => Map<String, dynamic>.from(a)).toList(),
    mutating: _mutating, clientId: _clientId,
    userController: _userCtrl, roleCodesController: _roleCodesCtrl,
    onAssignRoles: _assign,
    onUnassignRole: (uid, code) => _unassign(uid),
  );

  Widget _menuSection(BuildContext context) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text('Navigation tree (JSON)', style: Theme.of(context).textTheme.titleMedium),
    const SizedBox(height: 8),
    TextField(controller: _menusCtrl, decoration: const InputDecoration(border: OutlineInputBorder()), maxLines: 6, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
    const SizedBox(height: 10),
    FilledButton(onPressed: _mutating ? null : _saveMenus, child: const Text('Save menus')),
  ])));
}
