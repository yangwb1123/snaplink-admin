import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'org_members_card.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'tenant_export_download.dart';
import 'tenant_organization_cards.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/admin_list_header.dart';
import 'admin_module_groups.dart';
import 'admin_navigation.dart';

/// Manages the B2B organization features attached to a Snaplink tenant.
///
/// Membership and invitations are independently optional in Snaplink. The
/// screen receives the runtime inventory and only exposes controls that the
/// connected replica actually registered.
class TenantOrganizationsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const TenantOrganizationsTab({
    super.key,
    required this.api,
    required this.capabilities,
  });

  @override
  State<TenantOrganizationsTab> createState() => _TenantOrganizationsTabState();
}

class _TenantOrganizationsTabState extends State<TenantOrganizationsTab> {
  static const _membersPath = '/api/v1/admin/tenants/:id/members';
  static const _memberPath = '/api/v1/admin/tenants/:id/members/:user_id';
  static const _invitationsPath = '/api/v1/admin/tenants/:id/invitations';
  static const _invitationPath = '/api/v1/admin/tenants/:id/invitations/:email';
  static const _exportPath = '/api/v1/admin/tenants/:id/export';

  final _tenantCtrl = TextEditingController();
  final _memberCtrl = TextEditingController();
  final _inviteCtrl = TextEditingController();

  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _invitations = const [];
  String? _loadError; // 加载错误 → 带 Retry 的横幅（X4）
  String? _actionError; // 校验/提交错误 → 表单内联提示
  /// 请求序号：快速连续刷新时丢弃过期响应（R12 竞态防护）。
  int _reqSeq = 0;
  bool _loading = false;
  bool _mutating = false;
  String _memberRole = 'member';
  String _inviteRole = 'member';

  /// 模块强调色（tenants 组 amber）：页内图标统一按组色上色（X7）。
  Color get _accent => adminModuleIconColor(AdminModuleId.organizations);

  // Snaplink's inventory establishes whether an optional backing store is
  // wired. Older server builds advertise only one representative method of a
  // route family, so availability is deliberately prefix-based; the server
  // remains authoritative for each operation's method-level authorization.
  bool get _supportsMembers =>
      widget.capabilities.hasAnyPathPrefix('/api/v1/admin/tenants/:id/members');
  bool get _supportsInvitations => widget.capabilities.hasAnyPathPrefix(
    '/api/v1/admin/tenants/:id/invitations',
  );
  // The current Snaplink endpoint inventory omits this route even when its
  // tenant-user store mounted it. Keep the documented control available and
  // let the server report a genuinely unwired feature at request time.
  bool get _supportsExport =>
      widget.capabilities.has('POST', _exportPath) ||
      SnaplinkAdminOperationCatalog.hasDocumentedPathPrefix(_exportPath);

  @override
  void dispose() {
    _tenantCtrl.dispose();
    _memberCtrl.dispose();
    _inviteCtrl.dispose();
    super.dispose();
  }

  String? get _tenantId {
    final value = _tenantCtrl.text.trim();
    return value.isEmpty ? null : value;
  }

  String _path(
    String template,
    String tenantId, {
    String? userId,
    String? email,
  }) => template
      .replaceAll(':id', Uri.encodeComponent(tenantId))
      .replaceAll(':user_id', Uri.encodeComponent(userId ?? ''))
      .replaceAll(':email', Uri.encodeComponent(email ?? ''));

  Future<void> _load() async {
    final tenantId = _tenantId;
    if (tenantId == null) {
      setState(() => _actionError = 'Enter a tenant ID first.');
      return;
    }
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _loadError = null;
      _actionError = null;
    });
    try {
      final jobs = <Future<Map<String, dynamic>>>[];
      if (_supportsMembers) {
        jobs.add(widget.api.get(_path(_membersPath, tenantId)));
      }
      if (_supportsInvitations) {
        jobs.add(widget.api.get(_path(_invitationsPath, tenantId)));
      }
      final results = await Future.wait(jobs);
      var resultIndex = 0;
      final members = _supportsMembers
          ? _maps(results[resultIndex++]['members'])
          : const <Map<String, dynamic>>[];
      final invitations = _supportsInvitations
          ? _maps(results[resultIndex]['invitations'])
          : const <Map<String, dynamic>>[];
      if (!mounted || seq != _reqSeq) return;
      setState(() {
        _members = members;
        _invitations = invitations;
      });
    } on SnaplinkAdminApiError catch (error) {
      if (mounted && seq == _reqSeq) setState(() => _loadError = error.toString());
    } catch (_) {
      if (mounted && seq == _reqSeq) {
        setState(() => _loadError = 'Could not load organization data.');
      }
    } finally {
      if (mounted && seq == _reqSeq) setState(() => _loading = false);
    }
  }

  List<Map<String, dynamic>> _maps(Object? values) {
    if (values is! List) return const [];
    return values
        .whereType<Map>()
        .map((value) => Map<String, dynamic>.from(value))
        .toList(growable: false);
  }

  Future<void> _saveMember() async {
    final tenantId = _tenantId;
    final userId = _memberCtrl.text.trim();
    if (tenantId == null || userId.isEmpty) {
      setState(() => _actionError = 'Tenant ID and user ID are required.');
      return;
    }
    await _mutate(
      () => widget.api.put(_path(_memberPath, tenantId, userId: userId), {
        'role': _memberRole,
      }),
      success: 'Membership saved.',
      clear: _memberCtrl,
    );
  }

  Future<void> _removeMember(String userId) async {
    final tenantId = _tenantId;
    if (tenantId == null ||
        !await _confirm(
          'Remove member?',
          context.tr('Remove {userId} from this organization?', {
            'userId': userId,
          }),
          confirmLabel: 'Remove',
          confirmText: userId,
        )) {
      return;
    }
    await _mutate(
      () => widget.api.delete(_path(_memberPath, tenantId, userId: userId)),
      success: 'Member removed.',
    );
  }

  Future<void> _sendInvitation() async {
    final tenantId = _tenantId;
    final email = _inviteCtrl.text.trim();
    if (tenantId == null || email.isEmpty) {
      setState(
        () => _actionError = 'Tenant ID and invitation email are required.',
      );
      return;
    }
    await _mutate(
      () => widget.api.post(_path(_invitationsPath, tenantId), {
        'email': email,
        'role': _inviteRole,
      }),
      success: 'Invitation sent.',
      clear: _inviteCtrl,
    );
  }

  Future<void> _revokeInvitation(String email) async {
    final tenantId = _tenantId;
    if (tenantId == null ||
        !await _confirm(
          'Revoke invitation?',
          context.tr('Revoke every pending invitation for {email}?', {
            'email': email,
          }),
          confirmLabel: 'Revoke',
          confirmText: email,
        )) {
      return;
    }
    await _mutate(
      () => widget.api.delete(_path(_invitationPath, tenantId, email: email)),
      success: 'Invitation revoked.',
    );
  }

  Future<void> _exportTenant() async {
    final tenantId = _tenantId;
    if (tenantId == null) {
      setState(() => _actionError = 'Enter a tenant ID first.');
      return;
    }
    setState(() => _mutating = true);
    try {
      final export = await widget.api.postDownload(
        _path(_exportPath, tenantId),
      );
      if (!mounted) return;
      downloadTenantExport(export, tenantId);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: LocalizedText('Tenant export download started.'),
        ),
      );
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _actionError = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _mutate(
    Future<Map<String, dynamic>> Function() request, {
    required String success,
    TextEditingController? clear,
  }) async {
    setState(() {
      _mutating = true;
      _actionError = null;
    });
    try {
      await request();
      clear?.clear();
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LocalizedText(success)));
      await _load();
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _actionError = error.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String message, {
    String confirmLabel = 'Confirm',
    String? confirmText,
  }) async => ConfirmDialog.show(
    context,
    title: title,
    message: message,
    confirmLabel: confirmLabel,
    destructive: true,
    confirmText: confirmText,
  );

  @override
  Widget build(BuildContext context) {
    if (!_supportsMembers && !_supportsInvitations && !_supportsExport) {
      return const EmptyState(
        variant: EmptyStateVariant.notEnabled,
        title:
            'Organization management is not enabled on this Snaplink replica.',
      );
    }
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const AdminBreadcrumb(),
        AdminListHeader(
          title: AppStrings.of(context).tenantOrganizations,
          onRefresh: _load,
          actions: [
            IconButton(
              onPressed: _loading ? null : _load,
              icon: Icon(Icons.refresh, color: _accent),
              tooltip: context.strings.refresh,
            ),
          ],
        ),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _tenantCtrl,
                decoration: InputDecoration(
                  labelText: 'Tenant ID'.localized,
                  hintText: 'acme'.localized,
                  prefixIcon: Icon(Icons.business_outlined, color: _accent),
                ),
                onSubmitted: (_) => _load(),
              ),
            ),
            const SizedBox(width: 12),
            FilledButton.icon(
              onPressed: _loading ? null : _load,
              icon: const Icon(Icons.search, size: 18),
              label: const LocalizedText('Load organization'),
            ),
          ],
        ),
        if (_actionError != null) ...[
          const SizedBox(height: 12),
          LocalizedText(
            _actionError!,
            style: const TextStyle(color: AppColors.danger),
          ),
        ],
        if (_loadError != null) ...[
          const SizedBox(height: 12),
          ErrorStateCard(message: _loadError!, onRetry: _load, margin: EdgeInsets.zero),
        ],
        if (_loading)
          const Padding(
            padding: EdgeInsets.only(top: 20),
            child: SkeletonListTile(itemCount: 3),
          ),
        if (_supportsMembers) _membersCard(context),
        if (_supportsInvitations)
          OrganizationInvitationsCard(
            invitations: _invitations,
            emailController: _inviteCtrl,
            role: _inviteRole,
            mutating: _mutating,
            accent: _accent,
            onRoleChanged: (value) => setState(() => _inviteRole = value),
            onSend: _sendInvitation,
            onRevoke: _revokeInvitation,
          ),
        if (_supportsExport)
          TenantOrganizationExportCard(
            mutating: _mutating,
            accent: _accent,
            onExport: _exportTenant,
          ),
      ],
    );
  }

  Widget _membersCard(BuildContext context) => OrgMembersCard(
    members: _members,
    mutating: _mutating,
    memberUserController: _memberCtrl,
    memberRole: _memberRole,
    accent: _accent,
    onRoleChanged: (v) => setState(() => _memberRole = v),
    onSaveMember: _saveMember,
    onRemoveMember: (u) => _removeMember(u),
  );
}

