import 'package:flutter/material.dart';

/// 数字滚动动画（count-up）：统计卡数值从 0 滚动到目标值（Stripe 质感）。
///
/// 有限动画（600ms），测试 settle 安全。支持整数与一位小数。
class CountUp extends StatelessWidget {
  final num value;
  final TextStyle? style;
  final int fractionDigits;

  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.fractionDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, animated, _) => Text(
        animated.toStringAsFixed(fractionDigits),
        style: style,
      ),
    );
  }
}
