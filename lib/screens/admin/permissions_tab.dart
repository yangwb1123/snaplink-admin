import 'dart:convert';

import 'package:flutter/material.dart';

import 'permissions_role_dialog.dart';
import 'snaplink_admin_api.dart';

/// Client-scoped role definitions, subject assignments, and navigation trees.
///
/// Snaplink keeps these concerns in one permission provider; all mutations are
/// confirmed because removing a role also changes every affected assignment.
class PermissionsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const PermissionsTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<PermissionsTab> createState() => _PermissionsTabState();
}

class _PermissionsTabState extends State<PermissionsTab> {
  static const _basePath = '/api/v1/admin/permissions/:client_id';
  static const _rolesPath = '$_basePath/roles';
  static const _rolePath = '$_rolesPath/:role_code';
  static const _assignmentsPath = '$_basePath/assignments';
  static const _assignmentPath = '$_assignmentsPath/:user_id';
  static const _unassignPath = '$_assignmentPath/unassign';
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

  // The gateway CRUD routes are not part of the runtime inventory. A policy
  // bundle proves the same permission provider is wired; each write remains
  // subject to the server's method-level authorization and feature checks.
  bool get _hasPermissionProvider =>
      widget.capabilities.has('GET', _policyBundlePath);
  bool get _supportsRoles =>
      _hasPermissionProvider ||
      widget.capabilities.hasAnyPathPrefix('$_basePath/roles');
  bool get _supportsAssignments =>
      _hasPermissionProvider ||
      widget.capabilities.hasAnyPathPrefix('$_basePath/assignments');
  bool get _supportsMenus =>
      _hasPermissionProvider || widget.capabilities.has('PUT', _menusPath);
  String? get _clientId => _value(_clientCtrl);

  @override
  void dispose() {
    _clientCtrl.dispose();
    _userCtrl.dispose();
    _roleCodesCtrl.dispose();
    _menusCtrl.dispose();
    super.dispose();
  }

  String? _value(TextEditingController controller) {
    final value = controller.text.trim();
    return value.isEmpty ? null : value;
  }

  String _path(String template, Map<String, String> values) {
    var path = template;
    for (final entry in values.entries) {
      path = path.replaceAll(':${entry.key}', Uri.encodeComponent(entry.value));
    }
    return path;
  }

  List<String> _codes(String text) => text
      .split(RegExp(r'[,\n]'))
      .map((value) => value.trim())
      .where((value) => value.isNotEmpty)
      .toSet()
      .toList(growable: false);

  List<Map<String, dynamic>> _records(Object? value) {
    if (value is! List) return const [];
    return value
        .whereType<Map>()
        .map((item) => Map<String, dynamic>.from(item))
        .toList(growable: false);
  }

  Future<void> _load() async {
    final clientId = _clientId;
    if (clientId == null) {
      setState(() => _error = 'Enter a client ID first.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final jobs = <Future<Map<String, dynamic>>>[];
      if (_supportsRoles) {
        jobs.add(widget.api.get(_path(_rolesPath, {'client_id': clientId})));
      }
      if (_supportsAssignments) {
        jobs.add(
          widget.api.get(_path(_assignmentsPath, {'client_id': clientId})),
        );
      }
      final results = await Future.wait(jobs);
      var index = 0;
      final roles = _supportsRoles
          ? _records(results[index++]['roles'])
          : const <Map<String, dynamic>>[];
      final assignments = _supportsAssignments
          ? _records(results[index]['assignments'])
          : const <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() {
        _roles = roles;
        _assignments = assignments;
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load permission data.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _editRole([Map<String, dynamic>? existing]) async {
    final role = await showDialog<PermissionsRoleDraft>(
      context: context,
      builder: (_) => PermissionsRoleDialog(existing: existing),
    );
    if (role == null || !mounted) return;
    final clientId = _clientId;
    if (clientId == null) return;
    final isEditing = existing != null;
    final action = isEditing ? 'Update role?' : 'Create role?';
    if (!await _confirm(
      action,
      '${isEditing ? 'Update' : 'Add'} role ${role.code} for $clientId?',
    )) {
      return;
    }
    await _write(
      () => isEditing
          ? widget.api.put(
              _path(_rolePath, {'client_id': clientId, 'role_code': role.code}),
              role.toJson(),
            )
          : widget.api.post(
              _path(_rolesPath, {'client_id': clientId}),
              role.toJson(),
            ),
      isEditing ? 'Role updated.' : 'Role created.',
    );
  }

  Future<void> _deleteRole(String code) async {
    final clientId = _clientId;
    if (clientId == null || code.isEmpty) return;
    if (!await _confirm(
      'Delete role?',
      'Delete $code? Snaplink will also remove it from every user assignment.',
    )) {
      return;
    }
    await _write(
      () => widget.api.delete(
        _path(_rolePath, {'client_id': clientId, 'role_code': code}),
      ),
      'Role deleted.',
    );
  }

  Future<void> _assignRoles() async {
    final clientId = _clientId;
    final userId = _value(_userCtrl);
    final roles = _codes(_roleCodesCtrl.text);
    if (clientId == null || userId == null || roles.isEmpty) {
      setState(
        () =>
            _error = 'Client ID, user ID, and at least one role are required.',
      );
      return;
    }
    if (!await _confirm(
      'Assign roles?',
      'Assign ${roles.join(', ')} to $userId?',
    )) {
      return;
    }
    await _write(
      () => widget.api.post(
        _path(_assignmentPath, {'client_id': clientId, 'user_id': userId}),
        {'roles': roles},
      ),
      'Roles assigned.',
      clear: [_userCtrl, _roleCodesCtrl],
    );
  }

  Future<void> _unassignRole(String userId, String code) async {
    final clientId = _clientId;
    if (clientId == null || userId.isEmpty || code.isEmpty) return;
    if (!await _confirm('Unassign role?', 'Remove $code from $userId?')) return;
    await _write(
      () => widget.api.post(
        _path(_unassignPath, {'client_id': clientId, 'user_id': userId}),
        {
          'roles': [code],
        },
      ),
      'Role unassigned.',
    );
  }

  Future<void> _setMenus() async {
    final clientId = _clientId;
    if (clientId == null) {
      setState(() => _error = 'Enter a client ID first.');
      return;
    }
    Object? menus;
    try {
      menus = jsonDecode(_menusCtrl.text);
    } on FormatException {
      setState(() => _error = 'Menu JSON is not valid.');
      return;
    }
    if (menus is! List) {
      setState(() => _error = 'Menu JSON must be an array of menu items.');
      return;
    }
    if (!await _confirm(
      'Replace menu tree?',
      'This replaces the complete navigation tree for $clientId.',
    )) {
      return;
    }
    await _write(
      () => widget.api.put(_path(_menusPath, {'client_id': clientId}), {
        'menus': menus,
      }),
      'Menu tree updated.',
    );
  }

  Future<void> _write(
    Future<Map<String, dynamic>> Function() request,
    String success, {
    List<TextEditingController> clear = const [],
  }) async {
    setState(() {
      _mutating = true;
      _error = null;
    });
    try {
      await request();
      for (final controller in clear) {
        controller.clear();
      }
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not update permission data.');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<bool> _confirm(String title, String message) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.red),
              child: const Text('Confirm'),
            ),
          ],
        ),
      ) ??
      false;

  @override
  Widget build(BuildContext context) {
    if (!_supportsRoles && !_supportsAssignments && !_supportsMenus) {
      return const Center(
        child: Text(
          'Permission management is not enabled on this Snaplink replica.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Row(
          children: [
            Text(
              'Permissions',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const Spacer(),
            IconButton(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
        const SizedBox(height: 12),
        TextField(
          controller: _clientCtrl,
          decoration: const InputDecoration(
            labelText: 'Client ID',
            hintText: 'console',
          ),
          onSubmitted: (_) => _load(),
        ),
        const SizedBox(height: 10),
        FilledButton(
          onPressed: _loading ? null : _load,
          child: const Text('Load permissions'),
        ),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _error!,
              style: const TextStyle(color: Colors.redAccent),
            ),
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 24),
            child: Center(child: CircularProgressIndicator()),
          ),
        if (_supportsRoles) _rolesCard(context),
        if (_supportsAssignments) _assignmentsCard(context),
        if (_supportsMenus) _menusCard(context),
      ],
    );
  }

  Widget _rolesCard(BuildContext context) => _card(context, 'Roles', [
    Align(
      alignment: Alignment.centerRight,
      child: FilledButton.icon(
        onPressed: _mutating || _clientId == null ? null : () => _editRole(),
        icon: const Icon(Icons.add),
        label: const Text('Create role'),
      ),
    ),
    if (_roles.isEmpty) const Text('No roles loaded.'),
    for (final role in _roles)
      ListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(role['name']?.toString() ?? role['code']?.toString() ?? ''),
        subtitle: Text(
          '${role['code'] ?? ''}\n${_asStrings(role['permissions']).join(', ')}',
        ),
        isThreeLine: role['description']?.toString().isNotEmpty == true,
        trailing: Wrap(
          children: [
            IconButton(
              tooltip: 'Edit role',
              onPressed: _mutating ? null : () => _editRole(role),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: 'Delete role',
              onPressed: _mutating
                  ? null
                  : () => _deleteRole(role['code']?.toString() ?? ''),
              color: Colors.redAccent,
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
  ]);

  Widget _assignmentsCard(
    BuildContext context,
  ) => _card(context, 'User role assignments', [
    TextField(
      controller: _userCtrl,
      decoration: const InputDecoration(labelText: 'User ID'),
    ),
    const SizedBox(height: 10),
    TextField(
      controller: _roleCodesCtrl,
      decoration: const InputDecoration(
        labelText: 'Role codes',
        helperText:
            'Comma or line separated. Snaplink validates that each role exists.',
      ),
      minLines: 1,
      maxLines: 3,
    ),
    const SizedBox(height: 10),
    FilledButton(
      onPressed: _mutating || _clientId == null ? null : _assignRoles,
      child: const Text('Assign roles'),
    ),
    if (_assignments.isEmpty)
      const Padding(
        padding: EdgeInsets.only(top: 12),
        child: Text('No assignments loaded.'),
      ),
    for (final assignment in _assignments) _assignmentRow(assignment),
  ]);

  Widget _assignmentRow(Map<String, dynamic> assignment) {
    final userId = assignment['user_id']?.toString() ?? '';
    final roles = _asStrings(assignment['roles']);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(userId),
      subtitle: Wrap(
        spacing: 6,
        children: [
          for (final code in roles)
            InputChip(
              label: Text(code),
              onDeleted: _mutating ? null : () => _unassignRole(userId, code),
            ),
        ],
      ),
    );
  }

  Widget _menusCard(BuildContext context) => _card(context, 'Menu tree JSON', [
    const Text(
      'Provide an array of menu items. Each item needs id and name; children and buttons are nested arrays.',
    ),
    const SizedBox(height: 10),
    TextField(
      controller: _menusCtrl,
      decoration: const InputDecoration(labelText: 'Menu tree'),
      minLines: 8,
      maxLines: 16,
      style: const TextStyle(fontFamily: 'monospace'),
    ),
    const SizedBox(height: 10),
    FilledButton(
      onPressed: _mutating || _clientId == null ? null : _setMenus,
      child: const Text('Replace menu tree'),
    ),
  ]);

  List<String> _asStrings(Object? value) => value is List
      ? value.map((item) => item.toString()).toList(growable: false)
      : const [];

  Widget _card(BuildContext context, String title, List<Widget> children) =>
      Card(
        margin: const EdgeInsets.only(top: 20),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 10),
              ...children,
            ],
          ),
        ),
      );
}
