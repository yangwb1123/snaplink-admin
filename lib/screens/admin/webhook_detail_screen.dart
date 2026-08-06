import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/services/browser_navigation.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/api/sso_client.dart';
import 'package:sso_admin/widgets/confirm_dialog.dart';
import 'admin_route.dart';
import 'webhook_detail_widgets.dart';

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
  late final void Function() _cancelPopState;

  @override
  void initState() {
    super.initState();
    _handleRoute();
    _cancelPopState = BrowserNavigation.listenToLocationChange(() {
      if (mounted) _handleRoute();
    });
    _load();
    if (AdminRoute.current().subresource == 'deadletters') {
      _showDeadLetters = true;
    }
  }

  @override
  void dispose() {
    _cancelPopState();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        widget.api.get('/api/v1/admin/webhooks/subscriptions'),
        widget.api.get('/api/v1/admin/webhooks/deadletters'),
      ]);
      final subscriptions = results.first['subscriptions'] as List? ?? const [];
      final sub = subscriptions
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .where((item) => item['id']?.toString() == widget.subId)
          .firstOrNull;
      if (sub == null) {
        throw const SnaplinkAdminApiError(
          404,
          code: 'webhook_not_found',
          description: 'Webhook subscription was not found.',
        );
      }
      final allDeadLetters =
          results.last['deadletters'] as List? ??
          results.last['dead_letters'] as List? ??
          const [];
      final dead = allDeadLetters.whereType<Map>().where((item) {
        final subscriptionId =
            item['subscription_id'] ??
            item['subscriptionId'] ??
            item['webhook_id'];
        return subscriptionId?.toString() == widget.subId;
      }).toList();
      if (!mounted) return;
      setState(() {
        _sub = sub;
        _deadLetters = dead;
        _loading = false;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _loading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: LocalizedText('Webhook: ${widget.subId}'),
      leading: IconButton(
        tooltip: 'Back'.localized,
          icon: const Icon(Icons.arrow_back),
        onPressed: () => AdminRoute.go('webhooks'),
      ),
      actions: [
        IconButton(
          icon: const Icon(Icons.delete_outline),
          tooltip: 'Delete subscription'.localized,
          onPressed: _mutating ? null : () => _delete(context),
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
                const Icon(
                  Icons.error_outline,
                  size: 48,
                  color: Colors.redAccent,
                ),
                const SizedBox(height: 16),
                LocalizedText(
                  'Failed to load',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 32),
                  child: Text(
                    _error!,
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey.shade600,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                OutlinedButton.icon(
                  onPressed: _load,
                  icon: const Icon(Icons.refresh),
                  label: const LocalizedText('Retry'),
                ),
              ],
            ),
          )
        : Column(
            children: [
              AdminBreadcrumb(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      WebhookInfoCard(
                        subscriptionId: widget.subId,
                        subscription: _sub,
                      ),
                      const SizedBox(height: 16),
                      WebhookEventsCard(subscription: _sub),
                      const SizedBox(height: 16),
                      WebhookDeadLetterSection(
                        deadLetters: _deadLetters,
                        expanded: _showDeadLetters,
                        mutating: _mutating,
                        onToggle: () => setState(
                          () => _showDeadLetters = !_showDeadLetters,
                        ),
                        onReplay: _replay,
                        onReplayAll: _replayAll,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
  );

  Future<void> _replay(String dlId) async {
    if (dlId.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Replay webhook delivery?',
      message:
          'This sends the stored event to the subscription’s current URL '
          'using its current secret. The receiver may repeat a business action.',
      confirmLabel: 'Replay delivery',
      destructive: true,
      confirmText: dlId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      final response = await widget.api.post(
        '/api/v1/admin/webhooks/deadletters/${Uri.encodeComponent(dlId)}/replay',
        {},
      );
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final cleanupComplete = response['cleanup_status'] == 'complete';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: LocalizedText(
            cleanupComplete
                ? 'Delivery sent and dead-letter cleanup completed.'
                : 'Delivery succeeded; cleanup remains pending. Retrying this '
                      'entry is cleanup-only and cannot redeliver it.',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LocalizedText('$e')));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _replayAll() async {
    final ids = _deadLetters
        .whereType<Map>()
        .map((item) => item['id']?.toString() ?? '')
        .where((id) => id.isNotEmpty)
        .toList(growable: false);
    if (ids.isEmpty) return;
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Replay all?',
      message:
          'Send all ${ids.length} stored events again. Receivers may repeat '
          'business actions. Each result is reported independently.',
      confirmLabel: 'Replay all deliveries',
      destructive: true,
      confirmText: 'REPLAY ${ids.length}',
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    // Parallel replay: independent per-id operations (N+1 fix — the
    // sequential await-per-id loop is replaced with Future.wait).
    final results = await Future.wait(ids.map((id) async {
      try {
        final response = await widget.api.post(
          '/api/v1/admin/webhooks/deadletters/'
              '${Uri.encodeComponent(id)}/replay',
          {},
        );
        return (
          delivered: 1,
          cleanupPending: response['cleanup_status'] != 'complete' ? 1 : 0,
          failed: 0,
        );
      } catch (_) {
        return (delivered: 0, cleanupPending: 0, failed: 1);
      }
    }));
    var delivered = 0;
    var cleanupPending = 0;
    var failed = 0;
    for (final r in results) {
      delivered += r.delivered;
      cleanupPending += r.cleanupPending;
      failed += r.failed;
    }
    try {
      if (!mounted) return;
      await _load();
      if (!mounted) return;
      final remainingQueued = _deadLetters
          .whereType<Map>()
          .map((item) => item['id']?.toString() ?? '')
          .where(ids.contains)
          .length;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            cleanupPending > 0
                ? '$delivered deliveries succeeded; cleanup is pending for '
                      '$cleanupPending. Retrying those entries is cleanup-only '
                      'and cannot redeliver them.'
                : failed == 0
                ? 'All $delivered deliveries were sent and cleaned up.'
                : '$delivered deliveries were sent; $failed failed.',
          ),
        ),
      );
      if (failed > 0 || cleanupPending > 0 || remainingQueued > 0) {
        setState(
          () => _error =
              'Replay result: $delivered delivered, $failed failed, '
              '$cleanupPending awaiting cleanup, and $remainingQueued '
              'selected dead letters remain visible.',
        );
      }
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  Future<void> _delete(BuildContext context) async {
    final confirmed = await ConfirmDialog.show(
      context,
      title: 'Delete webhook?',
      message: 'Delete this subscription?',
      destructive: true,
      confirmText: widget.subId,
    );
    if (!confirmed) return;
    setState(() => _mutating = true);
    try {
      await widget.api.delete(
        '/api/v1/admin/webhooks/subscriptions/${Uri.encodeComponent(widget.subId)}',
      );
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: LocalizedText('Deleted')));
      AdminRoute.go('webhooks');
    } catch (e) {
      if (!context.mounted) return;
      // ignore: use_build_context_synchronously
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: LocalizedText('$e')));
    } finally {
      if (mounted) setState(() => _mutating = false);
    }
  }

  void _handleRoute() {
    final route = AdminRoute.current();
    if (route.module != 'webhooks') return;
  }
}
