import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/count_up.dart';
import 'package:sso_admin/widgets/hover_card.dart';
import 'package:sso_admin/widgets/sparkline.dart';

/// 指标卡（Stripe/Supabase 风格）：图标圆底 + 数值 + 标签 + 可选真实
/// delta/迷你趋势图/说明。
///
/// 数据诚实规则（T-KM-02/05 强制）：`delta == null` → 不渲染任何箭头；
/// `sparkline` 为空 → 不渲染 Sparkline；`icon == null` → 无图标圆底。
/// delta 为负数时使用 danger 色；否则使用卡片色。
class KeyMetricCard extends StatelessWidget {
  /// i18n source key (rendered via context.tr).
  final String label;

  /// CountUp-animated value.
  final num value;

  /// REAL % change; null => NO arrow at all (honesty rule).
  final num? delta;

  /// REAL series; null/empty => NO Sparkline (honesty rule).
  final List<num>? sparkline;

  /// null => no icon circle.
  final IconData? icon;

  /// AppColors/theme color only.
  final Color color;

  /// i18n source key; rendered under the label.
  final String? caption;

  final int fractionDigits;

  const KeyMetricCard({
    super.key,
    required this.label,
    required this.value,
    this.delta,
    this.sparkline,
    this.icon,
    this.color = AppColors.primary,
    this.caption,
    this.fractionDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final showDelta = delta != null;
    final showSparkline = sparkline != null && sparkline!.isNotEmpty;
    return HoverCard(
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (icon != null) ...[
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: color.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(icon, size: 20, color: color),
                    ),
                    const Spacer(),
                  ],
                  if (showDelta)
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          delta! < 0
                              ? Icons.arrow_downward
                              : Icons.arrow_upward,
                          size: 14,
                          color: delta! < 0 ? AppColors.danger : color,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${delta! < 0 ? '' : '+'}${delta!.toStringAsFixed(0)}%',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: delta! < 0 ? AppColors.danger : color,
                          ),
                        ),
                      ],
                    )
                  else
                    const Spacer(),
                ],
              ),
              const SizedBox(height: 12),
              CountUp(
                value: value,
                fractionDigits: fractionDigits,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.5,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                context.tr(label),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (caption != null) ...[
                const SizedBox(height: 4),
                Text(
                  context.tr(caption!),
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant.withValues(
                      alpha: 0.7,
                    ),
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              if (showSparkline) ...[
                const SizedBox(height: 8),
                Sparkline(data: sparkline!, color: color, height: 28),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Wrap of fixed-width [KeyMetricCard]s; flows to rows on narrow screens.
class MetricStrip extends StatelessWidget {
  /// 指标卡列表。
  final List<KeyMetricCard> cards;

  /// 每张卡固定宽度（默认 190）。
  final double cardWidth;

  /// 行内/行间间距（默认 12）。
  final double spacing;

  const MetricStrip({
    super.key,
    required this.cards,
    this.cardWidth = 190,
    this.spacing = 12,
  });

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: spacing,
    runSpacing: spacing,
    children: [
      for (final card in cards) SizedBox(width: cardWidth, child: card),
    ],
  );
}
