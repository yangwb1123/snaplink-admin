import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/localized_text.dart';

/// 窄约束安全下拉（R29 字体缩放修复）。
///
/// 原生 [DropdownButton] 的按钮内部 Row 是 `mainAxisSize.min` 且选中项
/// 不参与弹性约束——在 Wrap/窄容器给出有界宽度时，长文本（1.5x/2.0x
/// 字体缩放）会让内部 Row 横向溢出（Ahem 测试字体下更明显）。
///
/// 本组件把宽度封顶（[maxWidth]）+ `isExpanded`（选中项进入弹性约束）+
/// 按钮标签单行省略号，三管齐下：按钮永不溢出；弹出菜单项保持完整文本
/// 可换行（可读性不被截断）。浅色/1x 下仅按钮变宽至 [maxWidth]，
/// 交互语义不变。
class TightDropdownButton<T> extends StatelessWidget {
  /// 当前选中值。
  final T value;

  /// 选项：(值, i18n 文案键)。按钮标签与菜单项共用同一文案源。
  final List<(T, String)> options;

  /// 选中变化回调（值恒非空）。
  final ValueChanged<T> onChanged;

  /// 按钮宽度上限；长文本在此宽度内省略号收敛。
  final double maxWidth;

  const TightDropdownButton({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.maxWidth = 220,
  });

  @override
  Widget build(BuildContext context) => ConstrainedBox(
    constraints: BoxConstraints(maxWidth: maxWidth),
    child: DropdownButton<T>(
      value: value,
      isExpanded: true,
      items: [
        for (final (optionValue, label) in options)
          DropdownMenuItem(value: optionValue, child: LocalizedText(label)),
      ],
      // 按钮内选中项：单行省略号（避免换行撑高按钮/横向溢出）；
      // 弹出菜单项（items）不设限，完整文本可换行。
      selectedItemBuilder: (context) => [
        for (final (optionValue, label) in options)
          DropdownMenuItem(
            value: optionValue,
            child: LocalizedText(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
            ),
          ),
      ],
      onChanged: (value) {
        if (value == null) return;
        onChanged(value);
      },
    ),
  );
}
