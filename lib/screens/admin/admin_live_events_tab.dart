import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:sso_admin/api/admin_paths.dart';
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

part 'admin_live_events_tab_view.dart';

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
  final _searchCtrl = TextEditingController();
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
        endpoint.path == AdminPaths.adminEventStream,
  );

  @override
  void dispose() {
    _reconnectTimer?.cancel();
    _subscription?.cancel();
    _typesCtrl.dispose();
    _tenantCtrl.dispose();
    _searchCtrl.dispose();
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
    // Disconnect may be pressed while cancellation is still awaiting the
    // browser reader. Do not resurrect a connection from that stale open.
    if (!mounted || generation != _connectionGeneration || !_reconnectWanted) {
      return;
    }
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
    if (mounted) {
      setState(() {
        _connecting = false;
        _connected = false;
      });
    }
  }

  Future<void> _showDetail(SnaplinkAdminEvent event) async {
    final id = _eventId(event);
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

  String? _eventId(SnaplinkAdminEvent event) =>
      event.id ?? event.data['id']?.toString();

  List<SnaplinkAdminEvent> get _visibleEvents {
    final query = _searchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) return _events;
    return _events
        .where((event) {
          final haystack = <String>[
            event.id ?? '',
            event.type,
            event.data.toString(),
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  void _clearSearch() {
    _searchCtrl.clear();
    if (mounted) setState(() {});
  }

  void _onSearchChanged(String _) {
    if (mounted) setState(() {});
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

  void _clearFeed() {
    setState(_events.clear);
  }

  @override
  Widget build(BuildContext context) => _buildAdminLiveEventsTab(context);
}
