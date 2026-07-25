import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_route.dart';
import 'package:web/web.dart' as web;

/// Emergency (break-glass) access session detail.
/// URL: /admin/emergency-access/{id}[/approve|/reject]
class BreakGlassDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SSOAdminClient client;
  final String sessionId;

  const BreakGlassDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.sessionId,
  });

  @override
  State<BreakGlassDetailScreen> createState() => _BreakGlassDetailScreenState();
}

class _BreakGlassDetailScreenState extends State<BreakGlassDetailScreen> {
  Map<String, dynamic>? _session;
  String? _error;
  bool _loading = true;
  bool _mutating = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final result = await _fetchSession();
      if (!mounted) return;
      setState(() { _session = result; _loading = false; });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  Future<Map<String, dynamic>?> _fetchSession() async {
    // Try the main break-glass endpoint
    try {
      final result = await widget.api.get(
        '/api/v1/admin/break-glass/${Uri.encodeComponent(widget.sessionId)}');
      return result as Map<String, dynamic>?;
    } catch (_) {}
    // Fallback: scan sessions list
    try {
      final list = await widget.api.get('/api/v1/admin/break-glass');
      final sessions = (list as Map<String, dynamic>?)?.values.first as List? ?? [];
      for (final s in sessions) {
        if (s['id']?.toString() == widget.sessionId) return s as Map<String, dynamic>?;
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Emergency Access: ${widget.sessionId}'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => AdminRoute.go('emergency-access'),
      ),
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
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _infoCard(context),
                const SizedBox(height: 16),
                if (_isPending) _actionsCard(context),
                const SizedBox(height: 16),
                _auditCard(context),
              ]),
            )),
          ]),
  );

  bool get _isPending => _session?['status']?.toString() == 'pending';

  Widget _infoCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.warning_amber, size: 40, color: Colors.orange),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Break-Glass Session',
                  style: Theme.of(context).textTheme.titleMedium),
                Text('ID: ${widget.sessionId}'),
              ],
            )),
            _statusChip(),
          ]),
          const Divider(),
          _infoRow('Requested by', _session?['requested_by']?.toString() ?? '—'),
          _infoRow('Reason', _session?['reason']?.toString() ?? '—'),
          _infoRow('Target role', _session?['target_role']?.toString() ?? '—'),
          _infoRow('Expires', _session?['expires_at']?.toString() ?? _session?['expiry']?.toString() ?? '—'),
        ],
      ),
    ),
  );

  Widget _statusChip() {
    final status = _session?['status']?.toString() ?? 'unknown';
    Color bg;
    switch (status) {
      case 'active': bg = Colors.red.shade100; break;
      case 'approved': bg = Colors.green.shade100; break;
      case 'pending': bg = Colors.orange.shade100; break;
      case 'rejected': bg = Colors.grey.shade200; break;
      default: bg = Colors.grey.shade200;
    }
    return Chip(label: Text(status), backgroundColor: bg);
  }

  Widget _actionsCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Actions', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _mutating ? null : () => _approve(),
                icon: const Icon(Icons.check),
                label: const Text('Approve'),
                style: FilledButton.styleFrom(backgroundColor: Colors.green),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _mutating ? null : () => _reject(),
                icon: const Icon(Icons.close),
                label: const Text('Reject'),
                style: OutlinedButton.styleFrom(foregroundColor: Colors.redAccent),
              ),
            ),
          ]),
        ],
      ),
    ),
  );

  Widget _auditCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Audit Trail', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          if (_session?['audit'] != null)
            ...((_session!['audit'] as List?) ?? []).map((entry) => Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text('• ${entry['action'] ?? ''} by ${entry['actor'] ?? ''} at ${entry['timestamp'] ?? ''}'),
            ))
          else
            const Text('No audit entries'),
        ],
      ),
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 120, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
      Expanded(child: Text(value.isEmpty ? '—' : value)),
    ]),
  );

  Future<void> _approve() async {
    final confirmed = await ConfirmDialog.show(context,
      title: 'Approve emergency access?', message: 'Grant ${_session?['requested_by'] ?? ''} access?', destructive: false);
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.post(
        '/api/v1/admin/break-glass/${Uri.encodeComponent(widget.sessionId)}/approve', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Approved')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _mutating = false); }
  }

  Future<void> _reject() async {
    final confirmed = await ConfirmDialog.show(context,
      title: 'Reject emergency access?', message: 'Reject this request?', destructive: true);
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.post(
        '/api/v1/admin/break-glass/${Uri.encodeComponent(widget.sessionId)}/reject', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Rejected')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally { if (mounted) setState(() => _mutating = false); }
  }
}
