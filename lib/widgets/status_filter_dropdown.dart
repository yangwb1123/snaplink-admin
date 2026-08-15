import 'package:flutter/material.dart';
import 'package:sso_admin/widgets/tight_dropdown.dart';

/// 通用状态筛选下拉（列表页筛选区共用）。
///
/// options: value -> 已注册的 i18n 文案（LocalizedText 自动翻译）。
/// 服务端筛选语义由调用方在 filter 参数中组合（page/total 保持正确）。
/// R29：内部使用 [TightDropdownButton]——字体缩放（1.5x/2.0x）下按钮
/// 宽度封顶 + 标签省略号，不再横向溢出（原 DropdownButton 内部 Row
/// 在有界宽度下溢出）。
class StatusFilterDropdown extends StatelessWidget {
  /// 当前选中值（options 键）。
  final String value;

  /// 选项表：value -> i18n 文案键（LocalizedText 自动翻译）。
  final Map<String, String> options;

  /// 选中变化回调（服务端筛选语义由调用方组合）。
  final ValueChanged<String> onChanged;

  const StatusFilterDropdown({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) => TightDropdownButton<String>(
    value: value,
    options: [for (final entry in options.entries) (entry.key, entry.value)],
    maxWidth: 200,
    onChanged: onChanged,
  );
}
