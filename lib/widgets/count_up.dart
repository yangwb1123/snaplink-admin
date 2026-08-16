import 'package:flutter/material.dart';
import 'format_helpers.dart';

/// 数字滚动动画（count-up）：统计卡数值从 0 滚动到目标值（Stripe 质感）。
///
/// 有限动画（600ms），测试 settle 安全。支持整数与一位小数。
/// R64：系统「减少动态效果」开启时直渲终值（数据刷新语义不变）。
class CountUp extends StatelessWidget {
  /// 滚动目标数值。
  final num value;

  /// 数字文本样式（缺省主题默认）。
  final TextStyle? style;

  /// 小数位数（默认 0 = 整数）。
  final int fractionDigits;

  const CountUp({
    super.key,
    required this.value,
    this.style,
    this.fractionDigits = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return Text(
        fractionDigits == 0
            ? formatCount(value)
            : value.toDouble().toStringAsFixed(fractionDigits),
        style: style,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      builder: (context, animated, _) => Text(
        fractionDigits == 0
            ? formatCount(animated)
            : animated.toStringAsFixed(fractionDigits),
        style: style,
      ),
    );
  }
}
