import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/widgets/key_metric_card.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/empty_state.dart';

import 'admin_module_groups.dart';
import 'admin_navigation.dart';
import 'device_security_models.dart';
import 'device_security_widgets.dart';

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
    final palette = <Color>[
      AppColors.primary,
      AppColors.warning,
      AppColors.danger,
      AppColors.accentBlue,
    ];
    final total = stats['total'] ?? fleetTotal;
    final suspiciousCount = stats['suspicious'] ?? 0;
    final riskyFraction = total is num && total > 0
        ? (suspiciousCount is num ? suspiciousCount : 0) / total.toDouble()
        : 0.0;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 信任分布条（数据表达：可疑占比一眼可见，色编码）。
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Row(
            children: [
              LocalizedText(
                'Fleet trust distribution',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w600),
              ),
              const Spacer(),
              LocalizedText(
                '{percent}% suspicious',
                args: {'percent': (riskyFraction * 100).round()},
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: riskyFraction > 0.2
                      ? AppColors.danger
                      : riskyFraction > 0.05
                      ? AppColors.warning
                      : AppColors.success,
                ),
              ),
            ],
          ),
        ),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: Container(
            height: 6,
            margin: const EdgeInsets.only(bottom: 12),
            color: AppColors.success.withValues(alpha: 0.15),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: riskyFraction.clamp(0.0, 1.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  gradient: LinearGradient(
                    colors: [AppColors.warning, AppColors.danger],
                  ),
                ),
              ),
            ),
          ),
        ),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var index = 0; index < values.length; index++)
              SizedBox(
                width: 190,
                child: KeyMetricCard(
                  icon: values[index].$3,
                  label: values[index].$1,
                  value: values[index].$2,
                  color: palette[index % palette.length],
                ),
              ),
          ],
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
            child: const LocalizedText('Clear filter'),
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
      leading: Icon(
        Icons.policy_outlined,
        color: adminModuleIconColor(AdminModuleId.deviceSecurity),
      ),
      title: const LocalizedText('Security activity'),
      subtitle: LocalizedText(
        '{count} devices currently require attention',
        args: {'count': events.length},
      ),
      children: events.isEmpty
          ? const [
              EmptyState(
                compact: true,
                icon: Icons.verified_user_outlined,
                title: 'No suspicious or very-low-trust devices found.',
              ),
            ]
          : [
              for (final event in events)
                ListTile(
                  leading: const Icon(
                    Icons.warning_amber_outlined,
                    color: AppColors.danger,
                  ),
                  title: event['device_name']?.toString().isNotEmpty == true
                      ? Text(event['device_name'].toString())
                      : Text(
                          event['device_id']?.toString() ??
                              context.tr('Unknown device'),
                        ),
                  subtitle: Text(
                    'User ${event['user_id'] ?? '—'} · Trust '
                    '${event['trust_score'] ?? '—'} · ${event['time'] ?? ''}',
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

/// 单设备活动调查对话框：loading/error（含重试）/数据三态。
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
    setState(() {
      _error = null;
      _result = null;
    });
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
  Widget build(BuildContext context) => AlertDialog(
    title: const LocalizedText('Device activity'),
    content: SizedBox(
      width: 720,
      height: 520,
      child: _error != null
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.error_outline,
                    size: 40,
                    color: AppColors.danger,
                  ),
                  const SizedBox(height: 12),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Text(
                      '$_error',
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _load,
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const LocalizedText('Retry'),
                  ),
                ],
              ),
            )
          : _result == null
          ? const Center(child: CircularProgressIndicator())
          // 评估为无需 lazy：对话框固定 520 高，可见登录记录约 8 条；
          // LoginHistoryPanel 同时在页面上下文（user_device_security_panel）
          // 使用，改 ListView 需 shrinkWrap 或双语境重构，收益不抵风险。
          : SingleChildScrollView(
              child: LoginHistoryPanel(records: loginHistoryFrom(_result)),
            ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const LocalizedText('Close'),
      ),
    ],
  );
}
