import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/empty_state.dart';

import 'device_security_models.dart';

typedef DeviceAction = void Function(DeviceJson device);

class DeviceListPanel extends StatelessWidget {
  final String title;
  final List<DeviceJson> devices;
  final String emptyMessage;
  final DeviceAction? onActivity;
  final DeviceAction? onResetTrust;
  final DeviceAction? onRevoke;
  final bool actionsEnabled;

  const DeviceListPanel({
    super.key,
    required this.title,
    required this.devices,
    this.emptyMessage = 'No devices match the current filters.',
    this.onActivity,
    this.onResetTrust,
    this.onRevoke,
    this.actionsEnabled = true,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
          child: Row(
            children: [
              const Icon(Icons.devices_other),
              const SizedBox(width: 8),
              LocalizedText(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Chip(label: LocalizedText('{devices_length}', args: {'devices_length': devices.length})),
            ],
          ),
        ),
        const Divider(height: 1),
        if (devices.isEmpty)
          EmptyState(
            icon: Icons.devices_other_outlined,
            title: 'No devices',
            subtitle: emptyMessage,
          )
        else
          for (var index = 0; index < devices.length; index++) ...[
            DeviceListTile(
              device: devices[index],
              onActivity: onActivity,
              onResetTrust: onResetTrust,
              onRevoke: onRevoke,
              actionsEnabled: actionsEnabled,
            ),
            if (index < devices.length - 1) const Divider(height: 1),
          ],
      ],
    ),
  );
}

class DeviceListTile extends StatelessWidget {
  final DeviceJson device;
  final DeviceAction? onActivity;
  final DeviceAction? onResetTrust;
  final DeviceAction? onRevoke;
  final bool actionsEnabled;

  const DeviceListTile({
    super.key,
    required this.device,
    this.onActivity,
    this.onResetTrust,
    this.onRevoke,
    this.actionsEnabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final suspicious = device['suspicious'] == true;
    final name = device['device_name']?.toString().trim().isNotEmpty == true
        ? device['device_name'].toString()
        : '${device['platform'] ?? 'Unknown'} ${device['type'] ?? 'device'}';
    final details = [
      if (device['user_id']?.toString().isNotEmpty == true)
        'User ${device['user_id']}',
      if (device['last_ip']?.toString().isNotEmpty == true)
        'IP ${device['last_ip']}',
      if (device['last_location']?.toString().isNotEmpty == true)
        device['last_location'].toString(),
      if (device['last_seen_at']?.toString().isNotEmpty == true)
        'Last seen ${_readableTime(device['last_seen_at'])}',
    ];
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: suspicious
            ? AppColors.danger.withValues(alpha: 0.12)
            : AppColors.accentBlue.withValues(alpha: 0.12),
        foregroundColor: suspicious ? AppColors.danger : AppColors.accentBlue,
        child: Icon(_deviceIcon(device['type']?.toString())),
      ),
      title: Wrap(
        spacing: 8,
        runSpacing: 4,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(name),
          _TrustChip(device: device),
          if (suspicious)
            StatusChip(
              label: 'Suspicious',
              color: AppColors.warning,
              icon: Icons.warning_amber,
            ),
        ],
      ),
      subtitle: details.isEmpty
          ? const LocalizedText('No activity metadata')
          : Text(details.join(' · ')),
      trailing: onActivity == null && onResetTrust == null && onRevoke == null
          ? null
          : PopupMenuButton<String>(
              enabled: actionsEnabled,
              tooltip: 'Device actions'.localized,
              onSelected: (action) {
                switch (action) {
                  case 'activity':
                    onActivity?.call(device);
                  case 'trust':
                    onResetTrust?.call(device);
                  case 'revoke':
                    onRevoke?.call(device);
                }
              },
              itemBuilder: (context) => [
                if (onActivity != null)
                  const PopupMenuItem(
                    value: 'activity',
                    child: ListTile(
                      leading: Icon(Icons.history),
                      title: LocalizedText('View activity'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onResetTrust != null)
                  const PopupMenuItem(
                    value: 'trust',
                    child: ListTile(
                      leading: Icon(Icons.restart_alt),
                      title: LocalizedText('Reset trust'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                if (onRevoke != null)
                  const PopupMenuItem(
                    value: 'revoke',
                    child: ListTile(
                      leading: Icon(Icons.phonelink_erase, color: AppColors.danger),
                      title: LocalizedText('Revoke device'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
              ],
            ),
    );
  }
}

class LoginHistoryPanel extends StatelessWidget {
  final String title;
  final List<DeviceJson> records;

  const LoginHistoryPanel({
    super.key,
    this.title = 'Login history',
    required this.records,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              const Icon(Icons.manage_history),
              const SizedBox(width: 8),
              LocalizedText(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ],
          ),
        ),
        const Divider(height: 1),
        if (records.isEmpty)
          const EmptyState(
            icon: Icons.history_toggle_off,
            title: 'No login activity',
            subtitle: 'No login records are available for this scope.',
          )
        else
          for (var index = 0; index < records.length; index++) ...[
            _LoginHistoryTile(record: records[index]),
            if (index < records.length - 1) const Divider(height: 1),
          ],
      ],
    ),
  );
}

class _LoginHistoryTile extends StatelessWidget {
  final DeviceJson record;

  const _LoginHistoryTile({required this.record});

  @override
  Widget build(BuildContext context) {
    final success = record['success'] == true;
    final flags = [
      if (record['device_is_new'] == true) 'New device',
      if (record['location_is_new'] == true) 'New location',
    ];
    final details = [
      if (record['ip']?.toString().isNotEmpty == true) record['ip'].toString(),
      if (record['location']?.toString().isNotEmpty == true)
        record['location'].toString(),
      if (record['provider']?.toString().isNotEmpty == true)
        'via ${record['provider']}',
    ];
    return ListTile(
      leading: Icon(
        success ? Icons.login : Icons.gpp_bad_outlined,
        color: success ? AppColors.success : AppColors.danger,
      ),
      title: Text(_readableTime(record['time'])),
      subtitle: Text(
        [
          if (details.isNotEmpty) details.join(' · '),
          if (flags.isNotEmpty) flags.join(', '),
        ].join('\n'),
      ),
      trailing: success
          ? StatusChip.healthy()
          : StatusChip(
              label: 'Failed',
              color: AppColors.danger,
              icon: Icons.error,
            ),
    );
  }
}

class DeviceActivityDialog extends StatefulWidget {
  final SnaplinkAdminApi api;
  final DeviceJson device;

  const DeviceActivityDialog({
    super.key,
    required this.api,
    required this.device,
  });

  static Future<void> show(
    BuildContext context, {
    required SnaplinkAdminApi api,
    required DeviceJson device,
  }) => showDialog<void>(
    context: context,
    builder: (_) => DeviceActivityDialog(api: api, device: device),
  );

  @override
  State<DeviceActivityDialog> createState() => _DeviceActivityDialogState();
}

class _DeviceActivityDialogState extends State<DeviceActivityDialog> {
  Map<String, dynamic>? _result;
  Object? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final id = deviceId(widget.device);
      if (id.isEmpty) {
        throw StateError('The activity event has no device identifier.');
      }
      final result = await widget.api.get(DeviceSecurityPaths.activity(id));
      if (mounted) setState(() => _result = result);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final records = loginHistoryFrom(_result);
    return AlertDialog(
      title: const LocalizedText('Device activity'),
      content: SizedBox(
        width: 720,
        height: 520,
        child: _error != null
            ? Center(child: LocalizedText('Unable to load activity: {_error}', args: {'_error': _error}))
            : _result == null
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(child: LoginHistoryPanel(records: records)),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const LocalizedText('Close'),
        ),
      ],
    );
  }
}

class _TrustChip extends StatelessWidget {
  final DeviceJson device;

  const _TrustChip({required this.device});

  @override
  Widget build(BuildContext context) {
    final score = deviceTrustScore(device);
    final label = device['trust_label']?.toString().trim().isNotEmpty == true
        ? device['trust_label'].toString()
        : '${(score * 100).round()}%';
    final color = score < 0.3
        ? AppColors.danger
        : score < 0.6
        ? AppColors.warning
        : AppColors.success;
    return Chip(
      avatar: Icon(Icons.shield_outlined, size: 16, color: color),
      label: LocalizedText(label),
      visualDensity: VisualDensity.compact,
    );
  }
}

IconData _deviceIcon(String? type) => switch (type) {
  'mobile' => Icons.smartphone,
  'tablet' => Icons.tablet,
  'desktop' => Icons.desktop_windows,
  'browser' => Icons.public,
  'bot' => Icons.smart_toy_outlined,
  _ => Icons.devices_other,
};

String _readableTime(Object? value) {
  final text = value?.toString() ?? '';
  final parsed = DateTime.tryParse(text);
  return parsed?.toLocal().toString().split('.').first ??
      (text.isEmpty ? 'Unknown time' : text);
}
