import 'package:flutter/material.dart';
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
    return SizedBox(
      width: width ?? column.width ?? 160,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: headerPadding),
        child: sortable
            ? InkWell(
                onTap: onTap,
                borderRadius: BorderRadius.circular(8),
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
