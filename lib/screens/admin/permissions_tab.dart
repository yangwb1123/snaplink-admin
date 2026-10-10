import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/section_selector.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/api/admin_paths.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_module_groups.dart';
import 'admin_route.dart';
import 'permissions_role_dialog.dart';
import 'permissions_cards.dart';
import 'permissions_workspace_widgets.dart';

part 'permissions_tab_view.dart';
part 'permissions_tab_loading.dart';

/// Client-scoped role definitions, subject assignments, and navigation trees.
/// URL: /admin/permissions/{clientId}[/roles|assignments]
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
  static const _basePath = AdminPaths.permissionBaseTemplate;
  static const _rolesPath = AdminPaths.permissionRolesTemplate;
  static const _rolePath = '$_rolesPath/:role_code';
  static const _assignmentsPath = AdminPaths.permissionAssignmentsTemplate;
  static const _unassignPath = '$_assignmentsPath/:user_id/unassign';
  static const _menusPath = '$_basePath/menus';

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
  int _reqSeq = 0;
  String? _inputClient;
  String? _loadedClient;
  final _loadedSources = <String>{};

  // These core RPCs are registered separately from the REST inventory.
  bool _has(String method, String path) =>
      widget.capabilities.has(method, path) ||
      SnaplinkAdminOperationCatalog.endpoints.any(
        (endpoint) =>
            endpoint.method == method &&
            SnaplinkAdminCapabilities([endpoint]).has(method, path),
      );
  bool get _supportsRoles => _has('GET', _rolesPath);
  bool get _supportsAssignments => _has('GET', _assignmentsPath);
  bool get _supportsMenus => _has('PUT', _menusPath);
  void _update(VoidCallback mutation) => setState(mutation);
  String? get _clientId =>
      _clientCtrl.text.trim().isEmpty ? null : _clientCtrl.text.trim();

  @override
  void initState() {
    super.initState();
    _clientCtrl.addListener(_onClientChanged);
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'permissions') return;
    final routeClientId = route.resourceId;
    final clientChanged = routeClientId != _clientCtrl.text;
    final section = route.subresource.isNotEmpty ? route.subresource : 'all';
    final sectionChanged = section != _currentSection;
    if (clientChanged) _clientCtrl.text = routeClientId;
    _currentSection = section;
    if (clientChanged || sectionChanged) {
      if (_clientId != null) {
        _load();
      } else {
        _roles = const [];
        _assignments = const [];
        _error = null;
      }
    }
    if (mounted) setState(() {});
  }

  /// Search and keyboard submit share one action and keep the selected client
  /// in the URL without causing the location listener to load twice.
  void _searchClient() {
    final clientId = _clientId;
    if (clientId == null) {
      _load();
      return;
    }
    final section = _currentSection == 'all' ? '' : _currentSection;
    final route = AdminRoute.current();
    if (route.module != 'permissions' ||
        route.resourceId != clientId ||
        route.subresource != section) {
      BrowserNavigation.replaceState(
        AdminRoute.url(
          'permissions',
          resourceId: clientId,
          subresource: section,
        ),
      );
    }
    _load();
  }

  void _selectSection(String section) {
    AdminRoute.go(
      'permissions',
      resourceId: _clientId ?? '',
      subresource: section == 'all' ? '' : section,
    );
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

  List<String> _codes(String text) => text
      .split(RegExp(r'[,\n]'))
      .map((v) => v.trim())
      .where((v) => v.isNotEmpty)
      .toSet()
      .toList();

  List<Map<String, dynamic>> _records(Object? value) => value is! List
      ? const []
      : value
            .whereType<Map>()
            .map((i) => Map<String, dynamic>.from(i))
            .toList();

  Future<void> _editRole([Map<String, dynamic>? existing]) async {
    final cid = _clientId;
    if (cid == null) return;
    final role = await showDialog<PermissionsRoleDraft>(
      context: context,
      builder: (_) => PermissionsRoleDialog(existing: existing),
    );
    if (role == null || !mounted || cid != _clientId) return;
    final editing = existing != null;
    if (!await _confirm(
      context.tr(editing ? 'Update role?' : 'Create role?'),
      context.tr(
        editing
            ? 'Update role {code} for {client}?'
            : 'Create role {code} for {client}?',
        {'code': role.code, 'client': cid},
      ),
      confirmLabel: editing ? 'Update' : 'Create',
    )) {
      return;
    }
    await _write(
      () => editing
          ? widget.api.put(
              _path(_rolePath, {'client_id': cid, 'role_code': role.code}),
              role.toJson(),
            )
          : widget.api.post(
              _path(_rolesPath, {'client_id': cid}),
              role.toJson(),
            ),
      editing ? 'Role updated.' : 'Role created.',
      clientId: cid,
    );
  }

  Future<void> _deleteRole(String code) async {
    final cid = _clientId;
    if (cid == null || code.isEmpty) return;
    if (!await _confirm(
      context.tr('Delete role?'),
      context.tr('Delete {code} from {client}? This cannot be undone.', {
        'code': code,
        'client': cid,
      }),
      confirmLabel: 'Delete',
      destructive: true,
      confirmText: code,
    )) {
      return;
    }
    await _write(
      () => widget.api.delete(
        _path(_rolePath, {'client_id': cid, 'role_code': code}),
      ),
      'Role deleted.',
      clientId: cid,
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
      context.tr('Assign {roles} to {user}?', {
        'roles': codes.join(', '),
        'user': uid,
      }),
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
      clientId: cid,
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
      () => widget.api.post(
        _path(_unassignPath, {'client_id': cid, 'user_id': uid}),
      ),
      'User unassigned.',
      clientId: cid,
    );
  }

  Future<void> _saveMenus() async {
    final cid = _clientId;
    if (cid == null) return;
    try {
      final decoded = jsonDecode(_menusCtrl.text);
      if (decoded is! List) {
        if (mounted) setState(() => _error = 'Invalid JSON in menus field.');
        return;
      }
      final menus = decoded;
      if (!await _confirm(
        context.tr('Save menus?'),
        context.tr('Update navigation tree?'),
        confirmLabel: 'Save',
      )) {
        return;
      }
      await _write(
        () => widget.api.put(_path(_menusPath, {'client_id': cid}), {
          'menus': menus,
        }),
        'Navigation tree updated.',
        clientId: cid,
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

  Future<void> _write(
    Future<void> Function() fn,
    String okMsg, {
    required String clientId,
  }) async {
    if (!mounted ||
        _mutating ||
        _clientId != clientId ||
        _loadedClient != clientId) {
      return;
    }
    setState(() {
      _mutating = true;
      _error = null;
    });
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

  @override
  Widget build(BuildContext context) => _buildPermissionsTab(context);
}
