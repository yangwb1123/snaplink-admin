import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/format_helpers.dart';

/// One segment of a [DistributionBar].
class DistributionSegment {
  /// 图例文案（i18n 键）。
  final String label;

  /// 段值（非正数不渲染切片与图例）。
  final int value;

  /// 段色（AppColors/主题色）。
  final Color color;

  const DistributionSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  /// Pure fraction math; guarded against non-positive totals.
  double fractionOf(int total) => total <= 0 ? 0 : value / total;
}

/// Proportional distribution bar with legend.
///
/// Honesty rules: a non-positive total renders a muted placeholder track
/// (never a 0% claim); zero-valued segments render no slice and no legend
/// entry. The emphasized segment (persona-selected) renders bold + first.
class DistributionBar extends StatelessWidget {
  final List<DistributionSegment> segments;
  final int? total; // null => sum of segments
  final bool showLegend; // default true
  final double height; // default 8
  final String? emphasizedLabel; // persona-selected segment (i18n key)

  const DistributionBar({
    super.key,
    required this.segments,
    this.total,
    this.showLegend = true,
    this.height = 8,
    this.emphasizedLabel,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final brightness = Theme.of(context).brightness;
    final effectiveTotal =
        total ?? segments.fold<int>(0, (sum, s) => sum + s.value);
    if (effectiveTotal <= 0) {
      return Semantics(
        container: true,
        label: AppStrings.of(context).noData,
        excludeSemantics: true,
        child: Container(
          height: height,
          decoration: BoxDecoration(
            color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(999),
          ),
        ),
      );
    }
    final visible = [
      for (final segment in segments)
        if (segment.value > 0) segment,
    ];
    final ordered = emphasizedLabel == null
        ? visible
        : [
            for (final segment in visible)
              if (segment.label == emphasizedLabel) segment,
            for (final segment in visible)
              if (segment.label != emphasizedLabel) segment,
          ];
    // R64：无障碍——仅色条（showLegend: false）对读屏完全静默，统一由
    // 一个汇总标签表达；浅色恒等原色，dark 下分段色经 semanticFor 提亮
    // （R29 对比度门禁，warning 2.83→8.76:1 ≥AA）。
    final label = ordered
        .map(
          (segment) =>
              '${context.tr(segment.label)} ${formatCount(segment.value)}',
        )
        .join(', ');
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: Container(
              height: height,
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
              child: Row(
                children: [
                  for (final segment in ordered)
                    Expanded(
                      flex: segment.value,
                      child: ColoredBox(
                        color: AppColors.semanticFor(brightness, segment.color),
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (showLegend) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final segment in ordered)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.semanticFor(
                            brightness,
                            segment.color,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      const SizedBox(width: 4),
                      Text(
                        '${context.tr(segment.label)} · ${formatCount(segment.value)}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: scheme.onSurfaceVariant,
                          fontWeight: segment.label == emphasizedLabel
                              ? FontWeight.w700
                              : FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
