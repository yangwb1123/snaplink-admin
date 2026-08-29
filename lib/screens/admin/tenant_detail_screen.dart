import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/admin_paths.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/services/operator_persona.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'admin_route.dart';
import 'tenant_form_dialog.dart';
import 'tenant_branding_tab.dart';
import 'tenant_detail_tabs.dart';
import 'tenant_residency_summary.dart';
import 'usage_analytics_contract.dart';

part 'tenant_detail_view.dart';

/// Tenant detail screen with sub-resource tabs.
/// URL: /admin/tenants/{id}[/{subresource}]
class TenantDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SSOAdminClient client;
  final String tenantId;
  final SnaplinkAdminCapabilities capabilities;

  /// Persona emphasis (derived by the dashboard; default = no emphasis).
  final OperatorPersona persona;

  const TenantDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.tenantId,
    required this.capabilities,
    this.persona = OperatorPersona.general,
  });

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen>
    with _TenantDetailScreenView {
  @override
  Map<String, dynamic>? _tenant;
  @override
  List<dynamic> _members = [];
  @override
  List<dynamic> _invitations = [];
  @override
  Map<String, dynamic>? _usage;
  @override
  final Map<String, String> _sectionErrors = {};
  @override
  String? _error;
  @override
  bool _loading = true;
  @override
  int _tabIndex = 0;
  late final void Function() _cancelPopState;

  static const _tabSpecs = [
    (
      'members',
      'Members',
      Icons.people,
      'GET',
      AdminPaths.tenantMembersTemplate,
    ),
    (
      'invitations',
      'Invitations',
      Icons.mail_outline,
      'GET',
      AdminPaths.tenantInvitationsTemplate,
    ),
    (
      'usage',
      'Usage',
      Icons.bar_chart,
      'GET',
      '/api/v1/admin/tenants/:id/usage',
    ),
    (
      'branding',
      'Branding',
      Icons.palette_outlined,
      'GET',
      AdminPaths.branding,
    ),
  ];

  /// 模块强调色（tenants 组 amber）：AppBar 编辑键与 tab 芯片图标统一按组色上色（X7）。
  @override
  Color get _accent => adminModuleIconColor(AdminModuleId.tenants);

  /// Tabs backed by a runtime-inventory endpoint; while the inventory is
  /// still loading (empty) every tab stays visible.
  @override
  List<(String, String, IconData)> get _tabs =>
      widget.capabilities.endpoints.isEmpty
      ? [for (final s in _tabSpecs) (s.$1, s.$2, s.$3)]
      : [
          for (final s in _tabSpecs)
            if (widget.capabilities.has(s.$4, s.$5)) (s.$1, s.$2, s.$3),
        ];

  @override
  void initState() {
    super.initState();
    _load();
    _initTabFromRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _initTabFromRoute();
    });
  }

  @override
  void dispose() {
    _cancelPopState();
    super.dispose();
  }

  void _initTabFromRoute() {
    final route = AdminRoute.current();
    if (route.resourceId != widget.tenantId) return;
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].$1 == route.subresource) {
        setState(() => _tabIndex = i);
        return;
      }
    }
  }

  @override
  void _selectTab(int index, String subresource) {
    setState(() => _tabIndex = index);
    AdminRoute.go(
      'tenants',
      resourceId: widget.tenantId,
      subresource: subresource,
    );
  }

  @override
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final tenant = await widget.client.getTenant(widget.tenantId);
      // 各 tab 数据端点并行加载（Future.wait，_optionalGet 内部容错）。
      final futures = <String, Future<Map<String, dynamic>>>{};
      for (final tab in _tabs) {
        if (tab.$1 == 'branding') continue; // self-loading tab
        futures[tab.$1] = _optionalGet(tab.$1, _tabPath(tab.$1));
      }
      final results = await Future.wait(futures.values);
      if (!mounted) return;
      final sections = <String, Map<String, dynamic>>{
        for (var i = 0; i < futures.keys.length; i++)
          futures.keys.elementAt(i): results[i],
      };
      setState(() {
        _tenant = tenant;
        _members = _firstList(sections['members'] ?? const {});
        _invitations = _firstList(sections['invitations'] ?? const {});
        _usage = normalizeTenantUsageRecord(sections['usage'] ?? const {});
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

  String _tabPath(String tab) => switch (tab) {
    'members' => AdminPaths.tenantMembers(widget.tenantId),
    'invitations' => AdminPaths.tenantInvitations(widget.tenantId),
    'usage' =>
      '/api/v1/admin/tenants/${Uri.encodeComponent(widget.tenantId)}/usage',
    _ => throw ArgumentError.value(tab, 'tab', 'Unsupported tenant tab'),
  };

  Future<Map<String, dynamic>> _optionalGet(String section, String path) async {
    try {
      final result = await widget.api.get(path);
      _sectionErrors.remove(section);
      return result;
    } catch (error) {
      _sectionErrors[section] = error.toString();
      return <String, dynamic>{};
    }
  }

  List<dynamic> _firstList(Map<String, dynamic> response) {
    for (final value in response.values) {
      if (value is List) return value;
    }
    return const [];
  }

  void _snack(String message, [Map<String, Object?>? args]) {
    showAppSnackBar(context, content: LocalizedText(message, args: args));
  }

  void _snackError(String message, [Map<String, Object?>? args]) {
    showAppSnackBar(
      context,
      content: LocalizedText(message, args: args),
      kind: AppSnackBarKind.error,
    );
  }

  @override
  Future<void> _removeMember(String userId) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Remove member?',
      message: context.tr('Remove {userId} from tenant?', {'userId': userId}),
      confirmLabel: 'Remove',
      destructive: true,
      confirmText: userId,
    );
    if (!confirmed) return;
    try {
      await widget.api.delete(AdminPaths.tenantMember(widget.tenantId, userId));
      if (!mounted) return;
      _snack('Removed {userId}', {'userId': userId});
      _load();
    } catch (e) {
      if (mounted) _snackError('{e}', {'e': e});
    }
  }

  @override
  Future<void> _resendInvitation(Map<String, dynamic> invitation) async {
    final email = invitation['email']?.toString() ?? '';
    if (email.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Resend invitation?',
      message: context.tr(
        'Send a new invitation message to {email}. Any previously issued '
        'pending invitation for the address may be replaced.',
        {'email': email},
      ),
      confirmLabel: 'Resend invitation',
    );
    if (!confirmed) return;
    try {
      await widget.api.post(AdminPaths.tenantInvitations(widget.tenantId), {
        'email': email,
        'role': invitation['role']?.toString() ?? 'member',
      });
      if (!mounted) return;
      _snack('Invitation resent');
      await _load();
    } catch (error) {
      if (mounted) _snackError('Resend failed: {error}', {'error': error});
    }
  }

  @override
  Future<void> _revokeInvitation(String email) async {
    if (email.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Revoke invitation?',
      message: context.tr('Revoke this invitation?'),
      confirmLabel: 'Revoke',
      destructive: true,
      confirmText: email,
    );
    if (!confirmed) return;
    try {
      await widget.api.delete(
        AdminPaths.tenantInvitation(widget.tenantId, email),
      );
      if (!mounted) return;
      _snack('Invitation revoked');
      _load();
    } catch (error) {
      if (mounted) _snackError('Revoke failed: {error}', {'error': error});
    }
  }

  @override
  Future<void> _editTenant(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) =>
          TenantFormDialog(client: widget.client, existing: _tenant),
    );
    if (result == true) _load();
  }
}
