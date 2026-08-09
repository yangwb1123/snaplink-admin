import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';
import 'package:flutter/services.dart';

/// Row/header spacing density. Page-level opt-in knob only; affects spacing,
/// never fonts (11/13 fixed). Default `comfortable` = today's pixels exactly.
enum TableDensity { comfortable, compact }

/// 管理后台数据表格（Stripe/Supabase 风格）：
/// 列对齐、点击表头排序、斑马纹、行 hover、窄视口横向滚动。
///
/// 桌面管理后台的标志性元素——替代手机风格的 ListTile 列表。
class AdminDataTable extends StatefulWidget {
  final List<AdminDataColumn> columns;
  final int itemCount;
  final Widget Function(BuildContext context, int index) rowBuilder;
  final String? sortColumn;
  final bool sortAscending;
  final ValueChanged<String>? onSort;
  final double? minWidth;
  final void Function(int rowIndex)? onRowTap;
  final void Function(int rowIndex)? onRowLongPress;

  /// 表格自身是否垂直滚动（页面滚动容器内为 false；Expanded 内为 true）。
  final bool scrollable;

  /// Page-level density knob (default = today's rendering, pixel-identical).
  final TableDensity density;

  const AdminDataTable({
    super.key,
    required this.columns,
    required this.itemCount,
    required this.rowBuilder,
    this.sortColumn,
    this.sortAscending = true,
    this.onSort,
    this.minWidth,
    this.onRowTap,
    this.onRowLongPress,
    this.scrollable = false,
    this.density = TableDensity.comfortable,
  });

  @override
  State<AdminDataTable> createState() => _AdminDataTableState();
}

class _AdminDataTableState extends State<AdminDataTable> {
  int? _hoveredRow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tableWidth =
        widget.minWidth ??
        widget.columns.fold<double>(0, (sum, c) => sum + (c.width ?? 160)) + 64;

    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(12),
      ),
      clipBehavior: Clip.antiAlias,
      child: widget.scrollable
          ? SingleChildScrollView(
              scrollDirection: Axis.vertical,
              child: _table(theme, tableWidth),
            )
          : _table(theme, tableWidth),
    );
  }

  Widget _table(ThemeData theme, double tableWidth) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: tableWidth),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 表头。
            _headerRow(theme, tableWidth),
            // 数据行（斑马纹 + hover + 行点击）。
            for (var i = 0; i < widget.itemCount; i++)
              _dataRow(theme, tableWidth, i),
          ],
        ),
      ),
    );
  }

  Widget _headerRow(ThemeData theme, double tableWidth) {
    return Container(
      color: theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
      child: SizedBox(
        width: tableWidth,
        child: Row(
          children: [
            for (final column in widget.columns)
              _HeaderCell(
                column: column,
                sorted: widget.sortColumn == column.id,
                ascending: widget.sortAscending,
                sortable: column.sortable && widget.onSort != null,
                density: widget.density,
                onTap: column.sortable && widget.onSort != null
                    ? () => widget.onSort!(column.id)
                    : null,
              ),
          ],
        ),
      ),
    );
  }

  Widget _dataRow(ThemeData theme, double tableWidth, int i) {
    final rowPadding = widget.density == TableDensity.compact ? 5.0 : 10.0;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRow = i),
      onExit: (_) => setState(() => _hoveredRow = null),
      child: SizedBox(
        width: tableWidth,
        child: InkWell(
          onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(i),
          onLongPress: widget.onRowLongPress == null
              ? null
              : () => widget.onRowLongPress!(i),
          child: Container(
            color: _hoveredRow == i
                ? theme.colorScheme.primary.withValues(alpha: 0.05)
                : i.isEven
                ? null
                : theme.colorScheme.surfaceContainerHighest.withValues(
                    alpha: 0.3,
                  ),
            child: Row(
              children: [
                for (final column in widget.columns)
                  SizedBox(
                    width: column.width ?? 160,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: rowPadding,
                      ),
                      child: column.builder(context, i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// 表格列定义。
class AdminDataColumn {
  final String id;
  final String label;
  final double? width;
  final bool sortable;
  final Widget Function(BuildContext context, int rowIndex) builder;

  const AdminDataColumn({
    required this.id,
    required this.label,
    this.width,
    this.sortable = false,
    required this.builder,
  });
}

class _HeaderCell extends StatelessWidget {
  final AdminDataColumn column;
  final bool sorted;
  final bool ascending;
  final bool sortable;
  final VoidCallback? onTap;
  final TableDensity density;

  const _HeaderCell({
    required this.column,
    required this.sorted,
    required this.ascending,
    required this.sortable,
    required this.density,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text(
      column.label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        letterSpacing: 0.6,
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
    final headerPadding = density == TableDensity.compact ? 6.0 : 10.0;
    return SizedBox(
      width: column.width ?? 160,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: headerPadding),
        child: sortable
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(6),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        column.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      sorted
                          ? (ascending
                                ? Icons.arrow_upward
                                : Icons.arrow_downward)
                          : Icons.unfold_more,
                      size: 12,
                      color: sorted
                          ? theme.colorScheme.primary
                          : theme.colorScheme.onSurfaceVariant.withValues(
                              alpha: 0.5,
                            ),
                    ),
                  ],
                ),
              )
            : label,
      ),
    );
  }
}

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
      message: 'Click to copy',
      triggerMode: TooltipTriggerMode.tap,
      child: InkWell(
        onTap: () async {
          await Clipboard.setData(ClipboardData(text: text));
          final messenger = ScaffoldMessenger.maybeOf(contextProvider());
          if (messenger != null) {
            messenger.showSnackBar(
              SnackBar(
                content: Text(
                  AppStrings.of(
                    contextProvider(),
                  ).translate('Copied to clipboard'),
                ),
                duration: const Duration(seconds: 1),
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        borderRadius: BorderRadius.circular(6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(child: TableCellText(text, bold: true, maxLines: 1)),
            const SizedBox(width: 4),
            Icon(
              Icons.copy_rounded,
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
