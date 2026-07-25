import 'package:flutter/material.dart';

import 'portal_api.dart';
import 'portal_widgets.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'member_row_tile.dart';

/// Delegated tenant administration for a user's own organizations.
///
/// This deliberately uses the self-service `/me/organizations/...` surface,
/// not the platform-wide admin API. Snaplink authorizes it from the user's
/// tenant-admin membership and returns an intentionally non-specific 403 for
/// every other case, so this screen does not try to infer why access failed.
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
  static List<Map<String, dynamic>> _records(Object? values) =>
      (values as List? ?? const [])
          .whereType<Map>()
          .map((value) => Map<String, dynamic>.from(value))
          .toList(growable: false);

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    try {
      final members = await widget.api.get('$_base/members');
      if (!mounted) return;
      if (members.statusCode == 403 || members.statusCode == 404) {
        setState(() {
          _available = false;
          _members = const [];
          _invitations = const [];
        });
        return;
      }
      if (members.statusCode != 200) {
        setState(() => _message = 'Could not load the organization roster.');
        return;
      }
      final invitations = await widget.api.get('$_base/invitations');
      if (!mounted) return;
      if (invitations.statusCode == 403 || invitations.statusCode == 404) {
        setState(() => _available = false);
        return;
      }
      if (invitations.statusCode != 200) {
        setState(() => _message = 'Could not load pending invitations.');
        return;
      }
      setState(() {
        _available = true;
        _members = _records(PortalApi.decode(members)['members']);
        _invitations = _records(PortalApi.decode(invitations)['invitations']);
      });
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Could not load organization administration.',
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }
  Future<bool> _confirm(String title, String detail, String action) async =>
      ConfirmDialog.show(context, title: title, message: detail, confirmLabel: action);
  Future<void> _changeRole(Map<String, dynamic> member, String role) async {
    final userId = member['user_id']?.toString() ?? '';
    final oldRole = member['role']?.toString() ?? '';
    if (userId.isEmpty || role == oldRole) return;
    final accepted = await _confirm(
      'Change member role?',
      'Change $userId from $oldRole to $role.',
      'Change role',
    );
    if (!accepted) return;
    setState(() {
      _busy = true;
      _message = null;
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
        await _load();
      } else {
        setState(() {
          _message = response.statusCode == 409 ? 'Last admin protected.' : response.statusCode == 403 ? 'Cannot change.' : 'Role not updated.';
          _ok = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Request failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _remove(Map<String, dynamic> member) async {
    final userId = member['user_id']?.toString() ?? '';
    if (userId.isEmpty) return;
    final accepted = await _confirm(
      'Remove member?',
      '$userId will lose access to this organization.',
      'Remove',
    );
    if (!accepted) return;
    setState(() {
      _busy = true;
      _message = null;
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
        await _load();
      } else {
        setState(() {
          _message = response.statusCode == 409 ? 'Last admin protected.' : response.statusCode == 403 ? 'Cannot change.' : 'Not removed.';
          _ok = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Request failed.');
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
    final accepted = await _confirm(
      'Send invitation?',
      'Send a $_inviteRole invitation to $email.',
      'Send invitation',
    );
    if (!accepted) return;
    setState(() {
      _busy = true;
      _message = null;
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
        await _load();
      } else {
        setState(() {
          _message = response.statusCode == 409 ? 'Duplicate or protected.' : response.statusCode == 403 ? 'Cannot change.' : 'Invitation was not sent.';
          _ok = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Request failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  Future<void> _revoke(Map<String, dynamic> invitation) async {
    final email = invitation['email']?.toString() ?? '';
    if (email.isEmpty) return;
    final accepted = await _confirm(
      'Revoke invitation?',
      'Revoke all pending invitations for $email.',
      'Revoke',
    );
    if (!accepted) return;
    setState(() {
      _busy = true;
      _message = null;
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
        await _load();
      } else {
        setState(() {
          _message = response.statusCode == 409 ? 'Duplicate or protected.' : response.statusCode == 403 ? 'Cannot change.' : 'Not revoked.';
          _ok = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _message = 'Request failed.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: [
      Row(
        children: [
          IconButton(
            tooltip: 'Back to organizations',
            onPressed: widget.onClose,
            icon: const Icon(Icons.arrow_back),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Manage ${widget.tenantId}',
              style: Theme.of(context).textTheme.headlineSmall,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          IconButton(
            tooltip: 'Refresh',
            onPressed: _loading || _busy ? null : _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
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
        PortalCard(
          title: 'Invite member',
          children: [
            TextField(
              controller: _emailCtrl,
              enabled: !_busy,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email address'),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              initialValue: _inviteRole,
              decoration: const InputDecoration(labelText: 'Organization role'),
              items: _roles
                  .map(
                    (role) => DropdownMenuItem(value: role, child: Text(role)),
                  )
                  .toList(growable: false),
              onChanged: _busy
                  ? null
                  : (role) {
                      if (role != null) setState(() => _inviteRole = role);
                    },
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton(
                onPressed: _busy ? null : _invite,
                child: const Text('Send invitation'),
              ),
            ),
          ],
        ),
        PortalCard(
          title: 'Pending invitations',
          children: [
            const Text('Invitation tokens are intentionally never displayed.'),
            const SizedBox(height: 8),
            if (_invitations.isEmpty)
              const EmptyHint('No pending invitations.'),
            for (final invitation in _invitations)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(invitation['email']?.toString() ?? ''),
                subtitle: Text(
                  '${invitation['role'] ?? 'member'}${invitation['expires_at'] == null ? '' : ' · expires ${invitation['expires_at']}'}',
                ),
                trailing: TextButton(
                  onPressed: _busy ? null : () => _revoke(invitation),
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.redAccent,
                  ),
                  child: const Text('Revoke'),
                ),
              ),
          ],
        ),
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
