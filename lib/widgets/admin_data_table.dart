import 'dart:math' as math;
import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'admin_data_table/card_mode.dart';
import 'admin_data_table/header_cell.dart';
import 'staggered_fade_in.dart';

export 'admin_data_table/table_cells.dart' show TableCellText, CopyableCell;

/// Row/header spacing density. Page-level opt-in knob only; affects spacing,
/// never fonts (11/13 fixed). Default `comfortable` = today's pixels exactly.
enum TableDensity { comfortable, compact }

/// 管理后台数据表格（Stripe/Supabase 风格）：列对齐、点击表头排序、斑马纹、
/// 行 hover、窄视口横向滚动；行/卡按序号交错入场（桌面后台标志性元素）。
class AdminDataTable extends StatefulWidget {
  /// 列定义（宽于 640 时表格模式，否则自动降级卡片模式）。
  final List<AdminDataColumn> columns;

  /// 数据行数（行内容经 [rowBuilder] 按需构建）。
  final int itemCount;

  /// 行单元格构建器（每列调用 column.builder）。
  final Widget Function(BuildContext context, int index) rowBuilder;

  /// 当前排序列 id；null = 未排序。
  final String? sortColumn;

  /// 排序方向（升序 = true）。
  final bool sortAscending;

  /// 表头排序回调（传列 id）；null = 禁用排序。
  final ValueChanged<String>? onSort;

  /// 表格最小宽度（与列总宽取大，防表头溢出）。
  final double? minWidth;

  /// 行点击回调；null = 行不可点。
  final void Function(int rowIndex)? onRowTap;

  /// 行长按回调（批量选择入口）；null = 禁用。
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

  /// 列渲染宽度：显式 width 优先；空 label 列（复选框/操作列）保底 56，
  /// 保证窄列下交互控件不被裁剪且计入总宽（R6-a 操作列可达性）。
  double _columnWidth(AdminDataColumn c) =>
      math.max(c.width ?? 160, c.label.isEmpty ? 56 : 0);

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final columnSum =
        widget.columns.fold<double>(0, (sum, c) => sum + _columnWidth(c)) + 64;
    // minWidth 小于列总宽时取列总宽：header/data Row 在 tight 宽度下会溢出。
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
            child: _table(theme, tableWidth),
          );
        }
        return _cards(theme);
      },
    );
  }

  // ---- 卡片模式（窄视口） ----
  // 列表结构（排序条 + 数据卡行）在此组装（perf_gates _lazyExemptions
  // 登记：卡片数受分页 itemCount 约束，有界）；单卡渲染（主/细节字段
  // 派生、CopyableCell 复制保留、StatusChip 前缀、密度内边距）在
  // admin_data_table/card_mode.dart（AdminDataTableCards.rows +
  // AdminDataTableCard），保持主文件 ≤400 行。

  Widget _cards(ThemeData theme) {
    // R55：rows() 已返回新列表，无需再复制一遍（省一次逐项拷贝）。
    // R58：排序条与数据卡分离——数据卡收敛进 list 语义（listItem 由单卡
    // 渲染持有），排序条与焦点组共用同一 FocusTraversalGroup（方向键在
    // 卡内导航，不逃逸到页面其他焦点）。视觉零变化。
    final rowWidgets = AdminDataTableCards.rows(context, widget, theme);
    final sortBar = rowWidgets.isEmpty
        ? const SizedBox.shrink()
        : rowWidgets.first;
    final cards = <Widget>[
      for (var i = 1; i < rowWidgets.length; i++) rowWidgets[i],
    ];
    final list = FocusTraversalGroup(
      child: Column(
        children: [
          sortBar,
          Semantics(
            role: SemanticsRole.list,
            child: Column(children: cards),
          ),
        ],
      ),
    );
    if (widget.scrollable) {
      return SingleChildScrollView(scrollDirection: Axis.vertical, child: list);
    }
    return list;
  }

  Widget _table(ThemeData theme, double tableWidth) {
    final horizontal = SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: tableWidth),
        // R58：表格语义——数据行收敛进 list（行内逐项 listItem 由
        // _dataRow 持有）；表头不参与列表语义。FocusTraversalGroup 把
        // 表头排序按钮与数据行按钮收敛进同一焦点域（方向键在表格内
        // 导航，Enter 激活行）。视觉零变化。
        child: FocusTraversalGroup(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _headerRow(theme, tableWidth),
              Semantics(
                role: SemanticsRole.list,
                child: Column(
                  children: [
                    for (var i = 0; i < widget.itemCount; i++)
                      _dataRow(theme, tableWidth, i),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
    // scrollable 时表格自滚（固定高容器内纵向滚动）；否则由页面滚动承载。
    if (!widget.scrollable) return horizontal;
    return SingleChildScrollView(
      scrollDirection: Axis.vertical,
      child: horizontal,
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
                width: _columnWidth(column),
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
    // R49：仅可交互行（有点击/长按回调）显示 hover 高亮——只读/禁用行
    // 保持中性底色，避免“可点”的虚假 affordance（行操作约定 a/d）。
    final interactive =
        widget.onRowTap != null || widget.onRowLongPress != null;
    // R58：行收敛进 list 语义（listItem）——屏幕阅读器按“列表项”逐行
    // 朗读；交互行内部 InkWell 按钮节点保留（tap/Enter 可达）。
    return Semantics(
      role: SemanticsRole.listItem,
      child: StaggeredFadeIn(
        index: i,
        child: MouseRegion(
          onEnter: (_) {
            if (!interactive) return;
            setState(() => _hoveredRow = i);
          },
          onExit: (_) => setState(() => _hoveredRow = null),
          child: SizedBox(
            width: tableWidth,
            child: InkWell(
              onTap: widget.onRowTap == null ? null : () => widget.onRowTap!(i),
              onLongPress: widget.onRowLongPress == null
                  ? null
                  : () => widget.onRowLongPress!(i),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 150),
                // A row-level tap/long-press is itself an action target. Keep
                // compact read-only rows compact, while guaranteeing the
                // interactive row does not fall below the 48px touch target.
                constraints: interactive
                    ? const BoxConstraints(minHeight: 48)
                    : null,
                color: interactive && _hoveredRow == i
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
                        width: _columnWidth(column),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: widget.density == TableDensity.compact
                                ? 5.0
                                : 10.0,
                          ),
                          child: column.builder(context, i),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// 表格列定义：标识 / 文案 / 宽度 / 排序与卡片模式元信息 / 单元格构建器。
class AdminDataColumn {
  /// 列唯一标识（排序回调的入参）。
  final String id;

  /// 表头文案；空串 = 无表头（Checkbox/菜单等前导/尾随列）。
  final String label;

  /// 列宽；null = 默认 160。
  final double? width;

  /// 可排序列标记（配合 [AdminDataTable.onSort]）。
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
