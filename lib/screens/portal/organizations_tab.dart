import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'organization_admin_tab.dart';
import 'portal_api.dart';
import 'portal_widgets.dart';

/// B2B organization membership: list + leave + accept an invitation token.
/// Ports the "Organizations" card / loadOrganizations() in app.js. app.js
/// hides the whole card when GET /me/organizations doesn't return 200 (the
/// TenantUserStore isn't wired); since this tab is a static NavigationRail
/// destination rather than a DOM element we can hide after the fact, we show
/// the tab always and render an explanatory empty state instead.
class OrganizationsTab extends StatefulWidget {
  final PortalApi api;
  const OrganizationsTab({super.key, required this.api});

  @override
  State<OrganizationsTab> createState() => _OrganizationsTabState();
}

class _OrganizationsTabState extends State<OrganizationsTab> {
  bool _loading = true;
  bool _available = true;
  List<dynamic> _orgs = const [];

  final TextEditingController _inviteCtrl = TextEditingController();
  String? _msg;
  bool _ok = false;
  bool _accepting = false;
  String? _leavingTenantId;
  String? _managedTenantId;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _inviteCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final r = await widget.api.get('/me/organizations');
      if (r.statusCode != 200) {
        setState(() {
          _available = false;
          _orgs = const [];
          _loading = false;
        });
        return;
      }
      final d = PortalApi.decode(r);
      setState(() {
        _available = true;
        _orgs = (d['organizations'] as List?) ?? const [];
        _loading = false;
      });
    } catch (_) {
      setState(() {
        _available = false;
        _orgs = const [];
        _loading = false;
      });
    }
  }

  Future<void> _leave(String tenantId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.tr('Leave organization?')),
        content: Text(
          context.tr(
            'You will lose access to {tenantId} and its organization resources until an administrator invites you again.',
            {'tenantId': tenantId},
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(context.strings.cancel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: Text(context.tr('Leave')),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _leavingTenantId = tenantId;
      _msg = null;
    });
    try {
      final response = await widget.api.delete(
        '/me/organizations/${Uri.encodeComponent(tenantId)}',
      );
      if (!mounted) return;
      if (response.statusCode >= 200 && response.statusCode < 300) {
        setState(() {
          _msg = 'You have left the organization.';
          _ok = true;
        });
        await _load();
      } else {
        setState(() {
          _msg = 'Could not leave the organization.';
          _ok = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _msg = 'Could not leave the organization.';
          _ok = false;
        });
      }
    } finally {
      if (mounted) setState(() => _leavingTenantId = null);
    }
  }

  Future<void> _acceptInvite() async {
    final token = _inviteCtrl.text.trim();
    if (token.isEmpty) {
      setState(() {
        _msg = 'Paste an invitation token.';
        _ok = false;
      });
      return;
    }
    setState(() {
      _accepting = true;
      _msg = null;
    });
    try {
      final r = await widget.api.post('/me/invitations/accept', {
        'token': token,
      });
      if (r.statusCode == 404) {
        setState(() {
          _msg = 'Invitations are not enabled.';
          _ok = false;
        });
      } else if (r.statusCode != 200) {
        setState(() {
          _msg = 'That invitation was not accepted.';
          _ok = false;
        });
      } else {
        _inviteCtrl.clear();
        setState(() {
          _msg = 'You have joined the organization.';
          _ok = true;
        });
        _load();
      }
    } catch (_) {
      setState(() {
        _msg = 'Request failed.';
        _ok = false;
      });
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final managedTenantId = _managedTenantId;
    if (managedTenantId != null) {
      return OrganizationAdminPanel(
        api: widget.api,
        tenantId: managedTenantId,
        onClose: () => setState(() => _managedTenantId = null),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text(
                context.strings.organizations,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const Spacer(),
              IconButton(onPressed: _load, icon: const Icon(Icons.refresh)),
            ],
          ),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    if (!_available)
                      const EmptyHint(
                        'Organizations are not available for this account.',
                      )
                    else if (_orgs.isEmpty)
                      const EmptyHint(
                        'You are not a member of any organization.',
                      )
                    else
                      for (final raw in _orgs)
                        _orgTile(raw as Map<String, dynamic>),
                    if (_available) ...[
                      const SizedBox(height: 20),
                      Text(
                        context.tr('Accept an invitation'),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 12),
                      TextField(
                        controller: _inviteCtrl,
                        decoration: InputDecoration(
                          labelText: context.tr('Invitation token'),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          onPressed: _accepting ? null : _acceptInvite,
                          child: _accepting
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : Text(context.tr('Join organization')),
                        ),
                      ),
                      MessageBanner(_msg, ok: _ok),
                    ],
                  ],
                ),
        ),
      ],
    );
  }

  Widget _orgTile(Map<String, dynamic> o) {
    final tenantId = o['tenant_id']?.toString() ?? '';
    final role = o['role']?.toString() ?? 'member';
    final canManage = role == 'admin' && tenantId.isNotEmpty;
    return ListTile(
      title: Text(tenantId),
      subtitle: Text(context.tr(role)),
      trailing: Wrap(
        spacing: 4,
        children: [
          if (canManage)
            TextButton(
              onPressed: () => setState(() => _managedTenantId = tenantId),
              child: Text(context.tr('Manage')),
            ),
          TextButton(
            onPressed: tenantId.isEmpty || _leavingTenantId != null
                ? null
                : () => _leave(tenantId),
            style: TextButton.styleFrom(foregroundColor: AppColors.danger),
            child: _leavingTenantId == tenantId
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : Text(context.tr('Leave')),
          ),
        ],
      ),
    );
  }
}
