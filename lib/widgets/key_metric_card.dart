import 'package:flutter/material.dart';
import 'package:sso_admin/i18n/app_strings.dart';
import 'package:sso_admin/theme/app_colors.dart';
import 'package:sso_admin/widgets/count_up.dart';
import 'package:sso_admin/widgets/format_helpers.dart';
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
    // R29：深色模式图标/涨跌色用同族 400 提亮变体（danger 2.26→5.29、
    // accentBlue 2.83→5.75）；浅色恒等原色（既有测试锁定浅色规范）。
    final effective = AppColors.semanticFor(
      theme.brightness,
      color,
    );
    final dangerColor = AppColors.semanticFor(
      theme.brightness,
      AppColors.danger,
    );
    final showDelta = delta != null;
    final showSparkline = sparkline != null && sparkline!.isNotEmpty;
    // R64：无障碍——单卡汇总标签（标签: 值 [+涨跌] [趋势]），读屏一次播报，
    // 不依赖视觉顺序（数值在上、标签在下）。
    final trendSummary = showSparkline && sparkline!.length >= 2
        ? context.tr('Trend line, {count} points, range {min}–{max}', {
            'count': formatCount(sparkline!.length),
            'min': formatDecimal(
              sparkline!.reduce((a, b) => a < b ? a : b),
              digits: 1,
            ),
            'max': formatDecimal(
              sparkline!.reduce((a, b) => a > b ? a : b),
              digits: 1,
            ),
          })
        : '';
    final semanticLabel =
        '${context.tr(label)}: ${formatCount(value)}'
        '${showDelta ? ' (${delta! < 0 ? '-' : '+'}${formatPercent(delta!)})' : ''}'
        '${trendSummary.isEmpty ? '' : ' ($trendSummary)'}';
    return Semantics(
      container: true,
      label: semanticLabel,
      excludeSemantics: true,
      child: HoverCard(
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
                        color: effective.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Icon(icon, size: 20, color: effective),
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
                          color: delta! < 0 ? dangerColor : effective,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          '${delta! < 0 ? '' : '+'}${formatPercent(delta!)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: delta! < 0 ? dangerColor : effective,
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
                Sparkline(data: sparkline!, color: effective, height: 28),
              ],
            ],
          ),
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
