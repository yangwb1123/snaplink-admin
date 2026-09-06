import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/admin_data_table.dart';

/// 表头单元：排序箭头（↑/↓/unfold_more）+ 密度内边距。
///
/// 内部实现——从 admin_data_table.dart 拆出，随主文件 `_headerRow` 使用，
/// 主文件不 re-export 本类，不构成公开 API。
class AdminDataTableHeaderCell extends StatelessWidget {
  final AdminDataColumn column;

  /// 实际渲染宽度（主文件按空 label 列保底后传入；null = column.width ?? 160）。
  final double? width;

  final bool sorted;
  final bool ascending;
  final bool sortable;
  final VoidCallback? onTap;
  final TableDensity density;

  const AdminDataTableHeaderCell({
    super.key,
    required this.column,
    this.width,
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
    // R58：列头语义——非排序列直接 header 标志；排序列把 header 标志 + 排序
    // 方向（经图标语义标签并入按钮节点，"USER, Ascending"）收敛进表头按钮，
    // 屏幕阅读器朗读列名与排序状态。视觉零变化。
    final sortIcon = Icon(
      sorted
          ? (ascending ? Icons.arrow_upward : Icons.arrow_downward)
          : Icons.unfold_more,
      size: 12,
      semanticLabel: sorted
          ? context.tr(ascending ? 'Ascending' : 'Descending')
          : null,
      color: sorted
          ? theme.colorScheme.primary
          : theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
    );
    return SizedBox(
      width: width ?? column.width ?? 160,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: headerPadding),
        child: sortable
            ? ConstrainedBox(
                constraints: const BoxConstraints(
                  minHeight: kMinInteractiveDimension,
                ),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(8),
                  // Compact density changes spacing, not the interactive
                  // target. Center preserves the existing text/icon visuals.
                  child: Center(
                    child: Semantics(
                      header: true,
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
                          sortIcon,
                        ],
                      ),
                    ),
                  ),
                ),
              )
            : Semantics(header: true, child: label),
      ),
    );
  }
}
