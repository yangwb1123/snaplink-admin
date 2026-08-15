import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/section_selector.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'permissions_role_dialog.dart';
import 'permissions_cards.dart';
import 'permissions_workspace_widgets.dart';

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
  late final void Function() _cancelPopState;

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
  String? get _clientId =>
      _clientCtrl.text.trim().isEmpty ? null : _clientCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    _handleRoute();
    if (_clientId != null) _load();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'permissions') return;
    if (route.resourceId.isNotEmpty && route.resourceId != _clientCtrl.text) _clientCtrl.text = route.resourceId;
    _currentSection = route.subresource.isNotEmpty ? route.subresource : 'all';
    if (_clientId != null) _load();
    if (mounted) setState(() {});
  }

  void _selectSection(String section) {
    setState(() => _currentSection = section);
    AdminRoute.go('permissions', resourceId: _clientId ?? '', subresource: section == 'all' ? '' : section);
  }

  @override
  void dispose() {
    _cancelPopState();
    _clientCtrl.dispose();
    _userCtrl.dispose();
    _roleCodesCtrl.dispose();
    _menusCtrl.dispose();
    super.dispose();
  }

  String _path(String template, Map<String, String> values) {
    var path = template;
    for (final entry in values.entries) {
      path = path.replaceAll(':${entry.key}', Uri.encodeComponent(entry.value));
    }
    return path;
  }

  List<String> _codes(String text) =>
      text.split(RegExp(r'[,\n]')).map((v) => v.trim()).where((v) => v.isNotEmpty).toSet().toList();

  List<Map<String, dynamic>> _records(Object? value) => value is! List
      ? const []
      : value.whereType<Map>().map((i) => Map<String, dynamic>.from(i)).toList();

  Future<void> _load() async {
    widget.api.skipCache();
    final clientId = _clientId;
    if (clientId == null) {
      setState(() => _error = 'Enter a client ID first.');
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      final jobs = <Future>[
        if (_supportsRoles)
          widget.api.get(_path(_rolesPath, {'client_id': clientId})),
        if (_supportsAssignments)
          widget.api.get(_path(_assignmentsPath, {'client_id': clientId})),
      ];
      final results = await Future.wait(jobs);
      var idx = 0;
      final roles = _supportsRoles
          ? _records(results[idx++]['roles'])
          : <Map<String, dynamic>>[];
      final assignments = _supportsAssignments
          ? _records(results[idx]['assignments'])
          : <Map<String, dynamic>>[];
      if (!mounted) return;
      setState(() { _roles = roles; _assignments = assignments; });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
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
    final cid = _clientId;
    if (cid == null) return;
    final editing = existing != null;
    if (!await _confirm(
      context.tr(editing ? 'Update role?' : 'Create role?'),
      context.tr(
        editing ? 'Update role {code} for {client}?' : 'Create role {code} for {client}?',
        {'code': role.code, 'client': cid},
      ),
      confirmLabel: editing ? 'Update' : 'Create',
    )) {
      return;
    }
    await _write(
      () => editing
          ? widget.api.put(_path(_rolePath, {'client_id': cid, 'role_code': role.code}), role.toJson())
          : widget.api.post(_path(_rolesPath, {'client_id': cid}), role.toJson()),
      editing ? 'Role updated.' : 'Role created.',
    );
  }

  Future<void> _deleteRole(String code) async {
    final cid = _clientId;
    if (cid == null || code.isEmpty) return;
    if (!await _confirm(
      context.tr('Delete role?'),
      context.tr('Delete {code} from {client}? This cannot be undone.', {'code': code, 'client': cid}),
      confirmLabel: 'Delete',
      destructive: true,
      confirmText: code,
    )) {
      return;
    }
    await _write(
      () => widget.api.delete(_path(_rolePath, {'client_id': cid, 'role_code': code})),
      'Role deleted.',
    );
  }

  Future<void> _assign() async {
    final cid = _clientId;
    final uid = _userCtrl.text.trim();
    if (cid == null || uid.isEmpty) {
      setState(() => _error = 'Enter a user ID.');
      return;
    }
    final codes = _codes(_roleCodesCtrl.text);
    if (codes.isEmpty) {
      setState(() => _error = 'Enter at least one role code.');
      return;
    }
    if (!await _confirm(
      context.tr('Assign roles?'),
      context.tr('Assign {roles} to {user}?', {'roles': codes.join(', '), 'user': uid}),
      confirmLabel: 'Assign',
    )) {
      return;
    }
    await _write(
      () => widget.api.post(
        _path('$_assignmentsPath/:user_id', {'client_id': cid, 'user_id': uid}),
        {'roles': codes},
      ),
      'Roles assigned.',
    );
  }

  Future<void> _unassign(String uid) async {
    final cid = _clientId;
    if (cid == null) return;
    if (!await _confirm(
      context.tr('Unassign user?'),
      context.tr('Remove all role assignments for {user}?', {'user': uid}),
      confirmLabel: 'Unassign',
      destructive: true,
      confirmText: uid,
    )) {
      return;
    }
    await _write(
      () => widget.api.post(_path(_unassignPath, {'client_id': cid, 'user_id': uid})),
      'User unassigned.',
    );
  }

  Future<void> _saveMenus() async {
    final cid = _clientId;
    if (cid == null) return;
    try {
      final menus = jsonDecode(_menusCtrl.text) as List;
      if (!await _confirm(
        context.tr('Save menus?'),
        context.tr('Update navigation tree?'),
        confirmLabel: 'Save',
      )) {
        return;
      }
      await _write(
        () => widget.api.put(_path(_menusPath, {'client_id': cid}), {'menus': menus}),
        'Navigation tree updated.',
      );
    } on FormatException {
      if (mounted) setState(() => _error = 'Invalid JSON in menus field.');
    }
  }

  Future<bool> _confirm(
    String title,
    String msg, {
    String confirmLabel = 'Confirm',
    bool destructive = false,
    String? confirmText,
  }) async => await ConfirmDialog.show(
    context,
    title: title,
    message: msg,
    confirmLabel: confirmLabel,
    destructive: destructive,
    confirmText: confirmText,
  );

  Future<void> _write(Future<void> Function() fn, String okMsg) async {
    setState(() => _mutating = true);
    try {
      await fn();
      if (!mounted) return;
      showAppSnackBar(context, content: LocalizedText(okMsg));
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  // ---- BUILD ----

  @override
  Widget build(BuildContext context) {
    final clientId = _clientId;
    final accent = adminModuleIconColor('permissions');
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        const SizedBox(height: 4),
        Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(Icons.admin_panel_settings_outlined, color: accent),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(container: true, header: true, child: Text(AppStrings.of(context).permissions, style: Theme.of(context).textTheme.headlineSmall)),
                  const SizedBox(height: 4),
                  LocalizedText(
                    'Client-scoped roles, assignments and navigation menus.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
                  ),
                ],
              ),
            ),
            IconButton(onPressed: _clientId == null || _loading ? null : _load, icon: Icon(Icons.refresh, color: accent), tooltip: context.strings.refresh),
          ],
        ),
        const SizedBox(height: 16),
        PermissionsClientSelector(
          controller: _clientCtrl,
          clientId: clientId,
          loading: _loading,
          onSearch: _load,
          onSubmitted: _handleRoute,
        ),
        if (_error != null) ...[const SizedBox(height: 8), _errorBanner(context)],
        if (clientId != null) ...[
          const SizedBox(height: 12),
          SectionSelector(
            current: _currentSection,
            onSelected: _selectSection,
            sections: [
              SectionDef('all', 'All', Icons.view_quilt_outlined, color: accent),
              SectionDef('roles', 'Roles', Icons.shield_outlined, color: accent),
              SectionDef('assignments', 'Assignments', Icons.assignment_outlined, color: accent),
              SectionDef('menus', 'Menus', Icons.account_tree_outlined, color: accent),
            ],
          ),
        ],
        if (clientId != null && _loading) ...[
          const SizedBox(height: 12),
          const SkeletonListTile(itemCount: 3),
        ],
        if (clientId != null && !_loading) ...[
          if ((_currentSection == 'all' || _currentSection == 'roles') && _supportsRoles) ...[
            const SizedBox(height: 12),
            _roleSection(context),
          ],
          if ((_currentSection == 'all' || _currentSection == 'assignments') && _supportsAssignments) ...[
            const SizedBox(height: 12),
            _assignmentSection(context),
          ],
          if ((_currentSection == 'all' || _currentSection == 'menus') && _supportsMenus) ...[
            const SizedBox(height: 12),
            PermissionMenusCard(
              controller: _menusCtrl,
              mutating: _mutating,
              onSave: _saveMenus,
            ),
          ],
        ],
      ],
    );
  }

  Widget _errorBanner(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    decoration: BoxDecoration(
      color: AppColors.dangerTint.withValues(alpha: 0.3),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        Icon(Icons.error_outline, size: 18, color: AppColors.semanticFor(Theme.of(context).brightness, AppColors.danger)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            context.tr(_error!),
            // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
            style: TextStyle(
              color: AppColors.semanticFor(
                Theme.of(context).brightness,
                AppColors.danger,
              ),
            ),
          ),
        ),        TextButton(
          onPressed: _clientId == null ? null : _load,
          child: const LocalizedText('Retry'),
        ),
      ],
    ),
  );

  Widget _roleSection(BuildContext context) => RolesCard(
    roles: _roles.map((r) => Map<String, dynamic>.from(r)).toList(),
    mutating: _mutating,
    clientId: _clientId,
    onCreateRole: () => _editRole(),
    onEditRole: (r) => _editRole(r),
    onDeleteRole: (c) => _deleteRole(c),
  );

  Widget _assignmentSection(BuildContext context) => AssignmentsCard(
    assignments: _assignments.map((a) => Map<String, dynamic>.from(a)).toList(),
    mutating: _mutating,
    clientId: _clientId,
    userController: _userCtrl,
    roleCodesController: _roleCodesCtrl,
    onAssignRoles: _assign,
    onUnassignRole: (uid, code) => _unassign(uid),
  );
}
