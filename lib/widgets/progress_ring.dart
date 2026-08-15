import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 圆形进度环（信任分数/健康度）：数值滚动 + 弧线动画（600ms）。
///
/// 用于 0-100 的百分比指标；颜色按分数阈值变化。
class ProgressRing extends StatelessWidget {
  /// 百分比数值（0-100，自动 clamp）。
  final double value;

  /// 环形直径（默认 56）。
  final double size;

  /// 弧线宽度（默认 5）。
  final double strokeWidth;

  /// 中心标签；null = 渲染百分比文本。
  final String? label;

  const ProgressRing({
    super.key,
    required this.value,
    this.size = 56,
    this.strokeWidth = 5,
    this.label,
  });

  Color _colorFor(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (value >= 60) return scheme.primary;
    if (value >= 30) return AppColors.warning;
    return scheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context);
    final theme = Theme.of(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.clamp(0, 100)),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, animated, _) => SizedBox(
        width: size,
        height: size,
        child: Stack(
          fit: StackFit.expand,
          children: [
            CircularProgressIndicator(
              value: animated / 100,
              strokeWidth: strokeWidth,
              strokeCap: StrokeCap.round,
              backgroundColor: color.withValues(alpha: 0.12),
              color: color,
            ),
            Center(
              child: label != null
                  ? Text(label!, style: theme.textTheme.labelLarge)
                  : Text(
                      '${animated.round()}%',
                      style: theme.textTheme.labelLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
