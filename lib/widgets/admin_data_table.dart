import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'admin_data_table/header_cell.dart';
import 'admin_data_table/table_cells.dart';

export 'admin_data_table/table_cells.dart' show TableCellText, CopyableCell;

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
    final columnSum = widget.columns
            .fold<double>(0, (sum, c) => sum + (c.width ?? 160)) +
        64;
    // minWidth 小于列总宽时取列总宽：header/data Row 在 tight 宽度下会
    // 溢出（表头 Row 溢出即此 bug 的渲染症状）。
    final tableWidth = math.max(widget.minWidth ?? 0, columnSum);

    // 卡片模式：父级可用宽度 < 640 且宽度有界（无界宽度 = 横向滚动容器内
    // 宿主 → 回退表格模式，防 unbounded 异常）。
    return LayoutBuilder(
      builder: (context, constraints) {
        if (!constraints.hasBoundedWidth || constraints.maxWidth >= 640) {
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
        return _cards(theme);
      },
    );
  }

  // ---- 卡片模式（窄视口） ----

  /// 具名列：label 非空的列（主字段/细节字段的候选）。
  List<AdminDataColumn> get _namedColumns =>
      widget.columns.where((c) => c.label.isNotEmpty).toList();

  /// 主字段：首个 `cardPrimary` 列，缺省 = 首个具名列。
  AdminDataColumn? get _cardPrimaryColumn {
    for (final column in widget.columns) {
      if (column.cardPrimary) return column;
    }
    final named = _namedColumns;
    return named.isEmpty ? null : named.first;
  }

  /// 细节字段：`cardDetail` 列，缺省 = 主字段之后的 2 个具名列。
  List<AdminDataColumn> get _cardDetailColumns {
    final flagged = widget.columns.where((c) => c.cardDetail).toList();
    if (flagged.isNotEmpty) return flagged;
    final named = _namedColumns;
    if (named.isEmpty) return const [];
    final primary = _cardPrimaryColumn;
    if (primary == null) return const [];
    return named.skip(named.indexOf(primary) + 1).take(2).toList();
  }

  /// 前导列（Checkbox 等）：首个空 label 列原样复用。
  AdminDataColumn? get _cardLeading {
    for (final column in widget.columns) {
      if (column.label.isEmpty) return column;
    }
    return null;
  }

  /// 尾随列（PopupMenuButton 等）：末尾空 label 列原样复用。
  AdminDataColumn? get _cardTrailing {
    AdminDataColumn? trailing;
    for (final column in widget.columns) {
      if (column.label.isEmpty) trailing = column;
    }
    return trailing;
  }

  Widget _cards(ThemeData theme) {
    final cards = <Widget>[
      _sortBar(theme),
      for (var i = 0; i < widget.itemCount; i++) _dataCard(theme, i),
    ];
    if (widget.scrollable) {
      return SingleChildScrollView(
        scrollDirection: Axis.vertical,
        child: Column(children: cards),
      );
    }
    return Column(children: cards);
  }

  /// 排序条：可排序列 → ChoiceChip（仅 onSort != null 时渲染）。
  Widget _sortBar(ThemeData theme) {
    final sortable = widget.columns
        .where((c) => c.sortable && widget.onSort != null)
        .toList();
    if (sortable.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final column in sortable) ...[
            ChoiceChip(
              label: Text(column.label, style: const TextStyle(fontSize: 12)),
              selected: widget.sortColumn == column.id,
              onSelected: (_) => widget.onSort!(column.id),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }

  Widget _dataCard(ThemeData theme, int i) {
    final leading = _cardLeading;
    var trailing = _cardTrailing;
    if (identical(leading, trailing)) trailing = null;
    final primary = _cardPrimaryColumn;
    final details = _cardDetailColumns;
    return MouseRegion(
      onEnter: (_) => setState(() => _hoveredRow = i),
      onExit: (_) => setState(() => _hoveredRow = null),
      child: InkWell(
        onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(i),
        onLongPress: widget.onRowLongPress == null
            ? null
            : () => widget.onRowLongPress!(i),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _hoveredRow == i
                ? theme.colorScheme.primary.withValues(alpha: 0.05)
                : null,
            border: Border.all(
              color: theme.colorScheme.outlineVariant.withValues(alpha: 0.4),
            ),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            children: [
              if (leading != null) leading.builder(context, i),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (primary != null) _cardCell(primary, i, primary: true),
                    for (final column in details) _cardCell(column, i),
                  ],
                ),
              ),
              if (trailing != null) trailing.builder(context, i),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right,
                size: 20,
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// 卡片单元格：可提取文本的单元格渲染为指定样式的 Text
  /// （主字段 titleSmall w600；细节字段 bodySmall + `label: value`），
  /// 其余（StatusChip 等）原样复用 builder 产物。
  Widget _cardCell(AdminDataColumn column, int i, {bool primary = false}) {
    final theme = Theme.of(context);
    final built = column.builder(context, i);
    final value = _cellValue(built);
    if (value == null) return built;
    if (primary) {
      return Text(
        value,
        style: theme.textTheme.titleSmall?.copyWith(
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return Text(
      '${column.label}: $value',
      style: theme.textTheme.bodySmall?.copyWith(
        color: theme.colorScheme.onSurfaceVariant,
      ),
    );
  }

  static String? _cellValue(Widget widget) {
    if (widget is Text) return widget.data;
    if (widget is TableCellText) return widget.text;
    if (widget is CopyableCell) return widget.text;
    return null;
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
              AdminDataTableHeaderCell(
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

  /// 卡片模式主字段（缺省自动派生：首个具名列）。
  final bool cardPrimary;

  /// 卡片模式细节字段（缺省自动派生：主字段后 2 个具名列）。
  final bool cardDetail;

  final Widget Function(BuildContext context, int rowIndex) builder;

  const AdminDataColumn({
    required this.id,
    required this.label,
    this.width,
    this.sortable = false,
    this.cardPrimary = false,
    this.cardDetail = false,
    required this.builder,
  });
}

