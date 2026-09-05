import 'dart:ui' show SemanticsRole;

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
/// R41 深化：CopyableCell 保留复制；文本细节保留省略号；非文本细节带
/// label 前缀；density 只影响内边距（R48 §2.3：compact 12→10）。
class AdminDataTableCards {
  const AdminDataTableCards._();

  /// 卡片行列表：排序条 + 逐卡渲染（StaggeredFadeIn 交错入场）。
  static List<Widget> rows(
    BuildContext context,
    AdminDataTable table,
    ThemeData theme,
  ) => [
    sortBar(context, table, theme),
    for (var i = 0; i < table.itemCount; i++)
      StaggeredFadeIn(
        index: i,
        child: AdminDataTableCard(table: table, theme: theme, index: i),
      ),
  ];

  /// 排序条：可排序列 → ChoiceChip；选中列追加方向箭头（升/降/无三态）。
  static Widget sortBar(
    BuildContext context,
    AdminDataTable table,
    ThemeData theme,
  ) {
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
                      // R58：方向经语义标签并入 chip label（视觉零变化）。
                      semanticLabel: context.tr(
                        table.sortAscending ? 'Ascending' : 'Descending',
                      ),
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

  @override
  Widget build(BuildContext context) {
    final i = widget.index;
    final theme = widget.theme;
    // R55：列派生每次 build 只遍历列定义一次（此前 5 个 getter ~8 次）；
    // 规则与 R41 一致（主 = cardPrimary/首个具名；细节 = cardDetail/主后 2；
    // 前导/尾随 = 空 label 列首/尾）。
    final plan = _CardColumnPlan.of(table.columns);
    final leading = plan.leading;
    var trailing = plan.trailing;
    if (identical(leading, trailing)) trailing = null;
    final primary = plan.primary;
    final details = plan.details;
    final compact = table.density == TableDensity.compact;
    // 设计 §2.3 / T-DEN-01..03：密度仅压间距不缩字体（compact 内边距
    // 12→10、卡间距 8→6；值域由 density 语义钉死）。
    final double cardGap = compact ? 6 : 8;
    final double cardPad = compact ? 10 : 12;
    // R49：仅可交互行显示 hover 高亮（只读行不显示，避免虚假 affordance）。
    final interactive = table.onRowTap != null || table.onRowLongPress != null;
    // R55：可见单元格只构建一次（语义 label 与渲染共用 builder 产物）。
    final primaryBuilt = primary == null ? null : primary.builder(context, i);
    final detailBuilt = <Widget>[
      for (final column in details) column.builder(context, i),
    ];
    // R51：行级语义——container 单节点承载行 label（与可视文本同源）；
    // 文本 ExcludeSemantics 防重复朗读，交互控件独立可达。
    final label = _semanticsLabel(
      primary,
      details,
      i,
      primaryBuilt: primaryBuilt,
      detailBuilt: detailBuilt,
    );
    return Semantics(
      container: true,
      role: SemanticsRole.listItem,
      label: label,
      child: MouseRegion(
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
                      if (primaryBuilt != null)
                        _cardCell(primary!, primaryBuilt, i, primary: true),
                      for (var k = 0; k < details.length; k++)
                        _cardCell(details[k], detailBuilt[k], i),
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
      ),
    );
  }

  /// R51 行级语义标签（主字段 + 细节 "label: value"；无文本列跳过，全空
  /// 返回 null）。R55：接收已构建单元格，不二次构建。
  String? _semanticsLabel(
    AdminDataColumn? primary,
    List<AdminDataColumn> details,
    int i, {
    required Widget? primaryBuilt,
    required List<Widget> detailBuilt,
  }) {
    final parts = <String>[];
    if (primary != null && primaryBuilt != null) {
      final value = _cellValue(primaryBuilt);
      if (value != null) parts.add(value);
    }
    for (var k = 0; k < details.length; k++) {
      final value = _cellValue(detailBuilt[k]);
      if (value != null) parts.add('${details[k].label}: $value');
    }
    return parts.isEmpty ? null : parts.join(', ');
  }

  /// 卡片单元格（R41；R55 接收已构建产物）：可提取文本 → 主 titleSmall
  /// w600 / 细节 bodySmall + label；CopyableCell 保留复制；其余原样复用。
  Widget _cardCell(
    AdminDataColumn column,
    Widget built,
    int i, {
    bool primary = false,
  }) {
    final theme = widget.theme;
    if (built is CopyableCell) {
      return _copyableCardCell(built, column, theme, primary: primary);
    }
    final value = _cellValue(built);
    if (value == null) {
      if (primary) return built;
      return Row(
        children: [
          ExcludeSemantics(
            excluding: true,
            child: Text('${column.label}: ', style: _detailLabelStyle(theme)),
          ),
          Flexible(child: built),
        ],
      );
    }
    final maxLines = _cellMaxLines(built);
    // R51：文本内容收敛进卡片行级语义 label，防重复朗读（find.text 不受
    // ExcludeSemantics 影响，既有卡片文本断言保持不变）。
    return ExcludeSemantics(
      excluding: true,
      child: Text(
        primary ? value : '${column.label}: $value',
        maxLines: maxLines,
        overflow: maxLines == null ? null : TextOverflow.ellipsis,
        style: primary ? _primaryStyle(theme) : _detailStyle(theme),
      ),
    );
  }

  /// 可复制单元格在卡片模式：文本不拦截 tap（整卡可点，R45 复制收敛到
  /// 小图标）；enabled=false（选择模式）只渲染纯文本。
  Widget _copyableCardCell(
    CopyableCell built,
    AdminDataColumn column,
    ThemeData theme, {
    required bool primary,
  }) {
    final style = primary ? _primaryStyle(theme) : _detailStyle(theme);
    // R51：文本收敛进行级语义 label（复制图标独立可达）。
    final Widget text = primary
        ? ExcludeSemantics(
            excluding: true,
            child: Text(
              built.text,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          )
        : ExcludeSemantics(
            excluding: true,
            child: Text(
              '${column.label}: ${built.text}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: style,
            ),
          );
    if (!built.enabled) {
      if (primary) return text;
      return Row(children: [Expanded(child: text)]);
    }
    final copyIcon = IconButton(
      tooltip: context.tr('Click to copy'),
      visualDensity: VisualDensity.compact,
      padding: EdgeInsets.zero,
      constraints: const BoxConstraints(minWidth: 56, minHeight: 56),
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

/// R55：卡片列派生集中计算（单次遍历）。规则与 R41 一致：主 = cardPrimary
/// 或首个具名；细节 = cardDetail 或主后 2 个具名；前导/尾随 = 空 label
/// 列首/尾。此前 5 个 getter 各自遍历（~8 次 O(columns)），集中后一次。
class _CardColumnPlan {
  final AdminDataColumn? primary;
  final List<AdminDataColumn> details;
  final AdminDataColumn? leading;
  final AdminDataColumn? trailing;

  const _CardColumnPlan._({
    this.primary,
    required this.details,
    this.leading,
    this.trailing,
  });

  static _CardColumnPlan of(List<AdminDataColumn> columns) {
    final named = <AdminDataColumn>[
      for (final column in columns)
        if (column.label.isNotEmpty) column,
    ];
    AdminDataColumn? primary;
    for (final column in columns) {
      if (column.cardPrimary) {
        primary = column;
        break;
      }
    }
    primary ??= named.isEmpty ? null : named.first;
    final flagged = <AdminDataColumn>[
      for (final column in columns)
        if (column.cardDetail) column,
    ];
    final details = flagged.isNotEmpty || primary == null || named.isEmpty
        ? flagged
        : named.skip(named.indexOf(primary) + 1).take(2).toList();
    AdminDataColumn? leading;
    AdminDataColumn? trailing;
    for (final column in columns) {
      if (column.label.isEmpty) {
        leading ??= column;
        trailing = column;
      }
    }
    return _CardColumnPlan._(
      primary: primary,
      details: details,
      leading: leading,
      trailing: trailing,
    );
  }
}
