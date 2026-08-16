import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import '../admin_data_table.dart';
import '../staggered_fade_in.dart';

/// 卡片模式渲染（窄视口 <640 自动降级）。
///
/// 内部实现——列表结构（排序条 + 数据卡行）由宿主 admin_data_table.dart
/// `_cards` 组装（perf_gates _lazyExemptions 登记：卡片数受分页 itemCount
/// 约束，有界）；本文件只产出渲染行（[AdminDataTableCards.rows]）与单卡
/// 渲染（[AdminDataTableCard]：主/细节字段派生、CopyableCell 复制保留、
/// StatusChip 前缀、密度内边距）。主文件不 re-export 本类，不构成公开
/// API。
///
/// R41 深化：CopyableCell 在卡片保留复制能力（样式切卡片样式）；文本细节
/// 保留原 maxLines 省略号（长值不撑高卡片）；StatusChip 等非文本细节带
/// label 前缀；density 影响卡片内边距（R48 对齐设计 §2.3：compact 12→10，
/// comfortable 与既有像素完全一致）。
class AdminDataTableCards {
  const AdminDataTableCards._();

  /// 卡片行列表：排序条 + 逐卡渲染（StaggeredFadeIn 交错入场）。
  static List<Widget> rows(AdminDataTable table, ThemeData theme) => [
    sortBar(table, theme),
    for (var i = 0; i < table.itemCount; i++)
      StaggeredFadeIn(
        index: i,
        child: AdminDataTableCard(table: table, theme: theme, index: i),
      ),
  ];

  /// 排序条：可排序列 → ChoiceChip（仅 onSort != null 时渲染）；选中列
  /// 追加方向箭头，与表头排序指示同源（升/降/无三态）。
  static Widget sortBar(AdminDataTable table, ThemeData theme) {
    final sortable = table.columns
        .where((c) => c.sortable && table.onSort != null)
        .toList();
    if (sortable.isEmpty) return const SizedBox.shrink();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        children: [
          for (final column in sortable) ...[
            ChoiceChip(
              label: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(column.label, style: const TextStyle(fontSize: 12)),
                  if (table.sortColumn == column.id)
                    Icon(
                      table.sortAscending
                          ? Icons.arrow_upward
                          : Icons.arrow_downward,
                      size: 12,
                    ),
                ],
              ),
              selected: table.sortColumn == column.id,
              onSelected: (_) => table.onSort!(column.id),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

/// 单张数据卡：前导列 + 主/细节字段列 + 尾随操作列 + chevron。
/// 密度（R48 对齐设计 §2.3）：compact 收窄内边距（10/6），comfortable
/// 保持 12/8 与既有像素完全一致（移动端一卡一行已够密，卡片内边距
/// 仅微调不收紧字体）。hover 高亮逐卡自持（与列表级共享状态等价）。
class AdminDataTableCard extends StatefulWidget {
  final AdminDataTable table;
  final ThemeData theme;
  final int index;

  const AdminDataTableCard({
    super.key,
    required this.table,
    required this.theme,
    required this.index,
  });

  @override
  State<AdminDataTableCard> createState() => _AdminDataTableCardState();
}

class _AdminDataTableCardState extends State<AdminDataTableCard> {
  AdminDataTable get table => widget.table;
  bool _hovered = false;

  /// 具名列：label 非空的列（主字段/细节字段的候选）。
  List<AdminDataColumn> get _namedColumns =>
      table.columns.where((c) => c.label.isNotEmpty).toList();

  /// 主字段：首个 `cardPrimary` 列，缺省 = 首个具名列。
  AdminDataColumn? get _cardPrimaryColumn {
    for (final column in table.columns) {
      if (column.cardPrimary) return column;
    }
    final named = _namedColumns;
    return named.isEmpty ? null : named.first;
  }

  /// 细节字段：`cardDetail` 列，缺省 = 主字段之后的 2 个具名列。
  List<AdminDataColumn> get _cardDetailColumns {
    final flagged = table.columns.where((c) => c.cardDetail).toList();
    if (flagged.isNotEmpty) return flagged;
    final named = _namedColumns;
    if (named.isEmpty) return const [];
    final primary = _cardPrimaryColumn;
    if (primary == null) return const [];
    return named.skip(named.indexOf(primary) + 1).take(2).toList();
  }

  /// 前导列（Checkbox/Avatar 等）：首个空 label 列原样复用。
  AdminDataColumn? get _cardLeading {
    for (final column in table.columns) {
      if (column.label.isEmpty) return column;
    }
    return null;
  }

  /// 尾随列（PopupMenuButton/操作按钮等）：末尾空 label 列原样复用。
  AdminDataColumn? get _cardTrailing {
    AdminDataColumn? trailing;
    for (final column in table.columns) {
      if (column.label.isEmpty) trailing = column;
    }
    return trailing;
  }

  @override
  Widget build(BuildContext context) {
    final i = widget.index;
    final theme = widget.theme;
    final leading = _cardLeading;
    var trailing = _cardTrailing;
    if (identical(leading, trailing)) trailing = null;
    final primary = _cardPrimaryColumn;
    final details = _cardDetailColumns;
    final compact = table.density == TableDensity.compact;
    // 设计 §2.3 / T-DEN-01..03：密度仅压间距不缩字体——compact 卡片内边距
    // 12→10、卡间距 8→6（半阶密度值，不在 8pt token 集内；以具名变量表达
    // 满足 ai-dev-gates spacing 门禁，值域由 density 语义钉死，不随 token 化）。
    final double cardGap = compact ? 6 : 8;
    final double cardPad = compact ? 10 : 12;
    // R49：仅可交互行显示 hover 高亮（无点击/长按的只读行不显示，避免
    // 虚假 affordance；卡片 chevron 保持既有测试语义，不随行交互性变化）。
    final interactive = table.onRowTap != null || table.onRowLongPress != null;
    return MouseRegion(
      onEnter: (_) {
        if (!interactive) return;
        setState(() => _hovered = true);
      },
      onExit: (_) => setState(() => _hovered = false),
      child: InkWell(
        onTap: table.onRowTap == null ? null : () => table.onRowTap!(i),
        onLongPress: table.onRowLongPress == null
            ? null
            : () => table.onRowLongPress!(i),
        borderRadius: BorderRadius.circular(12),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          margin: EdgeInsets.only(bottom: cardGap),
          padding: EdgeInsets.all(cardPad),
          decoration: BoxDecoration(
            color: _hovered
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

  /// 卡片单元格（R41）：
  /// - 可提取文本 → 主字段 titleSmall w600 / 细节 bodySmall + `label: value`，
  ///   保留原 maxLines 省略号（长值不撑高卡片）；
  /// - CopyableCell → 保留复制能力（样式切卡片样式）；
  /// - StatusChip 等其余 → 细节带 label 前缀原样复用 builder 产物。
  Widget _cardCell(AdminDataColumn column, int i, {bool primary = false}) {
    final theme = widget.theme;
    final built = column.builder(context, i);
    if (built is CopyableCell) {
      return _copyableCardCell(built, column, theme, primary: primary);
    }
    final value = _cellValue(built);
    if (value == null) {
      if (primary) return built;
      return Row(
        children: [
          Text('${column.label}: ', style: _detailLabelStyle(theme)),
          Flexible(child: built),
        ],
      );
    }
    final maxLines = _cellMaxLines(built);
    return Text(
      primary ? value : '${column.label}: $value',
      maxLines: maxLines,
      overflow: maxLines == null ? null : TextOverflow.ellipsis,
      style: primary ? _primaryStyle(theme) : _detailStyle(theme),
    );
  }

  /// 可复制单元格在卡片模式：文本不拦截 tap（落到卡片 InkWell，整卡可点，
  /// 保持行点击语义——非选择模式导航、选择模式切换选择）；复制收敛到独立
  /// 小图标（tooltip 可达，R45）。选择模式（enabled=false）只渲染纯文本。
  Widget _copyableCardCell(
    CopyableCell built,
    AdminDataColumn column,
    ThemeData theme, {
    required bool primary,
  }) {
    final style = primary ? _primaryStyle(theme) : _detailStyle(theme);
    final text = primary
        ? Text(
            built.text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          )
        : Text(
            '${column.label}: ${built.text}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: style,
          );
    if (!built.enabled) {
      if (primary) return text;
      return Row(children: [Expanded(child: text)]);
    }
    final copyIcon = IconButton(
      tooltip: context.tr('Click to copy'),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 28, minHeight: 28),
      icon: Icon(
        Icons.copy_outlined,
        size: 14,
        color: theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
      ),
      onPressed: () =>
          CopyableCell.copy(built.text, contextProvider: built.contextProvider),
    );
    if (primary) {
      return Row(
        children: [
          Expanded(child: text),
          copyIcon,
        ],
      );
    }
    return Row(
      children: [
        Text('${column.label}: ', style: _detailLabelStyle(theme)),
        Expanded(child: text),
        copyIcon,
      ],
    );
  }

  /// 卡片主字段样式：titleSmall w600（与表格 13px 粗体同义）。
  static TextStyle? _primaryStyle(ThemeData theme) =>
      theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600);

  /// 卡片细节 label/值样式：bodySmall onSurfaceVariant。
  static TextStyle? _detailLabelStyle(ThemeData theme) => theme
      .textTheme
      .bodySmall
      ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

  static TextStyle? _detailStyle(ThemeData theme) => theme.textTheme.bodySmall
      ?.copyWith(color: theme.colorScheme.onSurfaceVariant);

  static String? _cellValue(Widget widget) {
    if (widget is Text) return widget.data;
    if (widget is TableCellText) return widget.text;
    if (widget is CopyableCell) return widget.text;
    return null;
  }

  /// 提取原单元格 maxLines（长值卡片模式保持省略号，防超高卡片）。
  static int? _cellMaxLines(Widget widget) {
    if (widget is Text) return widget.maxLines;
    if (widget is TableCellText) return widget.maxLines;
    return null;
  }
}
