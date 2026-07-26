import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_route.dart';
import 'tenant_form_dialog.dart';
import 'package:web/web.dart' as web;

/// Tenant detail screen with sub-resource tabs.
/// URL: /admin/tenants/{id}[/{subresource}]
class TenantDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SSOAdminClient client;
  final String tenantId;

  const TenantDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.tenantId,
  });

  @override
  State<TenantDetailScreen> createState() => _TenantDetailScreenState();
}

class _TenantDetailScreenState extends State<TenantDetailScreen> {
  Map<String, dynamic>? _tenant;
  List<dynamic> _members = [];
  List<dynamic> _invitations = [];
  Map<String, dynamic>? _usage;
  String? _error;
  bool _loading = true;
  int _tabIndex = 0;

  static const _tabs = [
    ('members', 'Members', Icons.people),
    ('invitations', 'Invitations', Icons.mail_outline),
    ('usage', 'Usage', Icons.bar_chart),
  ];

  @override
  void initState() {
    super.initState();
    _load();
    _initTabFromRoute();
    void popListener() { if (mounted) _initTabFromRoute(); }
    web.window.addEventListener('popstate', popListener.toJS);
  }

  void _initTabFromRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    if (route.resourceId != widget.tenantId) return;
    for (var i = 0; i < _tabs.length; i++) {
      if (_tabs[i].$1 == route.subresource) {
        setState(() => _tabIndex = i);
        return;
      }
    }
  }

  void _selectTab(int index, String subresource) {
    setState(() => _tabIndex = index);
    AdminRoute.go('tenants', resourceId: widget.tenantId, subresource: subresource);
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final tid = Uri.encodeComponent(widget.tenantId);
      final results = await Future.wait([
        widget.client.getTenant(widget.tenantId),
        widget.api.get('/api/v1/admin/tenants/$tid/members'),
        widget.api.get('/api/v1/admin/tenants/$tid/invitations'),
        widget.api.get('/api/v1/admin/tenants/$tid/usage'),
      ]);
      if (!mounted) return;
      setState(() {
        _tenant = results[0] as Map<String, dynamic>?;
        _members = (results[1] as Map<String, dynamic>?)?.values.first as List? ?? [];
        _invitations = (results[2] as Map<String, dynamic>?)?.values.first as List? ?? [];
        _usage = results[3] as Map<String, dynamic>?;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Tenant: ${widget.tenantId}'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => AdminRoute.go('tenants'),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            tooltip: 'Edit tenant',
            onPressed: () => _editTenant(context),
          ),
        ],
      ),
      body: _loading
        ? const Center(child: CircularProgressIndicator())
        : _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline, size: 48, color: Colors.redAccent),
                  const SizedBox(height: 16),
                  Text('Failed to load', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Text(_error!, textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey.shade600)),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Retry'),
                  ),
                ],
              ),
            )
          : Column(children: [
              AdminBreadcrumb(),
              Expanded(child: _buildContent(context)),
            ]),
    );
  }

  Widget _buildContent(BuildContext context) => Column(
    children: [
      _tenantHeader(context),
      _tabBar(context),
      Expanded(child: _tabContent(context)),
    ],
  );

  Widget _tenantHeader(BuildContext context) => Card(
    margin: const EdgeInsets.all(16),
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Row(children: [
        const Icon(Icons.business, size: 48),
        const SizedBox(width: 16),
        Expanded(child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(_tenant?['name']?.toString() ?? widget.tenantId,
              style: Theme.of(context).textTheme.titleMedium),
            Text('ID: ${_tenant?['id'] ?? widget.tenantId}'),
            Text('Domain: ${_tenant?['domain'] ?? _tenant?['primary_domain'] ?? ''}'),
          ],
        )),
        if (_tenant?['status'] != null)
          Chip(
            label: Text(_tenant!['status'].toString()),
            backgroundColor: _tenant!['status'] == 'active'
              ? Colors.green.shade100 : Colors.orange.shade100,
          ),
      ]),
    ),
  );

  Widget _tabBar(BuildContext context) => SizedBox(
    height: 48,
    child: ListView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      children: [
        for (var i = 0; i < _tabs.length; i++)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text('${_tabs[i].$2}  (${_countForTab(i)})'),
              selected: _tabIndex == i,
              onSelected: (_) => _selectTab(i, _tabs[i].$1),
            ),
          ),
      ],
    ),
  );

  String _countForTab(int i) {
    switch (i) {
      case 0: return '${_members.length}';
      case 1: return '${_invitations.length}';
      default: return '';
    }
  }

  Widget _tabContent(BuildContext context) {
    switch (_tabIndex) {
      case 0: return _membersList(context);
      case 1: return _invitationsList(context);
      case 2: return _usageView(context);
      default: return const Center(child: Text('Select a tab'));
    }
  }

  Widget _membersList(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: _members.isEmpty
      ? [const Center(child: Text('No members'))]
      : _members.map((m) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(child: Text((m['user_id'] ?? m['id'] ?? '?').toString()[0].toUpperCase())),
            title: Text(m['user_id']?.toString() ?? m['id']?.toString() ?? ''),
            subtitle: Text('Role: ${m['role'] ?? 'member'}'),
            trailing: m['role'] != 'owner'
              ? TextButton(
                  onPressed: () => _removeMember(m['user_id']?.toString() ?? m['id']?.toString() ?? ''),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Remove'),
                )
              : null,
          ),
        )).toList(),
  );

  Future<void> _removeMember(String userId) async {
    final confirmed = await ConfirmDialog.show(context,
      title: 'Remove member?', message: 'Remove $userId from tenant?', destructive: true);
    if (!confirmed) return;
    try {
      await widget.api.delete('/api/v1/admin/tenants/${Uri.encodeComponent(widget.tenantId)}/members/${Uri.encodeComponent(userId)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Removed $userId')));
      _load();
    } catch (e) { if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("\$e"))); }
  }

  Widget _invitationsList(BuildContext context) => ListView(
    padding: const EdgeInsets.all(16),
    children: _invitations.isEmpty
      ? [const Center(child: Text('No pending invitations'))]
      : _invitations.map((inv) => Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.mail_outline),
            title: Text(inv['email']?.toString() ?? ''),
            subtitle: Text('Role: ${inv['role'] ?? 'member'}  Expires: ${inv['expires_at'] ?? inv['expiry'] ?? ''}'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: () => _resendInvitation(inv['id']?.toString() ?? ''),
                  child: const Text('Resend'),
                ),
                TextButton(
                  onPressed: () => _revokeInvitation(inv['id']?.toString() ?? ''),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                  child: const Text('Revoke'),
                ),
              ],
            ),
          ),
        )).toList(),
  );

  Future<void> _resendInvitation(String invId) async {
    try {
      await widget.api.post('/api/v1/admin/tenants/${Uri.encodeComponent(widget.tenantId)}/invitations/${Uri.encodeComponent(invId)}/resend', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation resent')));
    } catch (_) {}
  }

  Future<void> _revokeInvitation(String invId) async {
    final confirmed = await ConfirmDialog.show(context,
      title: 'Revoke invitation?', message: 'Revoke this invitation?', destructive: true);
    if (!confirmed) return;
    try {
      await widget.api.delete('/api/v1/admin/tenants/${Uri.encodeComponent(widget.tenantId)}/invitations/${Uri.encodeComponent(invId)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Invitation revoked')));
      _load();
    } catch (_) {}
  }

  Widget _usageView(BuildContext context) {
    final usage = _usage ?? {};
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (usage.isEmpty)
          const Center(child: Text('No usage data'))
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Tenant Usage', style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 16),
                  _usageRow('Active users', usage['active_users']?.toString() ?? '—'),
                  _usageRow('Total users', usage['total_users']?.toString() ?? '—'),
                  _usageRow('Token requests (24h)', usage['token_requests_24h']?.toString() ?? '—'),
                  _usageRow('Storage (MB)', usage['storage_mb']?.toString() ?? usage['storage']?.toString() ?? '—'),
                ],
              ),
            ),
          ),
      ],
    );
  }

  Widget _usageRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label),
      Text(value, style: const TextStyle(fontWeight: FontWeight.bold)),
    ]),
  );

  Future<void> _editTenant(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (_) => TenantFormDialog(client: widget.client, existing: _tenant),
    );
    if (result == true) _load();
  }
}
