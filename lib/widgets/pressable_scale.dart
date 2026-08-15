import 'package:flutter/material.dart';

/// 按钮按压反馈：按下时轻微缩小（0.98），松手回弹（Stripe/Linear 触感）。
///
/// 包在按钮外，不改变按钮本身样式。有限动画（90ms），测试 settle 安全。
class PressableScale extends StatefulWidget {
  /// 被包装的按钮/可点击控件（不改变其样式）。
  final Widget child;

  const PressableScale({super.key, required this.child});

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: (_) => setState(() => _pressed = true),
      onPointerUp: (_) => setState(() => _pressed = false),
      onPointerCancel: (_) => setState(() => _pressed = false),
      child: AnimatedScale(
        scale: _pressed ? 0.98 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOutCubic,
        child: widget.child,
      ),
    );
  }
}
