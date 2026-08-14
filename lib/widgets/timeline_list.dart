import 'package:flutter/material.dart';

/// 时间线列表（审计/活动流）：圆点 + 竖线连接 + 内容。
///
/// 每项：[leading] 状态图标、[title]、[subtitle]（时间/位置等）。
/// 语义色编码状态（成功/危险/警告/中性），竖线淡色贯穿。
class TimelineList extends StatelessWidget {
  final List<TimelineItem> items;

  const TimelineList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var index = 0; index < items.length; index++) ...[
          _TimelineRow(item: items[index], isLast: index == items.length - 1),
          if (index < items.length - 1)
            Container(
              // 竖线居中于 30px 圆点中心（x=15），与点对齐。
              margin: const EdgeInsets.only(left: 14),
              width: 2,
              height: 12,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
        ],
      ],
    );
  }
}

/// 时间线条目。
class TimelineItem {
  final IconData icon;
  final Color? color;
  final String title;
  final String? subtitle;

  const TimelineItem({
    required this.icon,
    this.color,
    required this.title,
    this.subtitle,
  });
}

class _TimelineRow extends StatelessWidget {
  final TimelineItem item;
  final bool isLast;

  const _TimelineRow({required this.item, required this.isLast});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = item.color ?? scheme.primary;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 状态圆点。
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Container(
            width: 30,
            height: 30,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(item.icon, size: 15, color: color),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.title,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (item.subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    item.subtitle!,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}
