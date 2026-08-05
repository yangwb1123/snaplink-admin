import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'portal_api.dart';
import 'organization_admin_widgets.dart';
import 'portal_widgets.dart';
import 'member_row_tile.dart';

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
    setState(() {
      _loading = true;
      if (!preserveMessage) {
        _message = null;
        _ok = false;
      }
    });
    try {
      final members = await widget.api.get('$_base/members');
      if (!mounted) return;
      if (members.statusCode == 403) {
        setState(() {
          _available = false;
          _members = const [];
          _invitations = const [];
        });
        return;
      }
      if (members.statusCode != 200) {
        setState(() {
          _available = true;
          _members = const [];
          _invitations = const [];
          _message = 'Could not load the organization roster.';
          _ok = false;
        });
        return;
      }
      final roster = organizationRecords(PortalApi.decode(members)['members']);
      final invitations = await widget.api.get('$_base/invitations');
      if (!mounted) return;
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
      if (mounted) {
        setState(() {
          _message = 'Could not load organization administration.';
          _ok = false;
        });
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _changeRole(Map<String, dynamic> member, String role) async {
    final userId = member['user_id']?.toString() ?? '';
    final oldRole = member['role']?.toString() ?? '';
    if (userId.isEmpty || role == oldRole) return;
    final accepted = await confirmOrganizationAction(
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
    );
    if (!accepted) return;
    setState(() {
      _busy = true;
      _message = null;
      _ok = false;
    });
    try {
      final response = await widget.api.put(
        '$_base/members/${Uri.encodeComponent(userId)}',
        {'role': role},
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _message = 'Member role updated.';
          _ok = true;
        });
        await _load(preserveMessage: true);
      } else {
        setState(() {
          _message = response.statusCode == 409
              ? 'Last admin protected.'
              : response.statusCode == 403
              ? 'Cannot change.'
              : 'Role not updated.';
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

  Future<void> _remove(Map<String, dynamic> member) async {
    final userId = member['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    final accepted = await confirmOrganizationAction(
      context,
      'Remove member?',
      context.tr('{userId} will lose access to this organization.', {
        'userId': userId,
      }),
      'Remove',
      confirmText: userId,
      destructive: true,
    );
    if (!accepted) return;
    setState(() {
      _busy = true;
      _message = null;
      _ok = false;
    });
    try {
      final response = await widget.api.delete(
        '$_base/members/${Uri.encodeComponent(userId)}',
      );
      if (!mounted) return;
      if (response.statusCode == 204) {
        setState(() {
          _message = 'Member removed.';
          _ok = true;
        });
        await _load(preserveMessage: true);
      } else {
        setState(() {
          _message = response.statusCode == 409
              ? 'Last admin protected.'
              : response.statusCode == 403
              ? 'Cannot change.'
              : 'Not removed.';
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

  Future<void> _invite() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() {
        _message = 'Enter an email address.';
        _ok = false;
      });
      return;
    }
    final accepted = await confirmOrganizationAction(
      context,
      'Send invitation?',
      context.tr('Send a {role} invitation to {email}.', {
        'role': _inviteRole,
        'email': email,
      }),
      'Send invitation',
    );
    if (!accepted) return;
    setState(() {
      _busy = true;
      _message = null;
      _ok = false;
    });
    try {
      final response = await widget.api.post('$_base/invitations', {
        'email': email,
        'role': _inviteRole,
      });
      if (!mounted) return;
      if (response.statusCode == 202) {
        _emailCtrl.clear();
        setState(() {
          _message = 'Invitation sent. Snaplink never exposes its token here.';
          _ok = true;
        });
        await _load(preserveMessage: true);
      } else {
        setState(() {
          _message = response.statusCode == 409
              ? 'Duplicate or protected.'
              : response.statusCode == 403
              ? 'Cannot change.'
              : 'Invitation was not sent.';
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

  Future<void> _revoke(Map<String, dynamic> invitation) async {
    final email = invitation['email']?.toString() ?? '';
    if (email.isEmpty) return;
    final accepted = await confirmOrganizationAction(
      context,
      'Revoke invitation?',
      context.tr('Revoke all pending invitations for {email}.', {
        'email': email,
      }),
      'Revoke',
      confirmText: email,
      destructive: true,
    );
    if (!accepted) return;
    setState(() {
      _busy = true;
      _message = null;
      _ok = false;
    });
    try {
      final response = await widget.api.delete(
        '$_base/invitations/${Uri.encodeComponent(email)}',
      );
      if (!mounted) return;
      if (response.statusCode == 204) {
        setState(() {
          _message = 'Invitation revoked.';
          _ok = true;
        });
        await _load(preserveMessage: true);
      } else {
        setState(() {
          _message = response.statusCode == 409
              ? 'Duplicate or protected.'
              : response.statusCode == 403
              ? 'Cannot change.'
              : 'Not revoked.';
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

  @override
  Widget build(BuildContext context) => ListView(
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
        const LinearProgressIndicator()
      else if (!_available)
        const EmptyHint(
          'Organization administration is not available to this account.',
        )
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
  );
  Widget _memberRow(Map<String, dynamic> member) => MemberRowTile(
    member: member,
    roles: _roles,
    busy: _busy,
    onChangeRole: (m, r) => _changeRole(m, r),
    onRemove: (m) => _remove(m),
  );
}
