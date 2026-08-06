import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

/// 通用状态筛选下拉（列表页筛选区共用）。
///
/// options: value -> 已注册的 i18n 文案（LocalizedText 自动翻译）。
/// 服务端筛选语义由调用方在 filter 参数中组合（page/total 保持正确）。
class StatusFilterDropdown extends StatelessWidget {
  final String value;
  final Map<String, String> options;
  final ValueChanged<String> onChanged;

  const StatusFilterDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => DropdownButton<String>(
    value: value,
    items: [
      for (final entry in options.entries)
        DropdownMenuItem(value: entry.key, child: LocalizedText(entry.value)),
    ],
    onChanged: (value) {
      if (value == null) return;
      onChanged(value);
    },
  );
}
