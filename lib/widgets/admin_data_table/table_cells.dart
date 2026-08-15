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

  const CopyableCell({
    super.key,
    required this.text,
    required this.contextProvider,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    if (!enabled) {
      return TableCellText(text, bold: true, maxLines: 1);
    }
    return Tooltip(
      message: context.tr('Click to copy'),
      triggerMode: TooltipTriggerMode.tap,
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: text));
          if (ScaffoldMessenger.maybeOf(contextProvider()) == null) return;
          showAppSnackBar(
            contextProvider(),
            content: Text(
              AppStrings.of(
                contextProvider(),
              ).translate('Copied to clipboard'),
            ),
            duration: const Duration(seconds: 1),
          );
        },
        borderRadius: BorderRadius.circular(8),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: TableCellText(text, bold: true, maxLines: 1)),
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
    );
  }
}
