import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';

import 'portal_api.dart';
import 'portal_security_contract.dart';
import 'portal_widgets.dart';

class DeviceDetailDialog extends StatefulWidget {
  final PortalApi api;
  final Map<String, dynamic> device;

  const DeviceDetailDialog({
    super.key,
    required this.api,
    required this.device,
  });

  static Future<void> show(
    BuildContext context, {
    required PortalApi api,
    required Map<String, dynamic> device,
  }) => showDialog<void>(
    context: context,
    builder: (_) => DeviceDetailDialog(api: api, device: device),
  );

  @override
  State<DeviceDetailDialog> createState() => _DeviceDetailDialogState();
}

class _DeviceDetailDialogState extends State<DeviceDetailDialog> {
  Map<String, dynamic>? _detail;
  List<Map<String, dynamic>> _activity = const [];
  List<Map<String, dynamic>> _sessions = const [];
  bool _detailLoading = true;
  bool _activityLoading = true;
  bool _sessionsLoading = true;
  String? _detailError;
  String? _activityError;
  String? _sessionsError;

  String get _id => widget.device['id']?.toString() ?? '';

  @override
  void initState() {
    super.initState();
    _loadDetail();
    _loadActivity();
    _loadSessions();
  }

  Future<void> _loadDetail() async {
    try {
      final response = await widget.api.get(PortalSecurityPaths.device(_id));
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() => _detail = PortalApi.decode(response));
      } else {
        setState(() => _detailError = 'Device details are unavailable.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _detailError = 'Device details are unavailable.');
      }
    } finally {
      if (mounted) setState(() => _detailLoading = false);
    }
  }

  Future<void> _loadActivity() async {
    try {
      final response = await widget.api.get(
        PortalSecurityPaths.deviceActivity(_id),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _activity = portalObjectList(PortalApi.decode(response), 'activity');
        });
      } else {
        setState(() => _activityError = 'Activity is not available.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _activityError = 'Activity is not available.');
      }
    } finally {
      if (mounted) setState(() => _activityLoading = false);
    }
  }

  Future<void> _loadSessions() async {
    try {
      final response = await widget.api.get(
        PortalSecurityPaths.deviceSessions(_id),
      );
      if (!mounted) return;
      if (response.statusCode == 200) {
        setState(() {
          _sessions = portalObjectList(PortalApi.decode(response), 'sessions');
        });
      } else {
        setState(() => _sessionsError = 'Sessions are not available.');
      }
    } catch (_) {
      if (mounted) {
        setState(() => _sessionsError = 'Sessions are not available.');
      }
    } finally {
      if (mounted) setState(() => _sessionsLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final device = <String, dynamic>{...widget.device, ...?_detail};
    return AlertDialog(
      title: Text(
        device['device_name']?.toString().isNotEmpty == true
            ? device['device_name'].toString()
            : context.tr('Device details'),
      ),
      content: SizedBox(
        width: 680,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _detailsSection(device),
              const Divider(height: 32),
              _activitySection(),
              const Divider(height: 32),
              _sessionsSection(),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.tr('Close')),
        ),
      ],
    );
  }

  Widget _detailsSection(Map<String, dynamic> device) {
    if (_detailLoading) return const LinearProgressIndicator();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          context.tr('Posture'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        if (_detailError != null) MessageBanner(_detailError),
        KvRow('Device ID', _id),
        if (device['type'] != null) KvRow('Type', '${device['type']}'),
        if (device['platform'] != null)
          KvRow(
            'Platform',
            '${device['platform']} ${device['os_version'] ?? ''}'.trim(),
          ),
        if (device['browser_name'] != null)
          KvRow(
            'Browser',
            '${device['browser_name']} ${device['browser_version'] ?? ''}'
                .trim(),
          ),
        if (device['last_ip'] != null) KvRow('Last IP', '${device['last_ip']}'),
        if (device['last_location'] != null)
          KvRow('Location', '${device['last_location']}'),
        KvRow(
          'Trust',
          '${device['trust_label'] ?? context.tr('Unknown')}'
              '${device['trust_score'] == null ? '' : ' (${device['trust_score']})'}',
        ),
        if (device['first_seen_at'] != null)
          KvRow('First seen', '${device['first_seen_at']}'),
        if (device['last_seen_at'] != null)
          KvRow('Last seen', '${device['last_seen_at']}'),
        if (device['notes']?.toString().isNotEmpty == true)
          KvRow('Notes', device['notes'].toString()),
      ],
    );
  }

  Widget _activitySection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('Recent activity'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (_activityLoading)
        const LinearProgressIndicator()
      else if (_activityError != null)
        MessageBanner(_activityError)
      else if (_activity.isEmpty)
        const EmptyHint('No recorded login activity.')
      else
        for (final event in _activity)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Icon(
              event['success'] == false
                  ? Icons.error_outline
                  : Icons.login_outlined,
            ),
            title: Text(
              context.tr(event['success'] == false ? 'Failed login' : 'Login'),
            ),
            subtitle: Text(
              _parts([
                event['time'],
                event['location'],
                event['ip'],
                event['provider'],
              ]),
            ),
          ),
    ],
  );

  Widget _sessionsSection() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Text(
        context.tr('Active sessions'),
        style: Theme.of(context).textTheme.titleMedium,
      ),
      if (_sessionsLoading)
        const LinearProgressIndicator()
      else if (_sessionsError != null)
        MessageBanner(_sessionsError)
      else if (_sessions.isEmpty)
        const EmptyHint('No active sessions on this device.')
      else
        for (final session in _sessions)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.key_outlined),
            title: Text(session['id']?.toString() ?? context.tr('Session')),
            subtitle: Text(
              _parts([
                session['created_at'],
                session['last_active_at'],
                session['ip'],
              ]),
            ),
          ),
    ],
  );
}

String _parts(Iterable<Object?> values) => values
    .where((value) => value?.toString().isNotEmpty == true)
    .map((value) => value.toString())
    .join(' · ');
