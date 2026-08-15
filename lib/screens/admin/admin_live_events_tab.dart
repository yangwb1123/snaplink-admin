import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/audit_read_client.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/admin_breadcrumb.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/section_header.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';
import 'package:sso_admin/widgets/status_chip.dart';

import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'snaplink_admin_api.dart';

/// Realtime, redacted audit activity backed by Snaplink's SSE endpoint.
///
/// The view is deliberately bounded: it is an incident-response feed rather
/// than an unbounded in-browser audit store. Complete event data remains on
/// the audited query endpoint and is fetched only on explicit operator input.
class AdminLiveEventsTab extends StatefulWidget {
  final SnaplinkAdminApi api;
  final List<SnaplinkAdminEndpoint> endpoints;

  const AdminLiveEventsTab({
    super.key,
    required this.api,
    required this.endpoints,
  });

  @override
  State<AdminLiveEventsTab> createState() => _AdminLiveEventsTabState();
}

class _AdminLiveEventsTabState extends State<AdminLiveEventsTab> {
  static const _maximumEvents = 50;

  final _typesCtrl = TextEditingController();
  final _tenantCtrl = TextEditingController();
  final _events = <SnaplinkAdminEvent>[];
  StreamSubscription<SnaplinkAdminEvent>? _subscription;
  Timer? _reconnectTimer;
  String? _lastEventId;
  String? _error;
  bool _connecting = false;
  bool _connected = false;
  bool _reconnectWanted = false;
  int _connectionGeneration = 0;
  int _reconnectAttempt = 0;

  /// Module accent: live-activity inherits the developers group (emerald).
  Color get _accent => adminModuleIconColor(AdminModuleId.liveActivity);

  bool get _advertised => widget.endpoints.any(
    (endpoint) =>
        endpoint.method == 'GET' &&
        endpoint.path == '/api/v1/admin/events/stream',
  );

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _typesCtrl.dispose();
    _tenantCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    _reconnectWanted = true;
    _reconnectAttempt = 0;
    _reconnectTimer?.cancel();
    await _openConnection(clearError: true);
  }

  Future<void> _openConnection({bool clearError = false}) async {
    final generation = ++_connectionGeneration;
    await _subscription?.cancel();
    if (!mounted) return;
    setState(() {
      _connecting = true;
      _connected = false;
      if (clearError) _error = null;
    });
    final stream = widget.api.streamAdminEvents(
      eventTypes: _typesCtrl.text,
      tenantId: _tenantCtrl.text,
      lastEventId: _lastEventId,
    );
    _subscription = stream.listen(
      (event) {
        if (!mounted || generation != _connectionGeneration) return;
        setState(() {
          _lastEventId = event.id ?? _lastEventId;
          _events.insert(0, event);
          if (_events.length > _maximumEvents) _events.removeLast();
          _connecting = false;
          _connected = true;
          _reconnectAttempt = 0;
        });
      },
      onError: (Object error) {
        if (!mounted || generation != _connectionGeneration) return;
        _scheduleReconnect(error);
      },
      onDone: () {
        if (!mounted || generation != _connectionGeneration) return;
        _scheduleReconnect();
      },
    );
    if (mounted) {
      // `send` stays pending while an SSE connection is open. The listener is
      // now active; a transport or authorization failure will still replace
      // this optimistic state through `onError`.
      setState(() {
        _connecting = false;
        _connected = true;
      });
    }
  }

  void _scheduleReconnect([Object? error]) {
    if (error is SnaplinkAdminApiError && error.status == 401) {
      _reconnectWanted = false;
    }
    if (!_reconnectWanted || _reconnectTimer != null || !mounted) {
      if (mounted) {
        setState(() {
          _connecting = false;
          _connected = false;
          if (error != null) {
            _error = error is SnaplinkAdminApiError
                ? error.toString()
                : 'The event stream disconnected.';
          }
        });
      }
      return;
    }
    final seconds = switch (_reconnectAttempt++) {
      0 => 1,
      1 => 2,
      2 => 5,
      3 => 10,
      _ => 30,
    };
    setState(() {
      _connecting = false;
      _connected = false;
      _error = error is SnaplinkAdminApiError
          ? '${error.toString()} Retrying in $seconds seconds.'
          : 'The event stream disconnected. Retrying in $seconds seconds.';
    });
    _reconnectTimer = Timer(Duration(seconds: seconds), () {
      _reconnectTimer = null;
      if (_reconnectWanted && mounted) _openConnection();
    });
  }

  Future<void> _disconnect() async {
    _reconnectWanted = false;
    _connectionGeneration++;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _subscription?.cancel();
    _subscription = null;
    if (mounted) setState(() => _connected = false);
  }

  Future<void> _showDetail(SnaplinkAdminEvent event) async {
    final id = event.id ?? event.data['id']?.toString();
    if (id == null || id.isEmpty) return;
    try {
      final detail = await widget.api.get(
        '${AuditReadClient.eventsPath}/${Uri.encodeComponent(id)}',
      );
      if (!mounted) return;
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: LocalizedText('Audit event {id}', args: {'id': id}),
          // 评估为无需 lazy：单个 SelectableText（完整审计记录），固定内容。
          content: SingleChildScrollView(
            child: SelectableText(
              const JsonEncoder.withIndent('  ').convert(detail),
              style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const LocalizedText('Close'),
            ),
          ],
        ),
      );
    } on SnaplinkAdminApiError catch (error) {
      if (mounted) setState(() => _error = error.toString());
    }
  }

  String _summary(SnaplinkAdminEvent event) {
    final fields = [
      'outcome',
      'actor_id',
      'tenant_id',
      'client_id',
      'resource',
      'timestamp',
    ];
    final values = fields
        .map((field) => event.data[field]?.toString())
        .whereType<String>()
        .where((value) => value.isNotEmpty)
        .toList(growable: false);
    return values.isEmpty ? 'Redacted event summary' : values.join(' · ');
  }

  // ---- presentational helpers ----

  Widget _connectionChip() {
    if (_connecting) {
      return StatusChip(
        label: context.tr('Connecting…'),
        color: AppColors.accentBlue,
        icon: Icons.sync,
      );
    }
    return StatusChip(
      label: context.tr(_connected ? 'Connected' : 'Disconnected'),
      color: _connected ? AppColors.success : AppColors.muted,
      icon: _connected ? Icons.wifi : Icons.wifi_off,
    );
  }

  /// Error banner; Retry covers terminal stops (e.g. 401), auto-reconnect
  /// carries its countdown in the message.
  Widget _errorCard() => ErrorStateCard(
    message: _error!,
    onRetry: _reconnectWanted ? null : _connect,
  );

  /// Loading / empty states for the feed. Event rows are deliberately not
  /// built here: [build] renders them lazily through [ListView.builder] so a
  /// rebuild on each incoming SSE event only mounts the visible rows instead
  /// of rebuilding the whole retained feed (bounded at 50).
  List<Widget> _feedTail() {
    if (_connecting) return const [SkeletonListTile(itemCount: 4)];
    return const [
      EmptyState(variant: EmptyStateVariant.empty, title: 'No events received yet.'),
    ];
  }

  /// Tappable row keeps the monospace id for the detail-read interaction.
  Widget _eventRow(SnaplinkAdminEvent event) {
    final theme = Theme.of(context);
    return Card(
      child: ListTile(
        onTap: () => _showDetail(event),
        leading: Icon(Icons.notifications_outlined, color: _accent),
        title: Text(event.data['type']?.toString() ?? event.type),
        subtitle: Text(_summary(event)),
        trailing: event.id == null
            ? null
            : Text(
                event.id!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Fixed header block; the data-driven feed rows below are rendered lazily
    // by ListView.builder so each incoming SSE event (which triggers a
    // rebuild) rebuilds only the visible rows instead of the full retained
    // feed. Scroll semantics and the bounded 50-event retention are unchanged.
    final header = <Widget>[
      AdminBreadcrumb(),
      const SizedBox(height: 4),
      Row(
        children: [
          Icon(Icons.sensors_outlined, color: _accent),
          const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              container: true,
              header: true,
              child: Text(
                AppStrings.of(context).liveActivity,
                style: theme.textTheme.headlineSmall,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 8),
      LocalizedText(
        _advertised
            ? 'The replica advertises the event broker. The feed shows only Snaplink\'s redacted event summaries; select an item to request its full audit record.'
            : 'The documented event broker is not listed by this replica\'s inventory. You can connect when the route is mounted; otherwise use audit queries.',
      ),
      const SizedBox(height: 16),
      Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          SizedBox(
            width: 280,
            child: TextField(
              controller: _typesCtrl,
              enabled: !_connecting && !_connected,
              decoration: InputDecoration(
                labelText: 'Event types'.localized,
                helperText:
                    'Comma-separated; empty includes all types.'.localized,
              ),
            ),
          ),
          SizedBox(
            width: 280,
            child: TextField(
              controller: _tenantCtrl,
              enabled: !_connecting && !_connected,
              decoration: InputDecoration(
                labelText: 'Tenant ID (optional)'.localized,
              ),
            ),
          ),
        ],
      ),
      const SizedBox(height: 12),
      Wrap(
        spacing: 8,
        children: [
          FilledButton.icon(
            onPressed: _connecting || _connected ? null : _connect,
            icon: const Icon(Icons.play_arrow),
            label: LocalizedText(_connecting ? 'Connecting…' : 'Connect'),
          ),
          OutlinedButton.icon(
            onPressed: _connected || _connecting ? _disconnect : null,
            icon: const Icon(Icons.stop),
            label: const LocalizedText('Disconnect'),
          ),
          TextButton(
            onPressed: _events.isEmpty
                ? null
                : () => setState(() => _events.clear()),
            child: const LocalizedText('Clear feed'),
          ),
        ],
      ),
      if (_error != null) ...[const SizedBox(height: 12), _errorCard()],
      const SizedBox(height: 16),
      Row(
        children: [
          _connectionChip(),
          if (_connected) ...[const SizedBox(height: 8), LocalizedText(
            'Connected · latest {count} events are retained locally.',
            args: {'count': _maximumEvents},
            style: theme.textTheme.titleSmall,
          )],
        ],
      ),
      const SizedBox(height: 16),
      SectionHeader(
        'Live event feed',
        count: _events.isEmpty ? null : _events.length,
      ),
      const SizedBox(height: 8),
    ];
    // Loading / empty tails are a handful of widgets and stay eager; the
    // event rows are the lazy part.
    final tail = _events.isNotEmpty ? const <Widget>[] : _feedTail();
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount:
          header.length + (_events.isNotEmpty ? _events.length : tail.length),
      itemBuilder: (context, index) {
        if (index < header.length) return header[index];
        if (_events.isNotEmpty) {
          return _eventRow(_events[index - header.length]);
        }
        return tail[index - header.length];
      },
    );
  }
}
