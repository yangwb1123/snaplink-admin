import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/widgets/data_emphasis.dart';

/// Section title row with an optional count pill and trailing action.
///
/// 标题为 i18n 键；[count] 非空时右侧渲染计数胶囊，[action] 占据行尾。
class SectionHeader extends StatelessWidget {
  /// 区块标题（i18n 键）。
  final String title;

  /// 计数胶囊；null = 不渲染徽章。
  final int? count;

  /// 行尾动作（如「查看全部」链接）。
  final Widget? action;

  /// 标题强调级别（默认 secondary）。
  final DataEmphasisLevel level;

  const SectionHeader(
    this.title, {
    super.key,
    this.count,
    this.action,
    this.level = DataEmphasisLevel.secondary,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Text(
          context.tr(title),
          style: dataEmphasisStyle(level, Theme.of(context)),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              '$count',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const Spacer(),
        ?action,
      ],
    );
  }
}
