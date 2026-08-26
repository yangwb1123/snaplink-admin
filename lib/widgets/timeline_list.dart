import 'dart:ui' show SemanticsRole;

import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'staggered_fade_in.dart';

/// 时间线列表（审计/活动流）：圆点 + 竖线连接 + 内容。
///
/// 每项：[leading] 状态图标、[title]、[subtitle]（时间/位置等）。
/// 语义色编码状态（成功/危险/警告/中性），竖线淡色贯穿。
/// 每项暴露为可读的 listItem 语义；空列表不渲染业务空态。入场动画：每项
/// 按序号交错 fade-in（R7 约定），并遵守 reduced-motion。
class TimelineList extends StatelessWidget {
  final List<TimelineItem> items;

  const TimelineList({super.key, required this.items});

  @override
  Widget build(BuildContext context) {
    // Empty rendering belongs to the page because its copy and action are
    // business-specific. Keep the shared timeline a zero-size layout helper.
    if (items.isEmpty) return const SizedBox.shrink();

    final scheme = Theme.of(context).colorScheme;
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final children = <Widget>[
      for (var index = 0; index < items.length; index++)
        _timelineEntry(
          scheme,
          items[index],
          index,
          isLast: index == items.length - 1,
          reduceMotion: reduceMotion,
        ),
    ];
    return Semantics(
      container: true,
      role: SemanticsRole.list,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _timelineEntry(
    ColorScheme scheme,
    TimelineItem item,
    int index, {
    required bool isLast,
    required bool reduceMotion,
  }) {
    final entry = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          container: true,
          role: SemanticsRole.listItem,
          label: _timelineItemLabel(item),
          excludeSemantics: true,
          child: _TimelineRow(item: item),
        ),
        if (!isLast)
          Container(
            // 竖线在 30px 圆点轨道内居中（2px 线居中于 x=15），与点对齐。
            width: 30,
            alignment: Alignment.center,
            child: Container(
              width: 2,
              height: 12,
              color: scheme.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
      ],
    );
    return reduceMotion ? entry : StaggeredFadeIn(index: index, child: entry);
  }

  String _timelineItemLabel(TimelineItem item) {
    final parts = <String>[
      if (item.title.isNotEmpty) item.title,
      if (item.subtitle?.isNotEmpty == true) item.subtitle!,
    ];
    return parts.join(', ');
  }
}

/// 时间线条目：状态图标 + 标题 + 可选副标题。
class TimelineItem {
  /// 状态图标（语义色编码：成功/危险/警告/中性）。
  final IconData icon;

  /// 圆点/图标语义色；null = 主题 primary。
  final Color? color;

  /// 条目标题（资源/事件名称）。
  final String title;

  /// 副标题（时间/位置等）；null = 不渲染。
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

  const _TimelineRow({required this.item});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    // Timeline callers use the shared light-theme semantic colors. Resolve
    // those colors for dark surfaces so warning/danger icons remain legible.
    final baseColor = item.color ?? scheme.primary;
    final color = AppColors.semanticFor(theme.brightness, baseColor);
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
                  style: Theme.of(
                    context,
                  ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
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
