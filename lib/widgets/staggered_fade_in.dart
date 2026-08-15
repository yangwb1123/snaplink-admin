import 'package:flutter/material.dart';

/// 列表项交错入场：每项 fade-in + 上移，依次延迟（Linear 的列表呼吸感）。
///
/// 用法：把列表项包在 [StaggeredFadeIn] 里，index 传该项序号。
/// 有限动画（总时长 ≤ 490ms），测试 settle 安全；首项无延迟。
class StaggeredFadeIn extends StatelessWidget {
  /// 列表项序号（决定入场延迟；>8 按 8 封顶）。
  final int index;

  /// 被包装的列表项。
  final Widget child;

  const StaggeredFadeIn({super.key, required this.index, required this.child});

  @override
  Widget build(BuildContext context) {
    final clamped = index.clamp(0, 8);
    // 每项在总时长中的延迟窗口：首项立即开始，后续每项晚 30ms。
    final delayMs = clamped * 30;
    final totalMs = 220 + delayMs;
    final begin = delayMs / totalMs;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: totalMs),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) {
        // begin 之前保持隐藏；之后线性推进（模拟延迟启动）。
        final v = ((value - begin) / (1 - begin)).clamp(0.0, 1.0);
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, 8 * (1 - v)),
            child: child,
          ),
        );
      },
      child: child,
    );
  }
}
