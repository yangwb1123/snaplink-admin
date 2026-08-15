import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/status_chip.dart';

typedef DeviceAction = void Function(Map<String, dynamic> device);

/// Physical-device list row: brand-tinted device icon, name + suspicious
/// StatusChip, platform/browser/IP/last-seen summary, trust + active-session
/// StatusChips, and the action menu (details / rename / trust / lost /
/// delete). Icons are tinted with the portal brand color
/// (`colorScheme.primary`) — admin group colors do not apply to portal
/// surfaces.
class PhysicalDeviceCard extends StatelessWidget {
  final Map<String, dynamic> device;
  final bool busy;
  final DeviceAction onDetails;
  final DeviceAction onEdit;
  final DeviceAction onTrust;
  final DeviceAction onLost;
  final DeviceAction onDelete;

  const PhysicalDeviceCard({
    super.key,
    required this.device,
    required this.busy,
    required this.onDetails,
    required this.onEdit,
    required this.onTrust,
    required this.onLost,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;
    final suspicious = device['suspicious'] == true;
    final name = _deviceName(context, device);
    final trustLabel = device['trust_label'] ?? _score(context, device);
    final trusted = device['trust_label'] == 'trusted';
    final details = <String>[
      if (device['platform']?.toString().isNotEmpty == true)
        device['platform'].toString(),
      if (device['browser_name']?.toString().isNotEmpty == true)
        device['browser_name'].toString(),
      if (device['last_ip']?.toString().isNotEmpty == true)
        device['last_ip'].toString(),
      if (device['last_seen_at']?.toString().isNotEmpty == true)
        context.tr('last seen {time}', {
          'time': _shortTime(device['last_seen_at']),
        }),
    ];
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        onTap: () => onDetails(device),
        leading: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: accent.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            _deviceIcon(device['type']?.toString()),
            size: 21,
            color: accent,
          ),
        ),
        title: Row(
          children: [
            Flexible(
              child: Text(
                name,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (suspicious) ...[
              const SizedBox(width: 8),
              StatusChip(
                label: context.tr('Suspicious'),
                color: AppColors.warning,
                icon: Icons.warning_amber_outlined,
              ),
            ],
          ],
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (details.isNotEmpty) Text(details.join(' · ')),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                StatusChip(
                  label: context.tr('Trust {value}', {
                    'value': trustLabel,
                  }),
                  color: suspicious
                      ? AppColors.warning
                      : trusted
                      ? AppColors.success
                      : AppColors.muted,
                  icon: trusted
                      ? Icons.verified_user_outlined
                      : Icons.shield_outlined,
                ),
                StatusChip(
                  label: context.tr('{count} active sessions', {
                    'count': device['active_sessions'] ?? 0,
                  }),
                  color: AppColors.accentBlue,
                  icon: Icons.devices_outlined,
                ),
              ],
            ),
          ],
        ),
        isThreeLine: true,
        trailing: PopupMenuButton<String>(
          enabled: !busy,
          onSelected: (value) {
            switch (value) {
              case 'details':
                onDetails(device);
              case 'edit':
                onEdit(device);
              case 'trust':
                onTrust(device);
              case 'lost':
                onLost(device);
              case 'delete':
                onDelete(device);
            }
          },
          itemBuilder: (_) => [
            PopupMenuItem(
              value: 'details',
              child: Text(context.tr('View details')),
            ),
            PopupMenuItem(
              value: 'edit',
              child: Text(context.tr('Rename / notes')),
            ),
            PopupMenuItem(
              value: 'trust',
              child: Text(context.tr('Mark trusted')),
            ),
            const PopupMenuDivider(),
            PopupMenuItem(
              value: 'lost',
              child: Text(context.tr('Report lost')),
            ),
            PopupMenuItem(
              value: 'delete',
              child: Text(context.tr('Delete device')),
            ),
          ],
        ),
      ),
    );
  }
}

String _deviceName(BuildContext context, Map<String, dynamic> device) {
  final name = device['device_name']?.toString().trim() ?? '';
  if (name.isNotEmpty) return name;
  final platform = device['platform']?.toString() ?? '';
  final type = device['type']?.toString() ?? context.tr('Device');
  return [platform, type].where((part) => part.isNotEmpty).join(' ');
}

String _score(BuildContext context, Map<String, dynamic> device) {
  final value = device['trust_score'];
  if (value is num) return value.toStringAsFixed(2);
  return context.tr('Unknown');
}

String _shortTime(Object? value) {
  final text = value?.toString() ?? '';
  if (text.length <= 19) return text;
  return text.substring(0, 19).replaceFirst('T', ' ');
}

IconData _deviceIcon(String? type) => switch (type) {
  'mobile' => Icons.smartphone,
  'tablet' => Icons.tablet,
  'desktop' => Icons.desktop_windows,
  'browser' => Icons.language,
  'bot' => Icons.smart_toy_outlined,
  _ => Icons.devices_other,
};
