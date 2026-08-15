import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/i18n/localized_text.dart';

import 'device_security_models.dart';
import 'device_security_widgets.dart';

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
                  // R29：dark 下提亮（2.26→5.29:1 ≥AA），浅色恒等。
                  Icon(
                    Icons.error_outline,
                    size: 40,
                    color: AppColors.semanticFor(
                      Theme.of(context).brightness,
                      AppColors.danger,
                    ),
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
