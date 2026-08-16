import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/pull_to_refresh.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

import 'portal_api.dart';
import 'organization_admin_widgets.dart';
import 'portal_widgets.dart';
import 'member_row_tile.dart';

/// Organization administration for a managed tenant: member roster with
/// role changes / removals plus email invitations and pending-invitation
/// revocation. Semantics preserved from app.js's organization admin view:
/// the role dropdown is the change-role control, the danger Remove revokes
/// membership, invitations are sent by email and never display their token.
///
/// Layout: admin header → three-state body. Loading renders
/// [SkeletonListTile], "not available" (members 403) renders an [EmptyState]
/// notEnabled variant, failures render a retryable [PortalErrorCard], and
/// loaded data renders the members + invitations cards (loading/empty/error
/// triad). Every mutation runs through a shared [ConfirmDialog] guard.
class OrganizationAdminPanel extends StatefulWidget {
  final PortalApi api;
  final String tenantId;
  final VoidCallback onClose;

  const OrganizationAdminPanel({
    super.key,
    required this.api,
    required this.tenantId,
    required this.onClose,
  });

  @override
  State<OrganizationAdminPanel> createState() => _OrganizationAdminPanelState();
}

class _OrganizationAdminPanelState extends State<OrganizationAdminPanel> {
  static const _roles = ['member', 'admin', 'guest'];

  final _emailCtrl = TextEditingController();
  String _inviteRole = 'member';
  bool _loading = true;
  bool _available = true;
  bool _invitationsAvailable = true;
  bool _busy = false;
  /// 请求序号：快速连续刷新时丢弃过期响应（R12 竞态防护）。
  int _reqSeq = 0;
  String? _error;
  List<Map<String, dynamic>> _members = const [];
  List<Map<String, dynamic>> _invitations = const [];
  String? _message;
  bool _ok = false;

  String get _base =>
      '/me/organizations/${Uri.encodeComponent(widget.tenantId)}';

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _load({bool preserveMessage = false}) async {
    final seq = ++_reqSeq;
    setState(() {
      _loading = true;
      _error = null;
      if (!preserveMessage) {
        _message = null;
        _ok = false;
      }
    });
    try {
      final members = await widget.api.get('$_base/members');
      if (!mounted || seq != _reqSeq) return;
      if (members.statusCode == 403) {
        setState(() {
          _available = false;
          _members = const [];
          _invitations = const [];
        });
        return;
      }
      if (members.statusCode != 200) {
        setState(() => _error = 'Could not load the organization roster.');
        return;
      }
      final roster = organizationRecords(PortalApi.decode(members)['members']);
      final invitations = await widget.api.get('$_base/invitations');
      if (!mounted || seq != _reqSeq) return;
      if (invitations.statusCode == 403 || invitations.statusCode == 404) {
        setState(() {
          _available = true;
          _invitationsAvailable = false;
          _members = roster;
          _invitations = const [];
        });
        return;
      }
      if (invitations.statusCode != 200) {
        setState(() {
          _available = true;
          _invitationsAvailable = true;
          _members = roster;
          _invitations = const [];
          _message = 'Could not load pending invitations.';
          _ok = false;
        });
        return;
      }
      setState(() {
        _available = true;
        _invitationsAvailable = true;
        _members = roster;
        _invitations = organizationRecords(
          PortalApi.decode(invitations)['invitations'],
        );
      });
    } catch (_) {
      if (mounted && seq == _reqSeq) {
        setState(() => _error = 'Could not load organization administration.');
      }
    } finally {
      if (mounted && seq == _reqSeq) setState(() => _loading = false);
    }
  }

  /// Shared mutation scaffold for role changes, removals, invites and
  /// revocations: guard (validation + confirm) → busy state → request →
  /// success banner + reload, or per-status failure copy.
  Future<void> _mutate({
    required Future<bool> Function() guard,
    required Future<http.Response> Function() request,
    required String success,
    required String Function(int status) failure,
  }) async {
    if (!await guard() || !mounted) return;
    setState(() {
      _busy = true;
      _message = null;
      _ok = false;
    });
    try {
      final response = await request();
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _message = success;
          _ok = true;
        });
        await _load(preserveMessage: true);
      } else {
        setState(() {
          _message = failure(response.statusCode);
          _ok = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _message = 'Request failed.';
          _ok = false;
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _changeRole(Map<String, dynamic> member, String role) async {
    final userId = member['user_id']?.toString() ?? '';
    final oldRole = member['role']?.toString() ?? '';
    if (userId.isEmpty || role == oldRole) return;
    await _mutate(
      guard: () async => confirmOrganizationAction(
        context,
        'Change member role?',
        context.tr('Change {userId} from {oldRole} to {role}.', {
          'userId': userId,
          'oldRole': oldRole,
          'role': role,
        }),
        'Change role',
        confirmText: userId,
        destructive: true,
      ),
      request: () => widget.api.put(
        '$_base/members/${Uri.encodeComponent(userId)}',
        {'role': role},
      ),
      success: 'Member role updated.',
      failure: (status) => status == 409
          ? 'Last admin protected.'
          : status == 403
          ? 'Cannot change.'
          : 'Role not updated.',
    );
  }

  Future<void> _remove(Map<String, dynamic> member) async {
    final userId = member['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    await _mutate(
      guard: () async => confirmOrganizationAction(
        context,
        'Remove member?',
        context.tr('{userId} will lose access to this organization.', {
          'userId': userId,
        }),
        'Remove',
        confirmText: userId,
        destructive: true,
      ),
      request: () => widget.api.delete(
        '$_base/members/${Uri.encodeComponent(userId)}',
      ),
      success: 'Member removed.',
      failure: (status) => status == 409
          ? 'Last admin protected.'
          : status == 403
          ? 'Cannot change.'
          : 'Not removed.',
    );
  }

  Future<void> _invite() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() {
        _message = 'Enter an email address.';
        _ok = false;
      });
      return;
    }
    await _mutate(
      guard: () async => confirmOrganizationAction(
        context,
        'Send invitation?',
        context.tr('Send a {role} invitation to {email}.', {
          'role': _inviteRole,
          'email': email,
        }),
        'Send invitation',
      ),
      request: () => widget.api.post('$_base/invitations', {
        'email': email,
        'role': _inviteRole,
      }),
      success: 'Invitation sent. Snaplink never exposes its token here.',
      failure: (status) => status == 409
          ? 'Duplicate or protected.'
          : status == 403
          ? 'Cannot change.'
          : 'Invitation was not sent.',
    );
  }

  Future<void> _revoke(Map<String, dynamic> invitation) async {
    final email = invitation['email']?.toString() ?? '';
    if (email.isEmpty) return;
    await _mutate(
      guard: () async => confirmOrganizationAction(
        context,
        'Revoke invitation?',
        context.tr('Revoke all pending invitations for {email}.', {
          'email': email,
        }),
        'Revoke',
        confirmText: email,
        destructive: true,
      ),
      request: () => widget.api.delete(
        '$_base/invitations/${Uri.encodeComponent(email)}',
      ),
      success: 'Invitation revoked.',
      failure: (status) => status == 409
          ? 'Duplicate or protected.'
          : status == 403
          ? 'Cannot change.'
          : 'Not revoked.',
    );
  }

  @override
  Widget build(BuildContext context) => PullToRefresh(onRefresh: _load, child: ListView(
    padding: const EdgeInsets.all(16),
    children: [
      OrganizationAdminHeader(
        tenantId: widget.tenantId,
        disabled: _loading || _busy,
        onClose: widget.onClose,
        onRefresh: _load,
      ),
      const SizedBox(height: 12),
      if (_loading)
        const SkeletonListTile(itemCount: 3)
      else if (!_available)
        const EmptyState(
          compact: true,
          variant: EmptyStateVariant.notEnabled,
          icon: Icons.admin_panel_settings_outlined,
          title:
              'Organization administration is not available to this account.',
        )
      else if (_error != null)
        PortalErrorCard(message: context.tr(_error!), onRetry: _load)
      else ...[
        PortalCard(
          title: 'Members',
          children: [
            if (_members.isEmpty)
              const EmptyHint('No organization members were returned.'),
            for (final member in _members) _memberRow(member),
          ],
        ),
        if (_invitationsAvailable) ...[
          OrganizationInvitationCards(
            emailController: _emailCtrl,
            role: _inviteRole,
            roles: _roles,
            busy: _busy,
            invitations: _invitations,
            onRoleChanged: (role) => setState(() => _inviteRole = role),
            onInvite: _invite,
            onRevoke: _revoke,
          ),
        ],
      ],
      MessageBanner(_message, ok: _ok),
    ],
  ));

  Widget _memberRow(Map<String, dynamic> member) => MemberRowTile(
    member: member,
    roles: _roles,
    busy: _busy,
    onChangeRole: (m, r) => _changeRole(m, r),
    onRemove: (m) => _remove(m),
  );
}
