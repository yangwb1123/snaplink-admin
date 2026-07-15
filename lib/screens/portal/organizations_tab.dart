import 'package:flutter/material.dart';
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
    await widget.api.delete('/me/organizations/${Uri.encodeComponent(tenantId)}');
    _load();
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
      final r = await widget.api.post('/me/invitations/accept', {'token': token});
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Text('Organizations', style: Theme.of(context).textTheme.headlineSmall),
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
                      const EmptyHint('Organizations are not available for this account.')
                    else if (_orgs.isEmpty)
                      const EmptyHint('You are not a member of any organization.')
                    else
                      for (final raw in _orgs) _orgTile(raw as Map<String, dynamic>),
                    if (_available) ...[
                      const SizedBox(height: 20),
                      Text('Accept an invitation', style: Theme.of(context).textTheme.titleMedium),
                      const SizedBox(height: 10),
                      TextField(
                        controller: _inviteCtrl,
                        decoration: const InputDecoration(labelText: 'Invitation token'),
                      ),
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: FilledButton(
                          onPressed: _accepting ? null : _acceptInvite,
                          child: _accepting
                              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
                              : const Text('Join organization'),
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
    return ListTile(
      title: Text(tenantId),
      subtitle: Text(o['role']?.toString() ?? 'member'),
      trailing: TextButton(
        onPressed: () => _leave(tenantId),
        style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
        child: const Text('Leave'),
      ),
    );
  }
}
