import 'dart:js_interop';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_route.dart';
import 'package:web/web.dart' as web;

/// Webhook detail screen with dead letter queue.
/// URL: /admin/webhooks/{id}[/deadletters]
class WebhookDetailScreen extends StatefulWidget {
  final SnaplinkAdminApi api;
  final SSOAdminClient client;
  final String subId;

  const WebhookDetailScreen({
    super.key,
    required this.api,
    required this.client,
    required this.subId,
  });

  @override
  State<WebhookDetailScreen> createState() => _WebhookDetailScreenState();
}

class _WebhookDetailScreenState extends State<WebhookDetailScreen> {
  Map<String, dynamic>? _sub;
  List<dynamic> _deadLetters = [];
  String? _error;
  bool _loading = true;
  bool _mutating = false;
  bool _showDeadLetters = false;

  @override
  void initState() {
    super.initState();
    _handleRoute();
    void p() { if (mounted) _handleRoute(); }
    web.window.addEventListener('popstate', p.toJS);
    _load();
    if (AdminRoute.fromUri(Uri.base).subresource == 'deadletters') {
      _showDeadLetters = true;
    }
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final sid = Uri.encodeComponent(widget.subId);
      final sub = await widget.api.get('/api/v1/admin/webhooks/subscriptions/$sid');
      List<dynamic> dead = [];
      try {
        final d = await widget.api.get('/api/v1/admin/webhooks/subscriptions/$sid/deadletters');
        dead = (d as Map<String, dynamic>?)?.values.first as List? ?? [];
      } catch (e) { debugPrint("webhook dead letters error: \$e"); }
      if (!mounted) return;
      setState(() {
        _sub = sub as Map<String, dynamic>?;
        _deadLetters = dead;
        _loading = false;
      });
    } catch (e) {
      if (mounted) setState(() { _error = e.toString(); _loading = false; });
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text('Webhook: ${widget.subId}'),
      leading: IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => AdminRoute.go('webhooks'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete subscription',
          onPressed: () => _delete(context),
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
            Expanded(child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(children: [
                _infoCard(context),
                const SizedBox(height: 16),
                _eventsCard(context),
                const SizedBox(height: 16),
                _deadLetterSection(context),
              ]),
            )),
          ]),
  );

  Widget _infoCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            const Icon(Icons.webhook, size: 40),
            const SizedBox(width: 12),
            Expanded(child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Webhook #${widget.subId}',
                  style: Theme.of(context).textTheme.titleMedium),
                Text('URL: ${_sub?['url']?['url'] ?? _sub?['url'] ?? '—'}'),
              ],
            )),
            Chip(
              label: Text(_sub?['active'] == true ? 'Active' : 'Inactive'),
              backgroundColor: _sub?['active'] == true
                ? Colors.green.shade100 : Colors.grey.shade200,
            ),
          ]),
          const Divider(),
          _infoRow('Created', _sub?['created_at']?.toString() ?? '—'),
          _infoRow('Updated', _sub?['updated_at']?.toString() ?? '—'),
        ],
      ),
    ),
  );

  Widget _eventsCard(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Subscribed Events', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: (_events()).map((e) => Chip(
              label: Text(e, style: const TextStyle(fontSize: 12)),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            )).toList(),
          ),
        ],
      ),
    ),
  );

  List<String> _events() {
    final events = _sub?['events'] ?? _sub?['event_types'] ?? [];
    if (events is List) return events.map((e) => e.toString()).toList();
    if (events is Map) return events.keys.map((k) => k.toString()).toList();
    return [];
  }

  Widget _deadLetterSection(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => setState(() => _showDeadLetters = !_showDeadLetters),
            child: Row(children: [
              Text('Dead Letters (${_deadLetters.length})',
                style: Theme.of(context).textTheme.titleMedium),
              const Spacer(),
              Icon(_showDeadLetters ? Icons.expand_less : Icons.expand_more),
            ]),
          ),
          if (_showDeadLetters) ...[
            const SizedBox(height: 8),
            if (_deadLetters.isEmpty)
              const Text('No dead letters')
            else
              ...(_deadLetters.take(20)).map((dl) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Card(
                  color: Colors.red.shade50,
                  child: ListTile(
                    title: Text(dl['event_type']?.toString() ?? 'Event'),
                    subtitle: Text('${dl['error']?.toString() ?? ''}\n${dl['failed_at']?.toString() ?? ''}'),
                    trailing: TextButton(
                      onPressed: _mutating ? null : () => _replay(dl['id']?.toString() ?? ''),
                      child: const Text('Replay'),
                    ),
                  ),
                ),
              )),
            if (_deadLetters.length > 20)
              Text('+ ${_deadLetters.length - 20} more', style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            if (_deadLetters.isNotEmpty)
              OutlinedButton(
                onPressed: _mutating ? null : () => _replayAll(),
                child: const Text('Replay all dead letters'),
              ),
          ],
        ],
      ),
    ),
  );

  Widget _infoRow(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))),
      Expanded(child: Text(value.isEmpty ? '—' : value)),
    ]),
  );

  Future<void> _replay(String dlId) async {
    setState(() => _mutating = true);
    try {
      await widget.api.post(
        '/api/v1/admin/webhooks/deadletters/${Uri.encodeComponent(dlId)}/replay', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Replayed')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _replayAll() async {
    final confirmed = await ConfirmDialog.show(context,
      title: 'Replay all?', message: 'Replay all ${_deadLetters.length} dead letters?', destructive: false);
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.post(
        '/api/v1/admin/webhooks/subscriptions/${Uri.encodeComponent(widget.subId)}/deadletters/replay', {});
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('All replayed')));
      _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(context,
      title: 'Delete webhook?', message: 'Delete this subscription?', destructive: true);
    if (!confirmed) return;
    try {
      await widget.api.delete('/api/v1/admin/webhooks/subscriptions/${Uri.encodeComponent(widget.subId)}');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      AdminRoute.go('webhooks');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  void _handleRoute() {
    final route = AdminRoute.fromUri(Uri.base);
    if (route.module != 'webhooks') return;
  }
}

