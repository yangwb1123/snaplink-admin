import 'package:flutter/material.dart';
import 'package:sso_admin/theme/app_colors.dart';

/// 圆形进度环（信任分数/健康度）：数值滚动 + 弧线动画（600ms）。
///
/// 用于 0-100 的百分比指标；颜色按分数阈值变化。
/// R64：dark 下 warning 段用同族 400 提亮（R29 对比度门禁）；无障碍由
/// 静态汇总标签表达（动画中间值不打断读屏）；系统「减少动态效果」时
/// 直渲终态。
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
    final clamped = value.clamp(0, 100);
    if (clamped >= 60) return scheme.primary;
    if (clamped >= 30) {
      // R29：dark 下 amber-600 对深色 surface 仅 2.83:1（非文本 <3），
      // 提亮为 amber-400（8.76:1 ≥AA）；浅色恒等原色。
      return AppColors.semanticFor(
        Theme.of(context).brightness,
        AppColors.warning,
      );
    }
    return scheme.error;
  }

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(context);
    final theme = Theme.of(context);
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    final clamped = value.clamp(0, 100);
    // R64：无障碍——中心文本随动画逐帧变化会打断读屏，用静态汇总标签
    // 替代（final 值），中间帧不进语义树。
    final label = this.label ?? '${clamped.round()}%';
    final child = Stack(
      fit: StackFit.expand,
      children: [
        CircularProgressIndicator(
          value: clamped / 100,
          strokeWidth: strokeWidth,
          strokeCap: StrokeCap.round,
          backgroundColor: color.withValues(alpha: 0.12),
          color: color,
        ),
        Center(
          child: this.label != null
              ? Text(this.label!, style: theme.textTheme.labelLarge)
              : Text(
                  '${clamped.round()}%',
                  style: theme.textTheme.labelLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ],
    );
    return Semantics(
      container: true,
      label: label,
      excludeSemantics: true,
      child: reduceMotion
          ? SizedBox(width: size, height: size, child: child)
          : TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: clamped.toDouble()),
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
                      child: this.label != null
                          ? Text(this.label!, style: theme.textTheme.labelLarge)
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
            ),
    );
  }
}
