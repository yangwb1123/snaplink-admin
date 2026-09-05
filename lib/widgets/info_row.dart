import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show Clipboard, ClipboardData;
import 'package:sso_admin/i18n/localized_text.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';

/// 详情页统一信息行（label + value 两列）。
///
/// 取代各页私有 `_InfoRow` / `_infoRow` 的共享实现，行为与既有页面一致：
/// - 布局语义不变：垂直 4px 间距、label 固定列宽、值自动换行；
/// - label 走 [LocalizedText]（i18n 键）；API/资源值保持 [Text]（不翻译）；
/// - 空值统一渲染 '—'；
/// - 可选 label 前置图标（默认 colorScheme 中性色，详情页可传模块组色）；
/// - 可选值强调级别（[DataEmphasisLevel]）与危险色（colorScheme.error，
///   双模式对比安全）；
/// - 可选复制按钮（点击复制 + SnackBar 反馈，与 CopyableCell 同款文案）。
class InfoRow extends StatelessWidget {
  /// 本地化 label 键（同 [LocalizedText]）。
  final String label;

  /// 值文本（API/资源原样渲染，不做翻译）。
  final String value;

  /// label 列宽：webhook 80 / connection 100 / client & break-glass 120。
  final double labelWidth;

  /// 可选 label 前置图标。
  final IconData? icon;

  /// 图标颜色（null = colorScheme.onSurfaceVariant；详情页可传组色）。
  final Color? iconColor;

  /// 值强调级别（null = 默认正文样式）。
  final DataEmphasisLevel? level;

  /// 危险色值（优先于 [level]）。
  final bool danger;

  /// 提供后显示复制按钮，复制 [copyValue]（缺省复制 [value]）。
  final String? copyValue;

  const InfoRow({
    super.key,
    required this.label,
    required this.value,
    this.labelWidth = 120,
    this.icon,
    this.iconColor,
    this.level,
    this.danger = false,
    this.copyValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final displayValue = value.isEmpty ? '—' : value;
    final valueStyle = danger
        ? theme.textTheme.bodyMedium?.copyWith(color: colorScheme.error)
        : level != null
        ? dataEmphasisStyle(level!, theme)
        : null;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 16,
              color: iconColor ?? colorScheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
          ],
          SizedBox(
            width: labelWidth,
            child: LocalizedText(
              label,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ),
          Expanded(child: Text(displayValue, style: valueStyle)),
          if (copyValue != null)
            IconButton(
              icon: const Icon(Icons.copy_outlined, size: 16),
              tooltip: 'Copy to clipboard'.localized,
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              // VisualDensity.compact subtracts from these constraints. Keep the
              // explicit minimum at 56 so the effective touch target remains
              // at least kMinInteractiveDimension (48) on both axes.
              constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: copyValue!));
                if (!context.mounted) return;
                showCopySnackBar(
                  context,
                  content: const LocalizedText('Copied to clipboard'),
                );
              },
            ),
        ],
      ),
    );
  }
}
