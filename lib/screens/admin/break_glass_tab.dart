import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'dart:js_interop';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:web/web.dart' as web;
import 'admin_route.dart';

/// Break Glass (emergency access) management tab.
///
/// Allows operators to create, list, approve, revoke, and impersonate
/// break-glass sessions for emergency support access.
class BreakGlassTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SnaplinkAdminCapabilities capabilities;

  const BreakGlassTab({super.key, required this.api, required this.capabilities});

  @override
  State<BreakGlassTab> createState() => _BreakGlassTabState();
}

class _BreakGlassTabState extends State<BreakGlassTab> {
  static const _basePath = '/api/v1/admin/break-glass';

  final _targetCtrl = TextEditingController();
  final _reasonCtrl = TextEditingController();
  String _scope = 'readonly';
  String? _ttl;
  bool _requireApproval = false;
  String? _tenantId;

  List<Map<String, dynamic>> _sessions = const [];
  String? _error;
  bool _loading = false;
  bool _mutating = false;

  bool get _available => widget.capabilities.hasAnyPathPrefix(_basePath);

  @override
  void initState() {
    super.initState();
    _handleRoute();
    final p = () { if (mounted) _handleRoute(); };
    web.window.addEventListener('popstate', p.toJS);
  }

  @override
  void _handleRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    if (route.module != 'break-glass') return;
    if (route.isNew) { _create(); }
  }

  void dispose() {
    _targetCtrl.dispose();
    _reasonCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final data = await widget.api.get(_basePath);
      final items = data['sessions'] ?? data['grants'] ?? data['items'] ?? data['break_glass'] ?? [];
      if (!mounted) return;
      setState(() {
        _sessions = (items as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
        _loading = false;
      });
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    } catch (_) {
      if (mounted) setState(() { _error = 'Could not load break-glass sessions.'; _loading = false; });
    }
  }

  Future<void> _create() async {
    if (_targetCtrl.text.trim().isEmpty || _reasonCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Target user and reason are required.');
      return;
    }
    setState(() { _mutating = true; _error = null; });
    try {
      await widget.api.post(_basePath, {
        'target_user_id': _targetCtrl.text.trim(),
        'reason': _reasonCtrl.text.trim(),
        'scope': _scope,
        if (_ttl != null && _ttl!.isNotEmpty) 'ttl_seconds': int.tryParse(_ttl!),
        if (_requireApproval) 'require_approval': true,
        if (_tenantId != null && _tenantId!.isNotEmpty) 'tenant_id': _tenantId,
      });
      if (!mounted) return;
      _targetCtrl.clear(); _reasonCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Break-glass session created.'))); if (mounted) AdminRoute.go('emergency-access');
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } catch (_) {
      if (mounted) setState(() => _error = 'Failed to create break-glass session.');
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _approve(String id) async {
    final confirmed = await ConfirmDialog.show(context, title: 'Approve?', message: 'Approve this break-glass request?', confirmLabel: 'Approve', destructive: false);
    if (!confirmed) return;
    setState(() { _mutating = true; _error = null; });
    try {
      await widget.api.post('$_basePath/${Uri.encodeComponent(id)}/approve');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Break-glass approved.')));
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _revoke(String id) async {
    final confirmed = await ConfirmDialog.show(context, title: 'Revoke?', message: 'Revoke this break-glass session? This cannot be undone.', confirmLabel: 'Revoke', destructive: true);
    if (!confirmed) return;
    setState(() { _mutating = true; _error = null; });
    try {
      await widget.api.delete('$_basePath/${Uri.encodeComponent(id)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Break-glass revoked.')));
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _impersonate(String id) async {
    final confirmed = await ConfirmDialog.show(context, title: 'Impersonate?', message: 'Impersonate the target user? This action is audited.', confirmLabel: 'Impersonate', destructive: true);
    if (!confirmed) return;
    setState(() { _mutating = true; _error = null; });
    try {
      final data = await widget.api.post('$_basePath/${Uri.encodeComponent(id)}/impersonate');
      if (!mounted) return;
      final token = data['access_token']?.toString() ?? data['token']?.toString() ?? '';
      if (token.isNotEmpty) {
        await showDialog<void>(context: context, builder: (c) => AlertDialog(
          title: const Text('Impersonation token'),
          content: SelectableText(token, style: const TextStyle(fontFamily: 'monospace', fontSize: 12)),
          actions: [FilledButton(onPressed: () => Navigator.pop(c), child: const Text('Done'))],
        ));
      }
      await _load();
    } on SnaplinkAdminApiError catch (e) {
      if (mounted) setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_available) {
      return const Center(child: Text('Break-glass access is not enabled on this replica.'));
    }
    return ListView(padding: const EdgeInsets.all(16), children: [
      AdminBreadcrumb(),
      Text('Emergency access (Break Glass)', style: Theme.of(context).textTheme.headlineSmall),
      const SizedBox(height: 4),
      const Text('Create audited, time-bound emergency access to user accounts.'),
      if (_error != null) Padding(padding: const EdgeInsets.only(top: 8), child: Text(_error!, style: const TextStyle(color: Colors.redAccent))),
      const SizedBox(height: 16),
      _createCard(context),
      const SizedBox(height: 16),
      _listCard(context),
    ]);
  }

  Widget _createCard(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(padding: const EdgeInsets.all(16), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      Text('New break-glass request', style: Theme.of(context).textTheme.titleMedium),
      const SizedBox(height: 12),
      TextField(controller: _targetCtrl, decoration: const InputDecoration(labelText: 'Target user ID', hintText: 'user@example.com')),
      const SizedBox(height: 10),
      TextField(controller: _reasonCtrl, decoration: const InputDecoration(labelText: 'Reason (ticket/incident ref)', hintText: 'INC-12345'), maxLines: 2),
      const SizedBox(height: 10),
      DropdownButtonFormField<String>(
        initialValue: _scope, decoration: const InputDecoration(labelText: 'Scope'),
        items: const [
          DropdownMenuItem(value: 'readonly', child: Text('Read-only')),
          DropdownMenuItem(value: 'impersonate', child: Text('Impersonate')),
          DropdownMenuItem(value: 'escalate', child: Text('Escalate')),
        ],
        onChanged: (v) => setState(() => _scope = v ?? 'readonly'),
      ),
      const SizedBox(height: 10),
      TextField(controller: null, decoration: const InputDecoration(labelText: 'TTL (seconds, default 900)'), onChanged: (v) => _ttl = v),
      CheckboxListTile(contentPadding: EdgeInsets.zero, title: const Text('Require approval'), value: _requireApproval, onChanged: (v) => setState(() => _requireApproval = v ?? false)),
      const SizedBox(height: 10),
      FilledButton(onPressed: () => AdminRoute.go('emergency-access', action: 'new'), child: _mutating
        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2))
        : const Text('Create break-glass request')),
    ])),
  );

  Widget _listCard(BuildContext context) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    Row(children: [
      Text('Sessions', style: Theme.of(context).textTheme.titleMedium),
      const Spacer(),
      IconButton(onPressed: _loading ? null : _load, icon: const Icon(Icons.refresh)),
    ]),
    if (_loading) const LinearProgressIndicator(),
    if (!_loading && _sessions.isEmpty) const Padding(padding: EdgeInsets.only(top: 12), child: Text('No break-glass sessions.')),
    if (!_loading) for (final s in _sessions) _sessionCard(context, s),
  ]);

  Widget _sessionCard(BuildContext context, Map<String, dynamic> s) {
    final id = s['id']?.toString() ?? '';
    final targetUser = s['target_user_id']?.toString() ?? s['target_user']?.toString() ?? '';
    final status = s['status']?.toString() ?? 'unknown';
    final reason = s['reason']?.toString() ?? '';
    final createdBy = s['created_by']?.toString() ?? '';
    final scope = s['scope']?.toString() ?? 'readonly';
    final pending = status == 'pending';
    final active = status == 'active';
    return Card(
      margin: const EdgeInsets.only(top: 8),
      child: ListTile(
        onTap: () => AdminRoute.go('emergency-access', resourceId: id),
        leading: Icon(
          pending ? Icons.hourglass_empty : active ? Icons.flash_on : Icons.cancel,
          color: pending ? Colors.orange : active ? Colors.green : Colors.grey,
        ),
        title: Text('$targetUser · $status'),
        subtitle: Text('$reason\nby $createdBy · scope: $scope · $id'),
        isThreeLine: true,
        trailing: Row(mainAxisSize: MainAxisSize.min, children: [
          if (pending)
            TextButton(onPressed: _mutating ? null : () => _approve(id), child: const Text('Approve')),
          if (active)
            TextButton(onPressed: _mutating ? null : () => _impersonate(id), child: const Text('Impersonate')),
          if (pending || active)
            TextButton(onPressed: _mutating ? null : () => _revoke(id), style: TextButton.styleFrom(foregroundColor: Colors.redAccent), child: const Text('Revoke')),
        ]),
      ),
    );
  }
}
