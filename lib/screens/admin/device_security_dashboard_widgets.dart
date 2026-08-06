import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'device_security_models.dart';

class DeviceStatsCards extends StatelessWidget {
  final Map<String, dynamic> stats;
  final int fleetTotal;

  const DeviceStatsCards({
    super.key,
    required this.stats,
    required this.fleetTotal,
  });

  @override
  Widget build(BuildContext context) {
    final trust = stats['trust_levels'] as Map? ?? const {};
    final risky =
        (trust['Very Low'] as num?)?.toInt() ??
        (trust['very_low'] as num?)?.toInt() ??
        0;
    final values = [
      ('Fleet devices', stats['total'] ?? fleetTotal, Icons.devices),
      ('Suspicious', stats['suspicious'] ?? 0, Icons.warning_amber_outlined),
      ('Very low trust', risky, Icons.shield_outlined),
      ('Platforms', (stats['platforms'] as Map?)?.length ?? 0, Icons.computer),
    ];
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final value in values)
          SizedBox(
            width: 190,
            child: Card(
              child: ListTile(
                leading: Icon(value.$3),
                title: LocalizedText('${value.$2}'),
                subtitle: LocalizedText(value.$1),
              ),
            ),
          ),
      ],
    );
  }
}

class DeviceFleetFilters extends StatelessWidget {
  final TextEditingController userController;
  final TextEditingController platformController;
  final TextEditingController ipController;
  final String deviceType;
  final String trustLevel;
  final bool suspiciousOnly;
  final bool loading;
  final ValueChanged<String> onDeviceTypeChanged;
  final ValueChanged<String> onTrustLevelChanged;
  final ValueChanged<bool> onSuspiciousChanged;
  final VoidCallback onApply;
  final VoidCallback onClear;

  const DeviceFleetFilters({
    super.key,
    required this.userController,
    required this.platformController,
    required this.ipController,
    required this.deviceType,
    required this.trustLevel,
    required this.suspiciousOnly,
    required this.loading,
    required this.onDeviceTypeChanged,
    required this.onTrustLevelChanged,
    required this.onSuspiciousChanged,
    required this.onApply,
    required this.onClear,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          _field(userController, 'User ID', 190),
          _field(platformController, 'Platform (exact)', 170),
          _field(ipController, 'Last IP (exact)', 160),
          _dropdown('Device type', deviceType, const [
            '',
            'browser',
            'mobile',
            'app',
            'desktop',
            'tablet',
            'bot',
          ], onDeviceTypeChanged),
          _dropdown('Trust level', trustLevel, const [
            '',
            'very_low',
            'low',
            'medium',
            'high',
            'very_high',
          ], onTrustLevelChanged),
          FilterChip(
            label: const LocalizedText('Suspicious only'),
            selected: suspiciousOnly,
            onSelected: onSuspiciousChanged,
          ),
          FilledButton(
            onPressed: loading ? null : onApply,
            child: const LocalizedText('Apply filters'),
          ),
          TextButton(
            onPressed: loading ? null : onClear,
            child: const LocalizedText('Clear'),
          ),
        ],
      ),
    ),
  );

  Widget _field(TextEditingController controller, String label, double width) =>
      SizedBox(
        width: width,
        child: TextField(
          controller: controller,
          onSubmitted: (_) => onApply(),
          decoration: InputDecoration(labelText: label.localized),
        ),
      );

  Widget _dropdown(
    String label,
    String value,
    List<String> values,
    ValueChanged<String> changed,
  ) => SizedBox(
    width: 160,
    child: DropdownButtonFormField<String>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label.localized),
      items: [
        for (final item in values)
          DropdownMenuItem(
            value: item,
            child: item.isEmpty
                ? const LocalizedText('Any')
                : LocalizedText(item.replaceAll('_', ' ')),
          ),
      ],
      onChanged: (next) => changed(next ?? ''),
    ),
  );
}

class DeviceSecurityActivityPanel extends StatelessWidget {
  final List<DeviceJson> events;
  final ValueChanged<DeviceJson> onInvestigate;

  const DeviceSecurityActivityPanel({
    super.key,
    required this.events,
    required this.onInvestigate,
  });

  @override
  Widget build(BuildContext context) => Card(
    child: ExpansionTile(
      initiallyExpanded: events.isNotEmpty,
      leading: const Icon(Icons.policy_outlined),
      title: const LocalizedText('Security activity'),
      subtitle: LocalizedText(
        '${events.length} devices currently require attention',
      ),
      children: events.isEmpty
          ? const [
              ListTile(
                leading: Icon(Icons.verified_user_outlined),
                title: LocalizedText(
                  'No suspicious or very-low-trust devices found.',
                ),
              ),
            ]
          : [
              for (final event in events)
                ListTile(
                  leading: const Icon(
                    Icons.warning_amber,
                    color: AppColors.danger,
                  ),
                  title: event['device_name']?.toString().isNotEmpty == true
                      ? Text(event['device_name'].toString())
                      : LocalizedText(
                          event['device_id']?.toString() ?? 'Unknown device',
                        ),
                  subtitle: LocalizedText(
                    'User ${event['user_id'] ?? '—'} · Trust ${event['trust_score'] ?? '—'} · ${event['time'] ?? ''}',
                  ),
                  trailing: TextButton(
                    onPressed: () => onInvestigate(event),
                    child: const LocalizedText('Investigate'),
                  ),
                ),
            ],
    ),
  );
}
