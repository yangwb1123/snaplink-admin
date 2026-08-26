import 'package:flutter/material.dart';
import 'package:sso_admin/api/snaplink_admin_api.dart';
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/async_view.dart';
import 'package:sso_admin/widgets/skeleton_list.dart';

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
  int _requestGeneration = 0;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final generation = ++_requestGeneration;
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
      if (mounted && generation == _requestGeneration) {
        setState(() => _result = result);
      }
    } catch (error) {
      if (mounted && generation == _requestGeneration) {
        setState(() => _error = error);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.sizeOf(context);
    // AlertDialog adds its title/actions around content. Keeping the content
    // inside the remaining viewport prevents the detail list from clipping on
    // phones and leaves every row in the existing scroll surface.
    final contentWidth = (size.width - 32).clamp(0.0, 720.0).toDouble();
    final contentHeight = (size.height - 176).clamp(0.0, 520.0).toDouble();
    return AlertDialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
      contentPadding: EdgeInsets.zero,
      title: const LocalizedText('Device activity'),
      content: SizedBox(
        width: contentWidth,
        height: contentHeight,
        child: _error != null
            // R38：错误态统一 ErrorStateView（图标 + 标题 + 明细 + 重试），
            // 替代手写 icon/text/retry 模板；重试语义不变。
            ? ErrorStateView(message: '$_error', onRetry: _load)
            : _result == null
            // R38：数据加载统一骨架（登录历史列表行形态），替代加载圈。
            ? const SkeletonListTile(itemCount: 3)
            // 评估为无需 lazy：对话框内容有界且可滚动，可见登录记录约 8 条；
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
}
