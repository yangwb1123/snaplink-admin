import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/status_chip.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:sso_admin/widgets/empty_state.dart';
import 'package:sso_admin/widgets/format_helpers.dart';

import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'device_security_models.dart';

typedef DeviceAction = void Function(DeviceJson device);

class DeviceListPanel extends StatelessWidget {
  final String title;
  final Map<String, Object?>? titleArgs;
  final List<DeviceJson> devices;
  final String emptyMessage;
  final DeviceAction? onActivity;
  final DeviceAction? onResetTrust;
  final DeviceAction? onRevoke;
  final bool actionsEnabled;

  const DeviceListPanel({
    super.key,
    required this.title,
    this.titleArgs,
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
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              Icon(
                Icons.devices_other,
                color: adminModuleIconColor(AdminModuleId.deviceSecurity),
              ),
              const SizedBox(width: 8),
              LocalizedText(
                title,
                args: titleArgs,
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  '${devices.length}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
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
          AdminDataTable(
            minWidth: 820,
            columns: [
              AdminDataColumn(
                id: 'avatar',
                label: '',
                width: 56,
                builder: (_, i) => _deviceAvatar(context, devices[i]),
              ),
              AdminDataColumn(
                id: 'device',
                label: 'Device',
                width: 200,
                cardPrimary: true,
                builder: (_, i) => TableCellText(
                  _deviceName(devices[i]),
                  level: DataEmphasisLevel.primary,
                ),
              ),
              AdminDataColumn(
                id: 'details',
                label: 'Details',
                cardDetail: true,
                builder: (_, i) {
                  final details = _deviceDetails(devices[i]);
                  return TableCellText(
                    details.isEmpty ? 'No activity metadata' : details.join(' · '),
                    muted: true,
                    maxLines: 2,
                  );
                },
              ),
              AdminDataColumn(
                id: 'trust',
                label: 'Trust',
                builder: (_, i) {
                  final device = devices[i];
                  return Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      _TrustChip(device: device),
                      if (device['suspicious'] == true)
                        StatusChip(
                          label: 'Suspicious',
                          color: AppColors.warning,
                          icon: Icons.warning_amber_outlined,
                        ),
                    ],
                  );
                },
              ),
              AdminDataColumn(
                id: 'actions',
                label: '',
                width: 64,
                builder: (_, i) => _deviceActionsMenu(
                  devices[i],
                  onActivity: onActivity,
                  onResetTrust: onResetTrust,
                  onRevoke: onRevoke,
                  actionsEnabled: actionsEnabled,
                ),
              ),
            ],
            itemCount: devices.length,
            rowBuilder: (_, _) => const SizedBox.shrink(),
          ),
      ],
    ),
  );

  Widget _deviceAvatar(BuildContext context, DeviceJson device) {
    final suspicious = device['suspicious'] == true;
    return CircleAvatar(
      backgroundColor: suspicious
          ? AppColors.danger.withValues(alpha: 0.12)
          : AppColors.accentBlue.withValues(alpha: 0.12),
      // R29：dark 下提亮（danger 2.26 / accentBlue 2.83 → 5.29-5.75 ≥AA
      // 非文本），浅色恒等。
      foregroundColor: AppColors.semanticFor(
        Theme.of(context).brightness,
        suspicious ? AppColors.danger : AppColors.accentBlue,
      ),
      child: Icon(_deviceIcon(device['type']?.toString()), size: 18),
    );
  }

  Widget _deviceActionsMenu(
    DeviceJson device, {
    DeviceAction? onActivity,
    DeviceAction? onResetTrust,
    DeviceAction? onRevoke,
    required bool actionsEnabled,
  }) {
    if (onActivity == null && onResetTrust == null && onRevoke == null) {
      return const SizedBox.shrink();
    }
    return PopupMenuButton<String>(
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
          PopupMenuItem(
            value: 'revoke',
            child: ListTile(
              // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
              leading: Icon(
                Icons.phonelink_erase,
                color: AppColors.semanticFor(
                  Theme.of(context).brightness,
                  AppColors.danger,
                ),
              ),
              title: const LocalizedText('Revoke device'),
              contentPadding: EdgeInsets.zero,
            ),
          ),
      ],
    );
  }
}

String _deviceName(DeviceJson device) =>
    device['device_name']?.toString().trim().isNotEmpty == true
        ? device['device_name'].toString()
        : '${device['platform'] ?? 'Unknown'} ${device['type'] ?? 'device'}';

List<String> _deviceDetails(DeviceJson device) => [
  if (device['user_id']?.toString().isNotEmpty == true)
    'User ${device['user_id']}',
  if (device['last_ip']?.toString().isNotEmpty == true)
    'IP ${device['last_ip']}',
  if (device['last_location']?.toString().isNotEmpty == true)
    device['last_location'].toString(),
  if (device['last_seen_at']?.toString().isNotEmpty == true)
    'Last seen ${_readableTime(device['last_seen_at'])}',
];

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
              Icon(
                Icons.manage_history,
                color: adminModuleIconColor(AdminModuleId.deviceSecurity),
              ),
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
        success ? Icons.login_outlined : Icons.gpp_bad_outlined,
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

class _TrustChip extends StatelessWidget {
  final DeviceJson device;

  const _TrustChip({required this.device});

  @override
  Widget build(BuildContext context) {
    final score = deviceTrustScore(device);
    final label = device['trust_label']?.toString().trim().isNotEmpty == true
        ? device['trust_label'].toString()
        : formatPercent(score * 100);
    final color = score < 0.3
        ? AppColors.danger
        : score < 0.6
        ? AppColors.warning
        : AppColors.success;
    return StatusChip(label: label, color: color, icon: Icons.shield_outlined);
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

String _readableTime(Object? value) => formatLocalTime(value);
