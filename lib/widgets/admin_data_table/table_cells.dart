import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/app_snackbar.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';

/// 表格内通用单元格文本。
class TableCellText extends StatelessWidget {
  final String text;
  final bool bold;
  final bool muted;
  final Color? color;
  final int maxLines;

  /// When non-null, overrides [bold]/[muted] at the cell's fixed 13px:
  /// primary → w700 onSurface; secondary → w600 onSurface;
  /// tertiary → w400 onSurfaceVariant. Null = today's behavior.
  final DataEmphasisLevel? level;

  const TableCellText(
    this.text, {
    super.key,
    this.bold = false,
    this.muted = false,
    this.color,
    this.maxLines = 1,
    this.level,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (fontWeight, textColor) = switch (level) {
      DataEmphasisLevel.primary => (
        FontWeight.w700,
        theme.colorScheme.onSurface,
      ),
      DataEmphasisLevel.secondary => (
        FontWeight.w600,
        theme.colorScheme.onSurface,
      ),
      DataEmphasisLevel.tertiary => (
        FontWeight.w400,
        theme.colorScheme.onSurfaceVariant,
      ),
      null => (
        bold ? FontWeight.w600 : FontWeight.w400,
        color ??
            (muted
                ? theme.colorScheme.onSurfaceVariant
                : theme.colorScheme.onSurface),
      ),
    };
    return Text(
      text,
      maxLines: maxLines,
      overflow: maxLines > 1 ? TextOverflow.ellipsis : null,
      style: TextStyle(fontSize: 13, fontWeight: fontWeight, color: textColor),
    );
  }
}

/// 可点击复制单元格（点击复制 + SnackBar 反馈）。
class CopyableCell extends StatelessWidget {
  final String text;
  final BuildContext Function() contextProvider;

  /// 选择模式下禁用复制（点击交给行手势做选择切换）。
  final bool enabled;

  /// 显示样式；null = 表格 13px 粗体（默认行为像素不变）。
  /// 卡片模式传卡片主/细节样式（见 AdminDataTableCardMode）。
  final TextStyle? style;

  const CopyableCell({
    super.key,
    required this.text,
    required this.contextProvider,
    this.enabled = true,
    this.style,
  });

  /// 复制文本 + SnackBar 反馈。表格行内 InkWell 与卡片模式复制图标共用
  /// （R45：卡片整卡可点时复制收敛到图标，行内仍整格复制）。contextProvider
  /// 由宿主传入，跨 Scaffold 场景也能找到 messenger。
  static Future<void> copy(
    String text, {
    required BuildContext Function() contextProvider,
  }) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (ScaffoldMessenger.maybeOf(contextProvider()) == null) return;
    showCopySnackBar(
      contextProvider(),
      content: Text(
        AppStrings.of(contextProvider()).translate('Copied to clipboard'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return TableCellText(text, bold: true, maxLines: 1);
    }
    return Tooltip(
      message: context.tr('Click to copy'),
      triggerMode: TooltipTriggerMode.tap,
      child: InkWell(
        onTap: () => copy(text, contextProvider: contextProvider),
        borderRadius: BorderRadius.circular(8),
        // Copy remains visually compact, but its interactive node meets the
        // Material target even inside compact table rows.
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: kMinInteractiveDimension,
            minHeight: kMinInteractiveDimension,
          ),
          child: Align(
            alignment: Alignment.center,
            widthFactor: 1,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: style == null
                      ? TableCellText(text, bold: true, maxLines: 1)
                      : Text(
                          text,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: style,
                        ),
                ),
                const SizedBox(width: 4),
                Icon(
                  Icons.copy_outlined,
                  size: 12,
                  color: Theme.of(
                    context,
                  ).colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
